local ApiUtils = require("cmakeseer.cmake.api.utils")
local CMakeApi = require("cmakeseer.cmake.api")

---@class Artifact An artifact produced by a target.
---@field path string The path to the artifact on disk. If relative, relative to the build directory.

---@class Target A CMake target.
---@field name string The name of the target.
---@field id string The unique ID for the target.
---@field type TargetType The type of the target.
---@field nameOnDisk string? The name of the target on disk.
---@field artifacts Artifact[]? The artifacts produced by the target.
---TODO: Add the rest

local M = {
  ---@enum TargetType The type of a target.
  TargetType = {
    Executable = "EXECUTABLE",
    StaticLibrary = "STATIC_LIBRARY",
    SharedLibrary = "SHARED_LIBRARY",
    ModuleLibrary = "MODULE_LIBRARY",
    ObjectLibrary = "OBJECT_LIBRARY",
    InterfaceLibrary = "INTERFACE_LIBRARY",
    Utility = "UTILITY",
  },
}

---@param type TargetType The type to check.
---@return boolean is_library If the provided type is a library.
function M.is_library(type)
  return type == M.TargetType.StaticLibrary
    or type == M.TargetType.SharedLibrary
    or type == M.TargetType.ModuleLibrary
    or type == M.TargetType.ObjectLibrary
    or type == M.TargetType.InterfaceLibrary
end

--- Parses a Target from the provided reference.
---@param reference TargetReference The reference to the Target.
---@param build_directory string The directory in which the CMake project was configured.
---@return Target|nil maybe_target The target, if one was contained in the referenced file.
function M.parse(reference, build_directory)
  local response_directory = CMakeApi.get_reply_directory(build_directory)
  local file_path = vim.fs.joinpath(response_directory, reference.jsonFile)
  local file_contents = vim.fn.readfile(file_path)
  if #file_contents == 0 then
    return nil
  end

  local maybe_target = vim.fn.json_decode(file_contents)
  if not M.is_valid(maybe_target) then
    return nil
  end

  return maybe_target
end

--- Checks if an object is a valid Target.
---@param obj table<string, any> The object to check.
---@return boolean is_valid If the object is a Target.
function M.is_valid(obj)
  if type(obj.name) ~= "string" then
    return false
  end

  if type(obj.id) ~= "string" then
    return false
  end

  --- TODO: Validate type
  if type(obj.type) ~= "string" then
    return false
  end

  if obj.nameOnDisk ~= nil and type(obj.nameOnDisk) ~= "string" then
    return false
  end

  if obj.artifacts ~= nil and type(obj.artifacts) ~= "table" then
    return false
  end

  return true
end

return M
