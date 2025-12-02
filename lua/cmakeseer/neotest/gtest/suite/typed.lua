local Basic = require("cmakeseer.neotest.gtest.suite.basic")

---@class cmakeseer.neotest.gtest.suite.Typed: cmakeseer.neotest.gtest.suite.Basic A suite with using a known set of types. They have a postfix, but no prefix.
---@field type_parameters string[] Type parameter IDs to types. The postfix can identify the parameter.
local Typed = Basic:new()

---@param o nil|table Optional table containing initial states.
---@return cmakeseer.neotest.gtest.suite.Typed instance A new Typed instance.
function Typed:new(o)
  ---@class cmakeseer.neotest.gtest.suite.Typed
  o = Basic.new(self, o)
  o.type_parameters = o.type_parameters or {}
  return o
end

---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param files table<string> The set of files to populate with files from this suite.
---@param prefix string? The prefix for the test.
---@param postfix string? The postfix for the test.
function Typed:parse_add_gtests(testsuite, files, prefix, postfix)
  _ = prefix
  local index = tonumber(postfix)
  if index == nil then
    vim.notify("Typed suite parse called with invalid postfix: " .. vim.inspect(postfix), vim.log.levels.ERROR)
    return
  end

  index = index + 1

  for _, test in ipairs(testsuite) do
    files[test.file] = true
    self.tests[test.name] = true
    if self.type_parameters[index] == nil then
      self.type_parameters[index] = test.type_param
    end
    assert(
      self.type_parameters[index] == test.type_param,
      "All tests in a suite with the same index should have the same type_param"
    )
  end
end

return Typed
