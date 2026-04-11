return function()
  ---@class cmakeseer.cmake.api.Configuration
  local default = {
    ---@type string The command used to run CMake. Defaults to `cmake`.
    cmake_command = "cmake",
    ---@type string|fun(): string The path (or a function that generates a path) to the build directory. Can be relative to the current working directory.
    build_directory = "./build",
    ---@type cmakeseer.cmake.api.CMakeSettings Contains definition:value pairs to be used when configuring the project.
    default_cmake_settings = {
      configureSettings = {},
      configureArgs = {},
      kit_name = nil,
      parallel = nil,
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
  return default
end
