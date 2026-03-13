---@class cmakeseer.cmake.api.Configuration
local config = {
  ---@type string The command used to run CMake. Defaults to `cmake`.
  cmake_command = "cmake",
  ---@type string|fun(): string The path (or a function that generates a path) to the build directory. Can be relative to the current working directory.
  build_directory = "./build",
  ---@type cmakeseer.cmake.api.CMakeSettings Contains definition:value pairs to be used when configuring the project.
  default_cmake_settings = {
    configureSettings = {},
    configureArgs = {},
    kit_name = nil,
  },
  ---@type boolean If the PATH environment variable directories should be scanned for kits.
  should_scan_path = true,
  ---@type string[] Additional paths to scan for kits.
  scan_paths = {
    "/usr/bin",
    "/usr/local/bin",
  },
  ---@type string[] Paths to files containing CMake kit definitions. These will not be expanded.
  kit_paths = {},
  ---@type cmakeseer.Kit[] Global user-defined kits.
  kits = {},
  ---@type string? The file to which kit information should be persisted. If nil, kits will not be persisted. Kits will be automatically loaded from this file.
  persist_file = nil,
}

local M = {}

--- Cleans and sets user-provided configuration.
---@param new_config cmakeseer.cmake.api.Configuration? The configuration to set.
---@return cmakeseer.cmake.api.Configuration config The cleaned and set configuration.
function M.set_config(new_config)
  new_config = new_config or {}
  new_config = vim.tbl_deep_extend("force", config, new_config)

  new_config.kit_paths = new_config.kit_paths or {}
  new_config.kits = new_config.kits or {}

  if type(new_config.kit_paths) == "string" then
    new_config.kit_paths = {
      new_config.kit_paths --[[@as string]],
    }
  end

  if new_config.persist_file ~= nil then
    new_config.persist_file = vim.fn.expand(new_config.persist_file)
    table.insert(new_config.kit_paths, new_config.persist_file)
  end

  new_config.kit_paths = vim.iter(new_config.kit_paths):unique():totable()
  new_config.kits = require("cmakeseer.kit").remove_duplicate_kits(new_config.kits)

  config = new_config
  return config
end
M.set = M.set_config

---@return cmakeseer.cmake.api.Configuration config CMakeSeer's configuration.
function M.get_config()
  return vim.deepcopy(config, true)
end
M.get = M.get_config

setmetatable(M, {
  __index = function(_, key)
    local val = config[key]
    if type(val) == "table" then
      return vim.deepcopy(val, true)
    end
    return val
  end,
  __newindex = function(_, key, value)
    if config[key] == nil then
      error("Unknown config item: " .. key)
    end

    local new_config = M.get_config()
    new_config[key] = value
    M.set_config(new_config)
  end,
})

return M
