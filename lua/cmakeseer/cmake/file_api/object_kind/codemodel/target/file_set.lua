--- File set entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet
---@field name string Name of the file set.
---@field type string Type of the file set.
---@field visibility "PUBLIC"|"PRIVATE"|"INTERFACE" Visibility of the file set.
---@field base_directories string[] Base directories containing sources.
local FileSet = {}

--- Creates a new FileSet instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet? obj, string? err The new instance if successful. Otherwise an error.
function FileSet.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local type_str = json.type
  if type(type_str) ~= "string" then
    return nil, "type is wrong type: " .. type(type_str)
  end

  local visibility = json.visibility
  if type(visibility) ~= "string" then
    return nil, "visibility is wrong type: " .. type(visibility)
  end
  if visibility ~= "PUBLIC" and visibility ~= "PRIVATE" and visibility ~= "INTERFACE" then
    return nil, "visibility is invalid: " .. visibility
  end

  local base_directories = json.baseDirectories
  if type(base_directories) ~= "table" or not vim.islist(base_directories) then
    return nil, "baseDirectories is wrong type: " .. type(base_directories)
  end
  for i, dir in ipairs(base_directories) do
    if type(dir) ~= "string" then
      return nil, ("baseDirectories[%d] is wrong type: %s"):format(i, type(dir))
    end
  end

  return {
    name = name,
    type = type_str,
    visibility = visibility,
    base_directories = base_directories,
  }
end

return FileSet
