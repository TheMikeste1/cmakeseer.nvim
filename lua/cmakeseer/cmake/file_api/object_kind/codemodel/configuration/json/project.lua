--- A project used by a build, in CMake's indexed JSON form.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project
---@field name string The name of the project.
---@field parent_index? number A 0-based index into the projects array for the parent.
---@field child_indices? number[] A list of 0-based indices into the projects array for children.
---@field directory_indices? number[] A list of 0-based indices into the directories array.
---@field target_indices? number[] A list of 0-based indices into the targets array.
---@field abstract_target_indices? number[] A list of 0-based indices into the abstractTargets array.
local Project = {}
Project.__index = Project

--- Creates a new Project instance.
---@param name string
---@param parent_index? number
---@param child_indices? number[]
---@param directory_indices? number[]
---@param target_indices? number[]
---@param abstract_target_indices? number[]
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project obj
function Project.new(name, parent_index, child_indices, directory_indices, target_indices, abstract_target_indices)
  ---@diagnostic disable-next-line: param-type-mismatch
  return Project.take(name, parent_index, vim.deepcopy(child_indices), vim.deepcopy(directory_indices), vim.deepcopy(target_indices), vim.deepcopy(abstract_target_indices))
end

--- Creates a new Project instance, taking ownership of the passed values.
---@param name string
---@param parent_index? number
---@param child_indices? number[]
---@param directory_indices? number[]
---@param target_indices? number[]
---@param abstract_target_indices? number[]
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project obj
function Project.take(name, parent_index, child_indices, directory_indices, target_indices, abstract_target_indices)
  local self = setmetatable({
    name = name,
    parent_index = parent_index,
    child_indices = child_indices,
    directory_indices = directory_indices,
    target_indices = target_indices,
    abstract_target_indices = abstract_target_indices,
  }, Project)
  return self
end

--- Creates a new Project instance from JSON.
---@param json any
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project? obj, string? err
function Project.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local parent_index = json.parentIndex
  if parent_index ~= nil then
    if type(parent_index) ~= "number" then
      return nil, "parentIndex is wrong type: " .. type(parent_index)
    end

    if parent_index < 0 then
      return nil, ("parentIndex is invalid: %d"):format(parent_index)
    end
  end

  local child_indices = json.childIndexes
  if child_indices ~= nil then
    if type(child_indices) ~= "table" or not vim.islist(child_indices) then
      return nil, "childIndexes is wrong type: " .. type(child_indices)
    end

    for i, index in ipairs(child_indices) do
      if type(index) ~= "number" then
        return nil, ("childIndexes at %d is wrong type: %s"):format(i, type(index))
      end
      if index < 0 then
        return nil, ("childIndexes at %d is invalid: %d"):format(i, index)
      end
    end
  end

  local directory_indices = json.directoryIndexes
  if directory_indices ~= nil then
    if type(directory_indices) ~= "table" or not vim.islist(directory_indices) then
      return nil, "directoryIndexes is wrong type: " .. type(directory_indices)
    end

    for i, index in ipairs(directory_indices) do
      if type(index) ~= "number" then
        return nil, ("directoryIndexes at %d is wrong type: %s"):format(i, type(index))
      end
      if index < 0 then
        return nil, ("directoryIndexes at %d is invalid: %d"):format(i, index)
      end
    end
  end

  local target_indices = json.targetIndexes
  if target_indices ~= nil then
    if type(target_indices) ~= "table" or not vim.islist(target_indices) then
      return nil, "targetIndexes is wrong type: " .. type(target_indices)
    end

    for i, index in ipairs(target_indices) do
      if type(index) ~= "number" then
        return nil, ("targetIndexes at %d is wrong type: %s"):format(i, type(index))
      end
      if index < 0 then
        return nil, ("targetIndexes at %d is invalid: %d"):format(i, index)
      end
    end
  end

  local abstract_target_indices = json.abstractTargetIndexes
  if abstract_target_indices ~= nil then
    if type(abstract_target_indices) ~= "table" or not vim.islist(abstract_target_indices) then
      return nil, "abstractTargetIndexes is wrong type: " .. type(abstract_target_indices)
    end

    for i, index in ipairs(abstract_target_indices) do
      if type(index) ~= "number" then
        return nil, ("abstractTargetIndexes at %d is wrong type: %s"):format(i, type(index))
      end
      if index < 0 then
        return nil, ("abstractTargetIndexes at %d is invalid: %d"):format(i, index)
      end
    end
  end

  return Project.take(name, parent_index, child_indices, directory_indices, target_indices, abstract_target_indices), nil
end

return Project
