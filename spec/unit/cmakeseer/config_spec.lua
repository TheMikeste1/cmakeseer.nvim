local config = require("cmakeseer.config")
local stub = require("luassert.stub")

describe("cmakeseer.config", function()
  local old_config

  before_each(function()
    old_config = config.get_config()
  end)

  after_each(function()
    config.set_config(old_config)
  end)

  describe("set_config", function()
    it("merges new config with defaults", function()
      config.set_config({ cmake_command = "my-cmake" })
      assert.are.equal("my-cmake", config.cmake_command)
      assert.are.equal("./build", config.build_directory)
    end)

    it("handles string kit_paths", function()
      config.set_config({ kit_paths = "some/path" })
      assert.are.same({ "some/path" }, config.kit_paths)
    end)

    it("deduplicates kit_paths", function()
      config.set_config({ kit_paths = { "a", "b", "a" } })
      assert.are.equal(2, #config.kit_paths)
    end)

    it("adds persist_file to kit_paths", function()
      local expand_stub = stub(vim.fn, "expand", function(f)
        return "/abs/" .. f
      end)
      config.set_config({ persist_file = "my-kits.json" })
      assert.is_true(vim.tbl_contains(config.kit_paths, "/abs/my-kits.json"))
      expand_stub:revert()
    end)
  end)

  describe("metatable", function()
    it("allows direct access to config values", function()
      assert.are.equal("cmake", config.cmake_command)
    end)

    it("allows updating config values directly", function()
      config.cmake_command = "new-cmake"
      assert.are.equal("new-cmake", config.get_config().cmake_command)
    end)

    it("errors on unknown config items", function()
      assert.has_error(function()
        config.unknown = "value"
      end, "Unknown config item: unknown")
    end)

    it("returns copies of tables", function()
      local paths = config.scan_paths
      table.insert(paths, "new-path")
      assert.are_not.equal(#paths, #config.scan_paths)
    end)
  end)
end)
