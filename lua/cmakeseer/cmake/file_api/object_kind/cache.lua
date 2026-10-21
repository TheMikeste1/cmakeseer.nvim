local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType

--- A property for a cache entry.
---@class cmakeseer.cmake.file_api.object_kind.Cache.Property
---@field name string The name of the property.
---@field value string The value of the property.

--- A cache entry. Includes the name, value, and other information about the entry.
---@class cmakeseer.cmake.file_api.object_kind.Cache.Entry
---@field name string The name of the entry.
---@field value string The value of the entry.
---@field type string The type of the entry.
---@field properties cmakeseer.cmake.file_api.object_kind.Cache.Property[] The properties associated with the entry.

--- A `cache` object from the CMake file API. Enumerates cache entries.
---@class cmakeseer.cmake.file_api.object_kind.Cache: cmakeseer.cmake.file_api.object_kind.ObjectKind
---@field kind "cache"
---@field entries cmakeseer.cmake.file_api.object_kind.Cache.Entry[] The cache entries for the object kind.
local Cache = {}
Cache.__index = Cache

--- Creates a new Cache instance.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param entries cmakeseer.cmake.file_api.object_kind.Cache.Entry[] The cache entries for the object kind.
---@return cmakeseer.cmake.file_api.object_kind.Cache obj The new instance.
function Cache.new(version, entries)
  return Cache.take(vim.deepcopy(version), vim.deepcopy(entries))
end

--- Creates a new Cache instance, taking ownership of the passed values.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param entries cmakeseer.cmake.file_api.object_kind.Cache.Entry[] The cache entries for the object kind.
---@return cmakeseer.cmake.file_api.object_kind.Cache obj The new instance.
function Cache.take(version, entries)
  local self = setmetatable({
    kind = ObjectKindType.Cache,
    version = version,
    entries = entries,
  }, Cache)
  return self
end

--- Creates a new Property instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Cache.Property? obj, string? err The new instance if successful. Otherwise an error.
local function try_property_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end
  local value = json.value
  if type(value) ~= "string" then
    return nil, "value is wrong type: " .. type(value)
  end

  return {
    name = name,
    value = value,
  }
end

--- Creates a new Entry instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Cache.Entry? obj, string? err The new instance if successful. Otherwise an error.
local function try_entry_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end
  local value = json.value
  if type(value) ~= "string" then
    return nil, "value is wrong type: " .. type(value)
  end
  local type_ = json.type
  if type(type_) ~= "string" then
    return nil, "type is wrong type: " .. type(type_)
  end
  local raw_properties = json.properties
  if type(raw_properties) ~= "table" or not vim.islist(raw_properties) then
    return nil, "properties is wrong type: " .. type(raw_properties)
  end

  local properties = {}
  for i, prop in ipairs(raw_properties) do
    local parsed_entry, err = try_property_from_json(prop)
    if parsed_entry == nil then
      return nil, ("property at index %d: %s"):format(i, err)
    end
    table.insert(properties, parsed_entry)
  end

  return {
    name = name,
    value = value,
    type = type_,
    properties = properties,
  }
end

--- Creates a new Cache instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Cache? obj, string? err The new instance if successful. Otherwise an error.
function Cache.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  if json.kind ~= ObjectKindType.Cache then
    return nil, "Incorrect kind: " .. vim.inspect(json.kind)
  end

  local version, err = object_kind.try_version_from_json(json.version)
  if version == nil then
    return nil, err
  end

  local entries_raw = json.entries
  if type(entries_raw) ~= "table" or not vim.islist(entries_raw) then
    return nil, "entries is wrong type: " .. type(entries_raw)
  end

  local entries = {}
  for i, entry in ipairs(entries_raw) do
    local parsed_entry
    parsed_entry, err = try_entry_from_json(entry)
    if parsed_entry == nil then
      return nil, ("entry at index %d: %s"):format(i, err)
    end
    table.insert(entries, parsed_entry)
  end

  return Cache.take(version, entries)
end

--- Creates a new Cache instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.Cache? obj, string? err The new instance if successful. Otherwise an error.
function Cache.try_from_file(path)
  local json, err = object_kind.try_decode_file(path)
  if json == nil then
    return nil, err
  end
  return Cache.try_from_json(json)
end

return Cache
