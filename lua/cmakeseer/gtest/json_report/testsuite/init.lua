--- A JSON test suite.
---@class cmakeseer.gtest.JsonReport.AbstractTestSuite
---@field name string The name of the suite
---@field type cmakeseer.gtest.JsonReport.TestSuite.Type The type of the suite
---@field tests cmakeseer.gtest.JsonReport.Test[] The tests in the suite.
---@field counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the suite.
---@field time string? The time the suite took.
local AbstractTestSuite = {
  ---@enum cmakeseer.gtest.JsonReport.TestSuite.Type
  Type = {
    Basic = "basic",
    Typed = "typed",
    Parameterized = "parameterized",
    ParameterizedTyped = "parameterized_typed",
  },
}
AbstractTestSuite.__index = AbstractTestSuite

--- Determines the type of the test given the name.
---@param name string The name of the tests
---@param testsuite any[] The raw tests of the suite
---@return cmakeseer.gtest.JsonReport.TestSuite.Type? type_, string? err
local function determine_test_type(name, testsuite)
  local parts = vim.split(name, "/", { plain = true })
  if #parts == 1 then
    return AbstractTestSuite.Type.Basic
  end
  if #parts == 3 then
    return AbstractTestSuite.Type.ParameterizedTyped
  end

  if #parts > 3 then
    return nil, "Invalid name: " .. name
  end

  -- Parameterized and Typed can be indistinguishable by name alone.
  -- We could look for name hints, but not everyone follows conventions.
  -- This ends up requiring more information about the suite than I'd like, but
  -- there's not too much I can do about it.
  local test = testsuite[1]
  if test.value_param ~= nil then
    return AbstractTestSuite.Type.Parameterized
  elseif test.type_param ~= nil then
    return AbstractTestSuite.Type.Typed
  end
  return nil, "Name does not fit Basic or ParameterizedTyped, and tests do not have type_param nor value_param"
end

--- Creates a new TestSuite instance from JSON.
---@param json any
---@return cmakeseer.gtest.JsonReport.AbstractTestSuite? obj, string? err
function AbstractTestSuite.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local raw_tests = json.testsuite
  if not vim.islist(raw_tests) then
    return nil, "testsuite is wrong type: " .. type(raw_tests)
  end

  local type_, err = determine_test_type(name, raw_tests)
  if type_ == nil then
    return nil, "Cannot determine test type: " .. err
  end

  local Counts = require("cmakeseer.gtest.json_report.testsuite.counts")

  local counts, err = Counts.try_from_json(json)
  if counts == nil then
    return nil, "counts: " .. err
  end

  ---@type string?
  local time = json.time
  if time ~= nil and type(time) ~= "string" then
    return nil, "time is wrong type: " .. type(time)
  end

  if type_ == AbstractTestSuite.Type.Basic then
    return require("cmakeseer.gtest.json_report.testsuite.basic").try_from_json_tests(name, raw_tests, counts, time)
  elseif type_ == AbstractTestSuite.Type.Typed then
    return require("cmakeseer.gtest.json_report.testsuite.typed").try_from_json_tests(name, raw_tests, counts, time)
  elseif type_ == AbstractTestSuite.Type.Parameterized then
    return require("cmakeseer.gtest.json_report.testsuite.parameterized").try_from_json_tests(name, raw_tests, counts, time)
  elseif type_ == AbstractTestSuite.Type.ParameterizedTyped then
    return require("cmakeseer.gtest.json_report.testsuite.parameterized_typed").try_from_json_tests(name, raw_tests, counts, time)
  end

  error("Unreachable")
end

function AbstractTestSuite:disabled()
  return vim.startswith(self.name, "DISABLED_")
end

---Merges two suites together, merging their tests and variants. Merges in place.
---@param _other cmakeseer.gtest.JsonReport.AbstractTestSuite The other suite to merge with. Must be the same type as self.
function AbstractTestSuite:merge(_other)
  assert(false, "Cannot call merge on an abstract test suite!")
end

---@alias cmakeseer.gtest.JsonReport.TestSuite
---| cmakeseer.gtest.JsonReport.TestSuite.Basic
---| cmakeseer.gtest.JsonReport.TestSuite.Typed
---| cmakeseer.gtest.JsonReport.TestSuite.Parameterized
---| cmakeseer.gtest.JsonReport.TestSuite.ParameterizedTyped

return AbstractTestSuite
