local Basic = require("cmakeseer.neotest.gtest.suite.basic")

---@class cmakeseer.neotest.gtest.suite.ParameterizedTyped: cmakeseer.neotest.gtest.suite.Basic A suite with parameterized types. The have a prefix and a postfix.
---@field parameterized_type_parameters table<string, string[]> Prefixes to postfixes to type parameters.
local ParameterizedTyped = Basic:new()

---@param o nil|table Optional table containing initial states.
---@return cmakeseer.neotest.gtest.suite.ParameterizedTyped instance A new Typed instance.
function ParameterizedTyped:new(o)
  ---@class cmakeseer.neotest.gtest.suite.ParameterizedTyped
  o = Basic.new(self, o)
  o.parameterized_type_parameters = o.parameterized_type_parameters or {}
  return o
end

---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param files table<string> The set of files to populate with files from this suite.
---@param prefix string? The prefix for the test.
---@param postfix string? The postfix for the test.
function ParameterizedTyped:parse_add_gtests(testsuite, files, prefix, postfix)
  if prefix == nil then
    vim.notify("ParameterizedTyped suite parse called with invalid nil prefix", vim.log.levels.ERROR)
    return
  end

  local index = tonumber(postfix)
  if index == nil then
    vim.notify("ParameterizedTyped suite parse called with invalid postfix: " .. vim.inspect(postfix), vim.log.levels.ERROR)
    return
  end

  index = index + 1

  self.parameterized_type_parameters[prefix] = self.parameterized_type_parameters[prefix] or {}
  local params = self.parameterized_type_parameters[prefix]
  for _, test in ipairs(testsuite) do
    files[test.file] = true
    self.tests[test.name] = true
    if params[index] == nil then
      params[index] = test.type_param
    end
    assert(params[index] == test.type_param, "All tests in a suite with the same key should have the same type_param")
  end
end

return ParameterizedTyped
