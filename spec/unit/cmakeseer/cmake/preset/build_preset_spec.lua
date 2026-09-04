local BuildPreset = require("cmakeseer.cmake.preset.build_preset")

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
end)
