local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local BacktraceGraph = require("cmakeseer.cmake.file_api.object_kind.codemodel.backtrace_graph")
local CompileGroup = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.compile_group")
local Install = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.install")
local Launcher = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.launcher")
local Link = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.link")
local Archive = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.archive")
local Source = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.source")
local FileSet = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.file_set")
local LinkLibrary = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.link_library")
local InterfaceLinkLibrary = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.interface_link_library")
local InterfaceInclude = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.interface_include")
local InterfaceSource = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.interface_source")
local SourceGroup = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.source_group")

---@enum cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Type
local TargetType = {
  Executable = "EXECUTABLE",
  StaticLibrary = "STATIC_LIBRARY",
  SharedLibrary = "SHARED_LIBRARY",
  ModuleLibrary = "MODULE_LIBRARY",
  ObjectLibrary = "OBJECT_LIBRARY",
  InterfaceLibrary = "INTERFACE_LIBRARY",
  Utility = "UTILITY",
}

--- Debugger information for a target.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Debugger
---@field working_directory? string Optional working directory for debugging.

--- Originating dependency for link libraries.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FromDependency
---@field id string Unique identifier of the target whose INTERFACE_LINK_LIBRARIES_DIRECT property created the relationship.

--- Compile dependency entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileDependency: cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency
---@field from_dependency? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FromDependency Optional originating dependency.

--- A dependency.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency
---@field id string Unique identifier of the target.
---@field backtrace? number Optional index into the backtrace graph.

--- Information about a codemodel's directories.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target
---@field codemodel_version? cmakeseer.cmake.file_api.object_kind.Version The version of the codemodel this is apart of.
---@field name string The name of the target.
---@field id string The ID of the target.
---@field type cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Type The type of the target.
---@field imported boolean If the target is an imported target.
---@field local boolean If the target is only defined in a local scope instead of global.
---@field abstract boolean If the target is abstract.
---@field symbolic boolean If the target is symbolic, which means it's essentially a group of targets.
---@field backtrace_index? number Optional index into the backtrace graph.
---@field folder? string Optional name of the target folder when the target property is set.
---@field source string The path to the source directory. Will be relative if inside the top-level source directory. Otherwise absolute.
---@field build string The path to the build directory. Will be relative if inside the top-level build directory. Otherwise absolute.
---@field name_on_disk? string The name of the target on disk.
---@field artifacts? string[] Optional paths to artifacts produced by the target.
---@field generator_provided boolean If the target is provided by the build system generator instead of source code.
---@field install? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install Optional install information about the target.
---@field launchers? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher[] Optional launchers for the target.
---@field backtrace_graph cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph The backtrace graph associated with this object.
---@field link? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link Optional link step information.
---@field archive? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive Optional archive step information for static libraries.
---@field debugger? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Debugger Optional debugger information.
---@field dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional build dependencies.
---@field link_libraries? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary[] Optional direct link libraries.
---@field interface_link_libraries? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary[] Optional interface link libraries.
---@field compile_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileDependency[] Optional compile dependencies.
---@field interface_compile_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional interface compile dependencies.
---@field object_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional object dependencies.
---@field order_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional order dependencies.
---@field file_sets? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet[] Optional file sets.
---@field sources? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source[] Optional source files.
---@field interface_sources? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource[] Optional interface source files.
---@field interface_includes? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude[] Optional interface include directories.
---@field source_groups? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup[] Optional source groups.
---@field compile_groups? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup[] Optional compile groups.
local Target = {}
Target.__index = Target

--- Creates a new Target instance.
---@param codemodel_version? cmakeseer.cmake.file_api.object_kind.Version The version of the codemodel this is apart of.
---@param name string The name of the target.
---@param id string The ID of the target.
---@param type_ cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Type The type of the target.
---@param imported boolean If the target is an imported target.
---@param local_ boolean If the target is only defined in a local scope instead of global.
---@param abstract boolean If the target is abstract.
---@param symbolic boolean If the target is symbolic, which means it's essentially a group of targets.
---@param backtrace_index? number Optional index into the backtrace graph.
---@param folder? string Optional name of the target folder when the target property is set.
---@param source string The path to the source directory. Will be relative if inside the top-level source directory. Otherwise absolute.
---@param build string The path to the build directory. Will be relative if inside the top-level build directory. Otherwise absolute.
---@param name_on_disk? string The name of the target on disk.
---@param artifacts? string[] Optional paths to artifacts produced by the target.
---@param generator_provided boolean If the target is provided by the build system generator instead of source code.
---@param install? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install Optional install information about the target.
---@param launchers? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher[] Optional launchers for the target.
---@param backtrace_graph cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph The backtrace graph associated with this object.
---@param link? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link Optional link step information.
---@param archive? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive Optional archive step information for static libraries.
---@param debugger? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Debugger Optional debugger information.
---@param dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional build dependencies.
---@param link_libraries? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary[] Optional direct link libraries.
---@param interface_link_libraries? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary[] Optional interface link libraries.
---@param compile_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileDependency[] Optional compile dependencies.
---@param interface_compile_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional interface compile dependencies.
---@param object_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional object dependencies.
---@param order_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional order dependencies.
---@param file_sets? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet[] Optional file sets.
---@param sources? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source[] Optional source files.
---@param interface_sources? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource[] Optional interface source files.
---@param interface_includes? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude[] Optional interface include directories.
---@param source_groups? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup[] Optional source groups.
---@param compile_groups? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup[] Optional compile groups.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target obj The new instance.
function Target.new(
  codemodel_version,
  name,
  id,
  type_,
  imported,
  local_,
  abstract,
  symbolic,
  backtrace_index,
  folder,
  source,
  build,
  name_on_disk,
  artifacts,
  generator_provided,
  install,
  launchers,
  backtrace_graph,
  link,
  archive,
  debugger,
  dependencies,
  link_libraries,
  interface_link_libraries,
  compile_dependencies,
  interface_compile_dependencies,
  object_dependencies,
  order_dependencies,
  file_sets,
  sources,
  interface_sources,
  interface_includes,
  source_groups,
  compile_groups
)
  return Target.take(
    vim.deepcopy(codemodel_version), ---@diagnostic disable-line: param-type-mismatch
    name,
    id,
    type_,
    imported,
    local_,
    abstract,
    symbolic,
    backtrace_index,
    folder,
    source,
    build,
    name_on_disk,
    vim.deepcopy(artifacts), ---@diagnostic disable-line: param-type-mismatch
    generator_provided,
    vim.deepcopy(install), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(launchers), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(backtrace_graph),
    vim.deepcopy(link), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(archive), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(debugger), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(dependencies), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(link_libraries), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(interface_link_libraries), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(compile_dependencies), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(interface_compile_dependencies), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(object_dependencies), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(order_dependencies), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(file_sets), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(sources), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(interface_sources), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(interface_includes), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(source_groups), ---@diagnostic disable-line: param-type-mismatch
    vim.deepcopy(compile_groups) ---@diagnostic disable-line: param-type-mismatch
  )
end

--- Creates a new Target instance, taking ownership of the passed values.
---@param codemodel_version? cmakeseer.cmake.file_api.object_kind.Version The version of the codemodel this is apart of.
---@param name string The name of the target.
---@param id string The ID of the target.
---@param type_ cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Type The type of the target.
---@param imported boolean If the target is an imported target.
---@param local_ boolean If the target is only defined in a local scope instead of global.
---@param abstract boolean If the target is abstract.
---@param symbolic boolean If the target is symbolic, which means it's essentially a group of targets.
---@param backtrace_index? number Optional index into the backtrace graph.
---@param folder? string Optional name of the target folder when the target property is set.
---@param source string The path to the source directory. Will be relative if inside the top-level source directory. Otherwise absolute.
---@param build string The path to the build directory. Will be relative if inside the top-level build directory. Otherwise absolute.
---@param name_on_disk? string The name of the target on disk.
---@param artifacts? string[] Optional paths to artifacts produced by the target.
---@param generator_provided boolean If the target is provided by the build system generator instead of source code.
---@param install? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install Optional install information about the target.
---@param launchers? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Launcher[] Optional launchers for the target.
---@param backtrace_graph cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph The backtrace graph associated with this object.
---@param link? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link Optional link step information.
---@param archive? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive Optional archive step information for static libraries.
---@param debugger? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Debugger Optional debugger information.
---@param dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional build dependencies.
---@param link_libraries? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary[] Optional direct link libraries.
---@param interface_link_libraries? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary[] Optional interface link libraries.
---@param compile_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileDependency[] Optional compile dependencies.
---@param interface_compile_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional interface compile dependencies.
---@param object_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional object dependencies.
---@param order_dependencies? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[] Optional order dependencies.
---@param file_sets? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet[] Optional file sets.
---@param sources? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source[] Optional source files.
---@param interface_sources? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource[] Optional interface source files.
---@param interface_includes? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude[] Optional interface include directories.
---@param source_groups? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup[] Optional source groups.
---@param compile_groups? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup[] Optional compile groups.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target obj The new instance.
function Target.take(
  codemodel_version,
  name,
  id,
  type_,
  imported,
  local_,
  abstract,
  symbolic,
  backtrace_index,
  folder,
  source,
  build,
  name_on_disk,
  artifacts,
  generator_provided,
  install,
  launchers,
  backtrace_graph,
  link,
  archive,
  debugger,
  dependencies,
  link_libraries,
  interface_link_libraries,
  compile_dependencies,
  interface_compile_dependencies,
  object_dependencies,
  order_dependencies,
  file_sets,
  sources,
  interface_sources,
  interface_includes,
  source_groups,
  compile_groups
)
  local self = setmetatable({
    codemodel_version = codemodel_version,
    name = name,
    id = id,
    type = type_,
    imported = imported,
    ["local"] = local_,
    abstract = abstract,
    symbolic = symbolic,
    backtrace_graph = backtrace_graph,
    backtrace_index = backtrace_index,
    folder = folder,
    source = source,
    build = build,
    name_on_disk = name_on_disk,
    artifacts = artifacts,
    generator_provided = generator_provided,
    install = install,
    launchers = launchers,
    link = link,
    archive = archive,
    debugger = debugger,
    dependencies = dependencies,
    link_libraries = link_libraries,
    interface_link_libraries = interface_link_libraries,
    compile_dependencies = compile_dependencies,
    interface_compile_dependencies = interface_compile_dependencies,
    object_dependencies = object_dependencies,
    order_dependencies = order_dependencies,
    file_sets = file_sets,
    sources = sources,
    interface_sources = interface_sources,
    interface_includes = interface_includes,
    source_groups = source_groups,
    compile_groups = compile_groups,
  }, Target)
  return self
end

--- Parses a dependency array from JSON.
---@param json any The JSON array.
---@param field_name string The field name for error messages.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[]? deps, string? err
local function parse_dependency_array(json, field_name)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, field_name .. " is wrong type: " .. type(json)
  end
  ---@type cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Dependency[]
  local deps = {}
  for i, dep_json in ipairs(json) do
    if type(dep_json) ~= "table" then
      return nil, ("%s[%d] is wrong type: %s"):format(field_name, i, type(dep_json))
    end
    local id = dep_json.id
    if type(id) ~= "string" then
      return nil, ("%s[%d].id is wrong type: %s"):format(field_name, i, type(id))
    end
    local backtrace = dep_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("%s[%d].backtrace is wrong type: %s"):format(field_name, i, type(backtrace))
    end
    local from_dependency = dep_json.fromDependency
    if from_dependency ~= nil then
      if type(from_dependency) ~= "table" then
        return nil, ("%s[%d].fromDependency is wrong type: %s"):format(field_name, i, type(from_dependency))
      end
      local from_id = from_dependency.id
      if type(from_id) ~= "string" then
        return nil, ("%s[%d].fromDependency.id is wrong type: %s"):format(field_name, i, type(from_id))
      end
      from_dependency = { id = from_id }
    end
    table.insert(deps, { id = id, backtrace = backtrace, from_dependency = from_dependency })
  end
  return deps, nil
end

--- Parses an array of objects using a try_from_json function.
---@param json any The JSON array.
---@param field_name string The field name for error messages.
---@param parser fun(json: any): any?, string? The parser function.
---@return any[]? results, string? err
local function parse_object_array(json, field_name, parser)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, field_name .. " is wrong type: " .. type(json)
  end
  local results = {}
  for i, item_json in ipairs(json) do
    local item, err = parser(item_json)
    if item == nil then
      return nil, ("%s[%d]: %s"):format(field_name, i, err)
    end
    table.insert(results, item)
  end
  return results, nil
end

--- Creates a new Target instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target? obj, string? err The new instance if successful. Otherwise an error.
function Target.try_from_json(json)
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

  local name = json.name
  if type(name) ~= "string" then
    return nil, "name is wrong type: " .. type(name)
  end

  local id = json.id
  if type(id) ~= "string" then
    return nil, "id is wrong type: " .. type(id)
  end

  local type_str = json.type
  if type(type_str) ~= "string" then
    return nil, "type is wrong type: " .. type(type_str)
  end
  local valid_type = false
  for _, v in pairs(TargetType) do
    if v == type_str then
      valid_type = true
      break
    end
  end
  if not valid_type then
    return nil, "type is invalid: " .. type_str
  end

  local imported = json.imported or false
  if type(imported) ~= "boolean" then
    return nil, "imported is wrong type: " .. type(imported)
  end

  local is_local = json["local"] or false
  if type(is_local) ~= "boolean" then
    return nil, "local is wrong type: " .. type(is_local)
  end

  local abstract = json.abstract or false
  if type(abstract) ~= "boolean" then
    return nil, "abstract is wrong type: " .. type(abstract)
  end

  local symbolic = json.symbolic or false
  if type(symbolic) ~= "boolean" then
    return nil, "symbolic is wrong type: " .. type(symbolic)
  end

  local backtrace_index = json.backtrace
  if backtrace_index ~= nil and type(backtrace_index) ~= "number" then
    return nil, "backtrace is wrong type: " .. type(backtrace_index)
  end

  local folder = json.folder
  if folder ~= nil then
    if type(folder) ~= "table" then
      return nil, "folder is wrong type: " .. type(folder)
    end
    local folder_name = folder.name
    if type(folder_name) ~= "string" then
      return nil, "folder.name is wrong type: " .. type(folder_name)
    end
    folder = folder_name
  end

  local paths = json.paths
  if type(paths) ~= "table" then
    return nil, "paths is wrong type: " .. type(paths)
  end
  local source = paths.source
  if type(source) ~= "string" then
    return nil, "paths.source is wrong type: " .. type(source)
  end
  local build = paths.build
  if type(build) ~= "string" then
    return nil, "paths.build is wrong type: " .. type(build)
  end

  local name_on_disk = json.nameOnDisk
  if name_on_disk ~= nil and type(name_on_disk) ~= "string" then
    return nil, "nameOnDisk is wrong type: " .. type(name_on_disk)
  end

  local artifacts
  local raw_artifacts = json.artifacts
  if raw_artifacts ~= nil then
    if not vim.islist(raw_artifacts) then
      return nil, "artifacts is wrong type: " .. type(raw_artifacts)
    end
    artifacts = {}
    for i, artifact in ipairs(raw_artifacts) do
      if type(artifact) == "string" then
        table.insert(artifacts, artifact)
      elseif type(artifact) == "table" then
        local path = artifact.path
        if type(path) ~= "string" then
          return nil, ("artifacts[%d].path is wrong type: %s"):format(i, type(path))
        end
        table.insert(artifacts, path)
      else
        return nil, ("artifacts[%d] is wrong type: %s"):format(i, type(artifact))
      end
    end
  end

  local generator_provided = json.generatorProvided or false
  if type(generator_provided) ~= "boolean" then
    return nil, "generatorProvided is wrong type: " .. type(generator_provided)
  end

  local backtrace_graph
  backtrace_graph, err = BacktraceGraph.try_from_json(json.backtraceGraph)
  if backtrace_graph == nil then
    return nil, "backtraceGraph is invalid: " .. err
  end

  local install
  if json.install ~= nil then
    install, err = Install.try_from_json(json.install)
    if install == nil then
      return nil, "install is invalid: " .. err
    end
  end

  local launchers, launchers_err = parse_object_array(json.launchers, "launchers", Launcher.try_from_json)
  if launchers == nil and launchers_err ~= nil then
    return nil, launchers_err
  end

  local link
  if json.link ~= nil then
    link, err = Link.try_from_json(json.link)
    if link == nil then
      return nil, "link is invalid: " .. err
    end
  end

  local archive
  if json.archive ~= nil then
    archive, err = Archive.try_from_json(json.archive)
    if archive == nil then
      return nil, "archive is invalid: " .. err
    end
  end

  local debugger
  if json.debugger ~= nil then
    if type(json.debugger) ~= "table" then
      return nil, "debugger is wrong type: " .. type(json.debugger)
    end
    local working_directory = json.debugger.workingDirectory
    if working_directory ~= nil and type(working_directory) ~= "string" then
      return nil, "debugger.workingDirectory is wrong type: " .. type(working_directory)
    end
    debugger = { working_directory = working_directory }
  end

  local dependencies, deps_err = parse_dependency_array(json.dependencies, "dependencies")
  if dependencies == nil and deps_err ~= nil then
    return nil, deps_err
  end

  local link_libraries, link_libs_err = parse_object_array(json.linkLibraries, "linkLibraries", LinkLibrary.try_from_json)
  if link_libraries == nil and link_libs_err ~= nil then
    return nil, link_libs_err
  end

  local interface_link_libraries, iface_link_libs_err = parse_object_array(json.interfaceLinkLibraries, "interfaceLinkLibraries", InterfaceLinkLibrary.try_from_json)
  if interface_link_libraries == nil and iface_link_libs_err ~= nil then
    return nil, iface_link_libs_err
  end

  local compile_dependencies, compile_deps_err = parse_dependency_array(json.compileDependencies, "compileDependencies")
  if compile_dependencies == nil and compile_deps_err ~= nil then
    return nil, compile_deps_err
  end

  local interface_compile_dependencies, iface_compile_deps_err = parse_dependency_array(json.interfaceCompileDependencies, "interfaceCompileDependencies")
  if interface_compile_dependencies == nil and iface_compile_deps_err ~= nil then
    return nil, iface_compile_deps_err
  end

  local object_dependencies, obj_deps_err = parse_dependency_array(json.objectDependencies, "objectDependencies")
  if object_dependencies == nil and obj_deps_err ~= nil then
    return nil, obj_deps_err
  end

  local order_dependencies, order_deps_err = parse_dependency_array(json.orderDependencies, "orderDependencies")
  if order_dependencies == nil and order_deps_err ~= nil then
    return nil, order_deps_err
  end

  local file_sets, file_sets_err = parse_object_array(json.fileSets, "fileSets", FileSet.try_from_json)
  if file_sets == nil and file_sets_err ~= nil then
    return nil, file_sets_err
  end

  local sources, sources_err = parse_object_array(json.sources, "sources", Source.try_from_json)
  if sources == nil and sources_err ~= nil then
    return nil, sources_err
  end

  local interface_sources, iface_sources_err = parse_object_array(json.interfaceSources, "interfaceSources", InterfaceSource.try_from_json)
  if interface_sources == nil and iface_sources_err ~= nil then
    return nil, iface_sources_err
  end

  local interface_includes, iface_includes_err = parse_object_array(json.interfaceIncludes, "interfaceIncludes", InterfaceInclude.try_from_json)
  if interface_includes == nil and iface_includes_err ~= nil then
    return nil, iface_includes_err
  end

  local source_groups, source_groups_err = parse_object_array(json.sourceGroups, "sourceGroups", SourceGroup.try_from_json)
  if source_groups == nil and source_groups_err ~= nil then
    return nil, source_groups_err
  end

  local compile_groups, compile_groups_err = parse_object_array(json.compileGroups, "compileGroups", CompileGroup.try_from_json)
  if compile_groups == nil and compile_groups_err ~= nil then
    return nil, compile_groups_err
  end

  local self = Target.take(
    codemodel_version,
    name,
    id,
    type_str,
    imported,
    is_local,
    abstract,
    symbolic,
    backtrace_index,
    folder,
    source,
    build,
    name_on_disk,
    artifacts,
    generator_provided,
    install,
    launchers,
    backtrace_graph,
    link,
    archive,
    debugger,
    dependencies,
    link_libraries,
    interface_link_libraries,
    compile_dependencies,
    interface_compile_dependencies,
    object_dependencies,
    order_dependencies,
    file_sets,
    sources,
    interface_sources,
    interface_includes,
    source_groups,
    compile_groups
  )

  return self
end

--- Creates a new Target instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target? obj, string? err The new instance if successful. Otherwise an error.
function Target.try_from_file(path)
  local json, err = object_kind.try_decode_file(path)
  if json == nil then
    return nil, err
  end
  return Target.try_from_json(json)
end

Target.Type = TargetType

return Target
