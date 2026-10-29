--- A typed test.
---@class cmakeseer.gtest.JsonReport.Test.Typed: cmakeseer.gtest.JsonReport.Test
---@field type "typed" The type of the suite
---@field variant string The variant of the test.
local Typed = {}
Typed.__index = Typed

--- Creates a new Typed instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param variant string The variant of the test.
---@return cmakeseer.gtest.JsonReport.Test.Typed obj The new instance.
function Typed.new(name, file, line, status, time, classname, failures, variant)
  ---@diagnostic disable-next-line: param-type-mismatch
  return Typed.take(name, file, line, status, time, classname, vim.deepcopy(failures), variant)
end

--- Creates a new Typed instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param variant string The variant of the test.
---@return cmakeseer.gtest.JsonReport.Test.Typed obj The new instance.
function Typed.take(name, file, line, status, time, classname, failures, variant)
  local self = setmetatable({
    type = "typed",
    name = name,
    file = file,
    line = line,
    status = status,
    time = time,
    classname = classname,
    failures = failures,
    variant = variant,
  }, Typed)
  return self
end

--- Creates a new Typed instance from JSON.
---@param _json any
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param suite_args table Args from the suite.[
---@return cmakeseer.gtest.JsonReport.Test.Typed? obj, string? err
function Typed.try_from_json_test(_json, name, file, line, status, time, classname, failures, suite_args)
  return Typed.take(name, file, line, status, time, classname, failures, suite_args.variant)
end

return Typed
