--- A ParameterizedTyped test.
---@class cmakeseer.gtest.JsonReport.Test.ParameterizedTyped: cmakeseer.gtest.JsonReport.Test
---@field type "parameterized_typed" The type of the suite
---@field prefix string The prefix of the test.
---@field postfix string The postfix of the test.
local ParameterizedTyped = {}
ParameterizedTyped.__index = ParameterizedTyped

--- Creates a new ParameterizedTyped instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param prefix string The prefix of the test.
---@param postfix string The postfix of the test.
---@return cmakeseer.gtest.JsonReport.Test.ParameterizedTyped obj The new instance.
function ParameterizedTyped.new(name, file, line, status, time, classname, failures, prefix, postfix)
  ---@diagnostic disable-next-line: param-type-mismatch
  return ParameterizedTyped.take(name, file, line, status, time, classname, vim.deepcopy(failures), prefix, postfix)
end

--- Creates a new ParameterizedTyped instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param prefix string The prefix of the test.
---@param postfix string The postfix of the test.
---@return cmakeseer.gtest.JsonReport.Test.ParameterizedTyped obj The new instance.
function ParameterizedTyped.take(name, file, line, status, time, classname, failures, prefix, postfix)
  local self = setmetatable({
    type = "parameterized_typed",
    name = name,
    file = file,
    line = line,
    status = status,
    time = time,
    classname = classname,
    failures = failures,
    prefix = prefix,
    postfix = postfix,
  }, ParameterizedTyped)
  return self
end

--- Creates a new ParameterizedTyped instance from JSON.
---@param _json any
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param suite_args table Args from the suite.[
---@return cmakeseer.gtest.JsonReport.Test.ParameterizedTyped? obj, string? err
function ParameterizedTyped.try_from_json_test(_json, name, file, line, status, time, classname, failures, suite_args)
  return ParameterizedTyped.take(name, file, line, status, time, classname, failures, suite_args.prefix, suite_args.postfix)
end

return ParameterizedTyped
