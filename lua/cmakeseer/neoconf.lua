local Neoconf = require("neoconf")
local NeoconfPlugins = require("neoconf.plugins")

local Settings = require("cmakeseer.settings")

local DEFAULT_SETTINGS = Settings.get_default_settings()

--- Loads the settings fresh from Neoconf.
--- @return table settings The loaded settings.
local function load_settings()
  local settings = Neoconf.get("cmake", DEFAULT_SETTINGS)
  local vscode_settings = Neoconf.get("vscode.cmake") or {}
  -- VSCode settings take last priority
  settings = vim.tbl_deep_extend("keep", settings, vscode_settings)
  return settings
end

local Plugin = { name = "CMakeSeer" }

function Plugin.setup()
  local settings = load_settings()
  Settings.set_settings(settings)
end

function Plugin.on_update(updated_file_name)
  -- We almost certainly could get the updates more efficiently, but we'll wait
  -- for load times to be a problem.
  vim.notify("Updating settings from " .. updated_file_name)
  local settings = load_settings()
  Settings.set_settings(settings)
end

function Plugin.on_schema(schema)
  schema:import("cmake", DEFAULT_SETTINGS)
end

return {
  setup = function()
    NeoconfPlugins.register(Plugin)
  end,
}
