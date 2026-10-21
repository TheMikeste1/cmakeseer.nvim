--- Interface source file entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource
---@field path string Path to the source file.
---@field source_group_index? number Index into the sourceGroups array.
---@field generated boolean True if the source is generated.
---@field file_set_indexes? number[] Indices into the fileSets array.
local InterfaceSource = {}

--- Creates a new InterfaceSource instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource? obj, string? err The new instance if successful. Otherwise an error.
function InterfaceSource.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local path = json.path
  if type(path) ~= "string" then
    return nil, "path is wrong type: " .. type(path)
  end

  local source_group_index = json.sourceGroupIndex
  if source_group_index ~= nil and type(source_group_index) ~= "number" then
    return nil, "sourceGroupIndex is wrong type: " .. type(source_group_index)
  end

  local generated = json.isGenerated or false
  if type(generated) ~= "boolean" then
    return nil, "isGenerated is wrong type: " .. type(generated)
  end

  local file_set_indexes
  local raw_file_set_indexes = json.fileSetIndexes
  if raw_file_set_indexes == nil then
    raw_file_set_indexes = json.fileSetIndex and { json.fileSetIndex } or nil
  end
  if raw_file_set_indexes ~= nil then
    if type(raw_file_set_indexes) ~= "table" or not vim.islist(raw_file_set_indexes) then
      return nil, "fileSetIndexes is wrong type: " .. type(raw_file_set_indexes)
    end
    file_set_indexes = {}
    for i, idx in ipairs(raw_file_set_indexes) do
      if type(idx) ~= "number" then
        return nil, ("fileSetIndexes[%d] is wrong type: %s"):format(i, type(idx))
      end
      table.insert(file_set_indexes, idx)
    end
  end

  return {
    path = path,
    source_group_index = source_group_index,
    generated = generated,
    file_set_indexes = file_set_indexes,
  }
end

return InterfaceSource
