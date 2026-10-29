local Test = require("cmakeseer.gtest.json_report.test")
local TestSuite = require("cmakeseer.gtest.json_report.testsuite")

--- A JSON test suite.
---@class cmakeseer.gtest.JsonReport.TestSuite.Basic: cmakeseer.gtest.JsonReport.AbstractTestSuite
---@field type "basic" The type of the suite
---@field tests cmakeseer.gtest.JsonReport.Test.Basic[] The tests in the suite.
local Basic = setmetatable({}, TestSuite)
Basic.__index = Basic

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.Basic[] The tests in the suite.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Basic obj The new instance.
function Basic.new(name, tests, counts, time)
  return Basic.take(name, vim.deepcopy(tests), counts, time)
end

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.Basic[] The tests in the suite.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Basic obj The new instance.
function Basic.take(name, tests, counts, time)
  local self = setmetatable({
    name = name,
    type = TestSuite.Type.Basic,
    tests = tests,
    counts = counts,
    time = time,
  }, Basic)
  return self
end

--- Creates a new TestSuite instance from JSON.
---@param name string The name of the suite
---@param raw_tests any[] The tests in raw JSON.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Basic? obj, string? err
function Basic.try_from_json_tests(name, raw_tests, counts, time)
  local tests = {}
  for i, raw_test in ipairs(raw_tests) do
    local test, err = Test.try_from_json(raw_test, "basic")
    if test == nil then
      return nil, ("test at index %d: %s"):format(i, err)
    end
    table.insert(tests, test)
  end

  return Basic.take(name, tests, counts, time)
end

return Basic
