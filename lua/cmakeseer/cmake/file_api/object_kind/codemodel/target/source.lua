--- Source file entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source
---@field path string Path to the source file. Relative if in the top-level project directory. Otherwise absolute.
---@field compile_group_index? number Index into the compileGroups array.
---@field source_group_index? number Index into the sourceGroups array.
---@field generated boolean True if the source is generated.
---@field file_set_indexes? number[] Indices into the fileSets array.
---@field backtraces? number[] Indices into the backtrace graph.
local Source = {}

--- Creates a new Source instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source? obj, string? err The new instance if successful. Otherwise an error.
function Source.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local path = json.path
  if type(path) ~= "string" then
    return nil, "path is wrong type: " .. type(path)
  end

  local compile_group_index = json.compileGroupIndex
  if compile_group_index ~= nil and type(compile_group_index) ~= "number" then
    return nil, "compileGroupIndex is wrong type: " .. type(compile_group_index)
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

  local backtraces = json.backtraces
  if backtraces ~= nil then
    if not vim.islist(backtraces) then
      return nil, "backtraces is wrong type: " .. type(backtraces)
    end

    for i, bt in ipairs(backtraces) do
      if type(bt) ~= "number" then
        return nil, ("backtraces[%d] is wrong type: %s"):format(i, type(bt))
      end
    end
  end

  local backtrace = json.backtrace
  if backtrace ~= nil then
    if type(backtrace) ~= "number" then
      return nil, "backtrace is wrong type: " .. type(backtrace)
    end

    backtraces = vim.deepcopy(backtraces) or {} ---@diagnostic disable-line: param-type-mismatch
    table.insert(backtraces, backtrace)
  end

  return {
    path = path,
    compile_group_index = compile_group_index,
    source_group_index = source_group_index,
    generated = generated,
    file_set_indexes = file_set_indexes,
    backtraces = backtraces,
  }
end

return Source
