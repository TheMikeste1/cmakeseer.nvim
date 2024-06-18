---@class Options
---@field build_directory string|function The path (or a function that generates a path) to the build directory. Can be relative to the current working directory.
---@field kit_paths table<string> Paths to files containing CMake kit definitions. These will not be expanded.
---@field kits table<cmakeseer.Kit>? Global user-defined kits.

local M = {
  ---@type cmakeseer.Kit[]
  kits = {},
  ---@type cmakeseer.Kit
  selected_kit = nil,
  ---@type Options
  options = {
    build_directory = "build",
    kit_paths = {},
    kits = nil,
  },
}

---@return string build_directory The project's build directory.
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

---@return boolean is_configured If the project is configured.
function M.project_is_configured()
  return vim.fn.filereadable(M.get_build_directory() .. "/CMakeCache.txt") ~= 0
end

---@return string build_cmd The command used to build the CMake project.
function M.get_build_command()
  return "cmake --build " .. M.get_build_directory()
end

---@return string configure_command The command used to configure the CMake project.
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
  local Utils = require("cmakeseer.utils")

  local kits = M.options.kits
  local file_kits = Utils.read_cmakekit_files(M.options.kit_paths)
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
      ---@param item cmakeseer.Kit
      ---@return string
      format_item = function(item)
        vim.print(item)
        local c_compiler = item.compilers.C
        if #c_compiler > 20 then
          c_compiler = vim.fn.pathshorten(c_compiler)
        end

        local cxx_compiler = item.compilers.CXX
        if #cxx_compiler > 20 then
          cxx_compiler = vim.fn.pathshorten(cxx_compiler)
        end
        return item.name .. " (" .. c_compiler .. ", " .. cxx_compiler .. ")"
      end,
    },
    ---@param choice cmakeseer.Kit
    function(choice)
      M.selected_kit = choice
    end
  )
end

---@param opts Options
function M.setup(opts)
  if type(opts.kit_paths) == "string" then
    opts.kit_paths = { opts.kit_paths }
  end
  M.options = vim.tbl_deep_extend("force", M.options, opts)

  M.kits = M.get_all_kits()
  require("cmakeseer.neoconf").setup()
end

return M
