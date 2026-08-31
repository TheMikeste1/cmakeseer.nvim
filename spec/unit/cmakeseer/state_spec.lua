local state = require("cmakeseer.state")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.state", function()
  after_each(function()
    state.set_discovered_kits({})
    state.selections.kit = nil
    state.selections.variant = state.Variant.Debug
    state.set_targets({})
  end)

  it("manages discovered kits", function()
    local kits = { { name = "Kit 1" } }
    state.set_discovered_kits(kits)
    assert.are.same(kits, state.discovered_kits())
    assert.are_not.equal(kits, state.discovered_kits()) -- should be a copy
  end)

  it("manages selected variant", function()
    state.selections.variant = state.Variant.Release
    assert.are.equal(state.Variant.Release, state.selections.variant)
  end)

  it("manages targets", function()
    local targets = { { name = "Target 1" } }
    state.set_targets(targets)
    assert.are.same(targets, state.targets())
  end)

  describe("reload_targets", function()
    it("calls on_post_configure_success if configured", function()
      local main = require("cmakeseer")
      local callbacks = require("cmakeseer.callbacks")
      local is_configured_stub = stub(main, "project_is_configured", true)
      local on_success_stub = stub(callbacks, "on_post_configure_success")

      state.reload_targets()

      assert.stub(on_success_stub).was.called(1)

      is_configured_stub:revert()
      on_success_stub:revert()
    end)

    it("does nothing if not configured", function()
      local main = require("cmakeseer")
      local callbacks = require("cmakeseer.callbacks")
      local is_configured_stub = stub(main, "project_is_configured", false)
      local on_success_stub = stub(callbacks, "on_post_configure_success")

      state.reload_targets()

      assert.stub(on_success_stub).was.not_called()

      is_configured_stub:revert()
      on_success_stub:revert()
    end)
  end)

  describe("selected_kit", function()
    it("returns explicitly set kit", function()
      local kit = { name = "Explicit Kit" }
      state.selections.kit = kit
      assert.are.same(kit, state.selections.kit)
    end)

    it("falls back to settings.kit_name", function()
      local settings = require("cmakeseer.settings")
      local main = require("cmakeseer")

      local get_settings_stub = stub(settings, "get_settings", function()
        return { kit_name = "Settings Kit" }
      end)
      local get_all_kits_stub = stub(main, "get_all_kits", function()
        return { { name = "Settings Kit", compilers = { C = "gcc" } } }
      end)

      local kit = state.selections.kit
      assert.is_not_nil(kit)
      ---@cast kit -nil
      assert.are.equal("Settings Kit", kit.name)

      get_settings_stub:revert()
      get_all_kits_stub:revert()
    end)

    it("notifies once and returns nil if kit not found", function()
      local settings = require("cmakeseer.settings")
      local main = require("cmakeseer")
      local notify_stub = stub(vim, "notify_once")

      local get_settings_stub = stub(settings, "get_settings", function()
        return { kit_name = "Missing Kit" }
      end)
      local get_all_kits_stub = stub(main, "get_all_kits", function()
        return { { name = "Other Kit", compilers = { C = "gcc" } } }
      end)

      local kit = state.selections.kit
      assert.is_nil(kit)
      assert.stub(notify_stub).was.called_with(match.matches("Unable to find selected kit: Missing Kit", 1, true), vim.log.levels.ERROR)

      get_settings_stub:revert()
      get_all_kits_stub:revert()
      notify_stub:revert()
    end)

    it("returns nil if no kit_name in settings", function()
      local settings = require("cmakeseer.settings")
      local get_settings_stub = stub(settings, "get_settings", function()
        return {}
      end)

      assert.is_nil(state.selections.kit)

      get_settings_stub:revert()
    end)
  end)
end)
