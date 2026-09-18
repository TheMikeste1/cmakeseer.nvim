local BuildPreset = require("cmakeseer.cmake.preset.build_preset")
local PresetFile = require("cmakeseer.cmake.preset.preset_file")
local CMakeSeer = require("cmakeseer")
local stub = require("luassert.stub")

describe("cmakeseer.cmake.preset.BuildPreset", function()
  describe("try_from_json", function()
    it("returns nil when json is not a table", function()
      local preset, err = BuildPreset.try_from_json("not a table")
      assert.is_nil(preset)
      assert.are.equal("preset JSON must be an object", err)
    end)

    it("returns nil when name is missing or not a string", function()
      local preset1, err1 = BuildPreset.try_from_json({})
      assert.is_nil(preset1)
      assert.are.equal("Could not find name in preset", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = 123 })
      assert.is_nil(preset2)
      assert.are.equal("name must be a string", err2)
    end)

    it("succeeds with minimal valid json", function()
      local preset, err = BuildPreset.try_from_json({ name = "my-build" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.equal("my-build", preset.name)
      assert.is_nil(preset.hidden)
      assert.is_nil(preset.inherits)
    end)

    it("normalizes inherits string to an array", function()
      local preset, err = BuildPreset.try_from_json({ name = "b", inherits = "base" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "base" }, preset.inherits)
    end)

    it("accepts inherits array of strings", function()
      local preset, err = BuildPreset.try_from_json({ name = "b", inherits = { "base1", "base2" } })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "base1", "base2" }, preset.inherits)
    end)

    it("rejects invalid inherits", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", inherits = 123 })
      assert.is_nil(preset1)
      assert.are.equal("inherits must be a string or list of strings", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", inherits = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("inherits object at index 1 should be a string", err2)
    end)

    it("validates configurePreset and inheritConfigureEnvironment", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", configurePreset = 123 })
      assert.is_nil(preset1)
      assert.are.equal("configurePreset must be a string", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", inheritConfigureEnvironment = "yes" })
      assert.is_nil(preset2)
      assert.are.equal("inheritConfigureEnvironment must be a boolean", err2)

      local preset3, err3 = BuildPreset.try_from_json({
        name = "b",
        configurePreset = "default",
        inheritConfigureEnvironment = false,
      })
      assert.is_nil(err3)
      assert.are.equal("default", preset3.configure_preset)
      assert.is_false(preset3.inherit_configure_environment)
    end)

    it("validates jobs", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", jobs = "four" })
      assert.is_nil(preset1)
      assert.are.equal("jobs must be a number", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", jobs = 8 })
      assert.is_nil(err2)
      assert.are.equal(8, preset2.jobs)
    end)

    it("validates targets", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", targets = 123 })
      assert.is_nil(preset1)
      assert.are.equal("targets must be a string or list of strings", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", targets = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("targets at index 1 must be a string", err2)

      local preset3, err3 = BuildPreset.try_from_json({ name = "b", targets = "all" })
      assert.is_nil(err3)
      assert.are.equal("all", preset3.targets)

      local preset4, err4 = BuildPreset.try_from_json({ name = "b", targets = { "app", "tests" } })
      assert.is_nil(err4)
      assert.are.same({ "app", "tests" }, preset4.targets)
    end)

    it("validates configuration", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", configuration = 123 })
      assert.is_nil(preset1)
      assert.are.equal("configuration must be a string", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", configuration = "Debug" })
      assert.is_nil(err2)
      assert.are.equal("Debug", preset2.configuration)
    end)

    it("validates cleanFirst", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", cleanFirst = "yes" })
      assert.is_nil(preset1)
      assert.are.equal("cleanFirst must be a boolean", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", cleanFirst = true })
      assert.is_nil(err2)
      assert.is_true(preset2.clean_first)
    end)

    it("validates resolvePackageReferences", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", resolvePackageReferences = "invalid" })
      assert.is_nil(preset1)
      assert.are.equal("resolvePackageReferences must be 'on', 'off', or 'only'", err1)

      for _, valid_val in ipairs({ "on", "off", "only" }) do
        local preset, err = BuildPreset.try_from_json({ name = "b", resolvePackageReferences = valid_val })
        assert.is_nil(err)
        assert.are.equal(valid_val, preset.resolve_package_references)
      end
    end)

    it("validates verbose", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", verbose = "yes" })
      assert.is_nil(preset1)
      assert.are.equal("verbose must be a boolean", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", verbose = true })
      assert.is_nil(err2)
      assert.is_true(preset2.verbose)
    end)

    it("validates nativeToolOptions", function()
      local preset1, err1 = BuildPreset.try_from_json({ name = "b", nativeToolOptions = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("nativeToolOptions must be a list", err1)

      local preset2, err2 = BuildPreset.try_from_json({ name = "b", nativeToolOptions = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("nativeToolOptions at index 1 must be a string", err2)

      local preset3, err3 = BuildPreset.try_from_json({ name = "b", nativeToolOptions = { "-j", "4" } })
      assert.is_nil(err3)
      assert.are.same({ "-j", "4" }, preset3.native_tool_options)
    end)
  end)

  describe("expanded", function()
    local get_config_stub
    local test_dir

    before_each(function()
      test_dir = vim.fn.tempname()
      vim.fn.mkdir(test_dir, "p")
      get_config_stub = stub(CMakeSeer, "get_config", {
        get_project_root = function()
          return "/my/project"
        end,
      })
    end)

    after_each(function()
      get_config_stub:revert()
      vim.fn.delete(test_dir, "rf")
    end)

    it("expands string targets", function()
      local preset = BuildPreset.new({ name = "my-build", targets = "${sourceDir}/app" })
      local expanded = preset:expanded()
      assert.are.equal("/my/project/app", expanded.targets)
    end)

    it("expands array targets", function()
      local preset = BuildPreset.new({ name = "my-build", targets = { "${sourceDir}/app", "${sourceDir}/tests" } })
      local expanded = preset:expanded()
      assert.are.same({ "/my/project/app", "/my/project/tests" }, expanded.targets)
    end)

    it("expands native_tool_options", function()
      local preset = BuildPreset.new({
        name = "my-build",
        native_tool_options = { "-j", "${sourceDir}/opt" },
      })
      local expanded = preset:expanded()
      assert.are.same({ "-j", "/my/project/opt" }, expanded.native_tool_options)
    end)

    it("expands environment values", function()
      local preset = BuildPreset.new({ name = "my-build", environment = { A = "${sourceDir}" } })
      local expanded = preset:expanded()
      assert.are.equal("/my/project", expanded.environment.A)
    end)

    it("expands ${generator} from the associated configure preset", function()
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode({
        version = 1,
        configurePresets = {
          { name = "my-config", generator = "Ninja" },
        },
        buildPresets = {
          { name = "my-build", configurePreset = "my-config" },
        },
      }))
      file:close()

      local preset = BuildPreset.new({
        name = "my-build",
        configure_preset = "my-config",
        environment = { A = "${generator}" },
      })
      local pf = PresetFile.try_from_file(vim.fs.joinpath(test_dir, "CMakePresets.json"))
      assert.is_not_nil(pf)
      ---@cast pf -nil
      local expanded = preset:expanded(pf)
      assert.are.equal("Ninja", expanded.environment.A)
    end)

    it("preserves non-expandable fields", function()
      local preset = BuildPreset.new({
        name = "my-build",
        configure_preset = "my-config",
        inherit_configure_environment = false,
        jobs = 8,
        configuration = "Release",
        clean_first = true,
        resolve_package_references = "on",
        verbose = true,
      })
      local expanded = preset:expanded()
      assert.are.equal("my-config", expanded.configure_preset)
      assert.is_false(expanded.inherit_configure_environment)
      assert.are.equal(8, expanded.jobs)
      assert.are.equal("Release", expanded.configuration)
      assert.is_true(expanded.clean_first)
      assert.are.equal("on", expanded.resolve_package_references)
      assert.is_true(expanded.verbose)
    end)

    it("returns nil for nil optional fields", function()
      local preset = BuildPreset.new({ name = "my-build" })
      local expanded = preset:expanded()
      assert.is_nil(expanded.targets)
      assert.is_nil(expanded.native_tool_options)
      assert.is_nil(expanded.environment)
    end)

    it("handles empty arrays", function()
      local preset = BuildPreset.new({ name = "my-build", targets = {}, native_tool_options = {} })
      local expanded = preset:expanded()
      assert.are.same({}, expanded.targets)
      assert.are.same({}, expanded.native_tool_options)
    end)

    it("does not mutate the original", function()
      local preset = BuildPreset.new({ name = "my-build", targets = { "${sourceDir}/app" } })
      local expanded = preset:expanded()
      assert.are.same({ "/my/project/app" }, expanded.targets)
      assert.are.same({ "${sourceDir}/app" }, preset.targets)
    end)
  end)
end)
