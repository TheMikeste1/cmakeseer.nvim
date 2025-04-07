--[[
-- Source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2
--]]

local Utils = require("cmakeseer.utils")

-- TODO: Fill out descriptions

--- @class Paths Contains information about the paths in the CMake projects.
--- @field source string The path to the top-level source directory for the CMake project.
--- @field build string The path to the top-level build directory for the CMake project.

--- @class CMakeVersion
--- @field string string
--- TODO: Add methods to get major/minor/etc.

--- @class DirectoryReference
--- @field source string
--- @field parentIndex integer?
--- @field childIndexes integer[]?
--- @field projectIndex integer
--- @field targetIndexes integer[]?
--- @field minimumCMakeVersion CMakeVersion?
--- @field hasInstallRule boolean?
--- @field jsonFile string

--- @class Project
--- @field name string
--- @field parentIndex integer?
--- @field childIndexes integer[]?
--- @field directoryIndexes integer[]
--- @field targetIndexes integer[]?

--- @class TargetReference
--- @field name string
--- @field id string?
--- @field directoryIndex integer
--- @field projectIndex integer
--- @field jsonFile string

--- @class Configuration
--- @field name string
--- @field directories DirectoryReference[]
--- @field projects Project[]
--- @field targets TargetReference[]

--- @class CodeModel: ObjectKind
--- @field paths Paths The Paths used by the project.
--- @field configurations Configuration[] Contains the different configurations for the project. In the case of a single-configuration generators there will only ever be one entry.

-- TODO: Validate that all tables contain the correct data types

--- Checks if the provided object is a valid Directory.
---@param obj table<string, any> The object to check.
---@return boolean is_valid If the provided object is a valid Directory.
local function is_valid_directory(obj)
  if type(obj.source) ~= "string" then
    return false
  end

  if obj.parentIndex ~= nil and type(obj.parentIndex) ~= "number" then
    return false
  end

  if obj.childIndexes ~= nil and type(obj.childIndexes) ~= "table" then
    return false
  end

  if type(obj.projectIndex) ~= "number" then
    return false
  end

  if obj.targetIndexes ~= nil and type(obj.targetIndexes) ~= "table" then
    return false
  end

  if
    obj.minimumCMakeVersion ~= nil
    and (type(obj.minimumCMakeVersion) ~= "table" or type(obj.minimumCMakeVersion.string) ~= "string") -- TODO: Validate version
  then
    return false
  end

  if obj.hasInstallRule ~= nil and type(obj.hasInstallRule) ~= "boolean" then
    return false
  end

  if type(obj.jsonFile) ~= "string" then
    return false
  end

  return true
end

--- Checks if the provided object is a valid Project.
---@param obj table<string, any> The object to check.
---@return boolean is_valid If the provided object is a valid Project.
local function is_valid_project(obj)
  if type(obj.name) ~= "string" then
    return false
  end

  if obj.parentIndex ~= nil and type(obj.parentIndex) ~= "number" then
    return false
  end

  if obj.childIndexes ~= nil and type(obj.childIndexes) ~= "table" then
    return false
  end

  if type(obj.directoryIndexes) ~= "table" then
    return false
  end

  if obj.targetIndexes ~= nil and type(obj.targetIndexes) ~= "table" then
    return false
  end

  return true
end

--- Checks if the provided object is a valid Target.
---@param obj table<string, any> The object to check.
---@return boolean is_valid If the provided object is a valid Target.
local function is_valid_target(obj)
  if type(obj.name) ~= "string" then
    return false
  end

  if obj.id ~= nil and type(obj.id) ~= "string" then
    return false
  end

  if type(obj.directoryIndex) ~= "number" then
    return false
  end

  if type(obj.projectIndex) ~= "number" then
    return false
  end

  if type(obj.jsonFile) ~= "string" then
    return false
  end

  return true
end

--- Checks if the directories in the provided array are valid.
---@param directories any[] The directories to check.
---@return boolean are_valid If all the directories in the array are valid.
local function has_valid_directories(directories)
  for _, config in ipairs(directories) do
    if not is_valid_directory(config) then
      return false
    end
  end
  return true
end

--- Checks if the projects in the provided array are valid.
---@param projects any[] The projects to check.
---@return boolean are_valid If all the projects in the array are valid.
local function has_valid_projects(projects)
  for _, config in ipairs(projects) do
    if not is_valid_project(config) then
      return false
    end
  end
  return true
end

--- Checks if the targets in the provided array are valid.
---@param targets any[] The targets to check.
---@return boolean are_valid If all the targets in the array are valid.
local function has_valid_targets(targets)
  for _, config in ipairs(targets) do
    if not is_valid_target(config) then
      return false
    end
  end
  return true
end

--- Checks if the provided object is a valid Configuration.
---@param obj table<string, any> The object to check.
---@return boolean is_valid If the provided object is a valid Configuration.
local function is_valid_configuration(obj)
  if type(obj.name) ~= "string" then
    return false
  end

  if not Utils.is_array(obj.directories) then
    return false
  end

  if not Utils.is_array(obj.projects) then
    return false
  end

  if not Utils.is_array(obj.targets) then
    return false
  end

  if not has_valid_directories(obj.directories) then
    return false
  end
  if not has_valid_projects(obj.projects) then
    return false
  end
  if not has_valid_targets(obj.targets) then
    return false
  end

  return true
end

--- Checks if the configurations in the provided array are valid.
---@param configurations any[] The configurations to check.
---@return boolean are_valid If all the configurations in the array are valid.
local function has_valid_configurations(configurations)
  for _, config in ipairs(configurations) do
    if not is_valid_configuration(config) then
      return false
    end
  end
  return true
end

local M = {}

--- Checks if an object is a valid CodeModel.
---@param obj table<string, any> The object to check.
---@return boolean is_codemodel If the object is a CodeModel.
function M.is_valid(obj)
  if type(obj.paths) ~= "table" or type(obj.paths.source) ~= "string" or type(obj.paths.build) ~= "string" then
    return false
  end

  if not Utils.is_array(obj.configurations) then
    return false
  end

  return has_valid_configurations(obj.configurations)
end

return M
