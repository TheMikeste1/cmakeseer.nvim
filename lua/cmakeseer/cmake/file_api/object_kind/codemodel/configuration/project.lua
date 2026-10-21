--- A project used by a build.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project
---@field name string The name of the project.
---@field parent? string The name of the parent Project is not the top-level Project.
---@field children string[] The names of the children Projects if this Project has children.
---@field targets string[] The names of targets in this project if this Project has targets. Does not include subproject targets.
---@field abstract_targets string[] The names of abstract targets in this project if this Project has targets. Does not include subproject abstract targets.
---@field directory_indices? number[] A list of 0-based indices for directories. Indexes into the configuration's `directories` array.
local Project = {}
Project.__index = Project

--- Creates a new Project instance.
---@param name string The name of the project.
---@param parent? string The name of the parent Project is not the top-level Project.
---@param children string[] The names of the children Projects if this Project has children.
---@param targets string[] The names of targets in this project if this Project has targets. Does not include subproject targets.
---@param abstract_targets string[] The names of abstract targets in this project if this Project has targets. Does not include subproject abstract targets.
---@param directory_indices? number[] A list of 0-based indices for directories. Indexes into the configuration's `directories` array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project obj The new instance.
function Project.new(name, parent, children, targets, abstract_targets, directory_indices)
  return Project.take(name, parent, children and vim.deepcopy(children) or nil, vim.deepcopy(targets), vim.deepcopy(abstract_targets), directory_indices and vim.deepcopy(directory_indices) or nil)
end

--- Creates a new Project instance, taking ownership of the passed values.
---@param name string The name of the project.
---@param parent? string The name of the parent Project is not the top-level Project.
---@param children string[] The names of the children Projects if this Project has children.
---@param targets string[] The names of targets in this project if this Project has targets. Does not include subproject targets.
---@param abstract_targets string[] The names of abstract targets in this project if this Project has targets. Does not include subproject abstract targets.
---@param directory_indices? number[] A list of 0-based indices for directories. Indexes into the configuration's `directories` array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project obj The new instance.
function Project.take(name, parent, children, targets, abstract_targets, directory_indices)
  local self = setmetatable({
    name = name,
    parent = parent,
    children = children,
    targets = targets,
    abstract_targets = abstract_targets,
    directory_indices = directory_indices,
  }, Project)
  return self
end

--- Creates a non-json Project from a json-formatted Project.
---@param json_project cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project
---@param projects cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project[] The json projects array.
---@param directories cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory[] The json directories array.
---@param targets cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[] The json targets array.
---@param abstract_targets cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[] The json abstract targets array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Project? obj, string? err
function Project.try_from_json_object(json_project, projects, directories, targets, abstract_targets)
  local name = json_project.name

  local parent_name = nil
  local parent_index = json_project.parent_index
  if parent_index ~= nil then
    if parent_index < 0 or parent_index >= #projects then
      return nil, "parent_index is out of range"
    end
    parent_name = projects[parent_index + 1].name
  end

  local child_names = {}
  local child_indices = json_project.child_indices or {}
  for _, idx in ipairs(child_indices) do
    if idx < 0 or idx >= #projects then
      return nil, "child_indices contains an invalid index"
    end
    local p_name = projects[idx + 1].name
    table.insert(child_names, p_name)
  end

  local directory_indices = vim.deepcopy(json_project.directory_indices)
  if directory_indices ~= nil then
    for _, idx in ipairs(directory_indices) do
      if idx < 0 or idx >= #directories then
        return nil, "directory_indices contains an invalid index"
      end
    end
  end

  local target_names = {}
  local target_indices = json_project.target_indices or {}
  for _, idx in ipairs(target_indices) do
    if idx < 0 or idx >= #targets then
      return nil, "target_indices contains an invalid index"
    end
    local t_name = targets[idx + 1].name
    table.insert(target_names, t_name)
  end

  local abstract_target_names = {}
  local abstract_target_indices = json_project.abstract_target_indices or {}
  for _, idx in ipairs(abstract_target_indices) do
    if idx < 0 or idx >= #abstract_targets then
      return nil, "abstract_target_indices contains an invalid index"
    end
    local t_name = abstract_targets[idx + 1].name
    table.insert(abstract_target_names, t_name)
  end

  return Project.take(name, parent_name, child_names, target_names, abstract_target_names, directory_indices), nil
end

return Project
