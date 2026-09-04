local TestPreset = require("cmakeseer.cmake.preset.test_preset")

describe("cmakeseer.cmake.preset.TestPreset", function()
  describe("try_from_json", function()
    it("returns nil when json is not a table", function()
      local preset, err = TestPreset.try_from_json("not a table")
      assert.is_nil(preset)
      assert.are.equal("preset JSON must be an object", err)
    end)

    it("returns nil when name is missing or not a string", function()
      local preset1, err1 = TestPreset.try_from_json({})
      assert.is_nil(preset1)
      assert.are.equal("Could not find name in preset", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = 123 })
      assert.is_nil(preset2)
      assert.are.equal("name must be a string", err2)
    end)

    it("succeeds with minimal valid json", function()
      local preset, err = TestPreset.try_from_json({ name = "my-test" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.equal("my-test", preset.name)
      assert.is_nil(preset.hidden)
      assert.is_nil(preset.inherits)
    end)

    it("normalizes inherits string to an array", function()
      local preset, err = TestPreset.try_from_json({ name = "t", inherits = "base" })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "base" }, preset.inherits)
    end)

    it("accepts inherits array of strings", function()
      local preset, err = TestPreset.try_from_json({ name = "t", inherits = { "b1", "b2" } })
      assert.is_nil(err)
      assert.is_not_nil(preset)
      assert.are.same({ "b1", "b2" }, preset.inherits)
    end)

    it("rejects invalid inherits", function()
      local preset1, err1 = TestPreset.try_from_json({ name = "t", inherits = 123 })
      assert.is_nil(preset1)
      assert.are.equal("inherits must be a string or list of strings", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = "t", inherits = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("inherits object at index 1 should be a string", err2)
    end)

    it("validates configuration and overwriteConfigurationFile", function()
      local preset1, err1 = TestPreset.try_from_json({ name = "t", configuration = 123 })
      assert.is_nil(preset1)
      assert.are.equal("configuration must be a string", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = "t", overwriteConfigurationFile = "not a table" })
      assert.is_nil(preset2)
      assert.are.equal("overwriteConfigurationFile must be a list", err2)

      local preset3, err3 = TestPreset.try_from_json({ name = "t", overwriteConfigurationFile = { 123 } })
      assert.is_nil(preset3)
      assert.are.equal("overwriteConfigurationFile at index 1 must be a string", err3)

      local preset4, err4 = TestPreset.try_from_json({
        name = "t",
        configuration = "Release",
        overwriteConfigurationFile = { "Option=Value" },
      })
      assert.is_nil(err4)
      assert.are.equal("Release", preset4.configuration)
      assert.are.same({ "Option=Value" }, preset4.overwrite_configuration_file)
    end)

    it("validates output options", function()
      local preset1, err1 = TestPreset.try_from_json({ name = "t", output = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("output must be an object", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = "t", output = { verbosity = "invalid" } })
      assert.is_nil(preset2)
      assert.are.equal("output.verbosity must be 'default', 'verbose', or 'extra'", err2)

      local preset3, err3 = TestPreset.try_from_json({ name = "t", output = { testOutputTruncation = "invalid" } })
      assert.is_nil(preset3)
      assert.are.equal("output.testOutputTruncation must be 'tail', 'middle', or 'head'", err3)

      local preset4, err4 = TestPreset.try_from_json({ name = "t", output = { shortProgress = 123 } })
      assert.is_nil(preset4)
      assert.are.equal("output.shortProgress must be a boolean", err4)

      local preset5, err5 = TestPreset.try_from_json({ name = "t", output = { maxPassedTestOutputSize = "huge" } })
      assert.is_nil(preset5)
      assert.are.equal("output.maxPassedTestOutputSize must be a number", err5)

      local valid_output = {
        shortProgress = true,
        verbosity = "verbose",
        debug = true,
        outputOnFailure = true,
        quiet = false,
        outputLogFile = "ctest.log",
        outputJUnitFile = "results.xml",
        labelSummary = true,
        subprojectSummary = false,
        maxPassedTestOutputSize = 1024,
        maxFailedTestOutputSize = 2048,
        testOutputTruncation = "middle",
        maxTestNameWidth = 40,
      }
      local preset6, err6 = TestPreset.try_from_json({ name = "t", output = valid_output })
      assert.is_nil(err6)
      assert.is_true(preset6.output.short_progress)
      assert.are.equal("verbose", preset6.output.verbosity)
      assert.are.equal("middle", preset6.output.test_output_truncation)
      assert.are.equal(1024, preset6.output.max_passed_test_output_size)
    end)

    it("validates filter options", function()
      local preset1, err1 = TestPreset.try_from_json({ name = "t", filter = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("filter must be an object", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = "t", filter = { include = "not a table" } })
      assert.is_nil(preset2)
      assert.are.equal("filter.include must be an object", err2)

      local preset3, err3 = TestPreset.try_from_json({ name = "t", filter = { include = { name = 123 } } })
      assert.is_nil(preset3)
      assert.are.equal("filter.include.name must be a string", err3)

      local preset4, err4 = TestPreset.try_from_json({ name = "t", filter = { include = { index = { specificTests = "all" } } } })
      assert.is_nil(preset4)
      assert.are.equal("filter.include.index.specificTests must be a list", err4)

      local preset5, err5 = TestPreset.try_from_json({ name = "t", filter = { exclude = { fixtures = { any = 123 } } } })
      assert.is_nil(preset5)
      assert.are.equal("filter.exclude.fixtures.any must be a string", err5)

      local valid_filter = {
        include = {
          name = "test_.*",
          label = "unit",
          useUnion = true,
          index = { start = 1, ["end"] = 10, stride = 2, specificTests = { 1, 3, 5 } },
        },
        exclude = {
          name = "slow_.*",
          fixtures = { any = "db_fixture" },
        },
      }
      local preset6, err6 = TestPreset.try_from_json({ name = "t", filter = valid_filter })
      assert.is_nil(err6)
      assert.are.equal("test_.*", preset6.filter.include.name)
      assert.is_true(preset6.filter.include.use_union)
      assert.are.equal(10, preset6.filter.include.index["end"])
      assert.are.same({ 1, 3, 5 }, preset6.filter.include.index.specific_tests)
      assert.are.equal("db_fixture", preset6.filter.exclude.fixtures.any)
    end)

    it("validates execution options", function()
      local preset1, err1 = TestPreset.try_from_json({ name = "t", execution = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("execution must be an object", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = "t", execution = { showOnly = "invalid" } })
      assert.is_nil(preset2)
      assert.are.equal("execution.showOnly must be 'human' or 'json-v1'", err2)

      local preset3, err3 = TestPreset.try_from_json({ name = "t", execution = { ["repeat"] = "not a table" } })
      assert.is_nil(preset3)
      assert.are.equal("execution.repeat must be an object", err3)

      local preset4, err4 = TestPreset.try_from_json({ name = "t", execution = { ["repeat"] = { mode = "invalid", count = 3 } } })
      assert.is_nil(preset4)
      assert.are.equal("execution.repeat.mode must be 'until-fail', 'until-pass', or 'after-timeout'", err4)

      local preset5, err5 = TestPreset.try_from_json({ name = "t", execution = { ["repeat"] = { mode = "until-fail", count = "three" } } })
      assert.is_nil(preset5)
      assert.are.equal("execution.repeat.count must be a number", err5)

      local preset6, err6 = TestPreset.try_from_json({ name = "t", execution = { noTestsAction = "invalid" } })
      assert.is_nil(preset6)
      assert.are.equal("execution.noTestsAction must be 'default', 'error', or 'ignore'", err6)

      local valid_exec = {
        stopOnFailure = true,
        enableFailover = false,
        jobs = 4,
        resourceSpecFile = "/path/to/spec",
        testLoad = 2,
        showOnly = "human",
        ["repeat"] = { mode = "until-pass", count = 5 },
        interactiveDebugging = true,
        scheduleRandom = false,
        timeout = 60,
        noTestsAction = "error",
      }
      local preset7, err7 = TestPreset.try_from_json({ name = "t", execution = valid_exec })
      assert.is_nil(err7)
      assert.is_true(preset7.execution.stop_on_failure)
      assert.are.equal(4, preset7.execution.jobs)
      assert.are.equal("until-pass", preset7.execution["repeat"].mode)
      assert.are.equal(5, preset7.execution["repeat"].count)
      assert.are.equal("error", preset7.execution.no_tests_action)
    end)

    it("validates testPassthroughArguments", function()
      local preset1, err1 = TestPreset.try_from_json({ name = "t", testPassthroughArguments = "not a table" })
      assert.is_nil(preset1)
      assert.are.equal("testPassthroughArguments must be a list", err1)

      local preset2, err2 = TestPreset.try_from_json({ name = "t", testPassthroughArguments = { 123 } })
      assert.is_nil(preset2)
      assert.are.equal("testPassthroughArguments at index 1 must be a string", err2)

      local preset3, err3 = TestPreset.try_from_json({ name = "t", testPassthroughArguments = { "--gtest_filter=A.*" } })
      assert.is_nil(err3)
      assert.are.same({ "--gtest_filter=A.*" }, preset3.test_passthrough_arguments)
    end)
  end)
end)
