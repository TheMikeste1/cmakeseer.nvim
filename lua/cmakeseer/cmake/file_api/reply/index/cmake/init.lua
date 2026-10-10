local CMakeVersion = require("cmakeseer.cmake.file_api.reply.index.cmake.version")
local Generator = require("cmakeseer.cmake.file_api.reply.index.cmake.generator")
local Paths = require("cmakeseer.cmake.file_api.reply.index.cmake.paths")

--- Reply index CMake information.
---@class cmakeseer.cmake.file_api.reply.index.CMake
---@field version cmakeseer.cmake.file_api.reply.index.cmake.CMakeVersion Version information for CMake.
---@field paths cmakeseer.cmake.file_api.reply.index.cmake.Paths Paths for CMake executables and modules.
---@field generator cmakeseer.cmake.file_api.reply.index.cmake.Generator Information about the CMake generator in use.
local CMake = {}
CMake.__index = CMake

--- Creates a new CMake instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.reply.index.CMake? obj, string? err The new instance if successful. Otherwise an error.
function CMake.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local version, err = CMakeVersion.try_from_json(json.version)
  if version == nil then
    return nil, "version " .. err
  end

  local paths
  paths, err = Paths.try_from_json(json.paths)
  if paths == nil then
    return nil, "paths " .. err
  end

  local generator
  generator, err = Generator.try_from_json(json.generator)
  if generator == nil then
    return nil, "generator " .. err
  end

  local self = setmetatable({
    version = version,
    paths = paths,
    generator = generator,
  }, CMake)
  return self, nil
end

return CMake
