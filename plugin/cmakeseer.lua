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
