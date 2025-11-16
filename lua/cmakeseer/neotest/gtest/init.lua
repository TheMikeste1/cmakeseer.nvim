local NeotestLib = require("neotest.lib")
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
---@field suite { id: string, sub_ids: string[]? }
---@field tests cmakeseer.neotest.gtest.Test[]

---@private
---@class cmakeseer.neotest.gtest.TestCmd
---@field cmd vim.SystemObj? The process running the command. Will be nil if the cache was used instead.
---@field cache string

---@private
---@class cmakeseer.neotest.gtest.TestId
---@field file string
---@field suite string?
---@field test string?

---@private
---@class cmakeseer.neotest.gtest.SuitePosition
---@field suite neotest.Position
---@field tests neotest.Position[]

---@private
---@class cmakeseer.neotest.gtest.Positions
---@field file_position neotest.Position
---@field suites cmakeseer.neotest.gtest.SuitePosition[]

---@type table<string, string> Test files to executables.
local g_test_files = {}
---@type table<string, any> Set of test directories.
local g_test_dirs = {}
---@type table<string, table<string, cmakeseer.neotest.gtest.Suite>> Executables to suites, suites to tests.
local g_test_executables_suites = {}

--- Builds the tree for a suite of GTests.
---@param suite_position cmakeseer.neotest.gtest.SuitePosition The suite position.
---@param file_path string The path to the file containing the tests.
---@return any[] suite_tree The tree of suite tests.
local function build_suite_tree(suite_position, file_path)
  suite_position.suite.id = string.format("%s::%s", file_path, suite_position.suite.name)
  local suite_tree = {
    suite_position.suite,
  }
  for _, test in ipairs(suite_position.tests) do
    test.id = string.format("%s::%s", suite_position.suite.id, test.name)
    table.insert(suite_tree, { test })
  end
  return suite_tree
end

--- Builds the structure tree for GTests.
---@param file_path string The path to the file containing the tests.
---@param queried_tests cmakeseer.neotest.gtest.Positions The queried tests.
---@return any[] structure The recursive tree structure representing the tests.
local function build_structure(file_path, queried_tests)
  local executable = g_test_files[file_path]
  if executable == nil then
    return {}
  end
  local suites = g_test_executables_suites[executable]
  assert(suites ~= nil)

  local structure = { queried_tests.file_position }
  for _, suite_position in ipairs(queried_tests.suites) do
    -- Before we add the suite, we'll want to check if it's a parameterized test
    local suite_id = suite_position.suite.name
    local suite_data = suites[suite_id]
    if suite_data == nil or suite_data.suite.sub_ids == nil then
      -- Suite hasn't been compiled in yet or there are not sub IDs
      local suite_tree = build_suite_tree(suite_position, file_path)
      table.insert(structure, suite_tree)
      goto continue
    end

    -- We need to duplicate the suite and tests for each sub ID
    for _, sub_id in ipairs(suite_data.suite.sub_ids) do
      local new_suite_positions = vim.deepcopy(suite_position, true)
      new_suite_positions.suite.name = string.format("%s/%s", new_suite_positions.suite.name, sub_id)
      local suite_tree = build_suite_tree(new_suite_positions, file_path)
      table.insert(structure, suite_tree)
    end

    ::continue::
  end
  return structure
end

---@class cmakeseer.GTestAdapter : neotest.Adapter
---@field setup fun(opts: cmakeseer.CTestAdapterOpts?): neotest.Adapter
local M = {
  name = "CMakeSeer GTest",
  opts = {
    --- Filter out targets when looking for tests.
    ---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
    ---@return boolean keep If the target should be kept.
    target_filter = function(target)
      return string.match(target.name, "[tT]est")
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

--- Generates all the test commands to check if an executable is a gtest executable.
---@param targets cmakeseer.cmake.api.codemodel.Target[] The targets to check.
---@return table<string, cmakeseer.neotest.gtest.TestCmd> test_cmds The executable paired with the commands to check each target.
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
  for file, _ in pairs(g_test_files) do
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

local function pass_status_group(group)
  local ResultStatus = require("neotest.types").ResultStatus
  if group.failures > 0 or group.errors > 0 then
    return ResultStatus.failed
  end

  if group.tests ~= group.disabled then
    -- TODO: If a disabled test was run and it passes, we should also pass
    return ResultStatus.passed
  end

  -- Unknown status or all tests are disabled
  return ResultStatus.skipped
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
  return M
end

--- Filter out targets when looking for tests.
---@param target cmakeseer.cmake.api.codemodel.Target The target to test. Will be an executable.
---@return boolean does_depend If the target should be kept.
function M.depends_on_gtest(target)
  -- TODO: Check if target depends on GTest
  return true
end

--- Refreshes the list of test executables.
function M.refresh_test_executables()
  ---@type cmakeseer.cmake.api.codemodel.Target[]
  local targets = vim.tbl_filter(function(target)
    return target.type == TargetType.Executable and M.opts.target_filter(target) and M.depends_on_gtest(target)
  end, Cmakeseer.get_targets())

  g_test_files = {}
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

    -- Parse the suites
    ---@type table<string, cmakeseer.neotest.gtest.Suite>
    local suites = {}
    local test_data = vim.json.decode(io.open(test_cmd.cache, "r"):read("*a"))
    for _, suite in ipairs(test_data.testsuites) do
      local suite_name_parts = vim.fn.split(suite.name, "/")
      local suite_id = table.remove(suite_name_parts, 1)
      local suite_sub_id = #suite_name_parts > 0 and table.concat(suite_name_parts, "/") or nil

      if suites[suite_id] == nil then
        local tests = {}
        for _, test in ipairs(suite.testsuite) do
          tests[test.name] = {
            file = test.file,
            line = test.line,
          }

          g_test_files[test.file] = executable
        end

        ---@type cmakeseer.neotest.gtest.Suite
        local suite_data = {
          suite = {
            id = suite_id,
            sub_ids = suite_sub_id and { suite_sub_id } or nil,
          },
          tests = tests,
        }
        suites[suite_id] = suite_data
      elseif suite_sub_id ~= nil then
        if suites[suite_id].suite.sub_ids ~= nil then
          table.insert(suites[suite_id].suite.sub_ids, suite_sub_id)
        else
          vim.notify("Duplicate suite ID without sub ID: " .. suite_id, vim.log.levels.ERROR)
        end
      end
    end

    g_test_executables_suites[executable] = suites
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
  return g_test_files[file_path] ~= nil
end

---Given a filepath, parse all the tests within it.
---@async
---@param file_path string Absolute file path
---@return neotest.Tree | nil
function M.discover_positions(file_path)
  local queried_tests = M.treesitter.query_tests(file_path)
  if type(queried_tests) == "string" then
    vim.notify("Failed to find positions in " .. file_path, vim.log.levels.ERROR)
    return nil
  end

  local structure = build_structure(file_path, queried_tests)
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
  local executable = g_test_files[id_parts[1]]
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

  local output_file = vim.fs.joinpath(Cmakeseer.get_build_directory(), "cmakeseer_gtest_cache.json")
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
    local suites = {}
    for _, suite_tests in pairs(g_test_executables_suites) do
      for suite, _ in pairs(suite_tests) do
        table.insert(suites, suite)
      end
    end
    local suite_str = table.concat(suites, ".*:")
    spec = {
      command = { executable, string.format("--gtest_filter=%s.*", suite_str) },
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

  local results = { [context.id.file] = { status = pass_status_group(test_results) } }
  for _, suite in ipairs(test_results.testsuites) do
    local suite_id = string.format("%s::%s", context.id.file, suite.name)
    results[suite_id] = { status = pass_status_group(suite) }

    for _, test in ipairs(suite.testsuite) do
      local test_id = string.format("%s::%s::%s", test.file, suite.name, test.name)
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
      results[test_id] = { status = pass_status_test(test), errors = errors }
    end
  end

  return results
end

return M
