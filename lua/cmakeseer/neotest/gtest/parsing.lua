local Suite = require("cmakeseer.neotest.gtest.suite")

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
  elseif #suite_name_parts == 3 then
    prefix = suite_name_parts[1]
    suite_id = suite_name_parts[2]
    postfix = suite_name_parts[3]
  else
    vim.notify(string.format("Failed to parse suite name: %s; parts : %s", suite.name, vim.inspect(suite_name_parts)))
  end
  return prefix, suite_id, postfix
end

local M = {}

--- Parses a basic Suite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry cmakeseer.neotest.gtest.suite.Basic The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
function M.parse_basic_suite(testsuite, suite_entry, files)
  for _, test in ipairs(testsuite) do
    files[test.file] = true
    suite_entry.tests[test.name] = true
  end
end

--- Parses a ParameterizedSuite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry cmakeseer.neotest.gtest.suite.Parameterized The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
function M.parse_parameterized_suite(testsuite, suite_entry, files, prefix)
  suite_entry.value_parameters[prefix] = suite_entry.value_parameters[prefix] or {}
  local params = suite_entry.value_parameters[prefix]
  for _, test in ipairs(testsuite) do
    files[test.file] = true

    local test_parts = vim.split(test.name, "/")
    assert(#test_parts == 2, "ParameterizedSuite test names should consist of a name and an index, e.g. `SomeTest/0`")
    suite_entry.tests[test_parts[1]] = true
    local index = tonumber(test_parts[2])
    assert(index ~= nil, "Index should be a number")
    index = index + 1
    if params[index] == nil then
      params[index] = test.value_param
    end
    assert(params[index] == test.value_param, "Not all tests had the same value_param at the same index")
  end
end

--- Parses a TypedSuite.
---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param suite_entry cmakeseer.neotest.gtest.suite.Typed The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
function M.parse_typed_suite(testsuite, suite_entry, files, postfix)
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
---@param suite_entry cmakeseer.neotest.gtest.suite.ParameterizedTyped The entry to fill with data from this suite.
---@param files table<string> The set of files to populate with files from this suite.
function M.parse_parameterized_typed_suite(testsuite, suite_entry, files, prefix, postfix)
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

--- Parses suites for an executable out of an executable's GTest data.
---@param test_data table The GTest data for the test.
---@return table<string, cmakeseer.neotest.gtest.suite.Basic> suites, table<string> executable_files The suites in the test and the paths to the files containing tests compiled into the executable.
function M.parse_executable_suites(test_data)
  ---@type table<string, cmakeseer.neotest.gtest.suite.Basic> Suite IDs to Suite.
  local suites = {}
  ---@type table<string> Files used by suites
  local executable_files = {}
  for _, suite in ipairs(test_data.testsuites) do
    local prefix, suite_id, postfix = parse_gtest_suite_name(suite)
    if suite_id == nil then
      goto continue
    end

    local suite_type = Suite.type_from_id_parts(prefix, postfix)
    if suite_type == nil then
      vim.notify("Could not identify suite type for " .. suite, vim.log.levels.ERROR)
      goto continue
    end

    local suite_entry = suites[suite_id]
    if suite_entry == nil then
      -- Doesn't exist; create a new one
      if suite_type == Suite.Type.Basic then
        suite_entry = Suite.Basic:new({ name = suite_id })
      elseif suite_type == Suite.Type.Parameterized then
        suite_entry = Suite.Parameterized:new({ name = suite_id })
      elseif suite_type == Suite.Type.Typed then
        suite_entry = Suite.Typed:new({ name = suite_id })
      elseif suite_type == Suite.Type.ParameterizedTyped then
        suite_entry = Suite.ParameterizedTyped:new({ name = suite_id })
      end

      assert(suite_entry ~= nil)
      suites[suite_id] = suite_entry
    end

    if suite_type ~= Suite.type_from_suite(suite_entry) then
      vim.notify_once(
        "Suite type for " .. suite_entry.name .. " did not have the same test type for all tests. Skipping.",
        vim.log.levels.WARN
      )
      goto continue
    end

    if suite_type == Suite.Type.Basic then
      M.parse_basic_suite              (suite.testsuite, suite_entry, executable_files)
    elseif suite_type == Suite.Type.Parameterized then
      ---@cast suite_entry cmakeseer.neotest.gtest.suite.Parameterized
      M.parse_parameterized_suite      (suite.testsuite, suite_entry, executable_files, prefix)
    elseif suite_type == Suite.Type.Typed then
      ---@cast suite_entry cmakeseer.neotest.gtest.suite.Typed
      M.parse_typed_suite              (suite.testsuite, suite_entry, executable_files, postfix)
    elseif suite_type == Suite.Type.ParameterizedTyped then
      ---@cast suite_entry cmakeseer.neotest.gtest.suite.ParameterizedTyped
      M.parse_parameterized_typed_suite(suite.testsuite, suite_entry, executable_files, prefix, postfix)
    end
    ::continue::
  end

  return suites, executable_files
end

return M
