local BasePreset = require("cmakeseer.cmake.preset.base_preset")
local PresetFile = require("cmakeseer.cmake.preset.preset_file")
local CMakeSeer = require("cmakeseer")
local stub = require("luassert.stub")

describe("cmakeseer.cmake.preset.BasePreset", function()
  describe("new", function()
    it("creates an instance and preserves provided values", function()
      local obj = {
        name = "my-preset",
        hidden = true,
        environment = { FOO = "bar" },
      }
      local preset = BasePreset.new(obj)
      assert.is_not_nil(preset)
      assert.are.equal("my-preset", preset.name)
      assert.is_true(preset.hidden)
      assert.are.same({ FOO = "bar" }, preset.environment)
      obj.environment.FOO = "baz"
      assert.are.equal("bar", preset.environment.FOO)
    end)
  end)

  describe("expand_macros", function()
    local get_config_stub

    before_each(function()
      get_config_stub = stub(CMakeSeer, "get_config", {
        get_project_root = function()
          return "/my/project"
        end,
      })
    end)

    after_each(function()
      get_config_stub:revert()
    end)

    it("expands ${presetName}", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/path/${presetName}")
      assert.are.equal("/path/my-preset", res)
    end)

    pending("expands ${generator}", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/path/${generator}")
      assert.are.equal("/path/", res)
    end)

    it("expands ${fileDir} when a PresetFile is provided", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local pf = PresetFile.new({ path = "/some/dir/CMakePresets.json", version = 3 })
      local res = preset:expand_macros("${fileDir}/build", pf)
      assert.are.equal("/some/dir/build", res)
    end)

    it("leaves ${fileDir} unexpanded when no PresetFile is provided", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("${fileDir}/build")
      assert.are.equal("${fileDir}/build", res)
    end)

    it("expands $env{VAR} from vim.env", function()
      vim.env.MY_TEST_VAR = "env_val"
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/out/$env{MY_TEST_VAR}")
      assert.are.equal("/out/env_val", res)
      vim.env.MY_TEST_VAR = nil
    end)

    it("expands $env{VAR} from self.environment when not in vim.env", function()
      vim.env.MY_TEST_VAR = nil
      local preset = BasePreset.new({ name = "my-preset", environment = { MY_TEST_VAR = "preset_env_val" } })
      local res = preset:expand_macros("/out/$env{MY_TEST_VAR}")
      assert.are.equal("/out/preset_env_val", res)
    end)

    it("prefers self.environment over vim.env for $env{VAR}", function()
      vim.env.MY_TEST_VAR = "env_val"
      local preset = BasePreset.new({ name = "my-preset", environment = { MY_TEST_VAR = "preset_env_val" } })
      local res = preset:expand_macros("/out/$env{MY_TEST_VAR}")
      assert.are.equal("/out/preset_env_val", res)
      vim.env.MY_TEST_VAR = nil
    end)

    it("expands $env{VAR} to empty string when variable is not in vim.env or environment", function()
      vim.env.MY_TEST_VAR = nil
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/out/$env{MY_TEST_VAR}")
      assert.are.equal("/out/", res)
    end)

    it("expands $penv{VAR} from vim.env", function()
      vim.env.MY_TEST_VAR = "penv_val"
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/out/$penv{MY_TEST_VAR}")
      assert.are.equal("/out/penv_val", res)
      vim.env.MY_TEST_VAR = nil
    end)

    it("does not expand $penv{VAR} from self.environment", function()
      vim.env.MY_TEST_VAR = nil
      local preset = BasePreset.new({ name = "my-preset", environment = { MY_TEST_VAR = "preset_env_val" } })
      local res = preset:expand_macros("/out/$penv{MY_TEST_VAR}")
      assert.are.equal("/out/", res)
    end)

    it("leaves unrecognized variable unchanged", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/out/${unrecognizedVar}")
      assert.are.equal("/out/${unrecognizedVar}", res)
    end)

    it("expands multiple macros in a single path", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("${sourceDir}/build/${presetName}")
      assert.are.equal("/my/project/build/my-preset", res)
    end)
  end)
end)
