local Counts = require("cmakeseer.gtest.json_report.testsuite.counts")
local TestSuite = require("cmakeseer.gtest.json_report.testsuite")
local object_kind = require("cmakeseer.cmake.file_api.object_kind") -- TODO: Really should move this. . .

--- A JSON report from a GTest executable.
---@class cmakeseer.gtest.JsonReport
---@field name string The name of the tests file.
---@field counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the report.
---@field testsuites table<string, cmakeseer.gtest.JsonReport.TestSuite> The test suites in the test file.
---@field timestamp string? The timestamp of the test run (date-time).
---@field time string? The time the test run took.
local JsonReport = {}
JsonReport.__index = JsonReport

--- Creates a new JsonReport instance.
---@param name string The name of the tests file.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the report.
---@param testsuites table<string, cmakeseer.gtest.JsonReport.TestSuite> The test suites in the test file.
---@param timestamp string? The timestamp of the test run (date-time).
---@param time string? The time the test run took.
---@return cmakeseer.gtest.JsonReport obj The new instance.
function JsonReport.new(name, counts, testsuites, timestamp, time)
  return JsonReport.take(name, counts, vim.deepcopy(testsuites), timestamp, time)
end

--- Creates a new JsonReport instance.
---@param name string The name of the tests file.
---@param counts cmakeseer.gtest.JsonReport.TestSuite.Counts The test counts for the report.
---@param testsuites table<string, cmakeseer.gtest.JsonReport.TestSuite> The test suites in the test file.
---@param timestamp string? The timestamp of the test run (date-time).
---@param time string? The time the test run took.
---@return cmakeseer.gtest.JsonReport obj The new instance.
function JsonReport.take(name, counts, testsuites, timestamp, time)
  local self = setmetatable({
    counts = counts,
    name = name,
    testsuites = testsuites,
    timestamp = timestamp,
    time = time,
  }, JsonReport)
  return self
end

--- Creates a new JsonReport instance from JSON.
---@param json any
---@return cmakeseer.gtest.JsonReport? obj, string? err
function JsonReport.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local counts, err = Counts.try_from_json(json)
  if counts == nil then
    return nil, "counts: " .. err
  end

  ---@type string?
  local timestamp = json.timestamp
  if timestamp ~= nil and type(timestamp) ~= "string" then
    return nil, "timestamp is wrong type: " .. type(timestamp)
  end

  ---@type string?
  local time = json.time
  if time ~= nil and type(time) ~= "string" then
    return nil, "time is wrong type: " .. type(time)
  end

  local raw_suites = json.testsuites
  if not vim.islist(raw_suites) then
    return nil, "testsuites is wrong type: " .. type(raw_suites)
  end
  local suites = {}
  for i, raw_suite in ipairs(raw_suites) do
    local suite
    suite, err = TestSuite.try_from_json(raw_suite)
    if suite == nil then
      return nil, ("suite at index %d: %s"):format(i, err)
    end

    if suites[suite.name] ~= nil then
      suites[suite.name]:merge(suite)
    else
      suites[suite.name] = suite
    end
  end

  return JsonReport.take(name, counts, suites, timestamp, time)
end

--- Creates a new JsonReport instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.gtest.JsonReport? obj, string? err The new instance if successful. Otherwise an error.
function JsonReport.try_from_file(path)
  local json, err = object_kind.try_decode_file(path)
  if json == nil then
    return nil, err
  end
  return JsonReport.try_from_json(json)
end

return JsonReport
