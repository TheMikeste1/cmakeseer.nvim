--- A basic test.
---@class cmakeseer.gtest.JsonReport.Test.Basic: cmakeseer.gtest.JsonReport.Test
---@field type "basic" The type of the suite
local Basic = {}
Basic.__index = Basic

--- Creates a new Basic instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@return cmakeseer.gtest.JsonReport.Test.Basic obj The new instance.
function Basic.new(name, file, line, status, time, classname, failures)
  ---@diagnostic disable-next-line: param-type-mismatch
  return Basic.take(name, file, line, status, time, classname, vim.deepcopy(failures))
end

--- Creates a new Basic instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@return cmakeseer.gtest.JsonReport.Test.Basic obj The new instance.
function Basic.take(name, file, line, status, time, classname, failures)
  local self = setmetatable({
    type = "basic",
    name = name,
    file = file,
    line = line,
    status = status,
    time = time,
    classname = classname,
    failures = failures,
  }, Basic)
  return self
end

--- Creates a new Basic instance from JSON.
---@param _json any
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@return cmakeseer.gtest.JsonReport.Test.Basic? obj, string? err
function Basic.try_from_json_test(_json, name, file, line, status, time, classname, failures)
  return Basic.take(name, file, line, status, time, classname, failures)
end

return Basic
