local CMakeSeer = require("cmakeseer")

if pcall(require, "neoconf") then
  require("neoconf.cmakeseer").setup()
end

if CMakeSeer.project_is_configured() then
  vim.uv.fs_stat(require("cmakeseer.cmake.api").get_query_directory(CMakeSeer.get_config():resolve_build_directory()), function(err, stat)
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

local API_COMMAND_HANDLERS = {
  ["select_kit"] = require("cmakeseer.commands").select_kit,
  ["select_build_preset"] = require("cmakeseer.commands").select_build_preset,
  ["select_configure_preset"] = require("cmakeseer.commands").select_configure_preset,
  ["select_variant"] = require("cmakeseer.commands").select_variant,
}

vim.api.nvim_create_user_command("CMakeSeer", function(opts)
  local handler = API_COMMAND_HANDLERS[opts.fargs[1]]
  if handler ~= nil then
    handler()
    return
  end

  vim.notify("Unknown CMakeSeer command: " .. opts.args)
end, {
  desc = "Update CMakeSeer settings",
  nargs = "+",
  complete = function(ArgLead, CmdLine)
    local command_parts = vim.split(CmdLine, " ")
    local possibilities = {}
    if #command_parts < 3 then
      for key, _ in pairs(API_COMMAND_HANDLERS) do
        table.insert(possibilities, key)
      end
    end

    local matches = {}
    local nonmatches = {}
    for _, possiblity in ipairs(possibilities) do
      if vim.startswith(possiblity, ArgLead) then
        table.insert(matches, possiblity)
      else
        table.insert(nonmatches, possiblity)
      end
    end

    return vim.list_extend(matches, nonmatches)
  end,
})
