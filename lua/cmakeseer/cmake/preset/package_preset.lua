--- A container for CMake's package preset. See <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#package-preset>.
---@class cmakeseer.cmake.preset.PackagePreset
local PackagePreset = {}
PackagePreset.__index = PackagePreset

---@class cmakeseer.cmake.preset.PackagePreset.Output
---@field debug? boolean Whether to print debug output from CPack.
---@field verbose? boolean Whether to print verbose output from CPack.

---@class cmakeseer.cmake.preset.PackagePreset
---@field name string Machine-friendly name of the preset.
---@field hidden? boolean Whether the preset is hidden.
---@field inherits? string[] Presets from which to inherit. The first preset to set a value takes precedence.
---@field condition? boolean|cmakeseer.cmake.preset.ConfigurePreset.Condition Condition determining whether preset is enabled.
---@field vendor? table<string, any> Vendor-specific information.
---@field display_name? string Human-friendly name of the preset.
---@field description? string Human-friendly description of the preset.
---@field environment? table<string, string|nil> Environment variables to set.
---@field configure_preset? string The name of a configure preset to associate with this package preset.
---@field inherit_configure_environment? boolean Whether to inherit the environment from the configure preset.
---@field generators? string[] Generators for CPack to use.
---@field configurations? string[] Build configurations for CPack to package.
---@field variables? table<string, string> Variables to pass to CPack.
---@field config_file? string Path to the config file for CPack to use.
---@field output? cmakeseer.cmake.preset.PackagePreset.Output CPack output options.
---@field package_name? string The package name.
---@field package_version? string The package version.
---@field package_directory? string The directory in which to place the package.
---@field vendor_name? string The vendor name.
local _PackagePresetDefaults = {}

--- Creates a new PackagePreset instance.
---@param o cmakeseer.cmake.preset.PackagePreset Initial values.
---@return cmakeseer.cmake.preset.PackagePreset obj The new instance.
function PackagePreset.new(o)
  local self = setmetatable(vim.deepcopy(o), PackagePreset)
  for k, v in pairs(_PackagePresetDefaults) do
    if self[k] == nil then
      if type(v) == "table" then
        self[k] = vim.deepcopy(v)
      else
        self[k] = v
      end
    end
  end
  return self
end

--- Creates a new PackagePreset instance from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return cmakeseer.cmake.preset.PackagePreset? obj, string? error_msg The new instance, if one was successfully created.
function PackagePreset.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "preset JSON must be an object"
  end

  local name = json["name"]
  if name == nil then
    return nil, "Could not find name in preset"
  end
  if type(name) ~= "string" then
    return nil, "name must be a string"
  end

  local hidden = json["hidden"]
  if hidden ~= nil and type(hidden) ~= "boolean" then
    return nil, "hidden must be a boolean"
  end

  local inherits = json["inherits"]
  if inherits ~= nil then
    if type(inherits) ~= "table" then
      if type(inherits) == "string" then
        inherits = { inherits }
      else
        return nil, "inherits must be a string or list of strings"
      end
    end

    for i, x in ipairs(inherits) do
      if type(x) ~= "string" then
        return nil, ("inherits object at index %d should be a string"):format(i)
      end
    end
  end

  local condition = json["condition"]
  if condition ~= nil and condition ~= vim.NIL then
    if type(condition) ~= "boolean" and type(condition) ~= "table" then
      return nil, "condition must be a boolean or object"
    end
    if type(condition) == "table" then
      if condition.type == nil or type(condition.type) ~= "string" then
        return nil, "condition.type must be a string"
      end
    end
  else
    condition = nil
  end

  local vendor = json["vendor"]
  if vendor ~= nil and type(vendor) ~= "table" then
    return nil, "vendor must be an object"
  end

  local display_name = json["displayName"]
  if display_name ~= nil and type(display_name) ~= "string" then
    return nil, "displayName must be a string"
  end

  local description = json["description"]
  if description ~= nil and type(description) ~= "string" then
    return nil, "description must be a string"
  end

  local environment = json["environment"]
  if environment ~= nil then
    if type(environment) ~= "table" then
      return nil, "environment must be an object"
    end
    for k, v in pairs(environment) do
      if type(k) ~= "string" or k == "" then
        return nil, "environment keys must be non-empty strings"
      end
      if v ~= nil and v ~= vim.NIL and type(v) ~= "string" then
        return nil, ("environment[%s] must be a string or null"):format(k)
      end
    end
  end

  local configure_preset = json["configurePreset"]
  if configure_preset ~= nil and type(configure_preset) ~= "string" then
    return nil, "configurePreset must be a string"
  end

  local inherit_configure_environment = json["inheritConfigureEnvironment"]
  if inherit_configure_environment ~= nil and type(inherit_configure_environment) ~= "boolean" then
    return nil, "inheritConfigureEnvironment must be a boolean"
  end

  local generators = json["generators"]
  if generators ~= nil then
    if type(generators) ~= "table" then
      return nil, "generators must be a list"
    end
    for i, gen in ipairs(generators) do
      if type(gen) ~= "string" then
        return nil, ("generators at index %d must be a string"):format(i)
      end
    end
  end

  local configurations = json["configurations"]
  if configurations ~= nil then
    if type(configurations) ~= "table" then
      return nil, "configurations must be a list"
    end
    for i, cfg in ipairs(configurations) do
      if type(cfg) ~= "string" then
        return nil, ("configurations at index %d must be a string"):format(i)
      end
    end
  end

  local variables = json["variables"]
  if variables ~= nil then
    if type(variables) ~= "table" then
      return nil, "variables must be an object"
    end
    for k, v in pairs(variables) do
      if type(k) ~= "string" or k == "" then
        return nil, "variables keys must be non-empty strings"
      end
      if type(v) ~= "string" then
        return nil, ("variables[%s] must be a string"):format(k)
      end
    end
  end

  local config_file = json["configFile"]
  if config_file ~= nil and type(config_file) ~= "string" then
    return nil, "configFile must be a string"
  end

  local output = nil
  if json["output"] ~= nil then
    if type(json["output"]) ~= "table" then
      return nil, "output must be an object"
    end
    local out = json["output"]
    if out.debug ~= nil and type(out.debug) ~= "boolean" then
      return nil, "output.debug must be a boolean"
    end
    if out.verbose ~= nil and type(out.verbose) ~= "boolean" then
      return nil, "output.verbose must be a boolean"
    end
    output = {
      debug = out.debug,
      verbose = out.verbose,
    }
  end

  local package_name = json["packageName"]
  if package_name ~= nil and type(package_name) ~= "string" then
    return nil, "packageName must be a string"
  end

  local package_version = json["packageVersion"]
  if package_version ~= nil and type(package_version) ~= "string" then
    return nil, "packageVersion must be a string"
  end

  local package_directory = json["packageDirectory"]
  if package_directory ~= nil and type(package_directory) ~= "string" then
    return nil, "packageDirectory must be a string"
  end

  local vendor_name = json["vendorName"]
  if vendor_name ~= nil and type(vendor_name) ~= "string" then
    return nil, "vendorName must be a string"
  end

  return PackagePreset.new({
    name = name,
    hidden = hidden,
    inherits = inherits,
    condition = condition,
    vendor = vendor,
    display_name = display_name,
    description = description,
    environment = environment,
    configure_preset = configure_preset,
    inherit_configure_environment = inherit_configure_environment,
    generators = generators,
    configurations = configurations,
    variables = variables,
    config_file = config_file,
    output = output,
    package_name = package_name,
    package_version = package_version,
    package_directory = package_directory,
    vendor_name = vendor_name,
  })
end

return PackagePreset
