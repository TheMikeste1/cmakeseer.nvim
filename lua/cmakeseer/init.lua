local CmakeUtils = require("cmakeseer.cmake.utils")
local Kit = require("cmakeseer.kit")
local Options = require("cmakeseer.options")
local Utils = require("cmakeseer.utils")

--- TODO: Allow custom variants
---@enum Variant
local Variant = {
  Debug = "Debug",
  Release = "Release",
  RelWithDebInfo = "RelWithDebInfo",
  MinSizeRel = "MinSizeRel",
  Unspecified = "Unspecified",
}

local M = {
  Variant = Variant,
  --- @type Options
  __options = Options.default(),
  --- @type Kit[]
  __scanned_kits = {},
  --- @type Kit?
  __selected_kit = nil,
  --- @type Target[]
  __targets = {},
  ---@type Variant
  __selected_variant = Variant.Debug,
}

--- @return string build_directory The project's build directory.
function M.get_build_directory()
  local build_dir = M.__options.build_directory
  if type(build_dir) == "function" then
    build_dir = build_dir()
  end

  if build_dir:sub(1, 1) == "/" then
    return build_dir
  else
    return vim.fs.joinpath(vim.fn.getcwd(), build_dir)
  end
end

---@return Variant variant The selected variant.
function M.selected_variant()
  return M.__selected_variant
end

--- @return boolean is_configured If the project is configured.
function M.project_is_configured()
  return vim.fn.filereadable(M.get_build_directory() .. "/CMakeCache.txt") ~= 0
end

--- @return string build_cmd The command used to build the CMake project.
function M.get_build_command()
  return "cmake --build " .. M.get_build_directory()
end

--- @return string configure_command The command used to configure the CMake project.
function M.get_configure_command()
  local command = "cmake -S" .. vim.fn.getcwd() .. " -B" .. M.get_build_directory()

  local configure_settings = require("cmakeseer.settings").get_settings().configureSettings
  local definitions = CmakeUtils.create_definition_strings(configure_settings)
  for _, value in ipairs(definitions) do
    if string.find(value, " ") then
      value = '"' .. value .. '"'
    end

    command = command .. " " .. value
  end

  return command
end

---@return Kit[] kits All kits known by CMakeseer.
function M.get_all_kits()
  local kits = M.__options.kits
  kits = Utils.merge_arrays(kits, M.__scanned_kits)
  local file_kits = Kit.load_all_kits(M.__options.kit_paths)
  kits = Utils.merge_arrays(kits, file_kits)
  kits = Kit.remove_duplicate_kits(kits)
  return kits
end

---@return Target[] targets The list of CMake targets.
function M.get_targets()
  return M.__targets
end

---@return Target[] targets The list of CMake targets.
function M.reload_targets()
  if M.project_is_configured() then
    require("cmakeseer.callbacks").onPostConfigureSuccess()
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
      --- @param item Kit
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
    --- @param choice Kit
    function(choice)
      M.__selected_kit = choice
    end
  )
end

function M.select_variant()
  vim.ui.select(
    Variant,
    {
      prompt = "Select variant",
    },
    --- @param choice Variant
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

  local count_message = "Found " .. #kits .. " kit"
  if #kits ~= 1 then
    count_message = count_message .. "s"
  end
  vim.notify(count_message)

  M.__scanned_kits = Kit.remove_duplicate_kits(kits)

  if M.__options.persist_file then
    vim.notify("Persisting kits", vim.log.levels.INFO)
    Kit.persist_kits(M.__options.persist_file, M.get_all_kits())
  end
end

---@return Kit? selected_kit The currently selected kit, if one exists.
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
  return vim.fn.filereadable(vim.fn.getcwd() .. "/CMakeLists.txt") == 1
end

--- @param opts Options The options for setup.
function M.setup(opts)
  opts = Options.cleanup(opts)
  M.__options = vim.tbl_deep_extend("force", M.__options, opts)
  M.__options.default_cmake_settings = M.__options.default_cmake_settings or {}
  require("cmakeseer.settings").setup(M.__options)
  require("cmakeseer.neoconf").setup()

  if M.project_is_configured() then
    vim.notify("Project is already configured; attempting to load targets. . .")
    require("cmakeseer.callbacks").onPostConfigureSuccess()
  end
end

return M
