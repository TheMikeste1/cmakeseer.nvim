local CodemodelTarget = require("cmakeseer.cmake.file_api.object_kind.codemodel.target")

--- A target used by a build.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target
---@field name string The name of the target.
---@field id string A string uniquely identifying the target.
---@field directory_index number A 0-based index into the `directories` array of a cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration indicating the directory in which this target is defined.
---@field project string The name of the project containing this Target.
---@field json_file string The absolute path to JSON file containing the associated cmakeseer.cmake.file_api.object_kind.codemodel.Target.
local Target = {}
Target.__index = Target

--- Creates a new Target instance.
---@param name string The name of the target.
---@param id string A string uniquely identifying the target.
---@param directory_index number A 0-based index into the `directories` array of a cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration indicating the directory in which this target is defined.
---@param project string The name of the project containing this Target.
---@param json_file string The absolute path to JSON file containing the associated cmakeseer.cmake.file_api.object_kind.codemodel.Target.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target obj The new instance.
function Target.new(name, id, directory_index, project, json_file)
  return Target.take(name, id, directory_index, project, json_file)
end

--- Creates a new Target instance, taking ownership of the passed values.
---@param name string The name of the target.
---@param id string A string uniquely identifying the target.
---@param directory_index number A 0-based index into the `directories` array of a cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration indicating the directory in which this target is defined.
---@param project string The name of the project containing this Target.
---@param json_file string The absolute path to JSON file containing the associated cmakeseer.cmake.file_api.object_kind.codemodel.Target.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target obj The new instance.
function Target.take(name, id, directory_index, project, json_file)
  local self = setmetatable({
    name = name,
    id = id,
    directory_index = directory_index,
    project = project,
    json_file = json_file,
  }, Target)
  return self
end

--- Creates a non-json Target from a json-formatted Target.
---@param json_target cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target
---@param projects cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project[] The json projects array.
---@param directories cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory[] The json directories array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target? obj, string? err
function Target.try_from_json_object(json_target, projects, directories)
  local project_index = json_target.project_index
  if project_index < 0 or project_index >= #projects then
    return nil, "project_index is out of range"
  end
  local project_name = projects[project_index + 1].name

  if json_target.directory_index < 0 or json_target.directory_index >= #directories then
    return nil, "directory_index is out of range"
  end

  return Target.take(json_target.name, json_target.id, json_target.directory_index, project_name, json_target.json_file), nil
end

--- Attempts to read the associated codemodel file.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target? json, string? err The decoded JSON, if successful. Otherwise an error.
function Target:try_read_codemodel()
  local codemodel_target, err = CodemodelTarget.try_from_file(self.json_file)
  if codemodel_target == nil then
    return nil, err
  end
  return codemodel_target, nil
end

return Target
