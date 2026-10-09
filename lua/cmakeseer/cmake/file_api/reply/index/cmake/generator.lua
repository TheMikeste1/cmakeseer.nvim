--- Generator information.
---@class cmakeseer.cmake.file_api.reply.index.cmake.Generator
---@field multi_config boolean Indicates if the generator supports multiple output configurations.
---@field name string Name of the generator.
---@field platform? string The generator platform name, if the generator supports CMAKE_GENERATOR_PLATFORM.
local Generator = {}
Generator.__index = Generator

--- Creates a new Generator instance.
---@param multi_config boolean Indicates if the generator supports multiple output configurations.
---@param name string Name of the generator.
---@param platform? string The generator platform name, if the generator supports CMAKE_GENERATOR_PLATFORM.
---@return cmakeseer.cmake.file_api.reply.index.cmake.Generator obj The new instance.
function Generator.new(multi_config, name, platform)
  local self = setmetatable({
    multi_config = multi_config,
    name = name,
    platform = platform,
  }, Generator)
  return self
end

--- Creates a new Generator instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.reply.index.cmake.Generator? obj, string? err The new instance if successful. Otherwise an error.
function Generator.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local multi_config = json["multiConfig"]
  if type(multi_config) ~= "boolean" then
    return nil, "major is wrong type: " .. type(multi_config)
  end
  local name = json["name"]
  if type(name) ~= "string" then
    return nil, "minor is wrong type: " .. type(name)
  end
  local platform = json["platform"]
  if platform ~= nil and type(platform) ~= "string" then
    return nil, "suffix is wrong type: " .. type(platform)
  end

  return Generator.new(multi_config, name, platform), nil
end

return Generator
