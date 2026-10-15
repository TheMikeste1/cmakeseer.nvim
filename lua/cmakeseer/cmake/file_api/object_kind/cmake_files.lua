local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType

--- An input file consumed by CMake.
---@class cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input
---@field path string The path to the input file. Will be relative if inside the top-level source directory. Otherwise absolute. Use with cmakeseer.cmake.file_api.object_kind.CMakeFiles.source if you need the absolute path.
---@field generated boolean If the path is a generated file.
---@field external boolean If the path is not under the top-level source no build directories.
---@field is_cmake boolean If the path is a file in the CMake installation.

--- An object containing information about a glob used by the configuration.
---@class cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob
---@field expression string The glob expression used.
---@field recurse boolean If the glob is recursive, i.e., file(GLOB_RECURSE).
---@field list_directories boolean True if file(GLOB) was called without LIST_DIRECTORIES false or file(GLOB_RECURSE) was called with LIST_DIRECTORIES true.
---@field follow_symlinks boolean If the glob was called with the FOLLOW_SYMLINKS option.
---@field relative? string Present if the glob was called with the `RELATIVE <path>` option. If present, it is the value of `<path>`.
---@field paths string[] The files matching the glob.

--- A `cmakeFiles` object from the CMake file API. Lists CMake files used by the build system.
---@class cmakeseer.cmake.file_api.object_kind.CMakeFiles: cmakeseer.cmake.file_api.object_kind.ObjectKind
---@field kind "cmakeFiles"
---@field source string The absolute path to the top-level source directory.
---@field build string The absolute path to the top-level build directory.
---@field inputs cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input[] Input files consumed by CMake.
---@field globs? cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob[] Globs the configure depends on, if it depends on any.
local CMakeFiles = {}
CMakeFiles.__index = CMakeFiles

--- Creates a new CMakeFiles instance.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param source string The absolute path to the top-level source directory.
---@param build string The absolute path to the top-level build directory.
---@param inputs cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input[] Input files consumed by CMake.
---@param globs? cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob[] Globs the configure depends on, if it depends on any.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles obj The new instance.
function CMakeFiles.new(version, source, build, inputs, globs)
  return CMakeFiles.take(vim.deepcopy(version), source, build, vim.deepcopy(inputs), globs and vim.deepcopy(globs) or nil)
end

--- Creates a new CMakeFiles instance, taking ownership of the passed values.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the object.
---@param source string The absolute path to the top-level source directory.
---@param build string The absolute path to the top-level build directory.
---@param inputs cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input[] Input files consumed by CMake.
---@param globs? cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob[] Globs the configure depends on, if it depends on any.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles obj The new instance.
function CMakeFiles.take(version, source, build, inputs, globs)
  local self = setmetatable({
    kind = ObjectKindType.CMakeFiles,
    version = version,
    source = source,
    build = build,
    inputs = inputs,
    globs = globs,
  }, CMakeFiles)
  return self
end

--- Creates a new Glob instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob? obj, string? err The new instance if successful. Otherwise an error.
local function try_glob_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local expression = json.expression
  if type(expression) ~= "string" then
    return nil, "expression is wrong type: " .. type(expression)
  end
  local recurse = json.recurse or false
  if type(recurse) ~= "boolean" then
    return nil, "recurse is wrong type: " .. type(recurse)
  end
  local list_directories = json.listDirectories or false
  if type(list_directories) ~= "boolean" then
    return nil, "listDirectories is wrong type: " .. type(list_directories)
  end
  local follow_symlinks = json.followSymlinks or false
  if type(follow_symlinks) ~= "boolean" then
    return nil, "followSymlinks is wrong type: " .. type(follow_symlinks)
  end
  local relative = json.relative
  if relative ~= nil and type(relative) ~= "string" then
    return nil, "relative is wrong type: " .. type(relative)
  end

  local paths = json.paths
  if type(paths) ~= "table" or not vim.islist(paths) then
    return nil, "paths is wrong type: " .. type(paths)
  end

  for i, path in ipairs(paths) do
    if type(path) ~= "string" then
      return nil, ("path at index %d is wrong type: %s"):format(i, type(path))
    end
  end

  return {
    expression = expression,
    recurse = recurse,
    list_directories = list_directories,
    follow_symlinks = follow_symlinks,
    relative = relative,
    paths = vim.deepcopy(paths),
  }
end

--- Creates a new Input instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input? obj, string? err The new instance if successful. Otherwise an error.
local function try_input_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local path = json.path
  if type(path) ~= "string" then
    return nil, "path is wrong type: " .. type(path)
  end
  local generated = json.isGenerated or false
  if type(generated) ~= "boolean" then
    return nil, "isGenerated is wrong type: " .. type(generated)
  end
  local external = json.isExternal or false
  if type(external) ~= "boolean" then
    return nil, "isExternal is wrong type: " .. type(external)
  end
  local is_cmake = json.isCMake or false
  if type(is_cmake) ~= "boolean" then
    return nil, "isCMake is wrong type: " .. type(is_cmake)
  end

  return {
    path = path,
    generated = generated,
    external = external,
    is_cmake = is_cmake,
  }
end

--- Creates a new CMakeFiles instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles? obj, string? err The new instance if successful. Otherwise an error.
function CMakeFiles.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  if json.kind ~= ObjectKindType.CMakeFiles then
    return nil, "Incorrect kind: " .. vim.inspect(json.kind)
  end

  local version, err = object_kind.try_version_from_json(json.version)
  if version == nil then
    return nil, err
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

  local raw_inputs = json.inputs
  if type(raw_inputs) ~= "table" or not vim.islist(raw_inputs) then
    return nil, "inputs is wrong type: " .. type(raw_inputs)
  end

  local inputs = {}
  for i, raw_input in ipairs(raw_inputs) do
    local input
    input, err = try_input_from_json(raw_input)
    if input == nil then
      return nil, ("input at index %d: %s"):format(i, err)
    end
    table.insert(inputs, input)
  end

  local raw_globs = json.globsDependent
  local globs
  if raw_globs ~= nil then
    if type(raw_globs) ~= "table" or not vim.islist(raw_globs) then
      return nil, "globsDependent is wrong type: " .. type(raw_globs)
    end

    globs = {}
    for i, raw_glob in ipairs(raw_globs) do
      local glob
      glob, err = try_glob_from_json(raw_glob)
      if glob == nil then
        return nil, ("glob at index %d: %s"):format(i, err)
      end
      table.insert(globs, glob)
    end
  end

  return CMakeFiles.take(version, source, build, inputs, globs)
end

--- Creates a new CMakeFiles instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles? obj, string? err The new instance if successful. Otherwise an error.
function CMakeFiles.try_from_file(path)
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

  return CMakeFiles.try_from_json(object_or_err)
end

return CMakeFiles
