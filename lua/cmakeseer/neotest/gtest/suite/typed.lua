local Basic = require("cmakeseer.neotest.gtest.suite.basic")

---@class cmakeseer.neotest.gtest.suite.Typed: cmakeseer.neotest.gtest.suite.Basic A suite with using a known set of types. They have a postfix, but no prefix.
---@field type_parameters string[] Type parameter IDs to types. The postfix can identify the parameter.
local Typed = Basic:new({
  type_parameters = {},
})

---@param o nil|table Optional table containing initial states.
---@return cmakeseer.neotest.gtest.suite.Typed instance A new Typed instance.
function Typed:new(o)
  ---@class cmakeseer.neotest.gtest.suite.Typed
  o = Basic.new(self, o)
  o.type_parameters = o.type_parameters or {}
  return o
end

return Typed
