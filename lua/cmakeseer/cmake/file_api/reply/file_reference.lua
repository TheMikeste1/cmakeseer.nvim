local object_kind = require("cmakeseer.cmake.file_api.object_kind")

--- A reference to another file containing an object kind.
---@class cmakeseer.cmake.file_api.reply.FileReference
---@field kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The kind of the reference.
---@field version { major: integer, minor: integer } The version of the object kind.
---@field json_file string Absolute path to the object kind file.
local FileReference = {}
FileReference.__index = FileReference

--- Creates a new FileReference instance.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The kind of the reference.
---@param version { major: integer, minor: integer } The version of the object kind.
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
---@param version { major: integer, minor: integer } The version of the object kind.
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

  local version = json["version"]
  if type(version) ~= "table" then
    return nil, "version is wrong type: " .. type(version)
  end
  if type(version.major) ~= "number" then
    return nil, "version.major is wrong type: " .. type(version.major)
  end
  if type(version.minor) ~= "number" then
    return nil, "version.minor is wrong type: " .. type(version.minor)
  end

  local json_file = json["jsonFile"]
  if json_file ~= nil and type(json_file) ~= "string" then
    return nil, "jsonFile is wrong type: " .. type(json_file)
  end
  assert(vim.fn.isabsolutepath(json_file) == 0)
  json_file = vim.fs.joinpath(vim.fs.dirname(index_file_path), json_file)
  json_file = vim.fn.fnamemodify(json_file, ":p")

  return FileReference.new_unchecked(kind, vim.deepcopy(version), json_file)
end

return FileReference
