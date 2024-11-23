local Kit = require("cmakeseer.kit")
local Utils = require("cmakeseer.utils")

--- @class Options
--- @field build_directory string|function The path (or a function that generates a path) to the build directory. Can be relative to the current working directory.
--- @field default_cmake_settings CMakeSettings Contains definition:value pairs to be used when configuring the project.
--- @field should_scan_path boolean If the PATH environment variable directories should be scanned for kits.
--- @field scan_paths string[] Additional paths to scan for kits.
--- @field kit_paths string[] Paths to files containing CMake kit definitions. These will not be expanded.
--- @field kits Kit[] Global user-defined kits.

local M = {
  --- @type Kit[]
  kits = {},
  --- @type Kit[]
  scanned_kits = {},
  --- @type Kit
  selected_kit = nil,
  --- @type Options
  options = {
    build_directory = "build",
    default_cmake_settings = {
      configureSettings = {},
    },
    should_scan_path = true,
    scan_paths = {},
    kit_paths = {},
    --- @type Kit[]
    kits = {},
  },
}

--- @return string build_directory The project's build directory.
function M.get_build_directory()
  local build_dir = M.options.build_directory --[[@as string]]
  if type(M.options.build_directory) == "function" then
    build_dir = M.options.build_directory()
  end

  if build_dir[1] == "/" then
    return build_dir
  else
    return vim.fn.getcwd() .. "/" .. build_dir
  end
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

  local definitions = require("cmakeseer.utils").create_definition_strings()
  for _, value in ipairs(definitions) do
    if string.find(value, " ") then
      value = '"' .. value .. '"'
    end

    command = command .. " " .. value
  end

  return command
end

function M.get_all_kits()
  local kits = M.options.kits
  kits = Utils.merge_tables(kits, M.scanned_kits)
  local file_kits = Kit.load_all_kits(M.options.kit_paths)
  kits = Utils.merge_tables(kits, file_kits)
  return kits
end

--- Select a kit to use
function M.select_kit()
  M.kits = M.get_all_kits()
  vim.ui.select(
    M.kits,
    {
      prompt = "Select kit",
      --- @param item Kit
      --- @return string
      format_item = function(item)
        vim.print(item)
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
      M.selected_kit = choice
    end
  )
end

function M.scan_for_kits()
  local kits = {}

  local paths = M.options.scan_paths or {}
  if M.options.should_scan_path then
    local env_paths = vim.split(vim.env.PATH, ":", { trimempty = true })
    -- TODO: Remove duplicates
    paths = Utils.merge_tables(paths, env_paths)
  end
  print(vim.inspect(paths))

  for _, path in ipairs(paths) do
    local new_kits = Kit.scan_for_kits(path)
    kits = Utils.merge_tables(kits, new_kits)
    -- TODO: Remove duplicates
  end

  local count_message = "Found " .. #kits .. " kit"
  if #kits ~= 1 then
    count_message = count_message .. "s"
  end
  vim.notify(count_message)

  -- TODO: Check for duplicates in M.kits
  M.scanned_kits = kits

  -- TODO: Persist
end

--- @param opts Options
function M.setup(opts)
  if type(opts.kit_paths) == "string" then
    ---@diagnostic disable-next-line: assign-type-mismatch
    opts.kit_paths = { opts.kit_paths }
  end
  M.options = vim.tbl_deep_extend("force", M.options, opts)

  M.kits = M.get_all_kits()
  require("cmakeseer.settings").setup(M.options)
  require("cmakeseer.neoconf").setup()
end

return M
