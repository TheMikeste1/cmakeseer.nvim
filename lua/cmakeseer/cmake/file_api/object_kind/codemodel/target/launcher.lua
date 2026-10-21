--- Launcher information for a target
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher
---@field command string The path to the launcher on disk.
---@field arguments string[] Arguments for the Arguments for the launcher.
---@field type "emulator"|"test" The type of launcher.
local Launcher = {}

--- Creates a new Launcher instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher? obj, string? err The new instance if successful. Otherwise an error.
function Launcher.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local command = json.command
  if type(command) ~= "string" then
    return nil, "command is wrong type: " .. type(command)
  end

  local arguments = json.arguments
  if type(arguments) ~= "table" or not vim.islist(arguments) then
    return nil, "arguments is wrong type: " .. type(arguments)
  end
  for i, arg in ipairs(arguments) do
    if type(arg) ~= "string" then
      return nil, ("arguments[%d] is wrong type: %s"):format(i, type(arg))
    end
  end

  local type_str = json.type
  if type(type_str) ~= "string" then
    return nil, "type is wrong type: " .. type(type_str)
  end
  if type_str ~= "emulator" and type_str ~= "test" then
    return nil, "type is invalid: " .. type_str
  end

  return {
    command = command,
    arguments = arguments,
    type = type_str,
  }
end

return Launcher
