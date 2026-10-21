--- Interface include directory entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude
---@field path string Path to the include directory.
---@field is_system boolean If this is a system include directory.
---@field languages? string[] An array of strings to which the include applies.
---@field backtrace? number Optional index into the backtrace graph.
local InterfaceInclude = {}

--- Creates a new InterfaceInclude instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude? obj, string? err The new instance if successful. Otherwise an error.
function InterfaceInclude.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local path = json.path
  if type(path) ~= "string" then
    return nil, "path is wrong type: " .. type(path)
  end

  local is_system = json.isSystem or false
  if type(is_system) ~= "boolean" then
    return nil, "isSystem is wrong type: " .. type(is_system)
  end

  local languages = json.languages
  if languages ~= nil then
    if type(languages) ~= "table" or not vim.islist(languages) then
      return nil, "languages is wrong type: " .. type(languages)
    end
    for i, lang in ipairs(languages) do
      if type(lang) ~= "string" then
        return nil, ("languages[%d] is wrong type: %s"):format(i, type(lang))
      end
    end
  end

  local backtrace = json.backtrace
  if backtrace ~= nil and type(backtrace) ~= "number" then
    return nil, "backtrace is wrong type: " .. type(backtrace)
  end

  return {
    path = path,
    is_system = is_system,
    languages = languages,
    backtrace = backtrace,
  }
end

return InterfaceInclude
