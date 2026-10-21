--- Link command fragment.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link.CommandFragment
---@field fragment string A fragment of the link command line invocation.
---@field role "flags"|"libraries"|"libraryPath"|"frameworkPath" The role of the fragment's content.
---@field backtrace? number Optional index into the backtrace graph.

--- Link information for a target.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link
---@field language string The language of the toolchain used to invoke the linker.
---@field command_fragments? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link.CommandFragment[] Ordered link command fragments.
---@field lto boolean If link-time optimization is enabled.
---@field sysroot? string Optional sysroot path.
local Link = {}

--- Parses an array of command fragments.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link.CommandFragment[]? fragments, string? err
local function parse_link_command_fragments(json)
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
    if role ~= "flags" and role ~= "libraries" and role ~= "libraryPath" and role ~= "frameworkPath" then
      return nil, ("commandFragments[%d].role is invalid: %s"):format(i, role)
    end
    local backtrace = frag_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("commandFragments[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(fragments, { fragment = fragment, role = role, backtrace = backtrace })
  end
  return fragments, nil
end

--- Creates a new Link instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link? obj, string? err The new instance if successful. Otherwise an error.
function Link.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local language = json.language
  if type(language) ~= "string" then
    return nil, "language is wrong type: " .. type(language)
  end

  local command_fragments, err = parse_link_command_fragments(json.commandFragments)
  if command_fragments == nil and err ~= nil then
    return nil, err
  end

  local lto = json.lto or false
  if type(lto) ~= "boolean" then
    return nil, "lto is wrong type: " .. type(lto)
  end

  local sysroot = json.sysroot
  if sysroot ~= nil then
    if type(sysroot) ~= "table" then
      return nil, "sysroot is wrong type: " .. type(sysroot)
    end
    local sysroot_path = sysroot.path
    if type(sysroot_path) ~= "string" then
      return nil, "sysroot.path is wrong type: " .. type(sysroot_path)
    end
    sysroot = sysroot_path
  end

  return {
    language = language,
    command_fragments = command_fragments,
    lto = lto,
    sysroot = sysroot,
  }
end

return Link
