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

--- Parses suites for an executable out of an executable's GTest data.
---@param test_data table The GTest data for the test.
---@return table<string, cmakeseer.neotest.gtest.suite.Basic> suites, table<string> executable_files The suites in the test and the paths to the files containing tests compiled into the executable.
function M.parse_executable_suites(test_data)
  ---@type table<string, table<cmakeseer.neotest.gtest.suite.Type, cmakeseer.neotest.gtest.suite.Basic> > Suite IDs to Suite.
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

    suites[suite_id] = suites[suite_id] or {}
    local suite_entry = suites[suite_id][suite_type]
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
      suites[suite_id][suite_type] = suite_entry
    end

    suite_entry:parse_add_gtests(suite.testsuite, executable_files, prefix, postfix)
    ::continue::
  end

  return suites, executable_files
end

return M
