local CodemodelDirectory = require("cmakeseer.cmake.file_api.object_kind.codemodel.directory")

--- A minimum CMake version.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion
---@field major number The major version.
---@field minor number The minor version.
---@field patch? number The optional patch version.
---@field tweak? number The optional tweak version.
---@field suffix? string The optional version suffix.
local MinimumCMakeVersion = {}
MinimumCMakeVersion.__index = MinimumCMakeVersion

--- Creates a new MinimumCMakeVersion instance.
---@param major number The major version.
---@param minor number The minor version.
---@param patch? number The optional patch version.
---@param tweak? number The optional tweak version.
---@param suffix? string The optional version suffix.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion obj The new instance.
function MinimumCMakeVersion.new(major, minor, patch, tweak, suffix)
  return MinimumCMakeVersion.take(major, minor, patch, tweak, suffix)
end

--- Creates a new MinimumCMakeVersion instance, taking ownership of the passed values.
---@param major number The major version.
---@param minor number The minor version.
---@param patch? number The optional patch version.
---@param tweak? number The optional tweak version.
---@param suffix? string The optional version suffix.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion obj The new instance.
function MinimumCMakeVersion.take(major, minor, patch, tweak, suffix)
  local self = setmetatable({
    major = major,
    minor = minor,
    patch = patch,
    tweak = tweak,
    suffix = suffix,
  }, MinimumCMakeVersion)
  return self
end

--- A directory used by a build.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory
---@field source string The path to the source directory. Will be relative if inside the top-level source directory. Otherwise absolute.
---@field build string The path to the build directory. Will be relative if inside the top-level build directory. Otherwise absolute.
---@field minimum_cmake_version? cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion The minimum required CMake version for this directory.
---@field has_install_rule boolean Indicates if the directory or one of its subdirectories has an install rule.
---@field project string The name of the project containing this Directory.
---@field targets string[] The names of targets in this directory if this Directory has targets. Does not include subdirectory targets.
---@field abstract_targets string[] The names of abstract targets in this directory if this Directory has targets. Does not include subdirectory abstract targets.
---@field parent_index? number A 0-based index present when this Directory is not the top-level Directory. Indexes into the configuration's `directories` array.
---@field child_indices? number[] A list of 0-based indices present when this Directory has children Directories. Each indexes into the configuration's `directories` array.
---@field json_file string The absolute path to JSON file containing the associated cmakeseer.cmake.file_api.object_kind.codemodel.Directory.
local Directory = {}
Directory.__index = Directory

--- Creates a new Directory instance.
---@param source string The path to the source directory. Will be relative if inside the top-level source directory. Otherwise absolute.
---@param build string The path to the build directory. Will be relative if inside the top-level build directory. Otherwise absolute.
---@param minimum_cmake_version? cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion The minimum required CMake version for this directory.
---@param has_install_rule boolean Indicates if the directory or one of its subdirectories has an install rule.
---@param project string The name of the project containing this Directory.
---@param targets string[] The names of targets in this directory if this Directory has targets. Does not include subdirectory targets.
---@param abstract_targets string[] The names of abstract targets in this directory if this Directory has targets. Does not include subdirectory abstract targets.
---@param parent_index? number A 0-based index present when this Directory is not the top-level Directory. Indexes into the configuration's `directories` array.
---@param child_indices? number[] A list of 0-based indices present when this Directory has children Directories. Each indexes into the configuration's `directories` array.
---@param json_file string The absolute path to JSON file containing the associated cmakeseer.cmake.file_api.object_kind.codemodel.Directory.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory obj The new instance.
function Directory.new(source, build, minimum_cmake_version, has_install_rule, project, targets, abstract_targets, parent_index, child_indices, json_file)
  return Directory.take(
    source,
    build,
    minimum_cmake_version and vim.deepcopy(minimum_cmake_version) or nil,
    has_install_rule,
    project,
    vim.deepcopy(targets),
    vim.deepcopy(abstract_targets),
    parent_index,
    child_indices and vim.deepcopy(child_indices) or nil,
    json_file
  )
end

--- Creates a new Directory instance, taking ownership of the passed values.
---@param source string The path to the source directory. Will be relative if inside the top-level source directory. Otherwise absolute.
---@param build string The path to the build directory. Will be relative if inside the top-level build directory. Otherwise absolute.
---@param minimum_cmake_version? cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion The minimum required CMake version for this directory.
---@param has_install_rule boolean Indicates if the directory or one of its subdirectories has an install rule.
---@param project string The name of the project containing this Directory.
---@param targets string[] The names of targets in this directory if this Directory has targets. Does not include subdirectory targets.
---@param abstract_targets string[] The names of abstract targets in this directory if this Directory has targets. Does not include subdirectory abstract targets.
---@param parent_index? number A 0-based index present when this Directory is not the top-level Directory. Indexes into the configuration's `directories` array.
---@param child_indices? number[] A list of 0-based indices present when this Directory has children Directories. Each indexes into the configuration's `directories` array.
---@param json_file string The absolute path to JSON file containing the associated cmakeseer.cmake.file_api.object_kind.codemodel.Directory.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory obj The new instance.
function Directory.take(source, build, minimum_cmake_version, has_install_rule, project, targets, abstract_targets, parent_index, child_indices, json_file)
  local self = setmetatable({
    source = source,
    build = build,
    minimum_cmake_version = minimum_cmake_version,
    has_install_rule = has_install_rule,
    project = project,
    targets = targets,
    abstract_targets = abstract_targets,
    parent_index = parent_index,
    child_indices = child_indices,
    json_file = json_file,
  }, Directory)
  return self
end

--- Attempts to read the associated codemodel file.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory? json, string? err The decoded JSON, if successful. Otherwise an error.
function Directory:try_read_codemodel()
  local codemodel_directory, err = CodemodelDirectory.try_from_file(self.json_file)
  if codemodel_directory == nil then
    return nil, err
  end
  return codemodel_directory, nil
end

--- Parses a minimum CMake version string into a MinimumCMakeVersion.
---@param str string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.MinimumCMakeVersion? version
local function parse_minimum_cmake_version(str)
  local major, minor, rest = str:match("^(%d+)%.(%d+)(.*)$")
  if major == nil then
    return nil
  end
  local patch
  local tweak
  local suffix
  if rest ~= "" then
    local p, r2 = rest:match("^%.(%d+)(.*)$")
    if p ~= nil then
      patch = tonumber(p)
      rest = r2
      local t, r3 = rest:match("^%.(%d+)(.*)$")
      if t ~= nil then
        tweak = tonumber(t)
        rest = r3
      end
    end
    if rest ~= "" then
      suffix = rest
    end
  end
  return MinimumCMakeVersion.new(assert(tonumber(major)), assert(tonumber(minor)), patch, tweak, suffix)
end

--- Creates a non-json Directory from a json-formatted Directory.
---@param json_directory cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory
---@param projects cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Project[] The json projects array.
---@param directories cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Directory[] The json directories array.
---@param targets cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[] The json targets array.
---@param abstract_targets cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Json.Target[] The json abstract targets array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory? obj, string? err
function Directory.try_from_json_object(json_directory, projects, directories, targets, abstract_targets)
  if json_directory.parent_index ~= nil and (json_directory.parent_index < 0 or json_directory.parent_index >= #directories) then
    return nil, "parent_index is out of range"
  end

  if json_directory.child_indices ~= nil then
    for _, idx in ipairs(json_directory.child_indices) do
      if idx < 0 or idx >= #directories then
        return nil, "child_indices contains an invalid index"
      end
    end
  end

  local minimum_cmake_version
  local raw_minimum = json_directory.minimum_cmake_version
  if raw_minimum ~= nil then
    minimum_cmake_version = parse_minimum_cmake_version(raw_minimum)
    if minimum_cmake_version == nil then
      return nil, "minimum_cmake_version is invalid: " .. raw_minimum
    end
  end

  local project_index = json_directory.project_index
  if project_index < 0 or project_index >= #projects then
    return nil, "project_index is out of range"
  end
  local project_name = projects[project_index + 1].name

  local targets_list = {}
  local target_indices = json_directory.target_indices or {}
  for _, idx in ipairs(target_indices) do
    if idx < 0 or idx >= #targets then
      return nil, "target_indices contains an invalid index"
    end

    local t_name = targets[idx + 1].name
    table.insert(targets_list, t_name)
  end

  local abstract_targets_list = {}
  local abstract_target_indices = json_directory.abstract_target_indices or {}
  for _, idx in ipairs(abstract_target_indices) do
    if idx < 0 or idx >= #abstract_targets then
      return nil, "abstract_target_indices contains an invalid index"
    end
    local t_name = abstract_targets[idx + 1].name
    table.insert(abstract_targets_list, t_name)
  end

  return Directory.take(
    json_directory.source,
    json_directory.build,
    minimum_cmake_version,
    json_directory.has_install_rule,
    project_name,
    targets_list,
    abstract_targets_list,
    json_directory.parent_index,
    vim.deepcopy(json_directory.child_indices),
    json_directory.json_file
  )
end

Directory.MinimumCMakeVersion = MinimumCMakeVersion

return Directory
