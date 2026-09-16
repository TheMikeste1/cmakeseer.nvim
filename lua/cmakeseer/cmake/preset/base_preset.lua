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

--- Parses the common preset fields from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return table? base, string? error_msg A plain table of parsed base fields, if they were successfully parsed.
function BasePreset.try_from_json(json)
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

  return {
    name = name,
    hidden = hidden,
    inherits = inherits,
    condition = condition,
    vendor = vendor,
    display_name = display_name,
    description = description,
    environment = environment,
  }
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
