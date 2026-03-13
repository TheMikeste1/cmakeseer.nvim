local stub = require("luassert.stub")
local spy = require("luassert.spy")
local match = require("luassert.match")

describe("neoconf.cmakeseer", function()
  local neoconf_mod
  local neoconf_plugins_mod
  local settings_mod
  local neoconf_stub
  local register_stub
  local set_settings_spy
  local notify_stub
  local plugin
  local returned_settings

  before_each(function()
    neoconf_mod = require("neoconf")
    neoconf_plugins_mod = require("neoconf.plugins")
    settings_mod = require("cmakeseer.settings")

    returned_settings = {}
    neoconf_stub = stub(neoconf_mod, "get", function(name, _)
      if name == "cmake" then
        return returned_settings
      end
      return {}
    end)

    register_stub = stub(neoconf_plugins_mod, "register", function(p)
      plugin = p
    end)
    set_settings_spy = spy.on(settings_mod, "set_settings")
    notify_stub = stub(vim, "notify")
  end)

  after_each(function()
    neoconf_stub:revert()
    register_stub:revert()
    set_settings_spy:revert()
    notify_stub:revert()
    plugin = nil
    package.loaded["neoconf.cmakeseer"] = nil
  end)

  it("registers and tests all plugin methods", function()
    local mod = require("neoconf.cmakeseer")
    mod.setup()
    assert.stub(register_stub).was.called(1)
    assert.is_not_nil(plugin)

    -- Test Plugin.setup
    returned_settings = { setup = true }
    plugin.setup()
    assert.spy(set_settings_spy).was.called_with(returned_settings)

    -- Test Plugin.on_update
    returned_settings = { update = true }
    plugin.on_update("test.json")
    assert.stub(notify_stub).was.called_with(match.matches("Updating settings from test.json", 1, true))
    assert.spy(set_settings_spy).was.called_with(returned_settings)

    -- Test Plugin.on_schema
    local schema = {
      import = spy.new(function() end),
    }
    plugin.on_schema(schema)
    assert.spy(schema.import).was.called(1)
  end)
end)
