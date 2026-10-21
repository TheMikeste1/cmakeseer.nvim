--- Archive command fragment.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive.CommandFragment
---@field fragment string A fragment of the archiver command line invocation.
---@field role "flags" The role of the fragment's content.

--- Archive information for static library targets.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive
---@field command_fragments? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive.CommandFragment[] Archiver command fragments.
---@field lto boolean If link-time optimization is enabled.
local Archive = {}

--- Parses an array of command fragments.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive.CommandFragment[]? fragments, string? err
local function parse_archive_command_fragments(json)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "commandFragments is wrong type: " .. type(json)
  end
  local fragments = {}
  for i, frag_json in ipairs(json) do
    if type(frag_json) ~= "table" then
      return nil, ("commandFragments[%d] is wrong type: %s"):format(i, type(frag_json))
    end
    local fragment = frag_json.fragment
    if type(fragment) ~= "string" then
      return nil, ("commandFragments[%d].fragment is wrong type: %s"):format(i, type(fragment))
    end
    local role = frag_json.role
    if type(role) ~= "string" then
      return nil, ("commandFragments[%d].role is wrong type: %s"):format(i, type(role))
    end
    if role ~= "flags" then
      return nil, ("commandFragments[%d].role is invalid: %s"):format(i, role)
    end
    table.insert(fragments, { fragment = fragment, role = role })
  end
  return fragments, nil
end

--- Creates a new Archive instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive? obj, string? err The new instance if successful. Otherwise an error.
function Archive.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local command_fragments, err = parse_archive_command_fragments(json.commandFragments)
  if command_fragments == nil and err ~= nil then
    return nil, err
  end

  local lto = json.lto or false
  if type(lto) ~= "boolean" then
    return nil, "lto is wrong type: " .. type(lto)
  end

  return {
    command_fragments = command_fragments,
    lto = lto,
  }
end

return Archive
