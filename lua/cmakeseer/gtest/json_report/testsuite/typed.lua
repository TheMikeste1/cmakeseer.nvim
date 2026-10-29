local TestSuite = require("cmakeseer.gtest.json_report.testsuite")
local Test = require("cmakeseer.gtest.json_report.test")

--- A JSON test suite.
---@class cmakeseer.gtest.JsonReport.TestSuite.Typed: cmakeseer.gtest.JsonReport.AbstractTestSuite
---@field type "typed" The type of the suite
---@field tests cmakeseer.gtest.JsonReport.Test.Typed[] The tests in the suite.
---@field variants table<string, string> The variants for the suite.
---@field counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
local Typed = setmetatable({}, TestSuite)
Typed.__index = Typed

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.Typed[] The tests in the suite.
---@param variants table<string, string> The variants for the suite.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Typed obj The new instance.
function Typed.new(name, tests, variants, counts, time)
  return Typed.take(name, vim.deepcopy(tests), vim.deepcopy(variants), counts, time)
end

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.Typed[] The tests in the suite.
---@param variants table<string, string> The variants for the suite.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Typed obj The new instance.
function Typed.take(name, tests, variants, counts, time)
  local self = setmetatable({
    name = name,
    type = TestSuite.Type.Typed,
    tests = tests,
    variants = variants,
    counts = counts,
    time = time,
  }, Typed)
  return self
end

--- Creates a new TestSuite instance from JSON.
---@param name string The name of the suite
---@param raw_tests any[] The tests in raw JSON.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.Typed? obj, string? err
function Typed.try_from_json_tests(name, raw_tests, counts, time)
  local parts = vim.split(name, "/", { plain = true })
  if #parts ~= 2 then
    return nil, "Invalid Typed suite name: " .. name
  end

  name = parts[1]
  local variant = parts[2]
  if variant == nil then
    return nil, "Invalid Typed suite variant: " .. parts[2]
  end

  local tests = {}
  ---@type string?
  local variant_type
  for i, raw_test in ipairs(raw_tests) do
    local test, err = Test.try_from_json(raw_test, "typed", { variant = variant })
    if test == nil then
      return nil, ("test at index %d: %s"):format(i, err)
    end
    table.insert(tests, test)

    ---@type string
    local type_ = raw_test.type_param
    assert(variant_type == nil or variant_type == type_)
    variant_type = type_
  end

  return Typed.take(name, tests, { [variant] = variant_type }, counts, time)
end

---Merges two suites together, merging their tests and variants. Merges in place.
---@param other cmakeseer.gtest.JsonReport.TestSuite.Typed The other suite to merge with. Must be the same type as self.
function Typed:merge(other)
  assert(other.type == self.type)
  for variant, type_ in pairs(other.variants) do
    self.variants[variant] = type_
  end
  vim.list_extend(self.tests, other.tests)
end

return Typed
