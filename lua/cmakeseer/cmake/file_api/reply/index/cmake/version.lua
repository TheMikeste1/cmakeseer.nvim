--- Version information for CMake.
---@class cmakeseer.cmake.file_api.reply.index.cmake.CMakeVersion
---@field major integer The major version.
---@field minor integer The minor version.
---@field patch integer The patch version.
---@field suffix string The version suffix. Will be an empty string if there isn't one.
---@field is_dirty boolean If CMake was built from a source with local modifications.
local CMakeVersion = {}
CMakeVersion.__index = CMakeVersion

--- Creates a new CMakeVersion instance.
---@param major integer The major version.
---@param minor integer The minor version.
---@param patch integer The patch version.
---@param suffix? string The version suffix, if any.
---@param is_dirty boolean If CMake was built from a source with local modifications.
---@return cmakeseer.cmake.file_api.reply.index.cmake.CMakeVersion obj The new instance.
function CMakeVersion.new(major, minor, patch, suffix, is_dirty)
  suffix = suffix or ""
  local self = setmetatable({
    major = major,
    minor = minor,
    patch = patch,
    suffix = suffix,
    is_dirty = is_dirty,
  }, CMakeVersion)
  return self
end

--- Creates a new CMakeVersion instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.reply.index.cmake.CMakeVersion? obj, string? err The new instance if successful. Otherwise an error.
function CMakeVersion.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local major = json["major"]
  if type(major) ~= "number" then
    return nil, "major is wrong type: " .. type(major)
  end
  local minor = json["minor"]
  if type(minor) ~= "number" then
    return nil, "minor is wrong type: " .. type(minor)
  end
  local patch = json["patch"]
  if type(patch) ~= "number" then
    return nil, "patch is wrong type: " .. type(patch)
  end
  local suffix = json["suffix"]
  if suffix ~= nil and type(suffix) ~= "string" then
    return nil, "suffix is wrong type: " .. type(suffix)
  end
  local is_dirty = json["isDirty"]
  if type(is_dirty) ~= "boolean" then
    return nil, "isDirty is wrong type: " .. type(is_dirty)
  end

  return CMakeVersion.new(major, minor, patch, suffix, is_dirty), nil
end

---@return string version_string The CMake version as a string in the form of `<major>.<minor>.<patch>[-<suffix>]`.
function CMakeVersion:version_string()
  local version_string = ("%d.%d.%d"):format(self.major, self.minor, self.patch)
  if self.suffix ~= "" then
    version_string = version_string .. "-" .. self.suffix
  end
  return version_string
end

return CMakeVersion
