local CMakeSeer = require("cmakeseer")

if pcall(require, "neoconf") then
  require("neoconf.cmakeseer").setup()
end

CMakeSeer.load_if_configured()
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
