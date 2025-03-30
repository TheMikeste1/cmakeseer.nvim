--- @class Options
--- @field build_directory string|function The path (or a function that generates a path) to the build directory. Can be relative to the current working directory.
--- @field default_cmake_settings CMakeSettings Contains definition:value pairs to be used when configuring the project.
--- @field should_scan_path boolean If the PATH environment variable directories should be scanned for kits.
--- @field scan_paths string[] Additional paths to scan for kits.
--- @field kit_paths string[] Paths to files containing CMake kit definitions. These will not be expanded.
--- @field kits Kit[] Global user-defined kits.
--- @field persist_file string|nil The file to which kit information should be persisted. If nil, kits will not be persisted. Kits will be automatically loaded from this file.

local M = {}

---@return Options options The default set of options.
function M.default()
  return {
    build_directory = "build",
    default_cmake_settings = {
      configureSettings = {},
      kit_name = nil,
    },
    should_scan_path = true,
    scan_paths = {},
    kit_paths = {},
    --- @type Kit[]
    kits = {},
    persist_file = nil,
  }
end

return M
