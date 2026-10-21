local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.directory")
local Project = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.project")
local Target = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.target")
local DirectoryJson = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.directory")
local ProjectJson = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.project")
local TargetJson = require("cmakeseer.cmake.file_api.object_kind.codemodel.configuration.json.target")
local MinimumCMakeVersion = Directory.MinimumCMakeVersion

--- A CMake configuration, containing information about the build system for said configuration.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration
---@field name string The name of the configuration.
---@field projects table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project> The projects used in the configuration.
---@field targets table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target> The targets used in the configuration.
---@field abstract_targets table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target> The abstract targets used in the configuration, that is targets not present in the build system, but are instead imported.
---@field directories cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory[] The directories used in the configuration.
local Configuration = {}
Configuration.__index = Configuration

--- Creates a new Configuration instance.
---@param name string The name of the configuration.
---@param projects table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project> The projects used in the configuration.
---@param targets table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target> The targets used in the configuration.
---@param abstract_targets table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target> The abstract targets used in the configuration, that is targets not present in the build system, but are instead imported.
---@param directories cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory[] The directories used in the configuration.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration obj The new instance.
function Configuration.new(name, projects, targets, abstract_targets, directories)
  return Configuration.take(name, vim.deepcopy(projects), vim.deepcopy(targets), vim.deepcopy(abstract_targets), vim.deepcopy(directories))
end

--- Creates a new Configuration instance, taking ownership of the passed values.
---@param name string The name of the configuration.
---@param projects table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project> The projects used in the configuration.
---@param targets table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target> The targets used in the configuration.
---@param abstract_targets table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target> The abstract targets used in the configuration, that is targets not present in the build system, but are instead imported.
---@param directories cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory[] The directories used in the configuration.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration obj The new instance.
function Configuration.take(name, projects, targets, abstract_targets, directories)
  local self = setmetatable({
    name = name,
    projects = projects,
    targets = targets,
    abstract_targets = abstract_targets,
    directories = directories,
  }, Configuration)
  return self
end

--- Creates a new Configuration instance from JSON.
---@param json any The json object from which values should be extracted.
---@param codemodel_file_path string The path to the owning codemodel file, used to resolve relative paths.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration? obj, string? err The new instance if successful. Otherwise an error.
function Configuration.try_from_json(json, codemodel_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local raw_projects = json.projects
  if type(raw_projects) ~= "table" or not vim.islist(raw_projects) then
    return nil, "projects is wrong type: " .. type(raw_projects)
  end

  local raw_targets = json.targets
  if type(raw_targets) ~= "table" or not vim.islist(raw_targets) then
    return nil, "targets is wrong type: " .. type(raw_targets)
  end

  local raw_abstract_targets = json.abstractTargets or {} -- abstractTargets wasn't supported until recently, so we'll default to an empty list
  if type(raw_abstract_targets) ~= "table" or not vim.islist(raw_abstract_targets) then
    return nil, "abstractTargets is wrong type: " .. type(raw_abstract_targets)
  end

  local raw_directories = json.directories
  if type(raw_directories) ~= "table" or not vim.islist(raw_directories) then
    return nil, "directories is wrong type: " .. type(raw_directories)
  end

  -- Parse into JSON objects
  local projects_json = {}
  for i, raw in ipairs(raw_projects) do
    local obj, err = ProjectJson.try_from_json(raw)
    if obj == nil then
      return nil, ("project at index %d: %s"):format(i - 1, err)
    end
    projects_json[i] = obj
  end

  local targets_json = {}
  for i, raw in ipairs(raw_targets) do
    local obj, err = TargetJson.try_from_json(raw, codemodel_file_path)
    if obj == nil then
      return nil, ("target at index %d: %s"):format(i - 1, err)
    end
    targets_json[i] = obj
  end

  local abstract_targets_json = {}
  for i, raw in ipairs(raw_abstract_targets) do
    local obj, err = TargetJson.try_from_json(raw, codemodel_file_path)
    if obj == nil then
      return nil, ("abstract target at index %d: %s"):format(i - 1, err)
    end
    abstract_targets_json[i] = obj
  end

  local directories_json = {}
  for i, raw in ipairs(raw_directories) do
    local obj, err = DirectoryJson.try_from_json(raw, codemodel_file_path)
    if obj == nil then
      return nil, ("directory at index %d: %s"):format(i - 1, err)
    end
    directories_json[i] = obj
  end

  -- Convert to non-JSON versions.
  local projects = {}
  for i, pj in ipairs(projects_json) do
    local obj, err = Project.try_from_json_object(pj, projects_json, directories_json, targets_json, abstract_targets_json)
    if obj == nil then
      return nil, ("project at index %d: %s"):format(i - 1, err)
    end
    projects[obj.name] = obj
  end

  local targets = {}
  for i, tj in ipairs(targets_json) do
    local obj, err = Target.try_from_json_object(tj, projects_json, directories_json)
    if obj == nil then
      return nil, ("target at index %d: %s"):format(i - 1, err)
    end
    targets[obj.name] = obj
  end

  local abstract_targets = {}
  for i, tj in ipairs(abstract_targets_json) do
    local obj, err = Target.try_from_json_object(tj, projects_json, directories_json)
    if obj == nil then
      return nil, ("abstract target at index %d: %s"):format(i - 1, err)
    end
    abstract_targets[obj.name] = obj
  end

  local directories = {}
  for i, dj in ipairs(directories_json) do
    local obj, err = Directory.try_from_json_object(dj, projects_json, directories_json, targets_json, abstract_targets_json)
    if obj == nil then
      return nil, ("directory at index %d: %s"):format(i - 1, err)
    end
    directories[i] = obj
  end

  return Configuration.take(name, projects, targets, abstract_targets, directories)
end

Configuration.Directory = Directory
Configuration.Project = Project
Configuration.Target = Target
Configuration.MinimumCMakeVersion = MinimumCMakeVersion

return Configuration
