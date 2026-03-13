local M = {}

function M.setup()
  local has_dap, dap = pcall(require, "dap")
  if not has_dap then
    return
  end

  dap.adapters.cmake = function(callback, config)
    local pipe = vim.fn.tempname()
    local args = { "--debugger", "--debugger-pipe", pipe }
    local cmake_args = config.cmakeArgs
    if type(cmake_args) == "function" then
      cmake_args = cmake_args()
    end
    vim.list_extend(args, cmake_args or {})

    callback({
      type = "pipe",
      pipe = pipe,
      executable = {
        command = require("cmakeseer").cmake_command(),
        args = args,
      },
    })
  end

  dap.configurations.cmake = {
    {
      name = "CMake: Configure",
      type = "cmake",
      request = "launch",
      cmakeArgs = function()
        return require("cmakeseer").get_configure_args()
      end,
    },
    {
      name = "CMake: Configure (fresh)",
      type = "cmake",
      request = "launch",
      cmakeArgs = function()
        local args = require("cmakeseer").get_configure_args()
        table.insert(args, "--fresh")
        return args
      end,
    },
  }

  -- Allow breakpoints in CMake files
  require("dap.ext.vscode").type_to_filetypes["cmake"] = { "cmake" }
end

--- Starts a DAP session for CMake configuration.
--- @param fresh boolean? If the configuration should be fresh (i.e. delete cache).
function M.debug_configure(fresh)
  local has_dap, dap = pcall(require, "dap")
  if not has_dap then
    vim.notify("nvim-dap not found", vim.log.levels.ERROR)
    return
  end

  local version = require("cmakeseer.cmake.utils").get_cmake_version()
  if version == nil then
    vim.notify("Unable to get CMake version", vim.log.levels.ERROR)
    return
  end

  if version.major < 3 or (version.major == 3 and version.minor < 27) then
    vim.notify("CMake version >= 3.27 is required for debugging (found " .. version.major .. "." .. version.minor .. ")", vim.log.levels.ERROR)
    return
  end

  dap.run({
    name = "CMake Debugger",
    type = "cmake",
    request = "launch",
    cmakeArgs = function()
      local args = require("cmakeseer").get_configure_args()
      if fresh then
        table.insert(args, "--fresh")
      end
      return args
    end,
  })
end

return M
