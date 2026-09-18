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
BuildPreset.__index = BuildPreset
setmetatable(BuildPreset, { __index = Preset })

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

--- Copies the preset, expanding its fields.
---@param maybe_file? cmakeseer.cmake.preset.PresetFile The file owning this preset.
---@return cmakeseer.cmake.preset.BuildPreset expanded
function BuildPreset:expanded(maybe_file)
  local o = Preset.expanded(self)
  ---@cast o table
  o.configure_preset = self.configure_preset
  o.inherit_configure_environment = self.inherit_configure_environment
  o.jobs = self.jobs
  if type(self.targets) == "string" then
    o.targets = self:expand_macros(self.targets, maybe_file) ---@diagnostic disable-line: param-type-mismatch
  elseif self.targets ~= nil then
    local targets = self.targets
    ---@cast targets string[]
    o.targets = vim
      .iter(targets)
      :map(function(target)
        return self:expand_macros(target, maybe_file)
      end)
      :totable()
  end
  o.configuration = self.configuration
  o.clean_first = self.clean_first
  o.resolve_package_references = self.resolve_package_references
  o.verbose = self.verbose
  o.native_tool_options = self.native_tool_options and vim
    .iter(self.native_tool_options)
    :map(function(option)
      return self:expand_macros(option, maybe_file)
    end)
    :totable()
  return BuildPreset.take(o)
end

--- Creates a new BuildPreset instance from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return cmakeseer.cmake.preset.BuildPreset? obj, string? error_msg The new instance, if one was successfully created.
function BuildPreset.try_from_json(json)
  local base, error_msg = Preset.try_from_json(json)
  if base == nil then
    return nil, error_msg
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

  return BuildPreset.new(vim.tbl_extend("force", base, {
    configure_preset = configure_preset,
    inherit_configure_environment = inherit_configure_environment,
    jobs = jobs,
    targets = targets,
    configuration = configuration,
    clean_first = clean_first,
    resolve_package_references = resolve_package_references,
    verbose = verbose,
    native_tool_options = native_tool_options,
  }))
end

return BuildPreset
