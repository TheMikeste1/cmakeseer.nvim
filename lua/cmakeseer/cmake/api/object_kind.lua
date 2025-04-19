local CodeModel = require("cmakeseer.cmake.api.codemodel")
local CTestInfo = require("cmakeseer.cmake.api.ctest_info")

--- @class Version
--- @field major integer
--- @field minor integer

--- @class ObjectKind One of the object kinds produced by the CMake file API.
--- @field kind Kind The specific Kind of object.
--- @field version Version The version of the ObjectKind.

local M = {}

--- @enum Kind The kinds of objects available from the CMake file API.
M.Kind = {
  cache = "cache",
  cmake_files = "cmakeFiles",
  codemodel = "codemodel",
  configure_log = "configureLog",
  toolchains = "toolchains",
  ctest_info = "ctestInfo", -- This is technically a ctest object kind, but we're gonna put it here. . .
}

--- Checks if an object is a valid ObjectKind.
---@param obj table<string, any> The object to check.
---@param expected_kind Kind The expected Kind of object. If nil, attempt to determine its type.
---@return boolean is_object_kind If the object is an ObjectKind.
function M.is_valid(obj, expected_kind)
  if type(obj) ~= "table" then
    return false
  end

  if type(obj.kind) ~= "string" then
    return false
  end

  if type(obj.version) ~= "table" or type(obj.version.major) ~= "number" or type(obj.version.minor) ~= "number" then
    return false
  end

  if obj.kind ~= expected_kind then
    return false
  end

  if obj.kind == M.Kind.codemodel then
    return CodeModel.is_valid(obj)
  elseif obj.kind == M.Kind.ctest_info then
    return CTestInfo.is_valid(obj)
  else
    error("Unimplemented ObjectKind: " .. obj.kind)
  end
end

return M
