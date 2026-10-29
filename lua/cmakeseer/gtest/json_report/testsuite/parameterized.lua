local Test = require("cmakeseer.gtest.json_report.test")
local TestSuite = require("cmakeseer.gtest.json_report.testsuite")

--- A JSON test suite.
---@class cmakeseer.gtest.JsonReport.TestSuite.Parameterized: cmakeseer.gtest.JsonReport.AbstractTestSuite
---@field type "parameterized" The type of the suite
---@field tests cmakeseer.gtest.JsonReport.Test.Parameterized[] The tests in the suite.
---@field variants table<string, table<string, string>> The variant for the suite.
local Parameterized = setmetatable({}, TestSuite)
Parameterized.__index = Parameterized

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.Parameterized[] The tests in the suite.
---@param variants table<string, string[]> The variant for the suite.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Parameterized obj The new instance.
function Parameterized.new(name, tests, variants, counts, time)
  return Parameterized.take(name, vim.deepcopy(tests), vim.deepcopy(variants), counts, time)
end

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.Parameterized[] The tests in the suite.
---@param variants table<string, string[]> The variant for the suite.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Parameterized obj The new instance.
function Parameterized.take(name, tests, variants, counts, time)
  local self = setmetatable({
    name = name,
    type = TestSuite.Type.Parameterized,
    tests = tests,
    variants = variants,
    counts = counts,
    time = time,
  }, Parameterized)
  return self
end

--- Creates a new TestSuite instance from JSON.
---@param name string The name of the suite
---@param raw_tests any[] The tests in raw JSON.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Parameterized? obj, string? err
function Parameterized.try_from_json_tests(name, raw_tests, counts, time)
  local parts = vim.split(name, "/", { plain = true })
  if #parts ~= 2 then
    return nil, "Invalid Parameterized suite name: " .. name
  end

  name = parts[2]
  local variant = parts[1]

  local tests = {}
  local variants = {}
  for i, raw_test in ipairs(raw_tests) do
    local test, err = Test.try_from_json(raw_test, "parameterized", { prefix = variant })
    if test == nil then
      return nil, ("test at index %d: %s"):format(i, err)
    end
    table.insert(tests, test)

    local postfix = vim.split(raw_test.name, "/", { plain = true })[2]
    local value_param = raw_test.value_param
    variants[postfix] = value_param
  end

  return Parameterized.take(name, tests, { [variant] = variants }, counts, time)
end

---Merges two suites together, merging their tests and variants. Merges in place.
---@param other cmakeseer.gtest.JsonReport.TestSuite.Parameterized The other suite to merge with. Must be the same type as self.
function Parameterized:merge(other)
  assert(other.type == self.type)
  for variant, ids in pairs(other.variants) do
    assert(self.variants[variant] == nil)
    self.variants[variant] = ids
  end
  vim.list_extend(self.tests, other.tests)
end

return Parameterized
