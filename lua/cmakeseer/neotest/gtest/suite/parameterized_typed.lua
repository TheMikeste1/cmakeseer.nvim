local Basic = require("cmakeseer.neotest.gtest.suite.basic")

---@class cmakeseer.neotest.gtest.suite.ParameterizedTyped: cmakeseer.neotest.gtest.suite.Basic A suite with parameterized types. The have a prefix and a postfix.
---@field parameterized_type_parameters table<string, string[]> Prefixes to postfixes to type parameters.
local ParameterizedTyped = Basic:new({
  parameterized_type_parameters = {},
})

---@param o nil|table Optional table containing initial states.
---@return cmakeseer.neotest.gtest.suite.ParameterizedTyped instance A new Typed instance.
function ParameterizedTyped:new(o)
  ---@class cmakeseer.neotest.gtest.suite.ParameterizedTyped
  o = Basic.new(self, o)
  o.type_parameters = o.type_parameters or {}
  return o
end

return ParameterizedTyped
