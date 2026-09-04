local PackagePreset = require("cmakeseer.cmake.preset.package_preset")

describe("cmakeseer.cmake.preset.PackagePreset", function()
  describe("try_from_json", function()
    it("returns nil when json is not a table", function()
      local preset, err = PackagePreset.try_from_json("not a table")
      assert.is_nil(preset)
      assert.are.equal("preset JSON must be an object", err)
    end)

    it("returns nil when name is missing or not a string", function()
      local preset1, err1 = PackagePreset.try_from_json({})
      assert.is_nil(preset1)
      assert.are.equal("Could not find name in preset", err1)

      local preset2, err2 = PackagePreset.try_from_json({ name = 123 })
      assert.is_nil(preset2)
      assert.are.equal("name must be a string", err2)
    end)

    it("succeeds with minimal valid json", function()
      local preset, err = PackagePreset.try_from_json({ name = "my-package" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.equal("my-package", preset.name)
      assert.is_nil(preset.hidden)
      assert.is_nil(preset.inherits)
    end)

    it("normalizes inherits string to an array", function()
      local preset, err = PackagePreset.try_from_json({ name = "p", inherits = "base" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "base" }, preset.inherits)
    end)

    it("accepts inherits array of strings", function()
      local preset, err = PackagePreset.try_from_json({ name = "p", inherits = { "b1", "b2" } })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "b1", "b2" }, preset.inherits)
    end)

    it("rejects invalid inherits", function()
      local preset1, err1 = PackagePreset.try_from_json({ name = "p", inherits = 123 })
      assert.is_nil(preset1)
      assert.are.equal("inherits must be a string or list of strings", err1)

      local preset2, err2 = PackagePreset.try_from_json({ name = "p", inherits = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("inherits object at index 1 should be a string", err2)
    end)

    it("validates generators and configurations", function()
      local preset1, err1 = PackagePreset.try_from_json({ name = "p", generators = "TGZ" })
      assert.is_nil(preset1)
      assert.are.equal("generators must be a list", err1)

      local preset2, err2 = PackagePreset.try_from_json({ name = "p", generators = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("generators at index 1 must be a string", err2)

      local preset3, err3 = PackagePreset.try_from_json({ name = "p", configurations = "Release" })
      assert.is_nil(preset3)
      assert.are.equal("configurations must be a list", err3)

      local preset4, err4 = PackagePreset.try_from_json({ name = "p", configurations = { 123 } })
      assert.is_nil(preset4)
      assert.are.equal("configurations at index 1 must be a string", err4)

      local preset5, err5 = PackagePreset.try_from_json({
        name = "p",
        generators = { "TGZ", "ZIP" },
        configurations = { "Release" },
      })
      assert.is_nil(err5)
      assert.are.same({ "TGZ", "ZIP" }, preset5.generators)
      assert.are.same({ "Release" }, preset5.configurations)
    end)

    it("validates variables", function()
      local preset1, err1 = PackagePreset.try_from_json({ name = "p", variables = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("variables must be an object", err1)

      local preset2, err2 = PackagePreset.try_from_json({ name = "p", variables = { VAR = 123 } })
      assert.is_nil(preset2)
      assert.are.equal("variables[VAR] must be a string", err2)

      local preset3, err3 = PackagePreset.try_from_json({ name = "p", variables = { CPACK_VAR = "val" } })
      assert.is_nil(err3)
      assert.are.same({ CPACK_VAR = "val" }, preset3.variables)
    end)

    it("validates configFile", function()
      local preset1, err1 = PackagePreset.try_from_json({ name = "p", configFile = 123 })
      assert.is_nil(preset1)
      assert.are.equal("configFile must be a string", err1)

      local preset2, err2 = PackagePreset.try_from_json({ name = "p", configFile = "CPackConfig.cmake" })
      assert.is_nil(err2)
      assert.are.equal("CPackConfig.cmake", preset2.config_file)
    end)

    it("validates output options", function()
      local preset1, err1 = PackagePreset.try_from_json({ name = "p", output = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("output must be an object", err1)

      local preset2, err2 = PackagePreset.try_from_json({ name = "p", output = { debug = "yes" } })
      assert.is_nil(preset2)
      assert.are.equal("output.debug must be a boolean", err2)

      local preset3, err3 = PackagePreset.try_from_json({ name = "p", output = { verbose = "yes" } })
      assert.is_nil(preset3)
      assert.are.equal("output.verbose must be a boolean", err3)

      local preset4, err4 = PackagePreset.try_from_json({ name = "p", output = { debug = true, verbose = false } })
      assert.is_nil(err4)
      assert.is_true(preset4.output.debug)
      assert.is_false(preset4.output.verbose)
    end)

    it("validates package metadata fields", function()
      local string_fields = {
        { json_key = "packageName", lua_key = "package_name" },
        { json_key = "packageVersion", lua_key = "package_version" },
        { json_key = "packageDirectory", lua_key = "package_directory" },
        { json_key = "vendorName", lua_key = "vendor_name" },
      }

      for _, f in ipairs(string_fields) do
        local invalid_json = { name = "p", [f.json_key] = 123 }
        local preset_inv, err = PackagePreset.try_from_json(invalid_json)
        assert.is_nil(preset_inv)
        assert.are.equal(f.json_key .. " must be a string", err)

        local valid_json = { name = "p", [f.json_key] = "test-val" }
        local preset_val, err_ok = PackagePreset.try_from_json(valid_json)
        assert.is_nil(err_ok)
        assert.are.equal("test-val", preset_val[f.lua_key])
      end
    end)
  end)
end)
