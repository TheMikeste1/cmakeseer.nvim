--- Loads the settings fresh from Neoconf.
--- @return table settings The loaded settings.
local function load_settings()
  local Neoconf = require("neoconf")

  local settings = Neoconf.get("cmake", require("cmakeseer.settings").get_default_settings())
  local vscode_settings = Neoconf.get("vscode.cmake") or {}
  -- VSCode settings take last priority
  settings = vim.tbl_deep_extend("keep", settings, vscode_settings)
  return settings
end

local Plugin = { name = "CMakeSeer" }

function Plugin.setup()
  local settings = load_settings()
  require("cmakeseer.settings").set_settings(settings)
end

function Plugin.on_update(updated_file_name)
  -- We almost certainly could get the updates more efficiently, but we'll wait
  -- for load times to be a problem.
  vim.notify("Updating settings from " .. updated_file_name)
  local settings = load_settings()
  require("cmakeseer.settings").set_settings(settings)
end

function Plugin.on_schema(schema)
  schema:import("cmake", require("cmakeseer.settings").get_default_settings())
end

return {
  setup = function()
    require("neoconf.plugins").register(Plugin)
  end,
}
