local M = {}

--- Check if a command is available on the system.
--- @param cmd string
--- @return boolean
local function has_cmd(cmd)
  return vim.fn.executable(cmd) == 1
end

--- Run health checks for cmakeseer.
function M.check()
  vim.health.start("cmakeseer: Core Dependencies")

  if has_cmd("cmake") then
    local version = vim.fn.system("cmake --version"):match("[0-9%.]+")
    vim.health.ok("cmake found: v" .. version)
  else
    vim.health.error("cmake not found in PATH")
  end

  if has_cmd("ctest") then
    local version = vim.fn.system("ctest --version"):match("[0-9%.]+")
    vim.health.ok("ctest found: v" .. version)
  else
    vim.health.warn("ctest not found in PATH. CTest integration will not work.")
  end

  vim.health.start("cmakeseer: Optional Tools (Profiling & Documentation)")

  if pcall(require, "profile") then
    vim.health.ok("profile.nvim found (instrumenting profiling available)")
  else
    vim.health.info("profile.nvim not found (optional for development)")
  end

  if pcall(require, "mini.doc") then
    vim.health.ok("mini.doc found (documentation generation available)")
  else
    vim.health.info("mini.doc not found (optional for documentation generation)")
  end

  if has_cmd("pandoc") then
    vim.health.ok("pandoc found (panvimdoc generation available)")
  else
    vim.health.info("pandoc not found (optional for documentation generation)")
  end

  vim.health.start("cmakeseer: Configuration")
  local ok, init = pcall(require, "cmakeseer")
  if ok then
    if init.project_is_configured() then
      vim.health.ok("Project is currently configured in " .. init.get_build_directory())
    else
      vim.health.info("Project is not yet configured.")
    end
  else
    vim.health.error("Failed to require 'cmakeseer' module.")
  end
end

return M
