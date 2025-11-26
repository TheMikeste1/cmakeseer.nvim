---@class cmakeseer.neotest.gtest.suite.Basic A suite with no additional parameters or values. They have no prefix nor postfix.
---@field name string The name of the suite.
---@field tests table<string> A set of the tests in the suite.
local Basic = {
  name = "Unknown Suite",
  tests = {},
}

---@param o nil|table Optional table containing initial states.
---@return cmakeseer.neotest.gtest.suite.Basic instance A new Basic instance.
function Basic:new(o)
  o = o or {}
  o.tests = o.tests or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

---@param testsuite table<string, any> The GTest testsuite associated with the suite.
---@param files table<string> The set of files to populate with files from this suite.
---@param prefix string? The prefix for the test.
---@param postfix string? The postfix for the test.
function Basic:parse_add_gtests(testsuite, files, prefix, postfix)
  _ = prefix
  _ = postfix
  for _, test in ipairs(testsuite) do
    files[test.file] = true
    self.tests[test.name] = true
  end
end

return Basic
