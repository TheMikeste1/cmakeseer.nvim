local Basic = require("cmakeseer.neotest.gtest.suite.basic")

---@class cmakeseer.neotest.gtest.suite.Parameterized: cmakeseer.neotest.gtest.suite.Basic A suite with parameterized arguments. They have a prefix, but the postfix is added to the individual tests instead.
---@field value_parameters table<string, string[]> Prefixes to value parameter IDs to values. The postfix of each test can identify the parameter used for each prefix.
local Parameterized = Basic:new({
  value_parameters = {},
})

---@param o nil|table Optional table containing initial states.
---@return cmakeseer.neotest.gtest.suite.Parameterized instance A new Parameterized instance.
function Parameterized:new(o)
  ---@class cmakeseer.neotest.gtest.suite.Parameterized
  o = Basic.new(self, o)
  o.value_parameters = o.value_parameters or {}
  return o
end

return Parameterized
