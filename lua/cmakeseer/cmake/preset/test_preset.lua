--- A container for CMake's test preset. See <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#test-preset>.
---@class cmakeseer.cmake.preset.TestPreset
local TestPreset = {}
TestPreset.__index = TestPreset

---@class cmakeseer.cmake.preset.TestPreset.Output
---@field short_progress? boolean Whether to output test results in a compact format.
---@field verbosity? "default"|"verbose"|"extra" Verbosity level.
---@field debug? boolean Whether to pass debug output.
---@field output_on_failure? boolean Whether to output anything outputted by the test program if the test should fail.
---@field quiet? boolean Whether to run CTest in quiet mode.
---@field output_log_file? string Path to a log file.
---@field output_junit_file? string Path to a JUnit XML file for test results.
---@field label_summary? boolean Whether to print a summary of results for each label.
---@field subproject_summary? boolean Whether to print a summary of results for each subproject.
---@field max_passed_test_output_size? integer Maximum output size in bytes for passed tests.
---@field max_failed_test_output_size? integer Maximum output size in bytes for failed tests.
---@field test_output_truncation? "tail"|"middle"|"head" Test output truncation mode.
---@field max_test_name_width? integer Maximum width of a test name to output in characters.

---@class cmakeseer.cmake.preset.TestPreset.Filter.Index
---@field start? integer Test index at which to start testing.
---@field end? integer Test index at which to stop testing.
---@field stride? integer Increment for test indices.
---@field specific_tests? integer[] Specific test indices to run.

---@class cmakeseer.cmake.preset.TestPreset.Filter.Fixtures
---@field any? string Regex for any fixture to exclude.
---@field setup? string Regex for setup fixture to exclude.
---@field cleanup? string Regex for cleanup fixture to exclude.

---@class cmakeseer.cmake.preset.TestPreset.Filter.Include
---@field name? string Regex for test names to include.
---@field label? string Regex for test labels to include.
---@field use_union? boolean Whether to treat name and label filters as a union instead of intersection.
---@field index? cmakeseer.cmake.preset.TestPreset.Filter.Index Tests to include by test index.

---@class cmakeseer.cmake.preset.TestPreset.Filter.Exclude
---@field name? string Regex for test names to exclude.
---@field label? string Regex for test labels to exclude.
---@field fixtures? cmakeseer.cmake.preset.TestPreset.Filter.Fixtures Fixtures to exclude.

---@class cmakeseer.cmake.preset.TestPreset.Filter
---@field include? cmakeseer.cmake.preset.TestPreset.Filter.Include Tests to include.
---@field exclude? cmakeseer.cmake.preset.TestPreset.Filter.Exclude Tests to exclude.

---@class cmakeseer.cmake.preset.TestPreset.Execution.Repeat
---@field mode "until-fail"|"until-pass"|"after-timeout" Repeat mode.
---@field count integer Number of times to repeat.

---@class cmakeseer.cmake.preset.TestPreset.Execution
---@field stop_on_failure? boolean Whether to stop running tests after the first failure.
---@field enable_failover? boolean Whether to enable failover.
---@field jobs? integer Number of jobs to run concurrently.
---@field resource_spec_file? string Path to a resource specification file.
---@field test_load? integer Maximum CPU load when scheduling test jobs.
---@field show_only? "human"|"json-v1" Show tests without running them.
---@field repeat? cmakeseer.cmake.preset.TestPreset.Execution.Repeat How to repeat tests.
---@field interactive_debugging? boolean Whether to enable interactive debugging.
---@field schedule_random? boolean Whether to schedule tests in a random order.
---@field timeout? integer Test timeout in seconds.
---@field no_tests_action? "default"|"error"|"ignore" Behavior if no tests are found.

---@class cmakeseer.cmake.preset.TestPreset
---@field name string Machine-friendly name of the preset.
---@field hidden? boolean Whether the preset is hidden.
---@field inherits? string[] Presets from which to inherit. The first preset to set a value takes precedence.
---@field condition? boolean|cmakeseer.cmake.preset.ConfigurePreset.Condition Condition determining whether preset is enabled.
---@field vendor? table<string, any> Vendor-specific information.
---@field display_name? string Human-friendly name of the preset.
---@field description? string Human-friendly description of the preset.
---@field environment? table<string, string|nil> Environment variables to set.
---@field configure_preset? string The name of a configure preset to associate with this test preset.
---@field inherit_configure_environment? boolean Whether to inherit the environment from the configure preset.
---@field configuration? string Build configuration to test.
---@field overwrite_configuration_file? string[] Configuration options to overwrite CTest configuration options.
---@field output? cmakeseer.cmake.preset.TestPreset.Output Output options.
---@field filter? cmakeseer.cmake.preset.TestPreset.Filter Test filters.
---@field execution? cmakeseer.cmake.preset.TestPreset.Execution Test execution options.
---@field test_passthrough_arguments? string[] Arguments forwarded to every test executable.
local _TestPresetDefaults = {}

--- Creates a new TestPreset instance.
---@param o cmakeseer.cmake.preset.TestPreset Initial values.
---@return cmakeseer.cmake.preset.TestPreset obj The new instance.
function TestPreset.new(o)
  local self = setmetatable(vim.deepcopy(o), TestPreset)
  for k, v in pairs(_TestPresetDefaults) do
    if self[k] == nil then
      if type(v) == "table" then
        self[k] = vim.deepcopy(v)
      else
        self[k] = v
      end
    end
  end
  return self
end

--- Creates a new TestPreset instance from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return cmakeseer.cmake.preset.TestPreset? obj, string? error_msg The new instance, if one was successfully created.
function TestPreset.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "preset JSON must be an object"
  end

  local name = json["name"]
  if name == nil then
    return nil, "Could not find name in preset"
  end
  if type(name) ~= "string" then
    return nil, "name must be a string"
  end

  local hidden = json["hidden"]
  if hidden ~= nil and type(hidden) ~= "boolean" then
    return nil, "hidden must be a boolean"
  end

  local inherits = json["inherits"]
  if inherits ~= nil then
    if type(inherits) ~= "table" then
      if type(inherits) == "string" then
        inherits = { inherits }
      else
        return nil, "inherits must be a string or list of strings"
      end
    end

    for i, x in ipairs(inherits) do
      if type(x) ~= "string" then
        return nil, ("inherits object at index %d should be a string"):format(i)
      end
    end
  end

  local condition = json["condition"]
  if condition ~= nil and condition ~= vim.NIL then
    if type(condition) ~= "boolean" and type(condition) ~= "table" then
      return nil, "condition must be a boolean or object"
    end
    if type(condition) == "table" then
      if condition.type == nil or type(condition.type) ~= "string" then
        return nil, "condition.type must be a string"
      end
    end
  else
    condition = nil
  end

  local vendor = json["vendor"]
  if vendor ~= nil and type(vendor) ~= "table" then
    return nil, "vendor must be an object"
  end

  local display_name = json["displayName"]
  if display_name ~= nil and type(display_name) ~= "string" then
    return nil, "displayName must be a string"
  end

  local description = json["description"]
  if description ~= nil and type(description) ~= "string" then
    return nil, "description must be a string"
  end

  local environment = json["environment"]
  if environment ~= nil then
    if type(environment) ~= "table" then
      return nil, "environment must be an object"
    end
    for k, v in pairs(environment) do
      if type(k) ~= "string" or k == "" then
        return nil, "environment keys must be non-empty strings"
      end
      if v ~= nil and v ~= vim.NIL and type(v) ~= "string" then
        return nil, ("environment[%s] must be a string or null"):format(k)
      end
    end
  end

  local configure_preset = json["configurePreset"]
  if configure_preset ~= nil and type(configure_preset) ~= "string" then
    return nil, "configurePreset must be a string"
  end

  local inherit_configure_environment = json["inheritConfigureEnvironment"]
  if inherit_configure_environment ~= nil and type(inherit_configure_environment) ~= "boolean" then
    return nil, "inheritConfigureEnvironment must be a boolean"
  end

  local configuration = json["configuration"]
  if configuration ~= nil and type(configuration) ~= "string" then
    return nil, "configuration must be a string"
  end

  local overwrite_configuration_file = json["overwriteConfigurationFile"]
  if overwrite_configuration_file ~= nil then
    if type(overwrite_configuration_file) ~= "table" then
      return nil, "overwriteConfigurationFile must be a list"
    end
    for i, opt in ipairs(overwrite_configuration_file) do
      if type(opt) ~= "string" then
        return nil, ("overwriteConfigurationFile at index %d must be a string"):format(i)
      end
    end
  end

  local output = nil
  if json["output"] ~= nil then
    if type(json["output"]) ~= "table" then
      return nil, "output must be an object"
    end
    local out = json["output"]
    if out.shortProgress ~= nil and type(out.shortProgress) ~= "boolean" then
      return nil, "output.shortProgress must be a boolean"
    end
    if out.verbosity ~= nil and out.verbosity ~= "default" and out.verbosity ~= "verbose" and out.verbosity ~= "extra" then
      return nil, "output.verbosity must be 'default', 'verbose', or 'extra'"
    end
    if out.debug ~= nil and type(out.debug) ~= "boolean" then
      return nil, "output.debug must be a boolean"
    end
    if out.outputOnFailure ~= nil and type(out.outputOnFailure) ~= "boolean" then
      return nil, "output.outputOnFailure must be a boolean"
    end
    if out.quiet ~= nil and type(out.quiet) ~= "boolean" then
      return nil, "output.quiet must be a boolean"
    end
    if out.outputLogFile ~= nil and type(out.outputLogFile) ~= "string" then
      return nil, "output.outputLogFile must be a string"
    end
    if out.outputJUnitFile ~= nil and type(out.outputJUnitFile) ~= "string" then
      return nil, "output.outputJUnitFile must be a string"
    end
    if out.labelSummary ~= nil and type(out.labelSummary) ~= "boolean" then
      return nil, "output.labelSummary must be a boolean"
    end
    if out.subprojectSummary ~= nil and type(out.subprojectSummary) ~= "boolean" then
      return nil, "output.subprojectSummary must be a boolean"
    end
    if out.maxPassedTestOutputSize ~= nil and type(out.maxPassedTestOutputSize) ~= "number" then
      return nil, "output.maxPassedTestOutputSize must be a number"
    end
    if out.maxFailedTestOutputSize ~= nil and type(out.maxFailedTestOutputSize) ~= "number" then
      return nil, "output.maxFailedTestOutputSize must be a number"
    end
    if out.testOutputTruncation ~= nil and out.testOutputTruncation ~= "tail" and out.testOutputTruncation ~= "middle" and out.testOutputTruncation ~= "head" then
      return nil, "output.testOutputTruncation must be 'tail', 'middle', or 'head'"
    end
    if out.maxTestNameWidth ~= nil and type(out.maxTestNameWidth) ~= "number" then
      return nil, "output.maxTestNameWidth must be a number"
    end
    output = {
      short_progress = out.shortProgress,
      verbosity = out.verbosity,
      debug = out.debug,
      output_on_failure = out.outputOnFailure,
      quiet = out.quiet,
      output_log_file = out.outputLogFile,
      output_junit_file = out.outputJUnitFile,
      label_summary = out.labelSummary,
      subproject_summary = out.subprojectSummary,
      max_passed_test_output_size = out.maxPassedTestOutputSize,
      max_failed_test_output_size = out.maxFailedTestOutputSize,
      test_output_truncation = out.testOutputTruncation,
      max_test_name_width = out.maxTestNameWidth,
    }
  end

  local filter = nil
  if json["filter"] ~= nil then
    if type(json["filter"]) ~= "table" then
      return nil, "filter must be an object"
    end
    local f = json["filter"]
    local inc = f.include
    local filter_include = nil
    if inc ~= nil then
      if type(inc) ~= "table" then
        return nil, "filter.include must be an object"
      end
      if inc.name ~= nil and type(inc.name) ~= "string" then
        return nil, "filter.include.name must be a string"
      end
      if inc.label ~= nil and type(inc.label) ~= "string" then
        return nil, "filter.include.label must be a string"
      end
      if inc.useUnion ~= nil and type(inc.useUnion) ~= "boolean" then
        return nil, "filter.include.useUnion must be a boolean"
      end
      local filter_index = nil
      if inc.index ~= nil then
        if type(inc.index) ~= "table" then
          return nil, "filter.include.index must be an object"
        end
        local idx = inc.index
        if idx.start ~= nil and type(idx.start) ~= "number" then
          return nil, "filter.include.index.start must be a number"
        end
        if idx["end"] ~= nil and type(idx["end"]) ~= "number" then
          return nil, "filter.include.index.end must be a number"
        end
        if idx.stride ~= nil and type(idx.stride) ~= "number" then
          return nil, "filter.include.index.stride must be a number"
        end
        if idx.specificTests ~= nil then
          if type(idx.specificTests) ~= "table" then
            return nil, "filter.include.index.specificTests must be a list"
          end
          for i, test_idx in ipairs(idx.specificTests) do
            if type(test_idx) ~= "number" then
              return nil, ("filter.include.index.specificTests at index %d must be a number"):format(i)
            end
          end
        end
        filter_index = {
          start = idx.start,
          ["end"] = idx["end"],
          stride = idx.stride,
          specific_tests = idx.specificTests,
        }
      end
      filter_include = {
        name = inc.name,
        label = inc.label,
        use_union = inc.useUnion,
        index = filter_index,
      }
    end

    local exc = f.exclude
    local filter_exclude = nil
    if exc ~= nil then
      if type(exc) ~= "table" then
        return nil, "filter.exclude must be an object"
      end
      if exc.name ~= nil and type(exc.name) ~= "string" then
        return nil, "filter.exclude.name must be a string"
      end
      if exc.label ~= nil and type(exc.label) ~= "string" then
        return nil, "filter.exclude.label must be a string"
      end
      local fixtures = nil
      if exc.fixtures ~= nil then
        if type(exc.fixtures) ~= "table" then
          return nil, "filter.exclude.fixtures must be an object"
        end
        local fix = exc.fixtures
        if fix.any ~= nil and type(fix.any) ~= "string" then
          return nil, "filter.exclude.fixtures.any must be a string"
        end
        if fix.setup ~= nil and type(fix.setup) ~= "string" then
          return nil, "filter.exclude.fixtures.setup must be a string"
        end
        if fix.cleanup ~= nil and type(fix.cleanup) ~= "string" then
          return nil, "filter.exclude.fixtures.cleanup must be a string"
        end
        fixtures = {
          any = fix.any,
          setup = fix.setup,
          cleanup = fix.cleanup,
        }
      end
      filter_exclude = {
        name = exc.name,
        label = exc.label,
        fixtures = fixtures,
      }
    end

    filter = {
      include = filter_include,
      exclude = filter_exclude,
    }
  end

  local execution = nil
  if json["execution"] ~= nil then
    if type(json["execution"]) ~= "table" then
      return nil, "execution must be an object"
    end
    local exec = json["execution"]
    if exec.stopOnFailure ~= nil and type(exec.stopOnFailure) ~= "boolean" then
      return nil, "execution.stopOnFailure must be a boolean"
    end
    if exec.enableFailover ~= nil and type(exec.enableFailover) ~= "boolean" then
      return nil, "execution.enableFailover must be a boolean"
    end
    if exec.jobs ~= nil and type(exec.jobs) ~= "number" then
      return nil, "execution.jobs must be a number"
    end
    if exec.resourceSpecFile ~= nil and type(exec.resourceSpecFile) ~= "string" then
      return nil, "execution.resourceSpecFile must be a string"
    end
    if exec.testLoad ~= nil and type(exec.testLoad) ~= "number" then
      return nil, "execution.testLoad must be a number"
    end
    if exec.showOnly ~= nil and exec.showOnly ~= "human" and exec.showOnly ~= "json-v1" then
      return nil, "execution.showOnly must be 'human' or 'json-v1'"
    end
    local repeat_obj = nil
    if exec["repeat"] ~= nil then
      if type(exec["repeat"]) ~= "table" then
        return nil, "execution.repeat must be an object"
      end
      local rep = exec["repeat"]
      if rep.mode == nil or (rep.mode ~= "until-fail" and rep.mode ~= "until-pass" and rep.mode ~= "after-timeout") then
        return nil, "execution.repeat.mode must be 'until-fail', 'until-pass', or 'after-timeout'"
      end
      if rep.count == nil or type(rep.count) ~= "number" then
        return nil, "execution.repeat.count must be a number"
      end
      repeat_obj = {
        mode = rep.mode,
        count = rep.count,
      }
    end
    if exec.interactiveDebugging ~= nil and type(exec.interactiveDebugging) ~= "boolean" then
      return nil, "execution.interactiveDebugging must be a boolean"
    end
    if exec.scheduleRandom ~= nil and type(exec.scheduleRandom) ~= "boolean" then
      return nil, "execution.scheduleRandom must be a boolean"
    end
    if exec.timeout ~= nil and type(exec.timeout) ~= "number" then
      return nil, "execution.timeout must be a number"
    end
    if exec.noTestsAction ~= nil and exec.noTestsAction ~= "default" and exec.noTestsAction ~= "error" and exec.noTestsAction ~= "ignore" then
      return nil, "execution.noTestsAction must be 'default', 'error', or 'ignore'"
    end
    execution = {
      stop_on_failure = exec.stopOnFailure,
      enable_failover = exec.enableFailover,
      jobs = exec.jobs,
      resource_spec_file = exec.resourceSpecFile,
      test_load = exec.testLoad,
      show_only = exec.showOnly,
      ["repeat"] = repeat_obj,
      interactive_debugging = exec.interactiveDebugging,
      schedule_random = exec.scheduleRandom,
      timeout = exec.timeout,
      no_tests_action = exec.noTestsAction,
    }
  end

  local test_passthrough_arguments = json["testPassthroughArguments"]
  if test_passthrough_arguments ~= nil then
    if type(test_passthrough_arguments) ~= "table" then
      return nil, "testPassthroughArguments must be a list"
    end
    for i, arg in ipairs(test_passthrough_arguments) do
      if type(arg) ~= "string" then
        return nil, ("testPassthroughArguments at index %d must be a string"):format(i)
      end
    end
  end

  return TestPreset.new({
    name = name,
    hidden = hidden,
    inherits = inherits,
    condition = condition,
    vendor = vendor,
    display_name = display_name,
    description = description,
    environment = environment,
    configure_preset = configure_preset,
    inherit_configure_environment = inherit_configure_environment,
    configuration = configuration,
    overwrite_configuration_file = overwrite_configuration_file,
    output = output,
    filter = filter,
    execution = execution,
    test_passthrough_arguments = test_passthrough_arguments,
  })
end

return TestPreset
