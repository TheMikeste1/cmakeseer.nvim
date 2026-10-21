--- A directory used by a build, in CMake's indexed JSON form.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory
---@field source string The path to the source directory.
---@field build string The path to the build directory.
---@field parent_index? number A 0-based index into the directories array for the parent.
---@field child_indices? number[] A list of 0-based indices into the directories array for children.
---@field project_index number A 0-based index into the projects array.
---@field target_indices? number[] A list of 0-based indices into the targets array.
---@field abstract_target_indices? number[] A list of 0-based indices into the abstractTargets array.
---@field minimum_cmake_version? string The minimum CMake version, if it has one.
---@field has_install_rule boolean Indicates if the directory or one of its subdirectories has an install rule.
---@field json_file string The absolute path to the associated codemodel directory JSON file.
local Directory = {}
Directory.__index = Directory

--- Creates a new Directory instance.
---@param source string
---@param build string
---@param parent_index? number
---@param child_indices? number[]
---@param project_index number
---@param target_indices? number[]
---@param abstract_target_indices? number[]
---@param minimum_cmake_version? string
---@param has_install_rule boolean
---@param json_file string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory obj
function Directory.new(source, build, parent_index, child_indices, project_index, target_indices, abstract_target_indices, minimum_cmake_version, has_install_rule, json_file)
  ---@diagnostic disable-next-line: param-type-mismatch
  return Directory.take(source, build, parent_index, vim.deepcopy(child_indices), project_index, vim.deepcopy(target_indices), vim.deepcopy(abstract_target_indices), minimum_cmake_version, has_install_rule, json_file)
end

--- Creates a new Directory instance, taking ownership of the passed values.
---@param source string
---@param build string
---@param parent_index? number
---@param child_indices? number[]
---@param project_index number
---@param target_indices? number[]
---@param abstract_target_indices? number[]
---@param minimum_cmake_version? string
---@param has_install_rule boolean
---@param json_file string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory obj
function Directory.take(source, build, parent_index, child_indices, project_index, target_indices, abstract_target_indices, minimum_cmake_version, has_install_rule, json_file)
  local self = setmetatable({
    source = source,
    build = build,
    parent_index = parent_index,
    child_indices = child_indices,
    project_index = project_index,
    target_indices = target_indices,
    abstract_target_indices = abstract_target_indices,
    minimum_cmake_version = minimum_cmake_version,
    has_install_rule = has_install_rule,
    json_file = json_file,
  }, Directory)
  return self
end

--- Creates a new Directory instance from JSON.
---@param json any
---@param codemodel_file_path string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory? obj, string? err
function Directory.try_from_json(json, codemodel_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local source = json.source
  if type(source) ~= "string" then
    return nil, "source is wrong type: " .. type(source)
  end
  local build = json.build
  if type(build) ~= "string" then
    return nil, "build is wrong type: " .. type(build)
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

  local project_index = json.projectIndex
  if type(project_index) ~= "number" then
    return nil, "projectIndex is wrong type: " .. type(project_index)
  end
  if project_index < 0 then
    return nil, ("projectIndex is invalid: %d"):format(project_index)
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

  local minimum_cmake_version = json.minimumCMakeVersion
  if minimum_cmake_version ~= nil then
    if type(minimum_cmake_version) ~= "table" then
      return nil, "minimumCMakeVersion is wrong type: " .. type(minimum_cmake_version)
    end
    local version_string = minimum_cmake_version.string
    if type(version_string) ~= "string" then
      return nil, "minimumCMakeVersion.string is wrong type: " .. type(version_string)
    end
    minimum_cmake_version = version_string
  end

  local has_install_rule = json.hasInstallRule or false
  if type(has_install_rule) ~= "boolean" then
    return nil, "hasInstallRule is wrong type: " .. type(has_install_rule)
  end

  local json_file = json.jsonFile
  if type(json_file) ~= "string" then
    return nil, "jsonFile is wrong type: " .. type(json_file)
  end

  if vim.fn.isabsolutepath(json_file) == 0 then
    codemodel_file_path = vim.fn.fnamemodify(codemodel_file_path, ":p")
    json_file = vim.fs.joinpath(vim.fs.dirname(codemodel_file_path), json_file)
  end
  json_file = vim.fs.normalize(json_file)

  return Directory.take(source, build, parent_index, child_indices, project_index, target_indices, abstract_target_indices, minimum_cmake_version, has_install_rule, json_file), nil
end

return Directory
