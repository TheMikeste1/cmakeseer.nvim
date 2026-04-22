local CMakeSeer = require("cmakeseer")

if pcall(require, "neoconf") then
  require("neoconf.cmakeseer").setup()
end

if CMakeSeer.project_is_configured() then
  vim.uv.fs_stat(require("cmakeseer.cmake.api").get_query_directory(CMakeSeer.get_build_directory()), function(err, stat)
    _ = stat
    if err ~= nil then
      vim.notify("Project is already configured, but CMakeSeer is not a client. Targets won't be available until the project is reconfigured.")
      return
    end

    vim.notify("Project is already configured; attempting to load targets. . .")
    vim.schedule(require("cmakeseer.callbacks").on_post_configure_success)
  end)
end

require("cmakeseer.dap").setup()
local function handle_api_command(opts)
  vim.notify("CMakeSeer opts: " .. vim.inspect(opts), vim.log.levels.DEBUG)
  if not opts.fargs then
    vim.notify("Missing args")
    return
  end

  if opts.fargs[1] == "select_kit" then
    require("cmakeseer").select_kit()
    return
  end

  if opts.fargs[1] == "select_variant" then
    require("cmakeseer").select_variant()
    return
  end

  if opts.fargs[1] == "edit_cache_entry" then
    require("cmakeseer.ui.edit_cache_entry")()
    return
  end

  vim.notify("Unknown CMakeSeer command: " .. opts.args)
end

vim.api.nvim_create_user_command("CMakeSeer", handle_api_command, {
  desc = "Access the CMakeSeer API",
  nargs = "*",
  complete = function(_, _)
    return { "select_kit", "select_variant", "edit_cache_entry" }
  end,
})
