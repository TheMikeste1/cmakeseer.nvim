---@class CMakeSeer
local M = {
  config = require("cmakeseer.config"),
  state = require("cmakeseer.state"),
}
M.Variant = M.state.Variant

---@return string command The command used to run cmake.
function M.cmake_command()
  return M.config.cmake_command
end

--- @return string build_directory The project's build directory.
function M.get_build_directory()
  -- FIXME: If the user changes tabs or directories while a build is going AND this path is relative, it will try to place the build directory in the cd'd to directory
  local build_dir = M.config.build_directory
  if type(build_dir) == "function" then
    build_dir = build_dir()
  end

  return vim.fs.normalize(vim.fs.abspath(build_dir))
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
  local args = {
    "--build",
    M.get_build_directory(),
  }

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

---@return string[] args The args used to configure a CMake project.
function M.get_configure_args()
  local Settings = require("cmakeseer.settings")

  local args = {
    "-S",
    vim.fn.getcwd(),
    "-B",
    M.get_build_directory(),
    "-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON",
  }

  local variant = M.state.selected_variant()
  if variant ~= M.Variant.Unspecified then
    local definition = string.format("-DCMAKE_BUILD_TYPE:STRING=%s", variant)
    table.insert(args, definition)
  end

  local maybe_selected_kit = M.state.selected_kit()
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
  local command = { M.cmake_command() }
  local args = M.get_configure_args()
  for _, arg in ipairs(args) do
    table.insert(command, arg)
  end

  return command
end

---@return cmakeseer.Kit[] kits All kits known by CMakeseer.
function M.get_all_kits()
  local Kit = require("cmakeseer.kit")

  local kits = M.config.kits
  vim.list_extend(kits, M.state.discovered_kits())
  local file_kits = Kit.load_all_kits(M.config.kit_paths)
  vim.list_extend(kits, file_kits)
  kits = Kit.remove_duplicate_kits(kits)
  return kits
end

--- Select a kit to use
function M.select_kit()
  local kits = M.get_all_kits()
  vim.ui.select(kits, {
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
  }, M.state.set_selected_kit)
end

function M.select_variant()
  local variants = {}
  for _, value in pairs(M.Variant) do
    table.insert(variants, value)
  end

  vim.ui.select(variants, {
    prompt = "Select variant",
  }, M.state.set_selected_variant)
end

function M.scan_for_kits()
  local Kit = require("cmakeseer.kit")

  local kits = {}
  local paths = M.config.scan_paths or {}
  if M.config.should_scan_path then
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

  if M.config.persist_file then
    vim.notify("Persisting kits", vim.log.levels.INFO)
    Kit.persist_kits(M.config.persist_file, M.get_all_kits())
  end
end

---@return boolean is_cmake_project If the current project is a CMake project.
function M.is_cmake_project()
  local root = vim.fn.getcwd() -- TODO: Automatically discover root
  return vim.fn.glob(vim.fs.joinpath(root, "CMakeLists.txt")) ~= ""
end

---@return boolean is_ctest_project If the current project is a CTest project.
function M.is_ctest_project()
  return require("cmakeseer.ctest.api").is_ctest_project(M.get_build_directory())
end

M.setup = M.config.set

return M
