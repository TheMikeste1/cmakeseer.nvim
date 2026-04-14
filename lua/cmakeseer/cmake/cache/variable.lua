---@alias VariableType "BOOL"|"PATH"|"FILEPATH"|"STRING"|"INTERNAL"|"STATIC"|"UNINITIALIZED"

--- @class cmakeseer.cmake.cache.Variable
--- @field name string The name of the CMake cache variable.
--- @field description string The description of the CMake cache variable.
--- @field value string The value of the CMake cache variable.
--- @field type VariableType The type of the CMake cache variable.
--- @field advanced boolean Indicates if the variable is advanced.
local Variable = {}

--- @param name string The name of the variable.
--- @param value string The value of the variable.
--- @param description string A description for the variable.
--- @param type_ string The type of the variable.
--- @param advanced boolean? Whether the variable is advanced.
--- @return cmakeseer.cmake.cache.Variable
function Variable:new(name, value, description, type_, advanced)
  vim.validate("name", name, function(v)
    return type(v) == "string" and v ~= ""
  end, false, "non-empty string")
  vim.validate("description", description, "string", false)
  vim.validate("value", value, "string", false)
  vim.validate("type", type_, "string", false)
  vim.validate("advanced", advanced, "boolean", true)

  local new_var = {}
  new_var.name = name
  new_var.description = description
  new_var.value = value
  new_var.type = type_
  new_var.advanced = advanced ~= nil and advanced or false
  setmetatable(new_var, self)
  self.__index = self
  return new_var
end

return Variable
