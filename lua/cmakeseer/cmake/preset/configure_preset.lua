local Preset = require("cmakeseer.cmake.preset.base_preset")

--- A container for CMake's configure preset. See <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#configure-preset>.
---@class cmakeseer.cmake.preset.ConfigurePreset: cmakeseer.cmake.preset.BasePreset
---@field generator? string Generator to use for the preset.
---@field architecture? string|cmakeseer.cmake.preset.ConfigurePreset.Architecture Architecture/platform for generators that support it.
---@field toolset? string|cmakeseer.cmake.preset.ConfigurePreset.Toolset Toolset for generators that support it.
---@field toolchain_file? string Path to the toolchain file.
---@field graphviz? string Path to the graphviz input file.
---@field binary_dir? string Path to the output binary directory.
---@field install_dir? string Path to the installation directory (CMAKE_INSTALL_PREFIX).
---@field cmake_executable? string Path to the CMake executable to use for this preset.
---@field cache_variables? table<string, boolean|string|cmakeseer.cmake.preset.ConfigurePreset.CacheVariable|nil> Cache variables to set.
---@field warnings? cmakeseer.cmake.preset.ConfigurePreset.Warnings Warnings to enable.
---@field errors? cmakeseer.cmake.preset.ConfigurePreset.Errors Errors to enable.
---@field debug? cmakeseer.cmake.preset.ConfigurePreset.Debug Debug options.
---@field trace? cmakeseer.cmake.preset.ConfigurePreset.Trace Trace options.
local ConfigurePreset = {}
ConfigurePreset.__index = Preset

---@alias cmakeseer.cmake.preset.ConfigurePresetField
---| "generator"
---| "architecture"
---| "toolset"
---| "toolchain_file"
---| "graphviz"
---| "binary_dir"
---| "install_dir"
---| "cmake_executable"
---| "cache_variables"
---| "warnings"
---| "errors"
---| "debug"
---| "trace"

---@class cmakeseer.cmake.preset.ConfigurePreset.Architecture
---@field value? string The architecture/platform value.
---@field strategy? "set"|"external" Telling CMake how to handle the field.

---@class cmakeseer.cmake.preset.ConfigurePreset.Toolset
---@field value? string The toolset value.
---@field strategy? "set"|"external" Telling CMake how to handle the field.

---@class cmakeseer.cmake.preset.ConfigurePreset.CacheVariable
---@field type? string The type of the variable.
---@field value string|boolean The value of the variable.

---@class cmakeseer.cmake.preset.ConfigurePreset.Warnings
---@field author? boolean Equivalent to passing -Wauthor or -Wno-author on the command line.
---@field deprecated? boolean Equivalent to passing -Wdeprecated or -Wno-deprecated on the command line.
---@field dev? boolean Equivalent to passing -Wdev or -Wno-dev on the command line.
---@field experimental? boolean Equivalent to passing -Wexperimental or -Wno-experimental on the command line.
---@field install_absolute_destination? boolean Equivalent to passing -Winstall-absolute-destination or -Wno-install-absolute-destination on the command line.
---@field policy? boolean Equivalent to passing -Wpolicy or -Wno-policy on the command line.
---@field uninitialized? boolean Equivalent to passing -Wuninitialized or -Wno-uninitialized on the command line.
---@field unused_cli? boolean Equivalent to passing -Wunused-cli or -Wno-unused-cli on the command line.
---@field system_vars? boolean Setting this to true is equivalent to passing --check-system-vars on the command line.

---@class cmakeseer.cmake.preset.ConfigurePreset.Errors
---@field author? boolean Equivalent to passing -Werror=author or -Wno-error=author on the command line.
---@field deprecated? boolean Equivalent to passing -Werror=deprecated or -Wno-error=deprecated on the command line.
---@field dev? boolean Equivalent to passing -Werror=dev or -Wno-error=dev on the command line.
---@field experimental? boolean Equivalent to passing -Werror=experimental or -Wno-error=experimental on the command line.
---@field install_absolute_destination? boolean Equivalent to passing -Werror=install-absolute-destination or -Wno-error=install-absolute-destination on the command line.
---@field policy? boolean Equivalent to passing -Werror=policy or -Wno-error=policy on the command line.
---@field uninitialized? boolean Equivalent to passing -Werror=uninitialized or -Wno-error=uninitialized on the command line.
---@field unused_cli? boolean Equivalent to passing -Werror=unused-cli or -Wno-error=unused-cli on the command line.

---@class cmakeseer.cmake.preset.ConfigurePreset.Debug
---@field output? boolean Setting this to true is equivalent to passing --debug-output on the command line.
---@field try_compile? boolean Setting this to true is equivalent to passing --debug-trycompile on the command line.
---@field find? boolean Setting this to true is equivalent to passing --debug-find on the command line.

---@class cmakeseer.cmake.preset.ConfigurePreset.Trace
---@field mode? "on"|"off"|"expand" Specifies the trace mode.
---@field format? "human"|"json-v1" Specifies the format output of the trace.
---@field source? string|string[] Paths of source files to be traced.
---@field redirect? string Path to a trace output file.

---@class cmakeseer.cmake.preset.ConfigurePreset.Condition
---@field type "const"|"equals"|"notEquals"|"inList"|"notInList"|"matches"|"notMatches"|"anyOf"|"allOf"|"not" The condition type.
---@field value? boolean Constant boolean value when type is "const".
---@field lhs? string First string to compare for "equals" and "notEquals".
---@field rhs? string Second string to compare for "equals" and "notEquals".
---@field string? string String to search for or match against.
---@field list? string[] List of strings to search in.
---@field regex? string Regular expression to match against.
---@field conditions? (cmakeseer.cmake.preset.ConfigurePreset.Condition|boolean)[] Sub-conditions for "anyOf" or "allOf".
---@field condition? cmakeseer.cmake.preset.ConfigurePreset.Condition|boolean Sub-condition to negate for "not".

--- Creates a new ConfigurePreset instance.
---@param o cmakeseer.cmake.preset.ConfigurePreset Initial values.
---@return cmakeseer.cmake.preset.ConfigurePreset obj The new instance.
function ConfigurePreset.new(o)
  local self = Preset.new(o)
  self = setmetatable(self, ConfigurePreset)
  ---@cast self cmakeseer.cmake.preset.ConfigurePreset
  return self
end

--- Creates a new ConfigurePreset instance from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return cmakeseer.cmake.preset.ConfigurePreset? obj, string? error_msg The new instance, if one was successfully created.
function ConfigurePreset.try_from_json(json)
  local base, error_msg = Preset.try_from_json(json)
  if base == nil then
    return nil, error_msg
  end

  local generator = json["generator"]
  if generator ~= nil and type(generator) ~= "string" then
    return nil, "generator must be a string"
  end

  local architecture = json["architecture"]
  if architecture ~= nil then
    if type(architecture) == "table" then
      if architecture.value ~= nil and type(architecture.value) ~= "string" then
        return nil, "architecture.value must be a string"
      end
      if architecture.strategy ~= nil and architecture.strategy ~= "set" and architecture.strategy ~= "external" then
        return nil, "architecture.strategy must be 'set' or 'external'"
      end
    elseif type(architecture) ~= "string" then
      return nil, "architecture must be a string or object"
    end
  end

  local toolset = json["toolset"]
  if toolset ~= nil then
    if type(toolset) == "table" then
      if toolset.value ~= nil and type(toolset.value) ~= "string" then
        return nil, "toolset.value must be a string"
      end
      if toolset.strategy ~= nil and toolset.strategy ~= "set" and toolset.strategy ~= "external" then
        return nil, "toolset.strategy must be 'set' or 'external'"
      end
    elseif type(toolset) ~= "string" then
      return nil, "toolset must be a string or object"
    end
  end

  local toolchain_file = json["toolchainFile"]
  if toolchain_file ~= nil and type(toolchain_file) ~= "string" then
    return nil, "toolchainFile must be a string"
  end

  local graphviz = json["graphviz"]
  if graphviz ~= nil and type(graphviz) ~= "string" then
    return nil, "graphviz must be a string"
  end

  local binary_dir = json["binaryDir"]
  if binary_dir ~= nil and type(binary_dir) ~= "string" then
    return nil, "binaryDir must be a string"
  end

  local install_dir = json["installDir"]
  if install_dir ~= nil and type(install_dir) ~= "string" then
    return nil, "installDir must be a string"
  end

  local cmake_executable = json["cmakeExecutable"]
  if cmake_executable ~= nil and type(cmake_executable) ~= "string" then
    return nil, "cmakeExecutable must be a string"
  end

  local cache_variables = json["cacheVariables"]
  if cache_variables ~= nil then
    if type(cache_variables) ~= "table" then
      return nil, "cacheVariables must be an object"
    end
    for k, v in pairs(cache_variables) do
      if type(k) ~= "string" or k == "" then
        return nil, "cacheVariables keys must be non-empty strings"
      end
      if v ~= nil and v ~= vim.NIL then
        if type(v) == "table" then
          if v.value == nil or (type(v.value) ~= "string" and type(v.value) ~= "boolean") then
            return nil, ("cacheVariables[%s].value must be a string or boolean"):format(k)
          end
          if v.type ~= nil and type(v.type) ~= "string" then
            return nil, ("cacheVariables[%s].type must be a string"):format(k)
          end
        elseif type(v) ~= "string" and type(v) ~= "boolean" then
          return nil, ("cacheVariables[%s] must be null, a boolean, string, or object"):format(k)
        end
      end
    end
  end

  local warnings = nil
  if json["warnings"] ~= nil then
    if type(json["warnings"]) ~= "table" then
      return nil, "warnings must be an object"
    end
    local w = json["warnings"]
    local warning_keys = {
      "author",
      "deprecated",
      "dev",
      "experimental",
      "installAbsoluteDestination",
      "policy",
      "uninitialized",
      "unusedCli",
      "systemVars",
    }
    for _, field in ipairs(warning_keys) do
      if w[field] ~= nil and type(w[field]) ~= "boolean" then
        return nil, ("warnings.%s must be a boolean"):format(field)
      end
    end
    warnings = {
      author = w.author,
      deprecated = w.deprecated,
      dev = w.dev,
      experimental = w.experimental,
      install_absolute_destination = w.installAbsoluteDestination,
      policy = w.policy,
      uninitialized = w.uninitialized,
      unused_cli = w.unusedCli,
      system_vars = w.systemVars,
    }
  end

  local errors = nil
  if json["errors"] ~= nil then
    if type(json["errors"]) ~= "table" then
      return nil, "errors must be an object"
    end
    local e = json["errors"]
    local error_keys = {
      "author",
      "deprecated",
      "dev",
      "experimental",
      "installAbsoluteDestination",
      "policy",
      "uninitialized",
      "unusedCli",
    }
    for _, field in ipairs(error_keys) do
      if e[field] ~= nil and type(e[field]) ~= "boolean" then
        return nil, ("errors.%s must be a boolean"):format(field)
      end
    end
    errors = {
      author = e.author,
      deprecated = e.deprecated,
      dev = e.dev,
      experimental = e.experimental,
      install_absolute_destination = e.installAbsoluteDestination,
      policy = e.policy,
      uninitialized = e.uninitialized,
      unused_cli = e.unusedCli,
    }
  end

  local debug = nil
  if json["debug"] ~= nil then
    if type(json["debug"]) ~= "table" then
      return nil, "debug must be an object"
    end
    local d = json["debug"]
    if d.output ~= nil and type(d.output) ~= "boolean" then
      return nil, "debug.output must be a boolean"
    end
    if d.tryCompile ~= nil and type(d.tryCompile) ~= "boolean" then
      return nil, "debug.tryCompile must be a boolean"
    end
    if d.find ~= nil and type(d.find) ~= "boolean" then
      return nil, "debug.find must be a boolean"
    end
    debug = {
      output = d.output,
      try_compile = d.tryCompile,
      find = d.find,
    }
  end

  local trace = nil
  if json["trace"] ~= nil then
    if type(json["trace"]) ~= "table" then
      return nil, "trace must be an object"
    end
    local t = json["trace"]
    if t.mode ~= nil and t.mode ~= "on" and t.mode ~= "off" and t.mode ~= "expand" then
      return nil, "trace.mode must be 'on', 'off', or 'expand'"
    end
    if t.format ~= nil and t.format ~= "human" and t.format ~= "json-v1" then
      return nil, "trace.format must be 'human' or 'json-v1'"
    end
    if t.source ~= nil then
      if type(t.source) == "table" then
        for i, src in ipairs(t.source) do
          if type(src) ~= "string" then
            return nil, ("trace.source at index %d must be a string"):format(i)
          end
        end
      elseif type(t.source) ~= "string" then
        return nil, "trace.source must be a string or list of strings"
      end
    end
    if t.redirect ~= nil and type(t.redirect) ~= "string" then
      return nil, "trace.redirect must be a string"
    end
    trace = {
      mode = t.mode,
      format = t.format,
      source = t.source,
      redirect = t.redirect,
    }
  end

  return ConfigurePreset.new(vim.tbl_extend("force", base, {
    generator = generator,
    architecture = architecture,
    toolset = toolset,
    toolchain_file = toolchain_file,
    graphviz = graphviz,
    binary_dir = binary_dir,
    install_dir = install_dir,
    cmake_executable = cmake_executable,
    cache_variables = cache_variables,
    warnings = warnings,
    errors = errors,
    debug = debug,
    trace = trace,
  }))
end

return ConfigurePreset
