--- Run this file before you run unittests to download any extra dependencies.
local function profile_start()
  local ok, profile = pcall(require, "profile")
  if not ok then
    vim.notify("profile.nvim not found. Please install 'stevearc/profile.nvim'.", vim.log.levels.ERROR)
    return
  end

  profile.instrument_autocmds()
  if vim.bo.filetype == "lua" then
    profile.instrument("*")
  end

  profile.start("*")
  vim.notify("profile.nvim: Instrumentation started.", vim.log.levels.INFO)
end

--- Stop profiling and save to profile.json
local function profile_stop()
  local ok, profile = pcall(require, "profile")
  if not ok then
    return
  end

  if profile.is_recording() then
    profile.stop("profile.json")
    vim.notify("profile.nvim: Trace saved to profile.json", vim.log.levels.INFO)
  else
    vim.notify("profile.nvim: No active recording found.", vim.log.levels.WARN)
  end
end

--- Start LuaJIT sampling profiler (jit.p)
--- Output will be saved to luajit.p.report
local function jit_start()
  local ok, jit_p = pcall(require, "jit.p")
  if not ok then
    vim.notify("jit.p not found (standard with LuaJIT).", vim.log.levels.ERROR)
    return
  end

  -- Start sampling with 'v' (verbose) mode
  jit_p.start("v", "luajit.p.report")
  vim.notify("jit.p: Sampling started. Output: luajit.p.report", vim.log.levels.INFO)
end

--- Stop LuaJIT sampling profiler
local function jit_stop()
  local ok, jit_p = pcall(require, "jit.p")
  if not ok then
    return
  end

  jit_p.stop()
  vim.notify("jit.p: Sampling stopped. Results in luajit.p.report", vim.log.levels.INFO)
end

local project_root = vim.fn.getcwd()
local dependencies_dir = project_root .. "/.dependencies"

local _DEPENDENCIES = {
  ["https://github.com/Bilal2453/luvit-meta.git"] = "luvit-meta",
  ["https://github.com/LuaCATS/busted.git"] = "busted",
  ["https://github.com/LuaCATS/luassert.git"] = "luassert",
  ["https://github.com/folke/neoconf.nvim.git"] = "neoconf.nvim",
  ["https://github.com/nvim-neotest/neotest.git"] = "neotest",
  ["https://github.com/stevearc/overseer.nvim.git"] = "overseer.nvim",
  ["https://github.com/nvim-lua/plenary.nvim.git"] = "plenary.nvim",
  ["https://github.com/neovim/nvim-lspconfig.git"] = "nvim-lspconfig",
  ["https://github.com/nvim-neotest/nvim-nio.git"] = "nvim-nio",
}

local cloned = false
for url, directory in pairs(_DEPENDENCIES) do
  directory = dependencies_dir .. "/" .. directory
  if vim.fn.isdirectory(directory) ~= 1 then
    vim.fn.mkdir(vim.fn.fnamemodify(directory, ":h"), "p")
    print(string.format('Cloning "%s" to "%s" path.', url, directory))
    vim.fn.system({ "git", "clone", url, directory })
    cloned = true
  end
  vim.opt.rtp:append(directory)
end

if cloned then
  print("Finished cloning.")
end

-- Profiling support for tests (via Environment Variables)
if os.getenv("TEST_JIT") == "1" then
  jit_start()
elseif os.getenv("TEST_PROFILE") == "1" then
  profile_start()
end

vim.opt.rtp:append(".")

-- Automatically stop and save profiling data when Neovim exits
vim.api.nvim_create_autocmd("VimLeavePre", {
  callback = function()
    if os.getenv("TEST_JIT") == "1" then
      jit_stop()
    elseif os.getenv("TEST_PROFILE") == "1" then
      profile_stop()
    end
  end,
})

vim.cmd("runtime plugin/cmakeseer.lua")
