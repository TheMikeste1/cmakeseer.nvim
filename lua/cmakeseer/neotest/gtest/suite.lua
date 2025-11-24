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

local M = {
  Basic = Basic,
  Parameterized = Parameterized,
  Typed = Typed,
  ParameterizedTyped = ParameterizedTyped,
}

--- Identifies a suite type just from its ID parts.
---@param prefix string? The prefix of the suite.
---@param postfix string? The postfix of the suite.
---@return nil | "Suite" | "ParameterizedSuite" |  "TypedSuite" |  "ParameterizedTypedSuite" suite_type The type of the suite. nil if it is not a suite.
function M.type_from_id_parts(prefix, postfix)
  if prefix == nil and postfix == nil then
    return "Suite"
  end
  if prefix ~= nil and postfix == nil then
    return "ParameterizedSuite"
  end
  if prefix == nil and postfix ~= nil then
    return "TypedSuite"
  end
  if prefix ~= nil and postfix ~= nil then
    return "ParameterizedTypedSuite"
  end
  return nil
end

--- Determines the type for a suite.
---@param suite table The suite to check.
---@return nil | "Suite" | "ParameterizedSuite" |  "TypedSuite" |  "ParameterizedTypedSuite" suite_type The type of the suite. nil if it is not a suite.
function M.type_from_suite(suite)
  if suite == nil or suite.name == nil then
    return nil
  end

  if suite.value_parameters ~= nil then
    return "ParameterizedSuite"
  end

  if suite.type_parameters ~= nil then
    return "TypedSuite"
  end

  if suite.parameterized_type_parameters ~= nil then
    return "ParameterizedTypedSuite"
  end

  return "Suite"
end

return M
