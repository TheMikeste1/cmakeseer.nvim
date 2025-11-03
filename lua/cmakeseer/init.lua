local CmakeUtils = require("cmakeseer.cmake.utils")
local Kit = require("cmakeseer.kit")
local Options = require("cmakeseer.options")
local Settings = require("cmakeseer.settings")
local Utils = require("cmakeseer.utils")

--- TODO: Allow custom variants
---@enum cmakeseer.Variant
local Variant = {
  Debug = "Debug",
  Release = "Release",
  RelWithDebInfo = "RelWithDebInfo",
  MinSizeRel = "MinSizeRel",
  Unspecified = "Unspecified",
}

local M = {
  Variant = Variant,
  --- @type cmakeseer.cmake.api.Options
  __options = Options.default(),
  --- @type cmakeseer.Kit[]
  __scanned_kits = {},
  --- @type cmakeseer.Kit?
  __selected_kit = nil,
  --- @type cmakeseer.cmake.api.codemodel.Target[]
  __targets = {},
  ---@type cmakeseer.Variant
  __selected_variant = Variant.Debug,
  ---@type cmakeseer.cmake.api.CTestInfo?
  __ctest_info = nil,
}

---@return string command The command used to run cmake.
function M.cmake_command()
  return M.__options.cmake_command
end

--- @return string build_directory The project's build directory.
function M.get_build_directory()
  -- FIXME: If the user changes tabs or directories while a build is going AND this path is relative, it will try to place the build directory in the cd'd to directory
  local build_dir = M.__options.build_directory
  if type(build_dir) == "function" then
    build_dir = build_dir()
  end

  return vim.fs.abspath(build_dir)
end

---@return cmakeseer.Variant variant The selected variant.
function M.selected_variant()
  return M.__selected_variant
end

--- @return boolean is_configured If the project is configured.
function M.project_is_configured()
  return vim.fn.glob(vim.fs.joinpath(M.get_build_directory(), "CMakeCache.txt")) ~= ""
end

--- @return string build_cmd The command used to build the CMake project.
function M.get_build_command()
  return string.format("%s --build %s", M.cmake_command(), M.get_build_directory())
end

---@return string[] args The args used to build a CMake project.
function M.get_build_args()
  return {
    "--build",
    M.get_build_directory(),
  }
end

---@return string[] args The args used to configure a CMake project.
function M.get_configure_args()
  local args = {
    "-S",
    vim.fn.getcwd(),
    "-B",
    M.get_build_directory(),
    "-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON",
  }

  local variant = M.selected_variant()
  if variant ~= M.Variant.Unspecified then
    local definition = string.format("-DCMAKE_BUILD_TYPE:STRING=%s", variant)
    table.insert(args, definition)
  end

  local maybe_selected_kit = M.selected_kit()
  if maybe_selected_kit == nil then
    vim.notify("No kit selected; not specifying compilers in CMake configuration", vim.log.levels.WARN)
  else
    table.insert(args, "-DCMAKE_C_COMPILER:FILEPATH=" .. maybe_selected_kit.compilers.C)
    table.insert(args, "-DCMAKE_CXX_COMPILER:FILEPATH=" .. maybe_selected_kit.compilers.CXX)
  end

  local configure_settings = Settings.get_settings().configureSettings
  local definitions = CmakeUtils.create_definition_strings(configure_settings)
  args = Utils.merge_arrays(args, definitions)

  local additional_args = Settings.get_settings().configureArgs
  args = Utils.merge_arrays(args, additional_args)
  return args
end

--- @return string configure_command The command used to configure the CMake project.
function M.get_configure_command()
  local command = string.format("%s", M.cmake_command())
  local args = M.get_configure_args()
  for _, value in ipairs(args) do
    command = string.format("%s '%s'", command, value)
  end

  return command
end

---@return cmakeseer.Kit[] kits All kits known by CMakeseer.
function M.get_all_kits()
  local kits = M.__options.kits
  kits = Utils.merge_arrays(kits, M.__scanned_kits)
  local file_kits = Kit.load_all_kits(M.__options.kit_paths)
  kits = Utils.merge_arrays(kits, file_kits)
  kits = Kit.remove_duplicate_kits(kits)
  return kits
end

---@return cmakeseer.cmake.api.codemodel.Target[] targets The list of CMake targets.
function M.get_targets()
  return M.__targets
end

---@return cmakeseer.cmake.api.CTestInfo? info The CTest info.
function M.get_ctest_info()
  return M.__ctest_info
end

---@return cmakeseer.cmake.api.Test[]? tests The CTest tests.
function M.get_ctest_tests()
  if M.__ctest_info then
    return M.__ctest_info.tests
  end
  return nil
end

---@return cmakeseer.cmake.api.codemodel.Target[] targets The list of CMake targets.
function M.reload_targets()
  if M.project_is_configured() then
    require("cmakeseer.callbacks").on_post_configure_success()
  end

  return M.__targets
end

--- Select a kit to use
function M.select_kit()
  local kits = M.get_all_kits()
  vim.ui.select(
    kits,
    {
      prompt = "Select kit",
      --- @param item cmakeseer.Kit
      --- @return string
      format_item = function(item)
        local c_compiler = item.compilers.C
        if #c_compiler > 20 then
          c_compiler = vim.fn.pathshorten(c_compiler)
        end

        local cxx_compiler = item.compilers.CXX
        if cxx_compiler == nil then
          cxx_compiler = "<no CXX compiler>"
        end
        if #cxx_compiler > 20 then
          cxx_compiler = vim.fn.pathshorten(cxx_compiler)
        end
        return item.name .. " (" .. c_compiler .. ", " .. cxx_compiler .. ")"
      end,
    },
    --- @param choice cmakeseer.Kit
    function(choice)
      M.__selected_kit = choice
    end
  )
end

function M.select_variant()
  local variants = {}
  for _, value in pairs(Variant) do
    table.insert(variants, value)
  end

  vim.ui.select(
    variants,
    {
      prompt = "Select variant",
    },
    --- @param choice cmakeseer.Variant
    function(choice)
      M.__selected_variant = choice
    end
  )
end

function M.scan_for_kits()
  local kits = {}

  local paths = M.__options.scan_paths or {}
  if M.__options.should_scan_path then
    local env_paths = vim.split(vim.env.PATH, ":", { trimempty = true })
    paths = Utils.merge_sets(paths, env_paths)
  end

  for _, path in ipairs(paths) do
    local new_kits = Kit.scan_for_kits(path)
    kits = Utils.merge_arrays(kits, new_kits)
  end

  kits = Kit.remove_duplicate_kits(kits)

  local count_message = "Found " .. #kits .. " kit"
  if #kits ~= 1 then
    count_message = count_message .. "s"
  end
  vim.notify(count_message)

  M.__scanned_kits = kits

  if M.__options.persist_file then
    vim.notify("Persisting kits", vim.log.levels.INFO)
    Kit.persist_kits(M.__options.persist_file, M.get_all_kits())
  end
end

---@return cmakeseer.Kit? selected_kit The currently selected kit, if one exists.
function M.selected_kit()
  if M.__selected_kit ~= nil then
    return M.__selected_kit
  end

  local maybe_kit_name = require("cmakeseer.settings").get_settings().kit_name
  if maybe_kit_name then
    local kits = M.get_all_kits()
    for _, kit in ipairs(kits) do
      if kit.name == maybe_kit_name then
        M.__selected_kit = kit
        return M.__selected_kit
      end
    end

    vim.notify_once("Unable to find selected kit: " .. maybe_kit_name, vim.log.levels.ERROR)
  end

  return nil
end

---@return boolean is_cmake_project If the current project is a CMake project.
function M.is_cmake_project()
  return vim.fn.glob(vim.fs.joinpath(vim.fn.getcwd(), "CMakeLists.txt")) ~= ""
end

---@return boolean is_ctest_project If the current project is a CTest project.
function M.is_ctest_project()
  return require("cmakeseer.ctest.api").is_ctest_project(M.get_build_directory())
end

---@return cmakeseer.cmake.api.Callbacks callbacks The user-defined callbacks object for the project.
function M.callbacks()
  return M.__options.callbacks
end

--- @param opts cmakeseer.cmake.api.Options The options for setup.
function M.setup(opts)
  opts = Options.cleanup(opts)
  M.__options = vim.tbl_deep_extend("force", M.__options, opts)
  M.__options.default_cmake_settings = M.__options.default_cmake_settings or {}
  Settings.setup(M.__options)

  if pcall(require, "neoconf") then
    require("cmakeseer.neoconf").setup()
  end

  if M.project_is_configured() then
    if vim.fn.glob(require("cmakeseer.cmake.api").get_query_directory(M.get_build_directory())) == "" then
      vim.notify(
        "Project is already configured, but CMakeSeer is not a client. Targets won't be available until the project is reconfigured."
      )
    else
      vim.notify("Project is already configured; attempting to load targets. . .")
      vim.schedule(require("cmakeseer.callbacks").on_post_configure_success)
    end
  end
end

return M
