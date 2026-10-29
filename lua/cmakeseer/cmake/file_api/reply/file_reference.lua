local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType

--- A reference to another file containing an object kind.
---@class cmakeseer.cmake.file_api.reply.FileReference
---@field kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The kind of the reference.
---@field version cmakeseer.cmake.file_api.object_kind.Version The version of the object kind.
---@field json_file string Absolute path to the object kind file.
local FileReference = {}
FileReference.__index = FileReference

--- Creates a new FileReference instance.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The kind of the reference.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version of the object kind.
---@param json_file string Absolute path to the object kind file.
---@return cmakeseer.cmake.file_api.reply.FileReference? obj, string? err The new instance.
function FileReference.new(kind, version, json_file)
  if vim.fn.isabsolutepath(json_file) == 0 then
    return nil, ("`%s` is not an absolute path"):format(json_file)
  end

  return FileReference.new_unchecked(kind, version, json_file), nil
end

--- Creates a new FileReference instance without checking invariants.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The kind of the reference.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version of the object kind.
---@param json_file string Absolute path to the object kind file.
---@return cmakeseer.cmake.file_api.reply.FileReference obj The new instance.
function FileReference.new_unchecked(kind, version, json_file)
  local self = setmetatable({
    kind = kind,
    version = vim.deepcopy(version),
    json_file = json_file,
  }, FileReference)
  return self
end

--- Creates a new Generator instance from JSON.
---@param json any The json object from which values should be extracted.
---@param index_file_path string The path to the owning index file. Can be either absolute or relative.
---@return cmakeseer.cmake.file_api.reply.FileReference? obj, string? err The new instance if successful. Otherwise an error.
function FileReference.try_from_json(json, index_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local kind_value = json["kind"]
  if type(kind_value) ~= "string" then
    return nil, "kind is wrong type: " .. type(kind_value)
  end

  local kind = object_kind.from_string(kind_value)
  if kind == nil then
    return nil, "kind was an invalid object kind: " .. kind_value
  end

  local version, err = object_kind.try_version_from_json(json.version)
  if version == nil then
    return nil, err
  end

  local json_file = json["jsonFile"]
  if type(json_file) ~= "string" then
    return nil, "jsonFile is wrong type: " .. type(json_file)
  end
  if vim.fn.isabsolutepath(json_file) == 0 then
    json_file = vim.fs.joinpath(vim.fs.dirname(index_file_path), json_file)
    json_file = vim.fn.fnamemodify(json_file, ":p")
  end

  return FileReference.new_unchecked(kind, version, json_file)
end

--- Attempts to load the object kind.
---@return cmakeseer.cmake.file_api.object_kind.ObjectKind? obj, string? err The object kind if successful. Otherwise an error.
function FileReference:try_load()
  if self.kind == ObjectKindType.Codemodel then
    return require("cmakeseer.cmake.file_api.object_kind.codemodel").try_from_file(self.json_file)
  elseif self.kind == ObjectKindType.ConfigureLog then
    return require("cmakeseer.cmake.file_api.object_kind.configure_log").try_from_file(self.json_file)
  elseif self.kind == ObjectKindType.Cache then
    return require("cmakeseer.cmake.file_api.object_kind.cache").try_from_file(self.json_file)
  elseif self.kind == ObjectKindType.CMakeFiles then
    return require("cmakeseer.cmake.file_api.object_kind.cmake_files").try_from_file(self.json_file)
  elseif self.kind == ObjectKindType.Toolchains then
    return require("cmakeseer.cmake.file_api.object_kind.toolchains").try_from_file(self.json_file)
  end

  error("Unreachable")
end

return FileReference
