--- @class CMakeSettings
--- @field configureArgs table<string> Contains arguments to be appended to the configure command.
--- @field configureSettings table<string, string|boolean|number> Contains the definition:value pairs to be used when configuring the CMake project.
--- @field kit_name string? The name of the kit to use.

local M = {}

--- @type CMakeSettings The default settings.
local _default_settings = nil
--- @type CMakeSettings The settings actually used.
local _settings = nil

--- @param opts Options
function M.setup(opts)
  assert(opts.default_cmake_settings)
  _default_settings = opts.default_cmake_settings
  _settings = M.get_default_settings()
end

--- @return CMakeSettings default_settings The default settings to use.
function M.get_default_settings()
  assert(_default_settings, "Settings were never set!")
  return _default_settings
end

--- @return CMakeSettings settings The current CMake settings.
function M.get_settings()
  assert(_settings, "Settings were never set!")
  return _settings
end

--- @param settings CMakeSettings The new settings to use.
function M.set_settings(settings)
  assert(settings ~= nil, "Cannot set settings to nil")
  _settings = settings
end

--- Resets the settings to defaults.
function M.reset_settings()
  _settings = M.get_default_settings()
end

return M
