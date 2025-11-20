---@class cmakeseer.neotest.gtest.suite.Basic A suite with no additional parameters or values. They have no prefix nor postfix.
---@field name string The name of the suite.
---@field tests table<string> A set of the tests in the suite.

---@class cmakeseer.neotest.gtest.suite.Parameterized: cmakeseer.neotest.gtest.suite.Basic A suite with parameterized arguments. They have a prefix, but the postfix is added to the individual tests instead.
---@field value_parameters table<string, string[]> Prefixes to value parameter IDs to values. The postfix of each test can identify the parameter used for each prefix.

---@class cmakeseer.neotest.gtest.suite.Typed: cmakeseer.neotest.gtest.suite.Basic A suite with using a known set of types. They have a postfix, but no prefix.
---@field type_parameters string[] Type parameter IDs to types. The postfix can identify the parameter.

---@class cmakeseer.neotest.gtest.suite.ParameterizedTyped: cmakeseer.neotest.gtest.suite.Basic A suite with parameterized types. The have a prefix and a postfix.
---@field parameterized_type_parameters table<string, string[]> Prefixes to postfixes to type parameters.

local M = {}

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
