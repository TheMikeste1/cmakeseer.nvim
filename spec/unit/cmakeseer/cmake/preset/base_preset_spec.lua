local BasePreset = require("cmakeseer.cmake.preset.base_preset")
local ConfigurePreset = require("cmakeseer.cmake.preset.configure_preset")
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

  describe("try_from_json", function()
    it("returns nil when json is not a table", function()
      local base, err = BasePreset.try_from_json("not a table")
      assert.is_nil(base)
      assert.are.equal("preset JSON must be an object", err)
    end)

    it("returns nil when name is missing or not a string", function()
      local base1, err1 = BasePreset.try_from_json({})
      assert.is_nil(base1)
      assert.are.equal("Could not find name in preset", err1)

      local base2, err2 = BasePreset.try_from_json({ name = 123 })
      assert.is_nil(base2)
      assert.are.equal("name must be a string", err2)
    end)

    it("returns a plain table of parsed base fields", function()
      local base, err = BasePreset.try_from_json({ name = "my-preset" })
      assert.is_nil(err)
      assert.is_not_nil(base)
      assert.is_nil(getmetatable(base))
      assert.are.equal("my-preset", base.name)
      assert.is_nil(base.hidden)
      assert.is_nil(base.inherits)
      assert.is_nil(base.condition)
      assert.is_nil(base.vendor)
      assert.is_nil(base.display_name)
      assert.is_nil(base.description)
      assert.is_nil(base.environment)
    end)

    it("validates hidden", function()
      local base1, err1 = BasePreset.try_from_json({ name = "p", hidden = "true" })
      assert.is_nil(base1)
      assert.are.equal("hidden must be a boolean", err1)

      local base2, err2 = BasePreset.try_from_json({ name = "p", hidden = true })
      assert.is_nil(err2)
      assert.is_true(base2.hidden)
    end)

    it("normalizes inherits string to an array", function()
      local base, err = BasePreset.try_from_json({ name = "p", inherits = "base" })
      assert.is_nil(err)
      assert.is_not_nil(base)
      assert.are.same({ "base" }, base.inherits)
    end)

    it("accepts inherits array of strings", function()
      local base, err = BasePreset.try_from_json({ name = "p", inherits = { "base1", "base2" } })
      assert.is_nil(err)
      assert.is_not_nil(base)
      assert.are.same({ "base1", "base2" }, base.inherits)
    end)

    it("rejects invalid inherits", function()
      local base1, err1 = BasePreset.try_from_json({ name = "p", inherits = 123 })
      assert.is_nil(base1)
      assert.are.equal("inherits must be a string or list of strings", err1)

      local base2, err2 = BasePreset.try_from_json({ name = "p", inherits = { "ok", 123 } })
      assert.is_nil(base2)
      assert.are.equal("inherits object at index 2 should be a string", err2)
    end)

    it("validates condition", function()
      local base1, err1 = BasePreset.try_from_json({ name = "p", condition = "invalid" })
      assert.is_nil(base1)
      assert.are.equal("condition must be a boolean or object", err1)

      local base2, err2 = BasePreset.try_from_json({ name = "p", condition = {} })
      assert.is_nil(base2)
      assert.are.equal("condition.type must be a string", err2)

      local base3, err3 = BasePreset.try_from_json({ name = "p", condition = true })
      assert.is_nil(err3)
      assert.is_true(base3.condition)

      local base4, err4 = BasePreset.try_from_json({ name = "p", condition = { type = "const", value = false } })
      assert.is_nil(err4)
      assert.are.same({ type = "const", value = false }, base4.condition)
    end)

    it("treats vim.NIL condition as absent", function()
      local base, err = BasePreset.try_from_json({ name = "p", condition = vim.NIL })
      assert.is_nil(err)
      assert.is_not_nil(base)
      assert.is_nil(base.condition)
    end)

    it("validates vendor", function()
      local base1, err1 = BasePreset.try_from_json({ name = "p", vendor = "not a table" })
      assert.is_nil(base1)
      assert.are.equal("vendor must be an object", err1)

      local base2, err2 = BasePreset.try_from_json({ name = "p", vendor = { ide = { setting = 1 } } })
      assert.is_nil(err2)
      assert.are.same({ ide = { setting = 1 } }, base2.vendor)
    end)

    it("validates display_name and description", function()
      local base1, err1 = BasePreset.try_from_json({ name = "p", displayName = 123 })
      assert.is_nil(base1)
      assert.are.equal("displayName must be a string", err1)

      local base2, err2 = BasePreset.try_from_json({ name = "p", description = 123 })
      assert.is_nil(base2)
      assert.are.equal("description must be a string", err2)

      local base3, err3 = BasePreset.try_from_json({ name = "p", displayName = "My Preset", description = "Desc" })
      assert.is_nil(err3)
      assert.are.equal("My Preset", base3.display_name)
      assert.are.equal("Desc", base3.description)
    end)

    it("validates environment", function()
      local base1, err1 = BasePreset.try_from_json({ name = "p", environment = "not a table" })
      assert.is_nil(base1)
      assert.are.equal("environment must be an object", err1)

      local base2, err2 = BasePreset.try_from_json({ name = "p", environment = { FOO = 123 } })
      assert.is_nil(base2)
      assert.are.equal("environment[FOO] must be a string or null", err2)

      local base3, err3 = BasePreset.try_from_json({ name = "p", environment = { FOO = "bar" } })
      assert.is_nil(err3)
      assert.are.same({ FOO = "bar" }, base3.environment)
    end)

    it("rejects empty environment keys", function()
      local base, err = BasePreset.try_from_json({ name = "p", environment = { [""] = "bar" } })
      assert.is_nil(base)
      assert.are.equal("environment keys must be non-empty strings", err)
    end)

    it("accepts an empty environment object", function()
      local base, err = BasePreset.try_from_json({ name = "p", environment = {} })
      assert.is_nil(err)
      assert.is_not_nil(base)
      assert.are.same({}, base.environment)
    end)

    it("allows vim.NIL environment values", function()
      local base, err = BasePreset.try_from_json({ name = "p", environment = { FOO = vim.NIL } })
      assert.is_nil(err)
      assert.is_not_nil(base)
      assert.is_true(base.environment.FOO == vim.NIL)
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

    it("expands ${generator} to empty string for a base preset", function()
      local preset = BasePreset.new({ name = "my-preset" })
      local res = preset:expand_macros("/path/${generator}")
      assert.are.equal("/path/", res)
    end)

    it("expands ${generator} from the configure preset", function()
      local test_dir = vim.fn.tempname()
      vim.fn.mkdir(test_dir, "p")
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode({
        version = 1,
        configurePresets = {
          { name = "my-config", generator = "Ninja" },
        },
      }))
      file:close()

      local preset = ConfigurePreset.new({ name = "my-config" })
      local pf = PresetFile.try_from_file(vim.fs.joinpath(test_dir, "CMakePresets.json"))
      assert.is_not_nil(pf)
      ---@cast pf -nil
      local res = preset:expand_macros("/path/${generator}", pf)
      assert.are.equal("/path/Ninja", res)

      vim.fn.delete(test_dir, "rf")
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
