--- Compile command fragment.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.CompileCommandFragment
---@field fragment string A fragment of the compile command line invocation.
---@field backtrace? number Optional index into the backtrace graph.

--- Language standard entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.LanguageStandard
---@field standard string The language standard.
---@field backtraces? number[] Indices into the backtrace graph.

--- Include directory entry for a compile group.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Include
---@field path string Path to the include directory.
---@field is_system boolean If this is a system include directory.
---@field backtrace? number Optional index into the backtrace graph.

--- Framework entry for a compile group.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Framework
---@field path string Path to the framework directory.
---@field is_system boolean If this is a system framework.
---@field backtrace? number Optional index into the backtrace graph.

--- Precompile header entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.PrecompileHeader
---@field header string Full path to the precompile header file.
---@field backtrace? number Optional index into the backtrace graph.

--- Preprocessor definition entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Define
---@field define string The preprocessor definition.
---@field backtrace? number Optional index into the backtrace graph.

--- Compile group entry.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup
---@field source_indexes number[] Indices into the sources array.
---@field language string Language of the toolchain used to compile.
---@field language_standard? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.LanguageStandard Optional language standard.
---@field compile_command_fragments? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.CompileCommandFragment[] Ordered compile command fragments.
---@field includes? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Include[] Include directories.
---@field frameworks? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Framework[] Framework directories.
---@field precompile_headers? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.PrecompileHeader[] Precompile headers.
---@field defines? cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Define[] Preprocessor definitions.
---@field sysroot? string Optional sysroot.
local CompileGroup = {}

--- Parses an array of command fragments.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.CompileCommandFragment[]? fragments, string? err
local function parse_compile_command_fragments(json)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "compileCommandFragments is wrong type: " .. type(json)
  end
  local fragments = {}
  for i, frag_json in ipairs(json) do
    if type(frag_json) ~= "table" then
      return nil, ("compileCommandFragments[%d] is wrong type: %s"):format(i, type(frag_json))
    end
    local fragment = frag_json.fragment
    if type(fragment) ~= "string" then
      return nil, ("compileCommandFragments[%d].fragment is wrong type: %s"):format(i, type(fragment))
    end
    local backtrace = frag_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("compileCommandFragments[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(fragments, { fragment = fragment, backtrace = backtrace })
  end
  return fragments, nil
end

--- Parses an array of includes.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Include[]? includes, string? err
local function parse_includes(json)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "includes is wrong type: " .. type(json)
  end
  local includes = {}
  for i, inc_json in ipairs(json) do
    if type(inc_json) ~= "table" then
      return nil, ("includes[%d] is wrong type: %s"):format(i, type(inc_json))
    end
    local path = inc_json.path
    if type(path) ~= "string" then
      return nil, ("includes[%d].path is wrong type: %s"):format(i, type(path))
    end
    local is_system = inc_json.isSystem or false
    if type(is_system) ~= "boolean" then
      return nil, ("includes[%d].isSystem is wrong type: %s"):format(i, type(is_system))
    end
    local backtrace = inc_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("includes[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(includes, { path = path, is_system = is_system, backtrace = backtrace })
  end
  return includes, nil
end

--- Parses an array of frameworks.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Framework[]? frameworks, string? err
local function parse_frameworks(json)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "frameworks is wrong type: " .. type(json)
  end
  local frameworks = {}
  for i, fw_json in ipairs(json) do
    if type(fw_json) ~= "table" then
      return nil, ("frameworks[%d] is wrong type: %s"):format(i, type(fw_json))
    end
    local path = fw_json.path
    if type(path) ~= "string" then
      return nil, ("frameworks[%d].path is wrong type: %s"):format(i, type(path))
    end
    local is_system = fw_json.isSystem or false
    if type(is_system) ~= "boolean" then
      return nil, ("frameworks[%d].isSystem is wrong type: %s"):format(i, type(is_system))
    end
    local backtrace = fw_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("frameworks[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(frameworks, { path = path, is_system = is_system, backtrace = backtrace })
  end
  return frameworks, nil
end

--- Parses an array of precompile headers.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.PrecompileHeader[]? headers, string? err
local function parse_precompile_headers(json)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "precompileHeaders is wrong type: " .. type(json)
  end
  local headers = {}
  for i, hdr_json in ipairs(json) do
    if type(hdr_json) ~= "table" then
      return nil, ("precompileHeaders[%d] is wrong type: %s"):format(i, type(hdr_json))
    end
    local header = hdr_json.header
    if type(header) ~= "string" then
      return nil, ("precompileHeaders[%d].header is wrong type: %s"):format(i, type(header))
    end
    local backtrace = hdr_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("precompileHeaders[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(headers, { header = header, backtrace = backtrace })
  end
  return headers, nil
end

--- Parses an array of defines.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup.Define[]? defines, string? err
local function parse_defines(json)
  if json == nil then
    return nil, nil
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "defines is wrong type: " .. type(json)
  end
  local defines = {}
  for i, def_json in ipairs(json) do
    if type(def_json) ~= "table" then
      return nil, ("defines[%d] is wrong type: %s"):format(i, type(def_json))
    end
    local define = def_json.define
    if type(define) ~= "string" then
      return nil, ("defines[%d].define is wrong type: %s"):format(i, type(define))
    end
    local backtrace = def_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("defines[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(defines, { define = define, backtrace = backtrace })
  end
  return defines, nil
end

--- Creates a new CompileGroup instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup? obj, string? err The new instance if successful. Otherwise an error.
function CompileGroup.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local source_indexes = json.sourceIndexes
  if type(source_indexes) ~= "table" or not vim.islist(source_indexes) then
    return nil, "sourceIndexes is wrong type: " .. type(source_indexes)
  end
  for i, idx in ipairs(source_indexes) do
    if type(idx) ~= "number" then
      return nil, ("sourceIndexes[%d] is wrong type: %s"):format(i, type(idx))
    end
  end

  local language = json.language
  if type(language) ~= "string" then
    return nil, "language is wrong type: " .. type(language)
  end

  local language_standard
  local ls_json = json.languageStandard
  if ls_json ~= nil then
    if type(ls_json) ~= "table" then
      return nil, "languageStandard is wrong type: " .. type(ls_json)
    end
    local standard = ls_json.standard
    if type(standard) ~= "string" then
      return nil, "languageStandard.standard is wrong type: " .. type(standard)
    end
    local backtraces = ls_json.backtraces
    if backtraces ~= nil then
      if type(backtraces) ~= "table" or not vim.islist(backtraces) then
        return nil, "languageStandard.backtraces is wrong type: " .. type(backtraces)
      end
      for i, bt in ipairs(backtraces) do
        if type(bt) ~= "number" then
          return nil, ("languageStandard.backtraces[%d] is wrong type: %s"):format(i, type(bt))
        end
      end
    end
    language_standard = { standard = standard, backtraces = backtraces }
  end

  local compile_command_fragments, err = parse_compile_command_fragments(json.compileCommandFragments)
  if compile_command_fragments == nil and err ~= nil then
    return nil, err
  end

  local includes
  includes, err = parse_includes(json.includes)
  if includes == nil and err ~= nil then
    return nil, err
  end

  local frameworks
  frameworks, err = parse_frameworks(json.frameworks)
  if frameworks == nil and err ~= nil then
    return nil, err
  end

  local precompile_headers
  precompile_headers, err = parse_precompile_headers(json.precompileHeaders)
  if precompile_headers == nil and err ~= nil then
    return nil, err
  end

  local defines
  defines, err = parse_defines(json.defines)
  if defines == nil and err ~= nil then
    return nil, err
  end

  local sysroot = json.sysroot
  if sysroot ~= nil then
    if type(sysroot) ~= "table" then
      return nil, "sysroot is wrong type: " .. type(sysroot)
    end
    local sysroot_path = sysroot.path
    if type(sysroot_path) ~= "string" then
      return nil, "sysroot.path is wrong type: " .. type(sysroot_path)
    end
    sysroot = sysroot_path
  end

  return {
    source_indexes = source_indexes,
    language = language,
    language_standard = language_standard,
    compile_command_fragments = compile_command_fragments,
    includes = includes,
    frameworks = frameworks,
    precompile_headers = precompile_headers,
    defines = defines,
    sysroot = sysroot,
  }
end

return CompileGroup
