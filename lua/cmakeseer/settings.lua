---@class cmakeseer.cmake.api.CMakeSettings
---@field configureArgs table<string> Contains arguments to be appended to the configure command.
---@field configureSettings table<string, string|boolean|number> Contains the definition:value pairs to be used when configuring the CMake project.
---@field kit_name string? The name of the kit to use.
---@field parallel (integer|fun(): integer?)? The value to pass to CMake with the parallel flag. Negative or `nil` means don't pass the parallel flag. `0` means to pass the parallel flag without arguments.

---@type cmakeseer.cmake.api.CMakeSettings? The settings actually used.
local _settings = nil

local M = {}

---@return cmakeseer.cmake.api.CMakeSettings default_settings The default settings to use.
function M.get_default_settings()
  return require("cmakeseer").config.default_cmake_settings
end

---@return cmakeseer.cmake.api.CMakeSettings settings The current CMake settings.
function M.get_settings()
  _settings = _settings or M.get_default_settings()
  return _settings
end

---@param settings cmakeseer.cmake.api.CMakeSettings? The new settings to use. `nil` will reset to default. Will be taken by-copy.
function M.set_settings(settings)
  ---@diagnostic disable-next-line: param-type-mismatch
  _settings = vim.deepcopy(settings)
end

--- Resets the settings to defaults.
function M.reset_settings()
  _settings = nil
end

return M
