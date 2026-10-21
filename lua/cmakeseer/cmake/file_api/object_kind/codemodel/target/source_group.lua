--- Source group entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup
---@field name string Name of the source group.
---@field source_indexes number[] Indices into the sources array.
---@field interface_source_indexes? number[] Indices into the interfaceSources array.
local SourceGroup = {}

--- Creates a new SourceGroup instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup? obj, string? err The new instance if successful. Otherwise an error.
function SourceGroup.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local source_indexes = json.sourceIndexes
  if type(source_indexes) ~= "table" or not vim.islist(source_indexes) then
    return nil, "sourceIndexes is wrong type: " .. type(source_indexes)
  end
  for i, idx in ipairs(source_indexes) do
    if type(idx) ~= "number" then
      return nil, ("sourceIndexes[%d] is wrong type: %s"):format(i, type(idx))
    end
  end

  local interface_source_indexes = json.interfaceSourceIndexes
  if interface_source_indexes ~= nil then
    if type(interface_source_indexes) ~= "table" or not vim.islist(interface_source_indexes) then
      return nil, "interfaceSourceIndexes is wrong type: " .. type(interface_source_indexes)
    end
    for i, idx in ipairs(interface_source_indexes) do
      if type(idx) ~= "number" then
        return nil, ("interfaceSourceIndexes[%d] is wrong type: %s"):format(i, type(idx))
      end
    end
  end

  return {
    name = name,
    source_indexes = source_indexes,
    interface_source_indexes = interface_source_indexes,
  }
end

return SourceGroup
