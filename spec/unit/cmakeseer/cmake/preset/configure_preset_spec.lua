local ConfigurePreset = require("cmakeseer.cmake.preset.configure_preset")

describe("cmakeseer.cmake.preset.ConfigurePreset", function()
  describe("try_from_json", function()
    it("returns nil when json is not a table", function()
      local preset, err = ConfigurePreset.try_from_json("not a table")
      assert.is_nil(preset)
      assert.are.equal("preset JSON must be an object", err)
    end)

    it("returns nil when name is missing or not a string", function()
      local preset1, err1 = ConfigurePreset.try_from_json({})
      assert.is_nil(preset1)
      assert.are.equal("Could not find name in preset", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = 123 })
      assert.is_nil(preset2)
      assert.are.equal("name must be a string", err2)
    end)

    it("succeeds with minimal valid json", function()
      local preset, err = ConfigurePreset.try_from_json({ name = "my-preset" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.equal("my-preset", preset.name)
      assert.is_nil(preset.hidden)
      assert.is_nil(preset.inherits)
    end)

    it("validates hidden", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", hidden = "true" })
      assert.is_nil(preset1)
      assert.are.equal("hidden must be a boolean", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", hidden = true })
      assert.is_nil(err2)
      assert.is_true(preset2.hidden)
    end)

    it("normalizes inherits string to an array", function()
      local preset, err = ConfigurePreset.try_from_json({ name = "p", inherits = "base" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "base" }, preset.inherits)
    end)

    it("accepts inherits array of strings", function()
      local preset, err = ConfigurePreset.try_from_json({ name = "p", inherits = { "base1", "base2" } })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "base1", "base2" }, preset.inherits)
    end)

    it("rejects invalid inherits", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", inherits = 123 })
      assert.is_nil(preset1)
      assert.are.equal("inherits must be a string or list of strings", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", inherits = { "ok", 123 } })
      assert.is_nil(preset2)
      assert.are.equal("inherits object at index 2 should be a string", err2)
    end)

    it("validates condition", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", condition = "invalid" })
      assert.is_nil(preset1)
      assert.are.equal("condition must be a boolean or object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", condition = {} })
      assert.is_nil(preset2)
      assert.are.equal("condition.type must be a string", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", condition = true })
      assert.is_nil(err3)
      assert.is_true(preset3.condition)

      local preset4, err4 = ConfigurePreset.try_from_json({ name = "p", condition = { type = "const", value = false } })
      assert.is_nil(err4)
      assert.are.same({ type = "const", value = false }, preset4.condition)
    end)

    it("validates vendor", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", vendor = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("vendor must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", vendor = { ide = { setting = 1 } } })
      assert.is_nil(err2)
      assert.are.same({ ide = { setting = 1 } }, preset2.vendor)
    end)

    it("validates display_name and description", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", displayName = 123 })
      assert.is_nil(preset1)
      assert.are.equal("displayName must be a string", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", description = 123 })
      assert.is_nil(preset2)
      assert.are.equal("description must be a string", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", displayName = "My Preset", description = "Desc" })
      assert.is_nil(err3)
      assert.are.equal("My Preset", preset3.display_name)
      assert.are.equal("Desc", preset3.description)
    end)

    it("validates generator", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", generator = 123 })
      assert.is_nil(preset1)
      assert.are.equal("generator must be a string", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", generator = "Ninja" })
      assert.is_nil(err2)
      assert.are.equal("Ninja", preset2.generator)
    end)

    it("validates architecture", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", architecture = 123 })
      assert.is_nil(preset1)
      assert.are.equal("architecture must be a string or object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", architecture = { value = 123 } })
      assert.is_nil(preset2)
      assert.are.equal("architecture.value must be a string", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", architecture = { strategy = "invalid" } })
      assert.is_nil(preset3)
      assert.are.equal("architecture.strategy must be 'set' or 'external'", err3)

      local preset4, err4 = ConfigurePreset.try_from_json({ name = "p", architecture = { value = "x64", strategy = "set" } })
      assert.is_nil(err4)
      assert.are.same({ value = "x64", strategy = "set" }, preset4.architecture)

      local preset5, err5 = ConfigurePreset.try_from_json({ name = "p", architecture = "x64" })
      assert.is_nil(err5)
      assert.are.equal("x64", preset5.architecture)
    end)

    it("validates toolset", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", toolset = 123 })
      assert.is_nil(preset1)
      assert.are.equal("toolset must be a string or object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", toolset = { value = 123 } })
      assert.is_nil(preset2)
      assert.are.equal("toolset.value must be a string", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", toolset = { strategy = "invalid" } })
      assert.is_nil(preset3)
      assert.are.equal("toolset.strategy must be 'set' or 'external'", err3)

      local preset4, err4 = ConfigurePreset.try_from_json({ name = "p", toolset = { value = "v143", strategy = "external" } })
      assert.is_nil(err4)
      assert.are.same({ value = "v143", strategy = "external" }, preset4.toolset)
    end)

    it("validates string path fields", function()
      local fields = {
        { json_key = "toolchainFile", lua_key = "toolchain_file" },
        { json_key = "graphviz", lua_key = "graphviz" },
        { json_key = "binaryDir", lua_key = "binary_dir" },
        { json_key = "installDir", lua_key = "install_dir" },
        { json_key = "cmakeExecutable", lua_key = "cmake_executable" },
      }

      for _, f in ipairs(fields) do
        local invalid_json = { name = "p", [f.json_key] = 123 }
        local preset_inv, err = ConfigurePreset.try_from_json(invalid_json)
        assert.is_nil(preset_inv)
        assert.are.equal(f.json_key .. " must be a string", err)

        local valid_json = { name = "p", [f.json_key] = "/path/to/val" }
        local preset_val, err_ok = ConfigurePreset.try_from_json(valid_json)
        assert.is_nil(err_ok)
        assert.are.equal("/path/to/val", preset_val[f.lua_key])
      end
    end)

    it("validates cacheVariables", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", cacheVariables = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("cacheVariables must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", cacheVariables = { VAR = 123 } })
      assert.is_nil(preset2)
      assert.are.equal("cacheVariables[VAR] must be null, a boolean, string, or object", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", cacheVariables = { VAR = {} } })
      assert.is_nil(preset3)
      assert.are.equal("cacheVariables[VAR].value must be a string or boolean", err3)

      local preset4, err4 = ConfigurePreset.try_from_json({ name = "p", cacheVariables = { VAR = { value = "1", type = 123 } } })
      assert.is_nil(preset4)
      assert.are.equal("cacheVariables[VAR].type must be a string", err4)

      local valid_cache = {
        BOOL_VAR = true,
        STR_VAR = "hello",
        TYPED_VAR = { type = "FILEPATH", value = "/path" },
      }
      local preset5, err5 = ConfigurePreset.try_from_json({ name = "p", cacheVariables = valid_cache })
      assert.is_nil(err5)
      assert.are.same(valid_cache, preset5.cache_variables)
    end)

    it("validates environment", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", environment = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("environment must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", environment = { FOO = 123 } })
      assert.is_nil(preset2)
      assert.are.equal("environment[FOO] must be a string or null", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", environment = { FOO = "bar" } })
      assert.is_nil(err3)
      assert.are.same({ FOO = "bar" }, preset3.environment)
    end)

    it("validates warnings", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", warnings = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("warnings must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", warnings = { dev = 123 } })
      assert.is_nil(preset2)
      assert.are.equal("warnings.dev must be a boolean", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({
        name = "p",
        warnings = { dev = true, deprecated = false, unusedCli = true },
      })
      assert.is_nil(err3)
      assert.is_true(preset3.warnings.dev)
      assert.is_false(preset3.warnings.deprecated)
      assert.is_true(preset3.warnings.unused_cli)
    end)

    it("validates errors", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", errors = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("errors must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", errors = { dev = "yes" } })
      assert.is_nil(preset2)
      assert.are.equal("errors.dev must be a boolean", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({
        name = "p",
        errors = { dev = true, policy = false },
      })
      assert.is_nil(err3)
      assert.is_true(preset3.errors.dev)
      assert.is_false(preset3.errors.policy)
    end)

    it("validates debug", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", debug = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("debug must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", debug = { output = "yes" } })
      assert.is_nil(preset2)
      assert.are.equal("debug.output must be a boolean", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({
        name = "p",
        debug = { output = true, tryCompile = true, find = false },
      })
      assert.is_nil(err3)
      assert.is_true(preset3.debug.output)
      assert.is_true(preset3.debug.try_compile)
      assert.is_false(preset3.debug.find)
    end)

    it("validates trace", function()
      local preset1, err1 = ConfigurePreset.try_from_json({ name = "p", trace = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("trace must be an object", err1)

      local preset2, err2 = ConfigurePreset.try_from_json({ name = "p", trace = { mode = "invalid" } })
      assert.is_nil(preset2)
      assert.are.equal("trace.mode must be 'on', 'off', or 'expand'", err2)

      local preset3, err3 = ConfigurePreset.try_from_json({ name = "p", trace = { format = "invalid" } })
      assert.is_nil(preset3)
      assert.are.equal("trace.format must be 'human' or 'json-v1'", err3)

      local preset4, err4 = ConfigurePreset.try_from_json({ name = "p", trace = { source = 123 } })
      assert.is_nil(preset4)
      assert.are.equal("trace.source must be a string or list of strings", err4)

      local preset5, err5 = ConfigurePreset.try_from_json({ name = "p", trace = { source = { 123 } } })
      assert.is_nil(preset5)
      assert.are.equal("trace.source at index 1 must be a string", err5)

      local preset6, err6 = ConfigurePreset.try_from_json({ name = "p", trace = { redirect = 123 } })
      assert.is_nil(preset6)
      assert.are.equal("trace.redirect must be a string", err6)

      local preset7, err7 = ConfigurePreset.try_from_json({
        name = "p",
        trace = { mode = "on", format = "human", source = "src.cmake", redirect = "trace.log" },
      })
      assert.is_nil(err7)
      assert.are.equal("on", preset7.trace.mode)
      assert.are.equal("human", preset7.trace.format)
      assert.are.equal("src.cmake", preset7.trace.source)
      assert.are.equal("trace.log", preset7.trace.redirect)
    end)
  end)
end)
