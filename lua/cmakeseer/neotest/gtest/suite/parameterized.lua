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

---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param files table<string> The set of files to populate with files from this suite.
---@param prefix string? The prefix for the test.
---@param postfix string? The postfix for the test.
function Parameterized:parse_add_gtests(testsuite, files, prefix, postfix)
  _ = postfix
  if prefix == nil then
    vim.notify("Parameterized suite parse called with invalid nil prefix", vim.log.levels.ERROR)
    return
  end

  self.value_parameters[prefix] = self.value_parameters[prefix] or {}
  local params = self.value_parameters[prefix]
  for _, test in ipairs(testsuite) do
    files[test.file] = true

    local test_parts = vim.split(test.name, "/")
    assert(#test_parts == 2, "ParameterizedSuite test names should consist of a name and an index, e.g. `SomeTest/0`")
    self.tests[test_parts[1]] = true
    local index = tonumber(test_parts[2])
    assert(index ~= nil, "Index should be a number")
    index = index + 1
    if params[index] == nil then
      params[index] = test.value_param
    end
    assert(params[index] == test.value_param, "Not all tests had the same value_param at the same index")
  end
end

return Parameterized
