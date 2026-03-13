local M = {
  Basic = require("neotest.cmakeseer.gtest.suite.basic"),
  Parameterized = require("neotest.cmakeseer.gtest.suite.parameterized"),
  ParameterizedTyped = require("neotest.cmakeseer.gtest.suite.parameterized_typed"),
  Typed = require("neotest.cmakeseer.gtest.suite.typed"),
  ---@enum neotest.cmakeseer.gtest.suite.Type The type of a suite.
  Type = {
    Basic = "Basic",
    Parameterized = "Parameterized",
    ParameterizedTyped = "ParameterizedTyped",
    Typed = "Typed",
  },
}

--- Identifies a suite type just from its ID parts.
---@param prefix string? The prefix of the suite.
---@param postfix string? The postfix of the suite.
---@return nil|neotest.cmakeseer.gtest.suite.Type suite_type The type of the suite. nil if it is not a suite.
function M.type_from_id_parts(prefix, postfix)
  if prefix == nil and postfix == nil then
    return M.Type.Basic
  end
  if prefix ~= nil and postfix == nil then
    return M.Type.Parameterized
  end
  if prefix == nil and postfix ~= nil then
    return M.Type.Typed
  end
  if prefix ~= nil and postfix ~= nil then
    return M.Type.ParameterizedTyped
  end
  return nil
end

--- Determines the type for a suite.
---@param suite table The suite to check.
---@return nil|neotest.cmakeseer.gtest.suite.Type suite_type The type of the suite. nil if it is not a suite.
function M.type_from_suite(suite)
  if suite == nil or suite.name == nil then
    return nil
  end

  if suite.value_parameters ~= nil then
    return M.Type.Parameterized
  end

  if suite.type_parameters ~= nil then
    return M.Type.Typed
  end

  if suite.parameterized_type_parameters ~= nil then
    return M.Type.ParameterizedTyped
  end

  return M.Type.Basic
end

return M
