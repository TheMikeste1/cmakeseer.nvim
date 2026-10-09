--- Executable and resource path information.
---@class cmakeseer.cmake.file_api.reply.index.cmake.Paths
---@field cmake string Path to the CMake executable.
---@field ctest string Path to the CTest executable.
---@field cpack string Path to the CPack executable.
---@field root string Path to the directory containing CMake resources, i.e. CMAKE_ROOT.
local Paths = {}
Paths.__index = Paths

--- Creates a new Paths instance.
---@param cmake string Path to the CMake executable.
---@param ctest string Path to the CTest executable.
---@param cpack string Path to the CPack executable.
---@param root string Path to the directory containing CMake resources, i.e. CMAKE_ROOT.
---@return cmakeseer.cmake.file_api.reply.index.cmake.Paths obj The new instance.
function Paths.new(cmake, ctest, cpack, root)
  local self = setmetatable({
    cmake = cmake,
    ctest = ctest,
    cpack = cpack,
    root = root,
  }, Paths)
  return self
end

--- Creates a new Paths instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.reply.index.cmake.Paths? obj, string? err The new instance if successful. Otherwise an error.
function Paths.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local cmake = json["cmake"]
  if type(cmake) ~= "string" then
    return nil, "cmake is wrong type: " .. type(cmake)
  end
  local ctest = json["ctest"]
  if type(ctest) ~= "string" then
    return nil, "ctest is wrong type: " .. type(ctest)
  end
  local cpack = json["cpack"]
  if type(cpack) ~= "string" then
    return nil, "cpack is wrong type: " .. type(cpack)
  end
  local root = json["root"]
  if type(root) ~= "string" then
    return nil, "root is wrong type: " .. type(root)
  end

  return Paths.new(cmake, ctest, cpack, root), nil
end

return Paths
