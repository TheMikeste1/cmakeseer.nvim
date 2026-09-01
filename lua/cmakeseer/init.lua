local current_config = require("cmakeseer.config").Configuration.new()

---@class CMakeSeer
local M = {
  state = require("cmakeseer.state"),
}
M.Variant = M.state.Variant

---@return cmakeseer.Configuration config CMakeSeer's configuration.
function M.get_config()
  return current_config
end

function M.get_project_cache_file()
  local CMakePreset = require("cmakeseer.cmake.preset")

  local binary_dir = nil
  local build_preset = M.state.selections.build_preset
  if build_preset == nil then
    local configure_preset = M.state.selections.configure_preset
    if configure_preset ~= nil then
      binary_dir = CMakePreset.preset_binary_dir(configure_preset, current_config:project_root(), CMakePreset.PresetTypes.Configure)
    end
  else
    binary_dir = CMakePreset.preset_binary_dir(build_preset, current_config:project_root(), CMakePreset.PresetTypes.Build)
  end

  if binary_dir == nil then
    -- Add the default build directory
    binary_dir = current_config:resolve_build_directory()
  end

  return vim.fs.joinpath(binary_dir, "CMakeCache.txt")
end

---@return boolean is_configured If the project is configured.
function M.project_is_configured()
  local cache_path = M.get_project_cache_file()
  return vim.uv.fs_stat(cache_path) ~= nil
end

--- Resolves the current build directory. Will attempt to use the build preset's build directory, then the configure's, and finally the default configured build directory.
---@return string binary_dir The resolved build directory.
function M.resolve_build_directory()
  local CMakePreset = require("cmakeseer.cmake.preset")

  local binary_dir = nil
  local preset = M.state.selections.build_preset
  if preset == nil then
    -- If a build preset isn't selected but a configure preset is, we'll need to
    -- use the configure preset's build directory.
    local configure_preset = M.state.selections.configure_preset
    if configure_preset ~= nil then
      binary_dir = CMakePreset.preset_binary_dir(configure_preset, current_config:project_root(), CMakePreset.PresetTypes.Configure, { resolve_path = true })
    end
  else
    binary_dir = CMakePreset.preset_binary_dir(preset, current_config:project_root(), CMakePreset.PresetTypes.Build, { resolve_path = true })
  end

  if binary_dir == nil then
    binary_dir = current_config:resolve_build_directory()
  end
  return binary_dir
end

---@return string[] args The args used to build a CMake project.
function M.get_build_args()
  local args = { "--build" }

  local preset = M.state.selections.build_preset
  local CMakePreset = require("cmakeseer.cmake.preset")
  if preset == nil then
    -- If a build preset isn't selected but a configure preset is, we'll need to
    -- use the configure preset's build directory.
    local configure_preset = M.state.selections.configure_preset
    local binary_dir = nil
    if configure_preset == nil then
      -- Add the default build directory
      binary_dir = current_config:resolve_build_directory()
    else
      binary_dir = CMakePreset.preset_binary_dir(configure_preset, current_config:project_root(), CMakePreset.PresetTypes.Configure, { resolve_path = true })
    end
    table.insert(args, binary_dir)
  else
    local binary_dir = CMakePreset.preset_binary_dir(preset, current_config:project_root(), CMakePreset.PresetTypes.Build)
    -- If binary_dir is not nil, it must be taken care of by the preset
    if binary_dir == nil then
      binary_dir = current_config:resolve_build_directory()
      table.insert(args, binary_dir)
    end

    vim.list_extend(args, { "--preset", preset })
  end

  local parallel = require("cmakeseer.settings").get_settings().parallel
  if type(parallel) == "function" then
    parallel = parallel()
  end
  if parallel ~= nil and parallel >= 0 then
    table.insert(args, "--parallel")
    if parallel > 0 then
      table.insert(args, tostring(parallel))
    end
  end

  return args
end

---@return string[] args The basic args used to configure a CMake project.
function M.get_basic_configure_args()
  local args = {
    "-S",
    current_config:project_root(),
  }

  local binary_dir = nil
  local preset = M.state.selections.configure_preset
  if preset ~= nil then
    vim.list_extend(args, { "--preset", preset })

    -- Check if the preset includes the build directory
    local CMakePreset = require("cmakeseer.cmake.preset")
    binary_dir = CMakePreset.preset_binary_dir(preset, current_config:project_root(), CMakePreset.PresetTypes.Configure)
    -- We won't need to specify the dir if it does as the --preset flag will take care of it for us
  end

  if binary_dir == nil then
    -- Add the default build directory
    vim.list_extend(args, {
      "-B",
      current_config:resolve_build_directory(),
    })
  end

  table.insert(args, "-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON")
  return args
end

---@return string[] args The args used to configure a CMake project.
function M.get_configure_args()
  local Settings = require("cmakeseer.settings")

  local args = M.get_basic_configure_args()
  -- TODO: Check if this is taken care of in the preset
  local variant = M.state.selections.variant
  if variant ~= M.Variant.Unspecified then
    local definition = string.format("-DCMAKE_BUILD_TYPE:STRING=%s", variant)
    table.insert(args, definition)
  end

  -- TODO: Check if this is taken care of in the preset
  local maybe_selected_kit = M.state.selections.kit
  if maybe_selected_kit == nil then
    vim.notify("No kit selected; not specifying compilers in CMake configuration", vim.log.levels.WARN)
  else
    table.insert(args, "-DCMAKE_C_COMPILER:FILEPATH=" .. maybe_selected_kit.compilers.C)
    table.insert(args, "-DCMAKE_CXX_COMPILER:FILEPATH=" .. maybe_selected_kit.compilers.CXX)
  end

  local configure_settings = Settings.get_settings().configureSettings
  local definitions = require("cmakeseer.cmake.utils").create_definition_strings(configure_settings)
  vim.list_extend(args, definitions)

  local additional_args = Settings.get_settings().configureArgs
  vim.list_extend(args, additional_args)
  return args
end

--- @return string[] configure_command The command used to configure the CMake project.
function M.get_configure_command()
  local command = { current_config.cmake_command }
  local args = M.get_configure_args()
  for _, arg in ipairs(args) do
    table.insert(command, arg)
  end

  return command
end

---@return cmakeseer.Kit[] kits All kits known by CMakeseer.
function M.get_all_kits()
  local Kit = require("cmakeseer.kit")

  local kits = current_config.kits
  vim.list_extend(kits, M.state.discovered_kits())
  local file_kits = Kit.load_all_kits(current_config.kit_paths)
  vim.list_extend(kits, file_kits)
  kits = Kit.remove_duplicate_kits(kits)
  return kits
end

function M.scan_for_kits()
  local Kit = require("cmakeseer.kit")

  local kits = {}
  local paths = current_config.scan_paths or {}
  if current_config.should_scan_path then
    local env_paths = vim.split(vim.env.PATH, ":", { trimempty = true })
    paths = vim.iter({ paths, env_paths }):flatten():unique():totable()
  end

  for _, path in ipairs(paths) do
    local new_kits = Kit.scan_for_kits(path)
    vim.list_extend(kits, new_kits)
  end

  kits = Kit.remove_duplicate_kits(kits)

  if #kits ~= #M.state.discovered_kits() then
    local count_message = "Found " .. #kits .. " kit"
    if #kits ~= 1 then
      count_message = count_message .. "s"
    end
    vim.notify(count_message)
  end

  M.state.set_discovered_kits(kits)

  if current_config.persist_file then
    vim.notify("Persisting kits", vim.log.levels.INFO)
    Kit.persist_kits(current_config.persist_file, M.get_all_kits())
  end
end

---@param path string? Optional path to the directory to check. Will default to the project root.
---@return boolean is_cmake_project If the path contains a CMake project.
function M.is_cmake_project(path)
  local root = path or current_config:project_root()
  local cmake_list = vim.fs.joinpath(root, "CMakeLists.txt")
  return vim.uv.fs_stat(cmake_list) ~= nil
end

---@return boolean is_ctest_project If the current project is a CTest project.
function M.is_ctest_project()
  return require("cmakeseer.ctest.api").is_ctest_project(current_config:resolve_build_directory())
end

---@class cmakeseer.Options
---@field cmake_command string? The command used to run CMake. Defaults to `cmake`.
---@field build_directory (string|fun(): string)? The path (or a function that generates a path) to the build directory. Can be relative to the project root.
---@field project_root (fun(): string)? A function that generates a path to the project root. Can be relative to the current working directory.
---@field default_cmake_settings cmakeseer.CMakeSettings? Contains definition:value pairs to be used when configuring the project.
---@field should_scan_path boolean? If the PATH environment variable directories should be scanned for kits.
---@field scan_paths string[]? Additional paths to scan for kits.
---@field kit_paths string[]? Paths to files containing CMake kit definitions. These will not be expanded.
---@field kits cmakeseer.Kit[]? Global user-defined kits.
---@field persist_file string? The file to which kit information should be persisted. If nil, kits will not be persisted. Kits will be automatically loaded from this file.

---@param opts cmakeseer.Options
function M.setup(opts)
  current_config = current_config:with(opts)
end

return M
