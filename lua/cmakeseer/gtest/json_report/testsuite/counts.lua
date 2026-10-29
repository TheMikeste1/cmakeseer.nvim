--- Test suite/report counts.
---@class cmakeseer.gtest.JsonReport.TestSuite.Counts
---@field test_count integer The total number of tests.
---@field failures_count integer? The number of failed tests.
---@field disabled_count integer? The number of disabled tests.
---@field errors integer? The number of test errors.
local Counts = {}
Counts.__index = Counts

--- Creates a new Counts instance.
---@param test_count integer The total number of tests.
---@param failures_count integer? The number of failed tests.
---@param disabled_count integer? The number of disabled tests.
---@param errors integer? The number of test errors.
---@return cmakeseer.gtest.JsonReport.TestSuite.Counts obj The new instance.
function Counts.new(test_count, failures_count, disabled_count, errors)
  return Counts.take(test_count, failures_count, disabled_count, errors)
end

--- Creates a new Counts instance.
---@param test_count integer The total number of tests.
---@param failures_count integer? The number of failed tests.
---@param disabled_count integer? The number of disabled tests.
---@param errors integer? The number of test errors.
---@return cmakeseer.gtest.JsonReport.TestSuite.Counts obj The new instance.
function Counts.take(test_count, failures_count, disabled_count, errors)
  local self = setmetatable({
    test_count = test_count,
    failures_count = failures_count,
    disabled_count = disabled_count,
    errors = errors,
  }, Counts)
  return self
end

--- Creates a new Counts instance from JSON.
---@param json any
---@return cmakeseer.gtest.JsonReport.TestSuite.Counts? obj, string? err
function Counts.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local test_count = json.tests
  if type(test_count) ~= "number" then
    return nil, "tests is wrong type: " .. type(test_count)
  end

  ---@type integer?
  local failures_count = json.failures
  if failures_count ~= nil and type(failures_count) ~= "number" then
    return nil, "failures is wrong type: " .. type(failures_count)
  end

  ---@type integer?
  local disabled_count = json.disabled
  if disabled_count ~= nil and type(disabled_count) ~= "number" then
    return nil, "disabled is wrong type: " .. type(disabled_count)
  end

  ---@type integer?
  local errors = json.errors
  if errors ~= nil and type(errors) ~= "number" then
    return nil, "errors is wrong type: " .. type(errors)
  end

  return Counts.take(test_count, failures_count, disabled_count, errors)
end

return Counts
