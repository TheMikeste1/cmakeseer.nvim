---@class cmakeseer.cmake.file_api.object_kind.ObjectKind
---@field kind cmakeseer.cmake.file_api.object_kind.ObjectKindType
---@field version cmakeseer.cmake.file_api.object_kind.Version

---@class (exact) cmakeseer.cmake.file_api.object_kind.Version A CMake version object.
---@field major number The major version number.
---@field minor number The minor version number.

local M = {
  ---@enum cmakeseer.cmake.file_api.object_kind.ObjectKindType The possible Object Kind types.
  ObjectKindType = {
    Codemodel = "codemodel",
    ConfigureLog = "configureLog",
    Cache = "cache",
    CMakeFiles = "cmakeFiles",
    Toolchains = "toolchains",
  },
}

--- Converts a string to an ObjectKindType.
---@param str string
---@return cmakeseer.cmake.file_api.object_kind.ObjectKindType? maybe_type The type, if it was a valid type.
function M.from_string(str)
  for _, value in pairs(M.ObjectKindType) do
    if value == str then
      return value
    end
  end
  return nil
end

--- Tries to extract a Version from a JSON object.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Version? version, string? err The version, if successful. Otherwise an error.
function M.try_version_from_json(json)
  if type(json) ~= "table" then
    return nil, "version is wrong type: " .. type(json)
  end
  if type(json.major) ~= "number" then
    return nil, "version.major is wrong type: " .. type(json.major)
  end
  if type(json.minor) ~= "number" then
    return nil, "version.minor is wrong type: " .. type(json.minor)
  end
  return {
    major = json.major,
    minor = json.minor,
  }
end

return M
