local config_mod = require("cmakeseer.config")
local Configuration = config_mod.Configuration

describe("cmakeseer.config", function()
  describe("Configuration.new", function()
    it("creates configuration with defaults", function()
      local config = Configuration.new()
      assert.are.equal("cmake", config.cmake_command)
      assert.are.equal("./build", config.build_directory)
      assert.is_true(config.should_scan_path)
    end)

    it("overrides default fields when options provided", function()
      local config = Configuration.new({ cmake_command = "my-cmake", build_directory = "/custom/build" })
      assert.are.equal("my-cmake", config.cmake_command)
      assert.are.equal("/custom/build", config.build_directory)
    end)

    it("preserves persist_file option in Configuration.new", function()
      local config = Configuration.new({ persist_file = "/my/kits.json" })
      assert.are.equal("/my/kits.json", config.persist_file)
    end)
  end)

  describe("Configuration:with", function()
    it("merges new config with existing instance", function()
      local config = Configuration.new({ cmake_command = "cmake1" })
      local new_config = config:with({ cmake_command = "cmake2" })
      assert.are.equal("cmake2", new_config.cmake_command)
      assert.are.equal("./build", new_config.build_directory)
    end)

    it("handles empty options in with()", function()
      local config = Configuration.new()
      local new_config = config:with()
      assert.are.equal(config.cmake_command, new_config.cmake_command)
    end)
  end)

  describe("Configuration:resolve_build_directory", function()
    it("resolves function build_directory relative to project root", function()
      local config = Configuration.new({
        build_directory = function()
          return "dynamic_build"
        end,
        project_root = function()
          return "/project"
        end,
      })
      assert.are.equal("/project/dynamic_build", config:resolve_build_directory())
    end)

    it("resolves relative string build_directory", function()
      local config = Configuration.new({
        build_directory = "rel_build",
        project_root = function()
          return "/project"
        end,
      })
      assert.are.equal("/project/rel_build", config:resolve_build_directory())
    end)

    it("handles absolute build_directory", function()
      local config = Configuration.new({
        build_directory = "/abs/build",
        project_root = function()
          return "/project"
        end,
      })
      assert.are.equal("/abs/build", config:resolve_build_directory())
    end)
  end)

  describe("Configuration:get_project_root and reset_project_root", function()
    it("caches project root until reset", function()
      local call_count = 0
      local config = Configuration.new({
        project_root = function()
          call_count = call_count + 1
          return "/root" .. call_count
        end,
      })

      assert.are.equal("/root1", config:get_project_root())
      assert.are.equal("/root1", config:get_project_root())
      assert.are.equal(1, call_count)

      assert.are.equal("/root2", config:reset_project_root())
      assert.are.equal("/root2", config:get_project_root())
      assert.are.equal(2, call_count)
    end)

    it("uses default project_root resolution function", function()
      local config = Configuration.new()
      assert.is_string(config:get_project_root())
    end)
  end)
end)
