--- A target used by a build, in CMake's indexed JSON form.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target
---@field name string The name of the target.
---@field id string A string uniquely identifying the target.
---@field directory_index number A 0-based index into the directories array.
---@field project_index number A 0-based index into the projects array.
---@field json_file string The absolute path to the associated codemodel target JSON file.
local Target = {}
Target.__index = Target

--- Creates a new Target instance.
---@param name string
---@param id string
---@param directory_index number
---@param project_index number
---@param json_file string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target obj
function Target.new(name, id, directory_index, project_index, json_file)
  return Target.take(name, id, directory_index, project_index, json_file)
end

--- Creates a new Target instance, taking ownership of the passed values.
---@param name string
---@param id string
---@param directory_index number
---@param project_index number
---@param json_file string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target obj
function Target.take(name, id, directory_index, project_index, json_file)
  local self = setmetatable({
    name = name,
    id = id,
    directory_index = directory_index,
    project_index = project_index,
    json_file = json_file,
  }, Target)
  return self
end

--- Creates a new Target instance from JSON.
---@param json any
---@param codemodel_file_path string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target? obj, string? err
function Target.try_from_json(json, codemodel_file_path)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local id = json.id
  if type(id) ~= "string" then
    return nil, "id is wrong type: " .. type(id)
  end

  local directory_index = json.directoryIndex
  if type(directory_index) ~= "number" then
    return nil, "directoryIndex is wrong type: " .. type(directory_index)
  end
  if directory_index < 0 then
    return nil, ("directoryIndex is invalid: %d"):format(directory_index)
  end

  local project_index = json.projectIndex
  if type(project_index) ~= "number" then
    return nil, "projectIndex is wrong type: " .. type(project_index)
  end
  if project_index < 0 then
    return nil, ("projectIndex is invalid: %d"):format(project_index)
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

  return Target.take(name, id, directory_index, project_index, json_file), nil
end

return Target
