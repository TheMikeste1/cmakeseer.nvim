local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType

--- Implicit compiler information discovered by CMake.
---@class cmakeseer.cmake.file_api.object_kind.Toolchains.Compiler.Implicit
---@field include_directories? string[] Paths to implicit include directories. Present when CMAKE_<LANG>_IMPLICIT_INCLUDE_DIRECTORIES is defined.
---@field link_directories? string[] Paths to implicit link directories. Present when CMAKE_<LANG>_IMPLICIT_LINK_DIRECTORIES is defined.
---@field link_framework_directories? string[] Paths to implicit link framework directories. Present when CMAKE_<LANG>_IMPLICIT_LINK_FRAMEWORK_DIRECTORIES is defined.
---@field link_libraries? string[] Implicit link libraries. Present when CMAKE_<LANG>_IMPLICIT_LINK_LIBRARIES is defined.

--- Compiler information for a toolchain.
---@class cmakeseer.cmake.file_api.object_kind.Toolchains.Compiler
---@field path? string The path to the compiler. Present when CMAKE_<LANG>_COMPILER is defined.
---@field command_fragment? string Mandatory arguments to the compiler as a command line fragment. Present when CMAKE_<LANG>_COMPILER is a list or CC/similar env var has arguments.
---@field id? string The compiler ID (GNU, MSVC, etc.). Present when CMAKE_<LANG>_COMPILER_ID is defined.
---@field version? string The compiler version string. Present when CMAKE_<LANG>_COMPILER_VERSION is defined.
---@field target? string The cross-compiling target. Present when CMAKE_<LANG>_COMPILER_TARGET is defined.
---@field implicit cmakeseer.cmake.file_api.object_kind.Toolchains.Compiler.Implicit Implicit compiler information.

--- A single toolchain entry.
---@class cmakeseer.cmake.file_api.object_kind.Toolchains.Entry
---@field language string The toolchain language (e.g. "C", "CXX").
---@field compiler cmakeseer.cmake.file_api.object_kind.Toolchains.Compiler The compiler for this language.
---@field source_file_extensions? string[] File extensions (without leading dot) for the language. Present when CMAKE_<LANG>_SOURCE_FILE_EXTENSIONS is defined.

--- A `toolchains` object from the CMake file API. Lists properties of the toolchains used during the build.
---@class cmakeseer.cmake.file_api.object_kind.Toolchains: cmakeseer.cmake.file_api.object_kind.ObjectKind
---@field kind "toolchains"
---@field toolchains cmakeseer.cmake.file_api.object_kind.Toolchains.Entry[] The toolchain entries.
local Toolchains = {}
Toolchains.__index = Toolchains

--- Creates a new Toolchains instance.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param toolchains cmakeseer.cmake.file_api.object_kind.Toolchains.Entry[] The toolchain entries.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains obj The new instance.
function Toolchains.new(version, toolchains)
  return Toolchains.take(vim.deepcopy(version), vim.deepcopy(toolchains))
end

--- Creates a new Toolchains instance, taking ownership of the passed values.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param toolchains cmakeseer.cmake.file_api.object_kind.Toolchains.Entry[] The toolchain entries.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains obj The new instance.
function Toolchains.take(version, toolchains)
  local self = setmetatable({
    kind = ObjectKindType.Toolchains,
    version = version,
    toolchains = toolchains,
  }, Toolchains)
  return self
end

--- Parses an optional list of strings from a JSON field.
---@param json table<string, any> The parent JSON object.
---@param field string The field name to extract.
---@return string[]? value, string? err The list, or nil if absent. Error string on failure.
local function try_optional_string_list(json, field)
  local raw = json[field]
  if raw == nil then
    return nil
  end
  if type(raw) ~= "table" or not vim.islist(raw) then
    return nil, ("%s is wrong type: %s"):format(field, type(raw))
  end
  ---@cast raw any[]
  for i, item in ipairs(raw) do
    if type(item) ~= "string" then
      return nil, ("%s at index %d is wrong type: %s"):format(field, i, type(item))
    end
  end
  ---@type string[]
  local result = vim.deepcopy(raw)
  return result
end

--- Creates a new Implicit instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains.Compiler.Implicit? obj, string? err The new instance if successful. Otherwise an error.
local function try_implicit_from_json(json)
  if type(json) ~= "table" then
    return nil, "implicit is wrong type: " .. type(json)
  end

  local include_directories, err = try_optional_string_list(json, "includeDirectories")
  if err ~= nil then
    return nil, "compiler.implicit." .. err
  end

  local link_directories
  link_directories, err = try_optional_string_list(json, "linkDirectories")
  if err ~= nil then
    return nil, "compiler.implicit." .. err
  end

  local link_framework_directories
  link_framework_directories, err = try_optional_string_list(json, "linkFrameworkDirectories")
  if err ~= nil then
    return nil, "compiler.implicit." .. err
  end

  local link_libraries
  link_libraries, err = try_optional_string_list(json, "linkLibraries")
  if err ~= nil then
    return nil, "compiler.implicit." .. err
  end

  return {
    include_directories = include_directories,
    link_directories = link_directories,
    link_framework_directories = link_framework_directories,
    link_libraries = link_libraries,
  }
end

--- Creates a new Compiler instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains.Compiler? obj, string? err The new instance if successful. Otherwise an error.
local function try_compiler_from_json(json)
  if type(json) ~= "table" then
    return nil, "compiler is wrong type: " .. type(json)
  end

  local path = json.path
  if path ~= nil and type(path) ~= "string" then
    return nil, "compiler.path is wrong type: " .. type(path)
  end

  local command_fragment = json.commandFragment
  if command_fragment ~= nil and type(command_fragment) ~= "string" then
    return nil, "compiler.commandFragment is wrong type: " .. type(command_fragment)
  end

  local id = json.id
  if id ~= nil and type(id) ~= "string" then
    return nil, "compiler.id is wrong type: " .. type(id)
  end

  local version = json.version
  if version ~= nil and type(version) ~= "string" then
    return nil, "compiler.version is wrong type: " .. type(version)
  end

  local target = json.target
  if target ~= nil and type(target) ~= "string" then
    return nil, "compiler.target is wrong type: " .. type(target)
  end

  local raw_implicit = json.implicit
  if type(raw_implicit) ~= "table" then
    return nil, "compiler.implicit is wrong type: " .. type(raw_implicit)
  end

  local implicit, err = try_implicit_from_json(raw_implicit)
  if implicit == nil then
    return nil, err
  end

  return {
    path = path,
    command_fragment = command_fragment,
    id = id,
    version = version,
    target = target,
    implicit = implicit,
  }
end

--- Creates a new Entry instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains.Entry? obj, string? err The new instance if successful. Otherwise an error.
local function try_entry_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local language = json.language
  if type(language) ~= "string" then
    return nil, "language is wrong type: " .. type(language)
  end

  local raw_compiler = json.compiler
  local compiler, err = try_compiler_from_json(raw_compiler)
  if compiler == nil then
    return nil, err
  end

  local source_file_extensions
  source_file_extensions, err = try_optional_string_list(json, "sourceFileExtensions")
  if err ~= nil then
    return nil, err
  end

  return {
    language = language,
    compiler = compiler,
    source_file_extensions = source_file_extensions,
  }
end

--- Creates a new Toolchains instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains? obj, string? err The new instance if successful. Otherwise an error.
function Toolchains.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  if json.kind ~= ObjectKindType.Toolchains then
    return nil, "Incorrect kind: " .. vim.inspect(json.kind)
  end

  local version, err = object_kind.try_version_from_json(json.version)
  if version == nil then
    return nil, err
  end

  local raw_toolchains = json.toolchains
  if type(raw_toolchains) ~= "table" or not vim.islist(raw_toolchains) then
    return nil, "toolchains is wrong type: " .. type(raw_toolchains)
  end

  local toolchains = {}
  for i, raw_entry in ipairs(raw_toolchains) do
    local entry
    entry, err = try_entry_from_json(raw_entry)
    if entry == nil then
      return nil, ("toolchain at index %d: %s"):format(i, err)
    end
    table.insert(toolchains, entry)
  end

  return Toolchains.take(version, toolchains)
end

--- Creates a new Toolchains instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.Toolchains? obj, string? err The new instance if successful. Otherwise an error.
function Toolchains.try_from_file(path)
  local f, err = io.open(path, "r")
  if f == nil then
    return nil, err
  end

  ---@type string?
  local json = f:read("*a")
  f:close()
  if json == nil then
    return nil, "Failed to read " .. path .. ": Is a directory"
  end

  ---@type boolean, table<string>|string
  local success, object_or_err = pcall(vim.json.decode, json, { luanil = { object = true, array = true } })
  if not success then
    ---@cast object_or_err string
    return nil, "vim.json.decode: " .. object_or_err
  end

  return Toolchains.try_from_json(object_or_err)
end

return Toolchains
