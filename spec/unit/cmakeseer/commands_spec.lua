local commands = require("cmakeseer.commands")
local CMakeSeer = require("cmakeseer")
local CMakePreset = require("cmakeseer.cmake.preset")
local stub = require("luassert.stub")

describe("cmakeseer.commands", function()
  local select_stub

  before_each(function()
    select_stub = stub(vim.ui, "select")
    CMakeSeer.state.selections.kit = nil
    CMakeSeer.state.selections.configure_preset = nil
    CMakeSeer.state.selections.build_preset = nil
    CMakeSeer.state.selections.variant = CMakeSeer.Variant.Debug
  end)

  after_each(function()
    select_stub:revert()
  end)

  describe("select_kit", function()
    it("presents all kits and sets selected kit", function()
      local kits = {
        { name = "Kit 1", compilers = { C = "/gcc1", CXX = "/g++1" } },
      }
      local get_kits_stub = stub(CMakeSeer, "get_all_kits", kits)

      select_stub.invokes(function(items, opts, cb)
        assert.are.equal("Select kit", opts.prompt)
        assert.is_function(opts.format_item)
        local formatted = opts.format_item(items[1])
        assert.are.equal("Kit 1 (/gcc1, /g++1)", formatted)
        cb(items[1])
      end)

      commands.select_kit()
      assert.are.same(kits[1], CMakeSeer.state.selections.kit)

      get_kits_stub:revert()
    end)
  end)

  describe("select_configure_preset", function()
    it("fetches configure presets and sets selected configure preset", function()
      local fetch_stub = stub(CMakePreset, "fetch_presets", { "config-debug", "config-release" })

      select_stub.invokes(function(items, opts, cb)
        assert.are.equal("Select configure preset", opts.prompt)
        assert.are.same({ "config-debug", "config-release", "<none>" }, items)
        cb("config-debug")
      end)

      commands.select_configure_preset()
      assert.are.equal("config-debug", CMakeSeer.state.selections.configure_preset)

      fetch_stub:revert()
    end)

    it("handles selecting <none>", function()
      local fetch_stub = stub(CMakePreset, "fetch_presets", { "config-debug" })
      CMakeSeer.state.selections.configure_preset = "config-debug"

      select_stub.invokes(function(items, opts, cb)
        cb("<none>")
      end)

      commands.select_configure_preset()
      assert.is_nil(CMakeSeer.state.selections.configure_preset)

      fetch_stub:revert()
    end)
  end)

  describe("select_build_preset", function()
    it("fetches build presets and sets selected build preset", function()
      local fetch_stub = stub(CMakePreset, "fetch_presets", { "build-debug" })

      select_stub.invokes(function(items, opts, cb)
        assert.are.equal("Select build preset", opts.prompt)
        assert.are.same({ "build-debug", "<none>" }, items)
        cb("build-debug")
      end)

      commands.select_build_preset()
      assert.are.equal("build-debug", CMakeSeer.state.selections.build_preset)

      fetch_stub:revert()
    end)

    it("handles selecting <none>", function()
      local fetch_stub = stub(CMakePreset, "fetch_presets", { "build-debug" })
      CMakeSeer.state.selections.build_preset = "build-debug"

      select_stub.invokes(function(items, opts, cb)
        cb("<none>")
      end)

      commands.select_build_preset()
      assert.is_nil(CMakeSeer.state.selections.build_preset)

      fetch_stub:revert()
    end)
  end)

  describe("select_variant", function()
    it("sets selected variant", function()
      select_stub.invokes(function(items, opts, cb)
        assert.are.equal("Select variant", opts.prompt)
        cb(CMakeSeer.Variant.Release)
      end)

      commands.select_variant()
      assert.are.equal(CMakeSeer.Variant.Release, CMakeSeer.state.selections.variant)
    end)

    it("handles nil selection", function()
      select_stub.invokes(function(items, opts, cb)
        cb(nil)
      end)

      commands.select_variant()
      assert.are.equal(CMakeSeer.Variant.Debug, CMakeSeer.state.selections.variant)
    end)
  end)
end)
