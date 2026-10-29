local Test = require("cmakeseer.gtest.json_report.test")
local TestSuite = require("cmakeseer.gtest.json_report.testsuite")

--- A JSON test suite.
---@class cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped: cmakeseer.gtest.JsonReport.AbstractTestSuite
---@field type "parameterized_typed" The type of the suite
---@field tests cmakeseer.gtest.JsonReport.Test.ParameterizedTyped[] The tests in the suite.
---@field variants table<string, table<string, string>> The variant for the suite. { prefix: { postfix: type } }
---@field counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
local ParameterizedTyped = setmetatable({}, TestSuite)
ParameterizedTyped.__index = ParameterizedTyped

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.ParameterizedTyped[] The tests in the suite.
---@param variants table<string, table<string, string>> The variant for the suite. { prefix: { postfix: type } }
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped obj The new instance.
function ParameterizedTyped.new(name, tests, variants, counts, time)
  return ParameterizedTyped.take(name, vim.deepcopy(tests), vim.deepcopy(variants), counts, time)
end

--- Creates a new TestSuite instance.
---@param name string The name of the suite
---@param tests cmakeseer.gtest.JsonReport.Test.ParameterizedTyped[] The tests in the suite.
---@param variants table<string, table<string, string>> The variant for the suite. { prefix: { postfix: type } }
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped obj The new instance.
function ParameterizedTyped.take(name, tests, variants, counts, time)
  local self = setmetatable({
    name = name,
    type = TestSuite.Type.ParameterizedTyped,
    tests = tests,
    variants = variants,
    counts = counts,
    time = time,
  }, ParameterizedTyped)
  return self
end

--- Creates a new TestSuite instance from JSON.
---@param name string The name of the suite
---@param raw_tests any[] The tests in raw JSON.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@param time string? The time the suite took.
---@return cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped? obj, string? err
function ParameterizedTyped.try_from_json_tests(name, raw_tests, counts, time)
  local parts = vim.split(name, "/", { plain = true })
  if #parts ~= 3 then
    return nil, "Invalid ParameterizedTyped suite name: " .. name
  end

  name = parts[2]
  local prefix = parts[1]
  local postfix = parts[3]
  local tests = {}
  ---@type string?
  local variant_type
  for i, raw_test in ipairs(raw_tests) do
    local test, err = Test.try_from_json(raw_test, "parameterized_typed", { prefix = prefix, postfix = postfix })
    if test == nil then
      return nil, ("test at index %d: %s"):format(i, err)
    end
    table.insert(tests, test)

    ---@type string
    local type_ = raw_test.type_param
    assert(variant_type == nil or variant_type == type_)
    variant_type = type_
  end

  return ParameterizedTyped.take(name, tests, { [prefix] = { [postfix] = variant_type } }, counts, time)
end

---Merges two suites together, merging their tests and variants. Merges in place.
---@param other cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped The other suite to merge with. Must be the same type as self.
function ParameterizedTyped:merge(other)
  assert(other.type == self.type)
  for prefix, postfixes in pairs(other.variants) do
    self.variants[prefix] = self.variants[prefix] or {}
    for postfix, type_ in pairs(postfixes) do
      self.variants[prefix][postfix] = type_
    end
  end
  vim.list_extend(self.tests, other.tests)
end

return ParameterizedTyped
