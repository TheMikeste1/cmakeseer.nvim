local Cmakeseer = require("cmakeseer")
local TargetType = require("cmakeseer.cmake.api.codemodel.target").TargetType

---@private
---@class cmakeseer.neotest.gtest.Context
---@field executable string
---@field neotest_id string
---@field id cmakeseer.neotest.gtest.TestId
---@field output_file string

---@private
---@class cmakeseer.neotest.gtest.Test
---@field file string
---@field line integer

---@private
---@class cmakeseer.neotest.gtest.Suite
---@field suite { id: string, prefixes: string[]?, postfixes: string[]? }
---@field tests cmakeseer.neotest.gtest.Test[]

---@private
---@class cmakeseer.neotest.gtest.TestId
---@field file string
---@field suite string?
---@field test string?

---@private
---@class cmakeseer.neotest.gtest.SuitePosition
---@field suite {prefixes: string[], position: neotest.Position}
---@field tests neotest.Position[]

---@private
---@class cmakeseer.neotest.gtest.Positions
---@field file_position neotest.Position
---@field suites table<string, TreesitterTest[]>

---@class cmakeseer.neotest.gtest.ExecutableTests
---@field path string The path to the executable
---@field suites table<string,cmakeseer.neotest.gtest.SuiteTests> The suites contained in an executable.

---@class cmakeseer.neotest.gtest.SuiteName
---@field name string The core name of the suite.
---@field prefixes table<string> The prefixes used by the suite.
---@field postfixes table<string> The postfixes used by the suite.

---@class cmakeseer.neotest.gtest.SuiteTests
---@field names cmakeseer.neotest.gtest.SuiteName The names of the suite, including its prefixes and postfixes.
---@field tests table<string, cmakeseer.neotest.gtest.Test> The tests that are part of this suite.

---@class cmakeseer.neotest.gtest.TestName
---@field name string The core name of the test
---@field postfixes string[] The postfixes used by the test.

---@class cmakeseer.neotest.gtest.Test
---@field names cmakeseer.neotest.gtest.TestName The names of this test, including its postfixes.
---@field path string The path to the file containing the test.
---@field range [integer, integer, integer, integer] The range of the test, recorded in 0-indexed [top-line, top-column, bottom-line, bottom-column].

-- Executables to suites IDs
-- Suite ID to full name
-- Suite to tests
--  - Could be ID or full name; ID might be easiest
-- Cache test directories for easy lookup
-- Cach executables to test files for treesitter queries
--  - Or do we want to run TS while checking the executables?

---@type table<string, table<string>> Executables to test files.
local g_executable_files = {}
---@type table<string> Set of test directories.
local g_test_dirs = {}
---@type table<string, table<string, Suite>> Executables to suite names to Suites.
local g_test_executables_suites = {}

--- Parses the name of a GTest suite into its component parts.
---@param suite table<string, any> The GTest suite to parse.
---@return string? prefix, string? name, string? postfix Maybe the prefix, name, and postfix, in that order. The name will only be nil if there was an error parsing.
local function parse_gtest_suite_name(suite)
  -- The parts might be
  --  a. suite
  --  b. suite/postfix
  --  c. prefix/suite
  --  d. prefix/suite/postfix
  local suite_name_parts = vim.fn.split(suite.name, "/")

  local prefix = nil
  local suite_id = nil
  local postfix = nil

  if #suite_name_parts == 1 then
    suite_id = suite_name_parts[1]
  elseif #suite_name_parts == 2 then
    if #suite.testsuite > 0 then -- If there are no tests, we don't really care about the suite
      -- Parameterized tests (tests with a prefix) will have a value_param as part of the tests in their testsuite
      if suite.testsuite[1].value_param ~= nil then
        prefix = suite_name_parts[1]
        suite_id = suite_name_parts[2]
      else
        suite_id = suite_name_parts[1]
        postfix = suite_name_parts[2]
      end
    end
  elseif suite_name_parts == 3 then
    prefix = suite_name_parts[1]
    suite_id = suite_name_parts[2]
    postfix = suite_name_parts[3]
  end
  return prefix, suite_id, postfix
end

---@class Suite A suite with no additional parameters or values. They have no prefix nor postfix.
---@field name string The name of the suite.
---@field tests table<string> A set of the tests in the suite.

---@class ParameterizedSuite: Suite A suite with parameterized arguments. They have a prefix, but the postfix is added to the individual tests instead.
---@field prefix string The prefix for the test.
---@field value_parameters string[] Value parameter IDs to values. The postfix of each test can identify the parameter.

---@class TypedSuite: Suite A suite with using a known set of types. They have a postfix, but no prefix.
---@field type_parameters string[] Type parameter IDs to types. The postfix can identify the parameter.

---@class ParameterizedTypedSuite: Suite A suite with parameterized types. The have a prefix and a postfix.
---@field parameterized_type_parameters table<string, string[]> Prefixes to postfixes to type parameters.

--- Parses a normal Suite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry Suite The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
local function parse_normal_suite(testsuite, suite_entry, files)
  for _, test in ipairs(testsuite) do
    files[test.file] = true
    suite_entry.tests[test.name] = true
  end
end

--- Parses a ParameterizedSuite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry ParameterizedSuite The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
local function parse_parameterized_suite(testsuite, suite_entry, files)
  for _, test in ipairs(testsuite) do
    files[test.file] = true

    local test_parts = vim.split(test.name, "/")
    assert(#test_parts == 2, "ParameterizedSuite test names should consist of a name and an index, e.g. `SomeTest/0`")
    suite_entry.tests[test_parts[1]] = true
    local index = tonumber(test_parts[2])
    assert(index ~= nil, "Index should be a number")
    index = index + 1
    if suite_entry.value_parameters[index] == nil then
      suite_entry.value_parameters[index] = test.value_param
    end
    assert(
      suite_entry.value_parameters[index] == test.value_param,
      "Not all tests had the same value_param at the same index"
    )
  end
end

--- Parses a TypedSuite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry TypedSuite The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
local function parse_typed_suite(testsuite, suite_entry, files, postfix)
  for _, test in ipairs(testsuite) do
    files[test.file] = true
    suite_entry.tests[test.name] = true
    local index = tonumber(postfix)
    assert(index ~= nil, "Index should be a number")
    index = index + 1
    if suite_entry.type_parameters[index] == nil then
      suite_entry.type_parameters[index] = test.type_param
    end
    assert(
      suite_entry.type_parameters[index] == test.type_param,
      "All tests in a suite with the same index should have the same type_param"
    )
  end
end

--- Parses a ParameterizedTypedSuite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry ParameterizedTypedSuite The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
local function parse_parameterized_typed_suite(testsuite, suite_entry, files, prefix, postfix)
  suite_entry.parameterized_type_parameters[prefix] = suite_entry.parameterized_type_parameters[prefix] or {}
  local params = suite_entry.parameterized_type_parameters[prefix]
  for _, test in ipairs(testsuite) do
    files[test.file] = true
    suite_entry.tests[test.name] = true
    local index = tonumber(postfix)
    assert(index ~= nil, "Index should be a number")
    index = index + 1
    if params[index] == nil then
      params[index] = test.type_param
    end
    assert(params[index] == test.type_param, "All tests in a suite with the same key should have the same type_param")
  end
end

--- Determines the type for a suite.
---@param suite table The suite to check.
---@return nil | "Suite" | "ParameterizedSuite" |  "TypedSuite" |  "ParameterizedTypedSuite" suite_type The type of the suite. nil if it is not a suite.
local function suite_type_from_suite(suite)
  if suite.name == nil then
    return nil
  end

  if suite.value_parameters ~= nil then
    return "ParameterizedSuite"
  end

  if suite.type_parameters ~= nil then
    return "TypedSuite"
  end

  if suite.parameterized_type_parameters ~= nil then
    return "ParameterizedTypedSuite"
  end

  return "Suite"
end

--- Identifies a suite type just from its ID parts.
---@param prefix string? The prefix of the suite.
---@param postfix string? The postfix of the suite.
---@return nil | "Suite" | "ParameterizedSuite" |  "TypedSuite" |  "ParameterizedTypedSuite" suite_type The type of the suite. nil if it is not a suite.
local function suite_type_from_id_parts(prefix, postfix)
  if prefix == nil and postfix == nil then
    return "Suite"
  end
  if prefix ~= nil and postfix == nil then
    return "ParameterizedSuite"
  end
  if prefix == nil and postfix ~= nil then
    return "TypedSuite"
  end
  if prefix ~= nil and postfix ~= nil then
    return "ParameterizedTypedSuite"
  end
  return nil
end

--- Parses suites for an executable out of an executable's GTest data.
---@param test_data table The GTest data for the test.
---@return table<string, Suite> suites, table<string> executable_files The suites in the test and the paths to the files containing tests compiled into the executable.
local function parse_executable_suites(test_data)
  ---@type table<string, Suite> Suite IDs to Suite.
  local suites = {}
  ---@type table<string> Files used by suites
  local executable_files = {}
  for _, suite in ipairs(test_data.testsuites) do
    local prefix, suite_id, postfix = parse_gtest_suite_name(suite)
    if suite_id == nil then
      goto continue
    end

    local suite_type = suite_type_from_id_parts(prefix, postfix)
    if suite_type == nil then
      vim.notify("Could not identify suite type for " .. suite, vim.log.levels.ERROR)
      goto continue
    end

    local suite_entry = suites[suite_id]
    if suite_entry == nil then
      -- Doesn't exist; create a new one
      suite_entry = {
        name = suite_id,
        tests = {},
      }

      if suite_type == "ParameterizedSuite" then
        ---@cast suite_entry ParameterizedSuite
        assert(prefix ~= nil)
        suite_entry.prefix = prefix
        suite_entry.value_parameters = {}
      elseif suite_type == "TypedSuite" then
        ---@cast suite_entry TypedSuite
        suite_entry.type_parameters = {}
      elseif suite_type == "ParameterizedTypedSuite" then
        ---@cast suite_entry ParameterizedTypedSuite
        suite_entry.parameterized_type_parameters = {}
      end

      suites[suite_id] = suite_entry
    end
    if suite_type ~= suite_type_from_suite(suite_entry) then
      vim.notify(
        "Suite type for " .. suite_entry.name .. " did not have the same test type for all tests. Skipping.",
        vim.log.levels.WARN
      )
      goto continue
    end

    if suite_type == "Suite" then
      parse_normal_suite(suite.testsuite, suite_entry, executable_files)
    elseif suite_type == "ParameterizedSuite" then
      ---@cast suite_entry ParameterizedSuite
      parse_parameterized_suite(suite.testsuite, suite_entry, executable_files)
    elseif suite_type == "TypedSuite" then
      ---@cast suite_entry TypedSuite
      parse_typed_suite(suite.testsuite, suite_entry, executable_files, postfix)
    elseif suite_type == "ParameterizedTypedSuite" then
      ---@cast suite_entry ParameterizedTypedSuite
      parse_parameterized_typed_suite(suite.testsuite, suite_entry, executable_files, prefix, postfix)
    end
    ::continue::
  end

  return suites, executable_files
end

--- Builds the tree for a suite of GTests.
---@param suite_position cmakeseer.neotest.gtest.SuitePosition The suite position.
---@param file_path string The path to the file containing the tests.
---@return any[] suite_tree The tree of suite tests.
local function build_suite_tree(suite_position, file_path)
  suite_position.suite.position.id = string.format("%s::%s", file_path, suite_position.suite.position.name)
  local suite_tree = {
    suite_position.suite.position,
  }

  if #suite_position.suite.prefixes == 0 then
    for _, test in ipairs(suite_position.tests) do
      test.id = string.format("%s::%s", suite_position.suite.position.id, test.name)
      table.insert(suite_tree, { test })
    end
  else
    for _, prefix in ipairs(suite_position.suite.prefixes) do
      for _, test in ipairs(suite_position.tests) do
        test.id = string.format("%s/%s::%s", prefix, suite_position.suite.position.id, test.name)
        table.insert(suite_tree, { test })
      end
    end
  end
  return suite_tree
end

---@class SuiteStructure
---@field suite neotest.Position
---@field tests any[]

--- Builds the structure for a normal test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition Suite The definition for the Suite.
---@param tests TreesitterTest[] The treesitter tests for the suite.
---@return SuiteStructure[] positions The positions for the suite and its tests.
local function build_normal_suite_structure(executable, suite_definition, tests)
  local suite_id = string.format("%s::%s", executable, suite_definition.name)
  local positions = {}
  for _, test in ipairs(tests) do
    local test_is_recogized = suite_definition.tests[test.name] ~= nil
    if not test_is_recogized then
      goto continue
    end

    local position = {
      id = string.format("%s::%s", suite_id, test.name),
      type = "test",
      name = test.name,
      path = test.filepath,
      range = test.range,
    }
    table.insert(positions, { position })
    ::continue::
  end

  ---@type neotest.Position
  local suite_position = {
    id = suite_id,
    type = "namespace",
    name = suite_definition.name,
    path = positions[1][1].path,
    range = positions[1][1].range,
  }

  return { {
    suite = suite_position,
    tests = positions,
  } }
end

--- Builds the structure for a parameterized test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition ParameterizedSuite The definition for the suite.
---@param tests TreesitterTest[] The treesitter tests for the suite.
---@return SuiteStructure[] positions The positions for the suite and its tests.
local function build_parameterized_suite_structure(executable, suite_definition, tests)
  local suite_name = string.format("%s/%s", suite_definition.prefix, suite_definition.name)
  local suite_id = string.format("%s::%s", executable, suite_name)
  local positions = {}
  for _, test in ipairs(tests) do
    local test_is_recogized = suite_definition.tests[test.name] ~= nil
    if not test_is_recogized then
      goto continue
    end

    local test_id = string.format("%s::%s", suite_id, test.name)
    local test_positions = {
      {
        id = test_id,
        type = "dir",
        name = test.name,
        path = test.filepath,
        range = test.range,
      },
    }

    for i, param in ipairs(suite_definition.value_parameters) do
      ---@type neotest.Position
      local position = {
        id = string.format("%s/%d", test_id, i - 1),
        type = "file",
        name = param,
        path = test.filepath,
        range = test.range,
      }
      table.insert(test_positions, { position })
    end

    table.insert(positions, test_positions)
    ::continue::
  end

  ---@type neotest.Position
  local suite_position = {
    id = suite_id,
    type = "namespace",
    name = suite_name,
    path = positions[1][1].path,
    range = positions[1][1].range,
  }

  return { {
    suite = suite_position,
    tests = positions,
  } }
end

--- Builds the structure for a typed test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition ParameterizedTypedSuite The definition for the suite.
---@param tests TreesitterTest[] The treesitter tests for the suite.
---@return SuiteStructure[] positions The positions for the suite and its tests.
local function build_parameterized_typed_suite_structure(executable, suite_definition, tests)
  local suite_structures = {}
  for prefix, type_parameters in pairs(suite_definition.parameterized_type_parameters) do
    local suite_id = string.format("%s::%s/%s", executable, prefix, suite_definition.name)
    local suite_positions = {}
    for i, type_param in ipairs(type_parameters) do
      local postfix_id = string.format("%s/%d", suite_id, i - 1)
      local positions = {}
      for _, test in ipairs(tests) do
        local test_is_recogized = suite_definition.tests[test.name] ~= nil
        if not test_is_recogized then
          goto continue
        end

        local test_id = string.format("%s::%s", postfix_id, test.name)
        local position = {
          id = test_id,
          type = "test",
          name = test.name,
          path = test.filepath,
          range = test.range,
        }

        table.insert(positions, { position })
        ::continue::
      end

      local postfix_position = {
        id = postfix_id,
        type = "dir",
        name = type_param,
        path = positions[1][1].path,
        range = positions[1][1].range,
      }

      table.insert(positions, 1, postfix_position)
      table.insert(suite_positions, positions)
    end

    ---@type neotest.Position
    local suite_position = {
      id = suite_id,
      type = "namespace",
      name = suite_definition.name,
      path = suite_positions[1][1].path,
      range = suite_positions[1][1].range,
    }
    table.insert(suite_structures, {
      suite = suite_position,
      tests = suite_positions,
    })
  end

  return suite_structures
end

--- Builds the structure for a parameterized typed test suite.
---@param executable string The path to the executable containing suites.
---@param suite_definition TypedSuite The definition for the suite.
---@param tests TreesitterTest[] The treesitter tests for the suite.
---@return SuiteStructure[] positions The positions for the suite and its tests.
local function build_typed_suite_structure(executable, suite_definition, tests)
  local suite_id = string.format("%s::%s", executable, suite_definition.name)
  local all_positions = {}
  for i, type_param in ipairs(suite_definition.type_parameters) do
    local postfix_id = string.format("%s/%d", suite_id, i - 1)
    local positions = {}
    for _, test in ipairs(tests) do
      local test_is_recogized = suite_definition.tests[test.name] ~= nil
      if not test_is_recogized then
        goto continue
      end

      local test_id = string.format("%s::%s", postfix_id, test.name)
      local position = {
        id = test_id,
        type = "test",
        name = test.name,
        path = test.filepath,
        range = test.range,
      }

      table.insert(positions, { position })
      ::continue::
    end

    local postfix_position = {
      id = postfix_id,
      type = "dir",
      name = type_param,
      path = positions[1][1].path,
      range = positions[1][1].range,
    }

    table.insert(positions, 1, postfix_position)
    table.insert(all_positions, positions)
  end
  ---@type neotest.Position
  local suite_position = {
    id = suite_id,
    type = "namespace",
    name = suite_definition.name,
    path = all_positions[1][1].path,
    range = all_positions[1][1].range,
  }

  return { {
    suite = suite_position,
    tests = all_positions,
  } }
end

--- Builds the structure tree for GTests.
---@param executable string The path to the executable containing the tests.
---@param queried_tests table<string, TreesitterTest[]> The queried tests for the entire executable.
---@return any[] structure The recursive tree structure representing the tests.
local function build_structure(executable, queried_tests)
  local suites = g_test_executables_suites[executable]
  assert(suites ~= nil)

  local structure = {
    ---@type neotest.Position
    {
      id = executable,
      type = "file",
      name = vim.fn.fnamemodify(executable, ":t:r"),
      path = executable,
      range = { 0, 0, 0, 0 },
    },
  }

  local all_suite_positions = {}
  for suite_name, tests in pairs(queried_tests) do
    local suite_definition = suites[suite_name]
    if suite_definition == nil then
      -- We don't know about this suite yet
      -- We could probably do something with it though. . .
      goto continue
    end

    local suite_type = suite_type_from_suite(suite_definition)
    local suite_positions = {}
    if suite_type == "Suite" then
      suite_positions = build_normal_suite_structure(executable, suite_definition, tests)
    elseif suite_type == "ParameterizedSuite" then
      ---@cast suite_definition ParameterizedSuite
      suite_positions = build_parameterized_suite_structure(executable, suite_definition, tests)
    elseif suite_type == "TypedSuite" then
      ---@cast suite_definition TypedSuite
      suite_positions = build_typed_suite_structure(executable, suite_definition, tests)
    elseif suite_type == "ParameterizedTypedSuite" then
      ---@cast suite_definition ParameterizedTypedSuite
      suite_positions = build_parameterized_typed_suite_structure(executable, suite_definition, tests)
    else
      vim.notify_once("Unrecognized suite type for suite " .. suite_name, vim.log.levels.DEBUG)
      goto continue
    end

    vim.list_extend(all_suite_positions, suite_positions)
    ::continue::
  end

  table.sort(all_suite_positions, function(a, b)
    return a.suite.name < b.suite.name
  end)

  for _, positions in ipairs(all_suite_positions) do
    local position = positions.tests
    table.insert(position, 1, positions.suite)
    table.insert(structure, position)
  end

  return structure
end

-- TODO: Have the plugin subscribe to build events
local M
---@class cmakeseer.GTestAdapter : neotest.Adapter
---@field setup fun(opts: cmakeseer.CTestAdapterOpts?): neotest.Adapter
M = {
  name = "CMakeSeer GTest",
  opts = {
    --- Filter out targets when looking for tests.
    ---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
    ---@return boolean keep If the target should be kept.
    target_filter = function(target)
      return string.match(target.name, "[tT]est") and not M.is_gtest_test(target)
    end,
    cache_directory = function()
      return vim.fs.joinpath(Cmakeseer.get_build_directory(), ".cache", "cmakeseer", "gtest")
    end,
  },
  treesitter = require("cmakeseer.neotest.gtest.treesitter"),
}

--- Compares the times of two stat times.
---@param a { nsec: integer, sec: integer }
---@param b { nsec: integer, sec: integer }
---@return integer 1 if a is greater, -1 if a is lesser, 0 if equal
local function compares_times(a, b)
  if a.sec > b.sec then
    return 1
  end
  if a.sec < b.sec then
    return -1
  end

  if a.nsec > b.nsec then
    return 1
  end
  if a.nsec < b.nsec then
    return -1
  end
  return 0
end

--- Generates all the test commands to check if an executable is a GTest executable.
---@param targets cmakeseer.cmake.api.codemodel.Target[] The targets to check.
---@return table<string, {cmd: vim.SystemObj?, cache: string}> test_cmds The executable paired with the commands to check each target.
local function generate_executable_commands(targets)
  local test_cmds = {}
  for _, target in ipairs(targets) do
    assert(target.type == TargetType.Executable, "Only executable targets are supported")
    assert(target.artifacts ~= nil, "Artifacts for executable should not have been nil")
    assert(#target.artifacts == 1, "Should only have one artifact for executable")

    local executable = vim.fs.joinpath(Cmakeseer.get_build_directory(), target.artifacts[1].path)
    local cache = vim.fs.joinpath(M.opts.cache_directory(), string.format("%s.json", target.name))

    local cache_stat = vim.loop.fs_stat(cache)
    if cache_stat ~= nil then
      -- Cache already exists; is it outdated?
      local exe_stat = vim.loop.fs_stat(executable)
      if exe_stat ~= nil and compares_times(cache_stat.mtime, exe_stat.mtime) == 1 then
        -- Cache is not outdated; use it instead
        test_cmds[executable] = { cache = cache }
        goto continue
      end
    end

    -- Does the executable exist?
    if vim.fn.filereadable(executable) == 0 then
      goto continue
    end

    local success, test_cmd = pcall(vim.system, {
      executable,
      "--gtest_list_tests",
      string.format("--gtest_output=json:%s", cache),
    }, { timeout = 10 })
    if not success then
      vim.notify(string.format("Failed to check %s for gtests", executable), vim.log.levels.ERROR)
      goto continue
    end

    test_cmds[executable] = { cmd = test_cmd, cache = cache }
    ::continue::
  end
  return test_cmds
end

--- Refreshes the set of test directories.
local function refresh_test_directories()
  g_test_dirs = {}
  -- TODO: Almost all CWD calls actually probably need to be the project root instead. . .
  local cwd = vim.fn.getcwd()
  g_test_dirs[cwd] = true
  for file, _ in pairs(g_test_executables_suites) do
    local path = vim.fn.fnamemodify(file, ":h")
    if path:sub(1, #cwd) ~= cwd then
      vim.notify(string.format("Path `%s` is not in cwd; skipping tests", path), vim.log.levels.WARN)
      goto continue
    end

    while #path > #cwd do
      g_test_dirs[path] = true
      path = vim.fn.fnamemodify(path, ":h")
    end
    ::continue::
  end
end

local function pass_status_test(test)
  local ResultStatus = require("neotest.types").ResultStatus

  if test.status == "NOTRUN" or test.result == "SKIPPED" then
    return ResultStatus.skipped
  end

  if test.failures == nil then
    return ResultStatus.passed
  end
  return ResultStatus.failed
end

--- Sets up the adapter.
---@return neotest.Adapter adapter The adapter.
function M.setup(opts)
  M.opts = vim.tbl_extend("keep", opts or {}, M.opts)
  -- TODO: Add a post-build callback to refresh tests
  return M
end

--- Determines if a target relies on GTest.
---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
---@return boolean does_depend If the target depends on GTest.
function M.depends_on_gtest(target)
  for _, dependency in ipairs(target.dependencies) do
    if dependency.id:match("^gtest") then
      return true
    end
  end
  return false
end

--- Determines if a target is a test from GTest, as in a test for the GTest library.
---@see depends_on_gtest
---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
---@return boolean is_gtest_test If the target is a GTest test.
function M.is_gtest_test(target)
  return target.name:match("_gtest$")
end

--- Refreshes the list of test executables.
function M.refresh_test_executables()
  ---@type cmakeseer.cmake.api.codemodel.Target[]
  local targets = vim.tbl_filter(function(target)
    return target.type == TargetType.Executable and M.opts.target_filter(target) and M.depends_on_gtest(target)
  end, Cmakeseer.get_targets())

  g_test_executables_suites = {}
  local test_cmds = generate_executable_commands(targets)
  for executable, test_cmd in pairs(test_cmds) do
    if test_cmd.cmd ~= nil then
      -- Cache was not used
      test_cmd.cmd:wait(10)
    end

    if vim.fn.filereadable(test_cmd.cache) == 0 then
      goto continue
    end

    local file = io.open(test_cmd.cache, "r")
    if file == nil then
      goto continue
    end
    local contents = file:read("*a")
    file:close()
    local success, test_data = pcall(vim.json.decode, contents)
    if not success then
      vim.notify(
        string.format(
          "Failed to read output for executable %s; cannot detect if it is a gtest. Error: %s",
          executable,
          test_data
        )
      )
      goto continue
    end
    assert(type(test_data) == "table")

    -- Parse the suites
    local suites, executable_files = parse_executable_suites(test_data)
    g_test_executables_suites[executable] = suites
    g_executable_files[executable] = executable_files
    ::continue::
  end

  -- Enumerate all the test directories
  refresh_test_directories()
end

---Find the project root directory given a current directory to work from.
---Should no root be found, the adapter can still be used in a non-project context if a test file matches.
---@async
---@param cwd string @Directory to treat as cwd
---@return string | nil @Absolute root dir of test suite
function M.root(cwd)
  M.refresh_test_executables()
  return cwd
end

---Filter directories when searching for test files
---@async
---@param _ string Name of directory
---@param rel_path string Path to directory, relative to root
---@param project_root string Root directory of project
---@return boolean
function M.filter_dir(_, rel_path, project_root)
  local path = vim.fs.joinpath(project_root, rel_path)
  return g_test_dirs[path] ~= nil
end

---@async
---@param file_path string
---@return boolean
function M.is_test_file(file_path)
  return g_test_executables_suites[file_path] ~= nil
end

---Given a filepath, parse all the tests within it.
---@async
---@param executable_path string Absolute file path to the executable.
---@return neotest.Tree | nil
function M.discover_positions(executable_path)
  ---@type table<string, TreesitterTest[]>
  local suite_tests = {}
  local executable_files = g_executable_files[executable_path]
  for file, _ in pairs(executable_files) do
    local queried_tests = M.treesitter.query_tests(file)
    if type(queried_tests) == "string" then
      vim.notify(string.format("Failed to find positions in %s: %s", file, queried_tests), vim.log.levels.ERROR)
      goto continue
    end

    for suite, tests in pairs(queried_tests) do
      if suite_tests[suite] ~= nil then
        vim.list_extend(suite_tests[suite], tests)
      else
        suite_tests[suite] = tests
      end
    end

    ::continue::
  end

  --  - Executable
  --    - Prefix/Suite/Postfix; Might separate these later
  --      - Test/Postfix
  local structure = build_structure(executable_path, suite_tests)
  local tree = require("neotest.types.tree").from_list(structure, function(pos)
    return pos.id
  end)
  return tree
end

---@param args neotest.RunArgs
---@return nil | neotest.RunSpec | neotest.RunSpec[]
function M.build_spec(args)
  local raw_id = args[1]
  local id_parts = vim.fn.split(raw_id, "::")
  local executable = id_parts[1]
  if executable == nil then
    vim.notify(string.format("No executable for test ID `%s`", raw_id), vim.log.levels.ERROR)
    return nil
  end

  ---@type cmakeseer.neotest.gtest.TestId
  local id = {
    file = id_parts[1],
    suite = id_parts[2],
    test = id_parts[3],
  }

  local output_file = vim.fs.joinpath(M.opts.cache_directory(), "results.json")
  ---@type cmakeseer.neotest.gtest.Context
  local context = {
    executable = executable,
    neotest_id = raw_id,
    id = id,
    output_file = output_file,
  }

  local spec = nil
  if #id_parts == 1 then
    -- This is a file
    spec = {
      command = { executable },
    }
  elseif #id_parts == 2 then
    -- This is a suite
    spec = {
      command = { executable, string.format("--gtest_filter=%s.*", id.suite) },
    }
  elseif #id_parts == 3 then
    -- This is an individual test
    spec = {
      command = {
        executable,
        "--gtest_also_run_disabled_tests",
        string.format("--gtest_filter=%s.%s", id.suite, id.test),
      },
    }
  else
    vim.notify(string.format("Unrecognized test ID: `%s`", raw_id), vim.log.levels.ERROR)
    return nil
  end

  assert(spec ~= nil)
  spec.context = context
  table.insert(spec.command, string.format("--gtest_output=json:%s", output_file))

  return spec
end

---@async
---@param spec neotest.RunSpec
---@param result neotest.StrategyResult
---@param _ neotest.Tree
---@return table<string, neotest.Result>
function M.results(spec, result, _)
  local ResultStatus = require("neotest.types").ResultStatus

  _ = result

  ---@type cmakeseer.neotest.gtest.Context
  local context = spec.context
  local fin = io.open(context.output_file, "r")
  if fin == nil then
    vim.notify("Unable to access GTest cache file", vim.log.levels.ERROR)
    return { [context.neotest_id] = { status = ResultStatus.skipped } }
  end

  local test_results = vim.json.decode(fin:read("*a"))
  fin:close()

  local file_status = ResultStatus.passed
  local results = {}
  for _, suite in ipairs(test_results.testsuites) do
    local suite_status = ResultStatus.passed
    local suite_id = string.format("%s::%s", context.id.file, suite.name)

    for _, test in ipairs(suite.testsuite) do
      local test_id = string.format("%s::%s::%s", context.id.file, suite.name, test.name)
      local errors = test.failures or {}
      for i, error in ipairs(errors) do
        local failure = error.failure
        local failure_parts = vim.fn.split(failure, "\n")

        -- Start by getting the line the error occurred on
        local location = table.remove(failure_parts, 1)
        local line = nil
        if location ~= "unknown file" then
          local _, line_str = unpack(vim.fn.split(location, ":"))
          line = tonumber(line_str) - 1
        end

        -- Now we'll get the message
        local msg = table.concat(failure_parts, "\n")
        ---@type neotest.Error
        errors[i] = {
          message = msg,
          line = line,
        }
      end

      local test_status = pass_status_test(test)
      results[test_id] = { status = test_status, errors = #errors >= 1 and errors or nil }
      if test_status == ResultStatus.failed then
        suite_status = ResultStatus.failed
      end
    end

    results[suite_id] = { status = suite_status }
    if suite_status == ResultStatus.failed then
      file_status = ResultStatus.failed
    end
  end

  results[context.id.file] = { status = file_status }
  return results
end

return M
