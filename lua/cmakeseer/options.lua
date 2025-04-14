local Kit = require("cmakeseer.kit")
local Utils = require("cmakeseer.utils")

--- @class Callbacks
--- @field preconfigure fun()? Ran before CMake configures the project.
--- @field postconfigure fun()? Ran after CMake successfully configures the project.

--- @class Options
--- @field cmake_command string The command used to run CMake. Defaults to `cmake`.
--- @field build_directory string|fun(): string The path (or a function that generates a path) to the build directory. Can be relative to the current working directory.
--- @field default_cmake_settings CMakeSettings Contains definition:value pairs to be used when configuring the project.
--- @field should_scan_path boolean If the PATH environment variable directories should be scanned for kits.
--- @field scan_paths string[] Additional paths to scan for kits.
--- @field kit_paths string[] Paths to files containing CMake kit definitions. These will not be expanded.
--- @field kits Kit[] Global user-defined kits.
--- @field persist_file string? The file to which kit information should be persisted. If nil, kits will not be persisted. Kits will be automatically loaded from this file.
--- @field callbacks Callbacks Optional callbacks to run during various parts of the CMake cycle.

local M = {}

---@return Options options The default set of options.
function M.default()
  return {
    cmake_command = "cmake",
    build_directory = "build",
    default_cmake_settings = {
      configureSettings = {},
      kit_name = nil,
    },
    should_scan_path = true,
    scan_paths = {},
    kit_paths = {},
    kits = {},
    persist_file = nil,
    callbacks = {
      preconfigure = nil,
      postconfigure = nil,
    },
  }
end

--- Cleans user-provided options so they are consistent with the data model used.
---@param opts Options The options to clean.
---@return Options opts The cleaned options.
function M.cleanup(opts)
  opts.kit_paths = opts.kit_paths or {}
  opts.kits = opts.kits or {}

  if type(opts.kit_paths) == "string" then
    opts.kit_paths = {
      opts.kit_paths --[[@as string]],
    }
  end

  if opts.persist_file ~= nil then
    opts.persist_file = vim.fn.expand(opts.persist_file)
    table.insert(opts.kit_paths, opts.persist_file)
  end

  opts.kit_paths = Utils.remove_duplicates(opts.kit_paths)
  opts.kits = Kit.remove_duplicate_kits(opts.kits)

  return opts
end

return M
