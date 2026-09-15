--- Base class for presets.
---@class cmakeseer.cmake.preset.BasePreset
---@field name string Machine-friendly name of the preset.
---@field hidden? boolean Whether the preset is hidden.
---@field inherits? string[] Presets from which to inherit. The first preset to set a value takes precedence.
---@field condition? boolean|cmakeseer.cmake.preset.ConfigurePreset.Condition Condition determining whether preset is enabled.
---@field vendor? table<string, any> Vendor-specific information.
---@field display_name? string Human-friendly name of the preset.
---@field description? string Human-friendly description of the preset.
---@field environment? table<string, string|nil> Environment variables to set.
local BasePreset = {}
BasePreset.__index = BasePreset

--- Creates a new instance.
---@param o cmakeseer.cmake.preset.BasePreset Initial values.
---@return cmakeseer.cmake.preset.BasePreset obj The new instance.
function BasePreset.new(o)
  return BasePreset.take(vim.deepcopy(o))
end

--- Takes o and changes it to a BasePreset.
---@param o cmakeseer.cmake.preset.BasePreset Initial values.
---@return cmakeseer.cmake.preset.BasePreset obj The new instance.
function BasePreset.take(o)
  local self = setmetatable(o, BasePreset)
  return self
end

function BasePreset:expanded()
  local o = {
    name = self.name,
    hidden = self.hidden,
    inherits = vim.deepcopy(self.inherits),
    condition = vim.deepcopy(self.condition), ---@diagnostic disable-line: param-type-mismatch
    vendor = vim.deepcopy(self.vendor),
    display_name = self.display_name,
    description = self.description,
    environment = vim.deepcopy(self.environment),
  }
  return BasePreset.take(o)
end

--- Expands macros. Will also expand file-level macros if a PresetFile is provided.
--- Look for "preset-specific" to see which macros this does NOT expand:
--- <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion>
---@param str string The string to expand.
---@param maybe_file? cmakeseer.cmake.preset.PresetFile The file owning this preset.
---@return string str The expanded string.
function BasePreset:expand_macros(str, maybe_file)
  str = require("cmakeseer.cmake.preset").expand_macros(str, {
    fileDir = maybe_file and function()
      return vim.fs.dirname(maybe_file.path)
    end or nil,
    presetName = function()
      return self.name
    end,
    generator = function()
      vim.notify("Preset variable `generator` not yet supported", vim.log.levels.ERROR)
      return ""
    end,
  })

  str = str:gsub("%$env{([^}]+)}", function(var)
    if self.environment ~= nil and self.environment[var] ~= nil then
      return self.environment[var]
    end

    local maybe_env = vim.env[var]
    if maybe_env == nil then
      return ""
    end
    return maybe_env
  end)
  return str
end

return BasePreset
