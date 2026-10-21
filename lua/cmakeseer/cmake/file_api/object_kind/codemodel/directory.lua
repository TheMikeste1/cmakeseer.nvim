local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local BacktraceGraph = require("cmakeseer.cmake.file_api.object_kind.codemodel.backtrace_graph")

---@enum cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Type
local InstallerType = {
  File = "file",
  Directory = "directory",
  Target = "target",
  Export = "export",
  Script = "script",
  Code = "code",
  ImportedRuntimeArtifacts = "importedRuntimeArtifacts",
  RuntimeDependencySet = "runtimeDependencySet",
  FileSet = "fileSet",
  CxxModuleBmi = "cxxModuleBmi",
}

-- TODO: Extract the name of the target instead of the index
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.TargetId
---@field id string The ID of the target.
---@field index number The 0-based index into the codemodel's target array.

---@alias cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Path
---| string The path from which a file or directory is to be installed.
---| { from: string, to: string } The from and to install information.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field component string The name of the component being installed.
---@field type cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Type The type of the installer.
---@field exclude_from_all boolean If the install is excluded from all.
---@field for_all_components boolean If the install is for all components.
---@field backtrace_index? number 1-based index into the Directory's backtrace graph.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.File: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "file" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field paths cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Path[] The path information for installation.
---@field optional boolean If the install is optional.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Directory: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "directory" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field paths cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Path[] The path information for installation.
---@field optional boolean If the install is optional.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Target: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "target" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field paths cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Path[] The path information for installation.
---@field optional boolean If the install is optional.
---@field id string The unique identifier of the target.
-- TODO: Extract the name of the target instead of the index
---@field index number The index of the target in the codemodel's array.
---@field is_import_library boolean If the installer is for a Windows DLL or AIX linker import file.
---@field install_namelink? "skip"|"only" Present when the installer corresponds to a target that may use symbolic links to implement VERSION and SOVERSION. Indicates how to handle the symlinks.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Export: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "export" The type of the installer.
---@field name string The name of the export.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field paths cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Path[] The path information for installation.
---@field targets cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.TargetId[] The targets in the export.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Script: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "script" The type of the installer.
---@field file string The path to the script file on disk. Relative is inside the top-level source directory. Otherwise absolute.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Code: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "code" The type of the installer.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.ImportedRuntimeArtifacts: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "importedRuntimeArtifacts" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field optional boolean If the install is optional.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.RuntimeDependencySet: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "runtimeDependencySet" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field set_name? string The name of the runtime dependency set. Present when the installer was created using RUNTIME_DEPENDENCY_SET.
---@field set_type "library"|"framework" The type of the dependency set.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.FileSet: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "fileSet" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field paths cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Path[] The path information for installation.
---@field optional boolean If the install is optional.
---@field name string The name of the set
---@field set_type string The type of the file set.
---@field directories string[] The file set's base directories.
---@field target cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.TargetId The associated target.

---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.CxxModuleBmi: cmakeseer.cmake.file_api.object_kind.Codemodel.Installer
---@field type "cxxModuleBmi" The type of the installer.
---@field destination string The install destination path. May be absolute or relative to the install prefix.
---@field optional boolean If the install is optional.
---@field target cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.TargetId The associated target.

--- Information about a codemodel's directories.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Directory
---@field codemodel_version? cmakeseer.cmake.file_api.object_kind.Version The version of the codemodel this is apart of.
---@field source string The absolute path to the source directory.
---@field build string The absolute path to the build directory.
---@field installers cmakeseer.cmake.file_api.object_kind.Codemodel.Installer[] Install rules for components in the directory.
---@field backtrace_graph cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph The backtrace graph associated with this object.
local Directory = {}
Directory.__index = Directory

--- Creates a new Directory instance.
---@param codemodel_version? cmakeseer.cmake.file_api.object_kind.Version The version of the codemodel this is apart of.
---@param source string The absolute path to the top-level source directory.
---@param build string The absolute path to the top-level build directory.
---@param installers cmakeseer.cmake.file_api.object_kind.Codemodel.Installer[] Install rules for components in the directory.
---@param backtrace_graph cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph The backtrace graph associated with this object.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory obj The new instance.
function Directory.new(codemodel_version, source, build, installers, backtrace_graph)
  ---@diagnostic disable-next-line: param-type-mismatch
  return Directory.take(vim.deepcopy(codemodel_version), source, build, vim.deepcopy(installers), vim.deepcopy(backtrace_graph))
end

--- Creates a new Directory instance, taking ownership of the passed values.
---@param codemodel_version? cmakeseer.cmake.file_api.object_kind.Version The version of the codemodel this is apart of.
---@param source string The absolute path to the top-level source directory.
---@param build string The absolute path to the top-level build directory.
---@param installers table<string, cmakeseer.cmake.file_api.object_kind.Codemodel.Installer> Install rules for components in the directory.
---@param backtrace_graph cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph The backtrace graph associated with this object.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory obj The new instance.
function Directory.take(codemodel_version, source, build, installers, backtrace_graph)
  local self = setmetatable({
    codemodel_version = codemodel_version,
    source = source,
    build = build,
    installers = installers,
    backtrace_graph = backtrace_graph,
  }, Directory)
  return self
end

---@param path any The raw json for the path.
---@return string? err An error, if the path is invalid.
local function validate_path(path)
  if type(path) ~= "string" then
    if type(path) ~= "table" then
      return "wrong type: " .. type(path)
    end
    if type(path.from) ~= "string" then
      return "from wrong type: " .. type(path.from)
    end
    if type(path.to) ~= "string" then
      return "to wrong type: " .. type(path.to)
    end
  end

  return nil
end

---@param paths any The raw json for the paths.
---@return string[]? paths, string? err The pared paths, if successful. Otherwise an error.
local function try_parse_paths_from_json(paths)
  if not vim.islist(paths) then
    return nil, "paths is wrong type: " .. type(paths)
  end

  for i, path in ipairs(paths) do
    local err = validate_path(path)
    if err then
      return nil, ("path at index %d: %s"):format(i, err)
    end
  end

  ---@type string[]
  paths = vim.deepcopy(paths)
  return paths
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_destination_and_paths_and_optional(json, installer)
  local destination = json.destination
  if type(destination) ~= "string" then
    return "destination is wrong type: " .. type(destination)
  end

  local paths, err = try_parse_paths_from_json(json.paths)
  if paths == nil then
    return err
  end

  local optional = json.isOptional or false
  if type(optional) ~= "boolean" then
    return "isOptional is wrong type: " .. type(optional)
  end

  installer.destination = destination
  installer.paths = paths
  installer.optional = optional
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_target_installer(json, installer)
  local err = try_construct_destination_and_paths_and_optional(json, installer)
  if err then
    return err
  end

  local id = json.targetId
  if type(id) ~= "string" then
    return "targetId is wrong type: " .. type(id)
  end

  local index = json.targetIndex
  if type(index) ~= "number" then
    return "targetIndex is wrong type: " .. type(index)
  end

  local is_import_library = json.targetIsImportLibrary or false
  if type(is_import_library) ~= "boolean" then
    return "targetIsImportLibrary is wrong type: " .. type(is_import_library)
  end

  local install_namelink = json.targetInstallNamelink
  if install_namelink ~= nil then
    if type(install_namelink) ~= "string" then
      return "targetInstallNamelink is wrong type: " .. type(install_namelink)
    end
    if install_namelink ~= "skip" and install_namelink ~= "only" then
      return "targetInstallNamelink is invalid: " .. install_namelink
    end
  end

  installer.id = id
  installer.index = index
  installer.is_import_library = is_import_library
  installer.install_namelink = install_namelink
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_export_installer(json, installer)
  local name = json.exportName
  if type(name) ~= "string" then
    return "exportName is wrong type: " .. type(name)
  end

  local destination = json.destination
  if type(destination) ~= "string" then
    return "destination is wrong type: " .. type(destination)
  end

  local paths, err = try_parse_paths_from_json(json.paths)
  if paths == nil then
    return err
  end

  local raw_targets = json.exportTargets
  if not vim.islist(raw_targets) then
    return "exportTargets is wrong type: " .. type(raw_targets)
  end

  local targets = {}
  for i, target in ipairs(raw_targets) do
    if type(target) ~= "table" then
      return ("exportTarget at index %d is wrong type: %s"):format(i, type(target))
    end

    if type(target.id) ~= "string" then
      return ("exportTarget.id at index %d is wrong type: %s"):format(i, type(target.id))
    end
    if type(target.index) ~= "number" then
      return ("exportTarget.index at index %d is wrong type: %s"):format(i, type(target.index))
    end
    table.insert(targets, target)
  end

  installer.name = name
  installer.destination = destination
  installer.paths = paths
  installer.targets = targets
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_script_installer(json, installer)
  local file = json.scriptFile
  if type(file) ~= "string" then
    return "scriptFile is wrong type: " .. type(file)
  end
  installer.file = file
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_imported_runtime_artifacts_installer(json, installer)
  local destination = json.destination
  if type(destination) ~= "string" then
    return "destination is wrong type: " .. type(destination)
  end

  local optional = json.isOptional or false
  if type(optional) ~= "boolean" then
    return "isOptional is wrong type: " .. type(optional)
  end

  installer.destination = destination
  installer.optional = optional
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_runtime_dependency_set(json, installer)
  local destination = json.destination
  if type(destination) ~= "string" then
    return "destination is wrong type: " .. type(destination)
  end

  local set_name = json.runtimeDependencySetName
  if set_name ~= nil and type(set_name) ~= "string" then
    return "runtimeDependencySetName is wrong type: " .. type(set_name)
  end

  local set_type = json.runtimeDependencySetType
  if type(set_type) ~= "string" then
    return "runtimeDependencySetType is wrong type: " .. type(set_type)
  end
  if set_type ~= "library" and set_type ~= "framework" then
    return "runtimeDependencySetType has invalid value: " .. set_type
  end

  installer.destination = destination
  installer.set_name = set_name
  installer.set_type = set_type
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_file_set_installer(json, installer)
  local err = try_construct_destination_and_paths_and_optional(json, installer)
  if err then
    return err
  end

  local name = json.fileSetName
  if type(name) ~= "string" then
    return "fileSetName is wrong type: " .. type(name)
  end

  local set_type = json.fileSetType
  if type(set_type) ~= "string" then
    return "fileSetType is wrong type: " .. type(set_type)
  end

  local directories = json.fileSetDirectories or {}
  if not vim.islist(directories) then
    return "fileSetDirectories is wrong type: " .. type(directories)
  end

  local target = json.fileSetTarget
  if type(target) ~= "table" then
    return "fileSetTarget is wrong type: " .. type(target)
  end
  if type(target.id) ~= "string" then
    return ("fileSetTarget.id is wrong type: %s"):format(type(target.id))
  end
  if type(target.index) ~= "number" then
    return ("fileSetTarget.index is wrong type: %s"):format(type(target.index))
  end

  installer.name = name
  installer.set_type = set_type
  installer.directories = directories
  installer.target = target
end

---@param json table The json containing the installer.
---@param installer table The installer to construct into.
---@return string? err An error, if one occurred
local function try_construct_cxx_module_bmi(json, installer)
  local destination = json.destination
  if type(destination) ~= "string" then
    return "destination is wrong type: " .. type(destination)
  end

  local optional = json.isOptional or false
  if type(optional) ~= "boolean" then
    return "isOptional is wrong type: " .. type(optional)
  end

  local target = json.cxxModuleBmiTarget
  if type(target) ~= "table" then
    return "cxxModuleBmiTarget is wrong type: " .. type(target)
  end
  if type(target.id) ~= "string" then
    return ("cxxModuleBmiTarget.id is wrong type: %s"):format(type(target.id))
  end
  if type(target.index) ~= "number" then
    return ("cxxModuleBmiTarget.index is wrong type: %s"):format(type(target.index))
  end

  installer.destination = destination
  installer.optional = optional
  installer.target = target
end

--- Creates a new Installer instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Installer? obj, string? err The new instance if successful. Otherwise an error.
local function try_installer_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local component = json.component
  if type(component) ~= "string" then
    return nil, "component is wrong type: " .. type(component)
  end

  local type_ = json.type
  if type(type_) ~= "string" then
    return nil, "type is wrong type: " .. type(type_)
  end

  local exclude_from_all = json.isExcludeFromAll or false
  if type(exclude_from_all) ~= "boolean" then
    return nil, "isExcludeFromAll is wrong type: " .. type(exclude_from_all)
  end
  local for_all_components = json.isForAllComponents or false
  if type(for_all_components) ~= "boolean" then
    return nil, "isForAllComponents is wrong type: " .. type(for_all_components)
  end

  local backtrace_index = json.backtrace
  if backtrace_index ~= nil then
    if type(backtrace_index) ~= "number" then
      return nil, "backtrace is wrong type: " .. type(backtrace_index)
    end
    backtrace_index = backtrace_index + 1
  end

  local installer = {
    component = component,
    type = type_,
    exclude_from_all = exclude_from_all,
    for_all_components = for_all_components,
    backtrace_index = backtrace_index,
  }

  local err
  if type_ == InstallerType.File or type_ == InstallerType.Directory then
    err = try_construct_destination_and_paths_and_optional(json, installer)
  elseif type_ == InstallerType.Target then
    err = try_construct_target_installer(json, installer)
  elseif type_ == InstallerType.Export then
    err = try_construct_export_installer(json, installer)
  elseif type_ == InstallerType.Script then
    err = try_construct_script_installer(json, installer)
  elseif type_ == InstallerType.ImportedRuntimeArtifacts then
    err = try_construct_imported_runtime_artifacts_installer(json, installer)
  elseif type_ == InstallerType.RuntimeDependencySet then
    err = try_construct_runtime_dependency_set(json, installer)
  elseif type_ == InstallerType.FileSet then
    err = try_construct_file_set_installer(json, installer)
  elseif type_ == InstallerType.CxxModuleBmi then
    err = try_construct_cxx_module_bmi(json, installer)
  elseif type_ ~= InstallerType.Code then
    -- Code is a noop
    err = "unknown installer type: " .. type_
  end

  if err then
    return nil, err
  end

  return installer
end

--- Creates a new Directory instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory? obj, string? err The new instance if successful. Otherwise an error.
function Directory.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local err
  local codemodel_version = json.codemodelVersion
  if codemodel_version ~= nil then
    codemodel_version, err = object_kind.try_version_from_json(codemodel_version)
    if codemodel_version == nil then
      return nil, err
    end
  end

  if type(json.paths) ~= "table" then
    return nil, "paths is wrong type: " .. type(json.paths)
  end

  local source = json.paths.source
  if type(source) ~= "string" then
    return nil, "paths.source is wrong type: " .. type(source)
  end
  local build = json.paths.build
  if type(build) ~= "string" then
    return nil, "paths.build is wrong type: " .. type(build)
  end

  local raw_installers = json.installers
  if not vim.islist(raw_installers) then
    return nil, "installers is wrong type: " .. type(raw_installers)
  end

  ---@type cmakeseer.cmake.file_api.object_kind.Codemodel.Installer[]
  local installers = {}
  for i, raw_installer in ipairs(raw_installers) do
    local installer
    installer, err = try_installer_from_json(raw_installer)
    if installer == nil then
      return nil, ("installer at index %d: %s"):format(i, err)
    end
    table.insert(installers, installer)
  end

  local backtrace_graph
  backtrace_graph, err = BacktraceGraph.try_from_json(json.backtraceGraph)
  if backtrace_graph == nil then
    return nil, "backtraceGraph is invalid: " .. err
  end

  return Directory.take(codemodel_version, source, build, installers, backtrace_graph)
end

--- Creates a new Directory instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory? obj, string? err The new instance if successful. Otherwise an error.
function Directory.try_from_file(path)
  local json, err = object_kind.try_decode_file(path)
  if json == nil then
    return nil, err
  end
  return Directory.try_from_json(json)
end

Directory.InstallerType = InstallerType

return Directory
