local Preset = require("cmakeseer.cmake.preset.base_preset")

--- A container for CMake's build preset. See <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#build-preset>.
---@class cmakeseer.cmake.preset.BuildPreset: cmakeseer.cmake.preset.BasePreset
---@field configure_preset? string The name of a configure preset to associate with this build preset.
---@field inherit_configure_environment? boolean Whether to inherit the environment from the configure preset.
---@field jobs? integer Maximum number of concurrent processes to use when building.
---@field targets? string|string[] Target or targets to build.
---@field configuration? string Build configuration (e.g. Debug, Release).
---@field clean_first? boolean Whether to clean target artifacts before building.
---@field resolve_package_references? "on"|"off"|"only" Resolves package references before attempting a build.
---@field verbose? boolean Whether to execute verbose build output.
---@field native_tool_options? string[] Native build tool options passed to the underlying build tool.
local BuildPreset = {}
BuildPreset.__index = Preset

--- Creates a new BuildPreset instance.
---@param o cmakeseer.cmake.preset.BuildPreset Initial values.
---@return cmakeseer.cmake.preset.BuildPreset obj The new instance.
function BuildPreset.new(o)
  return BuildPreset.take(vim.deepcopy(o))
end

function BuildPreset.take(o)
  local self = Preset.take(o)
  self = setmetatable(self, BuildPreset)
  ---@cast self cmakeseer.cmake.preset.BuildPreset
  return self
end

function BuildPreset:expanded()
  local o = Preset.expanded(self)
  ---@cast o table
  o.configure_preset = self.configure_preset
  o.inherit_configure_environment = self.inherit_configure_environment
  o.jobs = self.jobs
  o.targets = vim.deepcopy(self.targets) ---@diagnostic disable-line: param-type-mismatch
  o.configuration = self.configuration
  o.clean_first = self.clean_first
  o.resolve_package_references = self.resolve_package_references
  o.verbose = self.verbose
  -- TODO: Expand
  o.native_tool_options = self.native_tool_options
  return BuildPreset.take(o)
end

--- Creates a new BuildPreset instance from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return cmakeseer.cmake.preset.BuildPreset? obj, string? error_msg The new instance, if one was successfully created.
function BuildPreset.try_from_json(json)
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

  local jobs = json["jobs"]
  if jobs ~= nil and type(jobs) ~= "number" then
    return nil, "jobs must be a number"
  end

  local targets = json["targets"]
  if targets ~= nil then
    if type(targets) == "table" then
      for i, tgt in ipairs(targets) do
        if type(tgt) ~= "string" then
          return nil, ("targets at index %d must be a string"):format(i)
        end
      end
    elseif type(targets) ~= "string" then
      return nil, "targets must be a string or list of strings"
    end
  end

  local configuration = json["configuration"]
  if configuration ~= nil and type(configuration) ~= "string" then
    return nil, "configuration must be a string"
  end

  local clean_first = json["cleanFirst"]
  if clean_first ~= nil and type(clean_first) ~= "boolean" then
    return nil, "cleanFirst must be a boolean"
  end

  local resolve_package_references = json["resolvePackageReferences"]
  if resolve_package_references ~= nil and resolve_package_references ~= "on" and resolve_package_references ~= "off" and resolve_package_references ~= "only" then
    return nil, "resolvePackageReferences must be 'on', 'off', or 'only'"
  end

  local verbose = json["verbose"]
  if verbose ~= nil and type(verbose) ~= "boolean" then
    return nil, "verbose must be a boolean"
  end

  local native_tool_options = json["nativeToolOptions"]
  if native_tool_options ~= nil then
    if type(native_tool_options) ~= "table" then
      return nil, "nativeToolOptions must be a list"
    end
    for i, opt in ipairs(native_tool_options) do
      if type(opt) ~= "string" then
        return nil, ("nativeToolOptions at index %d must be a string"):format(i)
      end
    end
  end

  return BuildPreset.new({
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
    jobs = jobs,
    targets = targets,
    configuration = configuration,
    clean_first = clean_first,
    resolve_package_references = resolve_package_references,
    verbose = verbose,
    native_tool_options = native_tool_options,
  })
end

return BuildPreset
