local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType
local Configuration = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration")

--- A `codemodel` object from the CMake file API. Describes the build system, including targets, directories, backtrace graphs, and other information.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel: cmakeseer.cmake.file_api.object_kind.ObjectKind
---@field kind "codemodel"
---@field source string The absolute path to the top-level source directory.
---@field build string The absolute path to the top-level build directory.
---@field configurations table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration> The configurations available for building. For single configuration generators, there will only ever be one.
local Codemodel = {}
Codemodel.__index = Codemodel

--- Creates a new Codemodel instance.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param source string The absolute path to the top-level source directory.
---@param build string The absolute path to the top-level build directory.
---@param configurations table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration> The configurations available for building.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel obj The new instance.
function Codemodel.new(version, source, build, configurations)
  return Codemodel.take(vim.deepcopy(version), source, build, vim.deepcopy(configurations))
end

--- Creates a new Codemodel instance, taking ownership of the passed values.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param source string The absolute path to the top-level source directory.
---@param build string The absolute path to the top-level build directory.
---@param configurations table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration> The configurations available for building.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel obj The new instance.
function Codemodel.take(version, source, build, configurations)
  local self = setmetatable({
    kind = ObjectKindType.Codemodel,
    version = version,
    source = source,
    build = build,
    configurations = configurations,
  }, Codemodel)
  return self
end

--- Creates a new Codemodel instance from JSON.
---@param json any The json object from which values should be extracted.
---@param path string The path to the codemodel instance being parsed.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel? obj, string? err The new instance if successful. Otherwise an error.
function Codemodel.try_from_json(json, path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  if json.kind ~= ObjectKindType.Codemodel then
    return nil, "Incorrect kind: " .. vim.inspect(json.kind)
  end

  local version, err = object_kind.try_version_from_json(json.version)
  if version == nil then
    return nil, err
  end

  local paths = json.paths
  if type(paths) ~= "table" then
    return nil, "paths is wrong type: " .. type(paths)
  end

  local source = paths.source
  if type(source) ~= "string" then
    return nil, "paths.source is wrong type: " .. type(source)
  end
  local build = paths.build
  if type(build) ~= "string" then
    return nil, "paths.build is wrong type: " .. type(build)
  end

  local raw_configurations = json.configurations
  if type(raw_configurations) ~= "table" or not vim.islist(raw_configurations) then
    return nil, "configurations is wrong type: " .. type(raw_configurations)
  end

  local configurations = {}
  for i, config in ipairs(raw_configurations) do
    local obj
    obj, err = Configuration.try_from_json(config, path)
    if obj == nil then
      return nil, ("configuration at index %d: %s"):format(i, err)
    end
    configurations[obj.name] = obj
  end

  return Codemodel.take(version, source, build, configurations)
end

--- Creates a new Codemodel instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel? obj, string? err The new instance if successful. Otherwise an error.
function Codemodel.try_from_file(path)
  local json, err = object_kind.try_decode_file(path)
  if json == nil then
    return nil, err
  end
  return Codemodel.try_from_json(json, path)
end

return Codemodel
