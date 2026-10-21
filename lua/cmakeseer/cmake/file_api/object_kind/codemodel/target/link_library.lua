--- Link library entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary
---@field id? string Unique identifier of the target library.
---@field fragment? string Raw linker command line arguments.
---@field backtrace? number Optional index into the backtrace graph.
---@field from_dependency? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FromDependency Optional originating dependency.
local LinkLibrary = {}

--- Creates a new LinkLibrary instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary? obj, string? err The new instance if successful. Otherwise an error.
function LinkLibrary.try_from_json(json)
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

  local from_dependency = json.fromDependency
  if from_dependency ~= nil then
    if type(from_dependency) ~= "table" then
      return nil, "fromDependency is wrong type: " .. type(from_dependency)
    end
    local from_id = from_dependency.id
    if type(from_id) ~= "string" then
      return nil, "fromDependency.id is wrong type: " .. type(from_id)
    end
    from_dependency = { id = from_id }
  end

  return {
    id = id,
    fragment = fragment,
    backtrace = backtrace,
    from_dependency = from_dependency,
  }
end

return LinkLibrary
