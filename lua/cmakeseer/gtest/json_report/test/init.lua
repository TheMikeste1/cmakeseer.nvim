--- A test.
---@class cmakeseer.gtest.JsonReport.Test
---@field type cmakeseer.gtest.JsonReport.TestSuite.Type The type of the suite
---@field name string The name of the test.
---@field file string The absolute file path containing the test.
---@field line number The line number where the test starts.
---@field status "RUN"|"NOTRUN"? The status of the test.
---@field time string? The time the test took.
---@field classname string? The classname of the test.
---@field failures { failure: string, type: string }[]? The failures of the test.
local Test = {}
Test.__index = Test

--- Creates a new Test instance from JSON.
---@param json any
---@param type_ cmakeseer.gtest.JsonReport.TestSuite.Type
---@param suite_args? table Args from the suite.
---@return cmakeseer.gtest.JsonReport.Test? obj, string? err
function Test.try_from_json(json, type_, suite_args)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end
  local file = json.file
  if type(file) ~= "string" then
    return nil, "file is wrong type: " .. type(file)
  end

  local line = json.line
  if type(line) ~= "number" then
    return nil, "line is wrong type: " .. type(line)
  end

  ---@type "RUN"|"NOTRUN"?
  local status = json.status
  if status ~= nil and status ~= "RUN" and status ~= "NOTRUN" then
    return nil, "status is wrong value: " .. tostring(status)
  end

  ---@type string?
  local time = json.time
  if time ~= nil and type(time) ~= "string" then
    return nil, "time is wrong type: " .. type(time)
  end

  ---@type string?
  local classname = json.classname
  if classname ~= nil and type(classname) ~= "string" then
    return nil, "classname is wrong type: " .. type(classname)
  end

  ---@type { failure: string, type: string }[]?
  local failures = json.failures
  if failures ~= nil then
    if not vim.islist(failures) then
      return nil, "failures is wrong type: " .. type(failures)
    end

    for i, failure in ipairs(failures) do
      if type(failure) ~= "table" then
        return nil, ("failure at index %d is wrong type: %s"):format(i, type(failure))
      end
      if type(failure.failure) ~= "string" then
        return nil, ("failure at index %d: failure is wrong type: %s"):format(i, type(failure.failure))
      end
      if type(failure.type) ~= "string" then
        return nil, ("failure at index %d: type is wrong type: %s"):format(i, type(failure.type))
      end
    end
  end

  if type_ == "basic" then
    return require("cmakeseer.gtest.json_report.test.basic").try_from_json_test(json, name, file, line, status, time, classname, failures)
  elseif type_ == "typed" then
    return require("cmakeseer.gtest.json_report.test.typed").try_from_json_test(json, name, file, line, status, time, classname, failures, assert(suite_args))
  elseif type_ == "parameterized" then
    return require("cmakeseer.gtest.json_report.test.parameterized").try_from_json_test(json, name, file, line, status, time, classname, failures, assert(suite_args))
  elseif type_ == "parameterized_typed" then
    return require("cmakeseer.gtest.json_report.test.parameterized_typed").try_from_json_test(json, name, file, line, status, time, classname, failures, assert(suite_args))
  end

  error("Unreachable")
end

function Test:disabled()
  return vim.startswith(self.name, "DISABLED_")
end

return Test
