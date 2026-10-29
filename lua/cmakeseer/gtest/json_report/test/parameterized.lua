--- A parameterized test.
---@class cmakeseer.gtest.JsonReport.Test.Parameterized: cmakeseer.gtest.JsonReport.Test
---@field type "parameterized" The type of the suite
---@field prefix string The prefix of the test.
---@field postfix string The postfix of the test.
local Parameterized = {}
Parameterized.__index = Parameterized

--- Creates a new Parameterized instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param prefix string The prefix of the test.
---@param postfix string The postfix of the test.
---@return cmakeseer.gtest.JsonReport.Test.Parameterized obj The new instance.
function Parameterized.new(name, file, line, status, time, classname, failures, prefix, postfix)
  ---@diagnostic disable-next-line: param-type-mismatch
  return Parameterized.take(name, file, line, status, time, classname, vim.deepcopy(failures), prefix, postfix)
end

--- Creates a new Parameterized instance.
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param prefix string The prefix of the test.
---@param postfix string The postfix of the test.
---@return cmakeseer.gtest.JsonReport.Test.Parameterized obj The new instance.
function Parameterized.take(name, file, line, status, time, classname, failures, prefix, postfix)
  local self = setmetatable({
    type = "parameterized",
    name = name,
    file = file,
    line = line,
    status = status,
    time = time,
    classname = classname,
    failures = failures,
    prefix = prefix,
    postfix = postfix,
  }, Parameterized)
  return self
end

--- Creates a new Parameterized instance from JSON.
---@param _json any
---@param name string The name of the test.
---@param file string The absolute file path containing the test.
---@param line number The line number where the test starts.
---@param status "RUN"|"NOTRUN"? The status of the test.
---@param time string? The time the test took.
---@param classname string? The classname of the test.
---@param failures { failure: string, type: string }[]? The failures of the test.
---@param suite_args table Args from the suite.
---@return cmakeseer.gtest.JsonReport.Test.Parameterized? obj, string? err
function Parameterized.try_from_json_test(_json, name, file, line, status, time, classname, failures, suite_args)
  local parts = vim.split(name, "/", { plain = true })
  name = parts[1]
  local postfix = parts[2]
  if postfix == nil then
    return nil, "No postfix!"
  end
  return Parameterized.take(name, file, line, status, time, classname, failures, suite_args.prefix, postfix)
end

return Parameterized
