--- Interface Link library entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary
---@field id? string Unique identifier of the target library.
---@field fragment? string Raw linker command line arguments.
---@field backtrace? number Optional index into the backtrace graph.
local InterfaceLinkLibrary = {}

--- Creates a new InterfaceLinkLibrary instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary? obj, string? err The new instance if successful. Otherwise an error.
function InterfaceLinkLibrary.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local id = json.id
  if id ~= nil and type(id) ~= "string" then
    return nil, "id is wrong type: " .. type(id)
  end

  local fragment = json.fragment
  if fragment ~= nil and type(fragment) ~= "string" then
    return nil, "fragment is wrong type: " .. type(fragment)
  end

  local backtrace = json.backtrace
  if backtrace ~= nil and type(backtrace) ~= "number" then
    return nil, "backtrace is wrong type: " .. type(backtrace)
  end

  return {
    id = id,
    fragment = fragment,
    backtrace = backtrace,
  }
end

return InterfaceLinkLibrary
