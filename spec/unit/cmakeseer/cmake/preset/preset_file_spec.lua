local PresetFile = require("cmakeseer.cmake.preset.preset_file")

describe("cmakeseer.cmake.preset.PresetFile", function()
  describe("new", function()
    it("creates an instance and preserves provided values", function()
      local obj = {
        path = "/path/to/CMakePresets.json",
        version = 3,
        vendor = { custom = 123 },
      }
      local pf = PresetFile.new(obj)
      assert.is_not_nil(pf)
      assert.are.equal("/path/to/CMakePresets.json", pf.path)
      assert.are.equal(3, pf.version)
      assert.are.same({ custom = 123 }, pf.vendor)
      -- Deepcopy check: modifying original should not affect instance
      obj.vendor.custom = 456
      assert.are.equal(123, pf.vendor.custom)
    end)
  end)

  describe("try_from_file", function()
    local temp_dir

    before_each(function()
      temp_dir = vim.fn.tempname()
      vim.fn.mkdir(temp_dir, "p")
    end)

    after_each(function()
      vim.fn.delete(temp_dir, "rf")
    end)

    local function write_preset_file(content, filename)
      filename = filename or "CMakePresets.json"
      local filepath = vim.fs.joinpath(temp_dir, filename)
      local file = io.open(filepath, "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      if type(content) == "table" then
        file:write(vim.json.encode(content))
      else
        file:write(content)
      end
      file:close()
      return filepath
    end

    it("returns nil when file cannot be opened", function()
      local pf, err = PresetFile.try_from_file(vim.fs.joinpath(temp_dir, "nonexistent.json"))
      assert.is_nil(pf)
      assert.is_not_nil(err)
    end)

    it("returns nil when file contains invalid JSON", function()
      local filepath = write_preset_file("{ not valid json }")
      local pf, err = PresetFile.try_from_file(filepath)
      assert.is_nil(pf)
      assert.is_not_nil(err)
    end)

    it("validates version", function()
      local filepath_no_ver = write_preset_file({})
      local pf1, err1 = PresetFile.try_from_file(filepath_no_ver)
      assert.is_nil(pf1)
      assert.are.equal("Could not find version in file", err1)

      local filepath_str_ver = write_preset_file({ version = "three" })
      local pf2, err2 = PresetFile.try_from_file(filepath_str_ver)
      assert.is_nil(pf2)
      assert.are.equal("Version was not a number", err2)

      local filepath_ok = write_preset_file({ version = 3 })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.equal(3, pf3.version)
      assert.are.equal(vim.fs.normalize(filepath_ok), pf3.path)
    end)

    it("validates cmakeMinimumRequired", function()
      local filepath_bad_major = write_preset_file({
        version = 3,
        cmakeMinimumRequired = { major = "three" },
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_major)
      assert.is_nil(pf1)
      assert.are.equal("cmakeMinimumRequired.major must be a number", err1)

      local filepath_bad_minor = write_preset_file({
        version = 3,
        cmakeMinimumRequired = { major = 3, minor = "twenty" },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_minor)
      assert.is_nil(pf2)
      assert.are.equal("cmakeMinimumRequired.minor must be a number", err2)

      local filepath_bad_patch = write_preset_file({
        version = 3,
        cmakeMinimumRequired = { major = 3, minor = 20, patch = "zero" },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_bad_patch)
      assert.is_nil(pf3)
      assert.are.equal("cmakeMinimumRequired.patch must be a number", err3)

      local filepath_ok = write_preset_file({
        version = 3,
        cmakeMinimumRequired = { major = 3, minor = 20, patch = 0 },
      })
      local pf4, err4 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err4)
      assert.is_not_nil(pf4)
      assert.are.same({ major = 3, minor = 20, patch = 0 }, pf4.cmake_minimum_required)
    end)

    it("validates include", function()
      local filepath_bad_type = write_preset_file({
        version = 3,
        include = "other.json",
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_type)
      assert.is_nil(pf1)
      assert.are.equal("include must be a list", err1)

      local filepath_bad_elem = write_preset_file({
        version = 3,
        include = { "other.json", 123 },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_elem)
      assert.is_nil(pf2)
      assert.are.equal("include object at index 2 should be a string", err2)

      local filepath_ok = write_preset_file({
        version = 3,
        include = { "a.json", "b.json" },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.same({ "a.json", "b.json" }, pf3.include)
    end)

    it("validates configurePresets", function()
      local filepath_bad_type = write_preset_file({
        version = 3,
        configurePresets = "not an array",
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_type)
      assert.is_nil(pf1)
      assert.are.equal("configurePresets must be an array", err1)

      local filepath_bad_preset = write_preset_file({
        version = 3,
        configurePresets = {
          { name = "valid" },
          { name = 123 },
        },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_preset)
      assert.is_nil(pf2)
      assert.are.equal("configure preset at index 2 invalid: name must be a string", err2)

      local filepath_ok = write_preset_file({
        version = 3,
        configurePresets = {
          { name = "default", generator = "Ninja", binaryDir = "build/default" },
        },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.equal(1, #pf3.configure_presets)
      assert.are.equal("default", pf3.configure_presets[1].name)
      assert.are.equal("Ninja", pf3.configure_presets[1].generator)
      assert.are.equal("build/default", pf3.configure_presets[1].binary_dir)
    end)

    it("validates buildPresets", function()
      local filepath_bad_type = write_preset_file({
        version = 3,
        buildPresets = "not an array",
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_type)
      assert.is_nil(pf1)
      assert.are.equal("buildPresets must be an array", err1)

      local filepath_bad_preset = write_preset_file({
        version = 3,
        buildPresets = {
          { name = "build-1", jobs = "bad" },
        },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_preset)
      assert.is_nil(pf2)
      assert.are.equal("build preset at index 1 invalid: jobs must be a number", err2)

      local filepath_ok = write_preset_file({
        version = 3,
        buildPresets = {
          { name = "build-1", configurePreset = "default", jobs = 4 },
        },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.equal(1, #pf3.build_presets)
      assert.are.equal("build-1", pf3.build_presets[1].name)
      assert.are.equal("default", pf3.build_presets[1].configure_preset)
      assert.are.equal(4, pf3.build_presets[1].jobs)
    end)

    it("validates testPresets", function()
      local filepath_bad_type = write_preset_file({
        version = 3,
        testPresets = "not an array",
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_type)
      assert.is_nil(pf1)
      assert.are.equal("testPresets must be an array", err1)

      local filepath_bad_preset = write_preset_file({
        version = 3,
        testPresets = {
          { name = "test-1", output = { verbosity = "bad_verbosity" } },
        },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_preset)
      assert.is_nil(pf2)
      assert.are.equal("test preset at index 1 invalid: output.verbosity must be 'default', 'verbose', or 'extra'", err2)

      local filepath_ok = write_preset_file({
        version = 3,
        testPresets = {
          { name = "test-1", configurePreset = "default" },
        },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.equal(1, #pf3.test_presets)
      assert.are.equal("test-1", pf3.test_presets[1].name)
    end)

    it("validates packagePresets", function()
      local filepath_bad_type = write_preset_file({
        version = 3,
        packagePresets = "not an array",
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_type)
      assert.is_nil(pf1)
      assert.are.equal("packagePresets must be an array", err1)

      local filepath_bad_preset = write_preset_file({
        version = 3,
        packagePresets = {
          { name = "pkg-1", generators = "not an array" },
        },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_preset)
      assert.is_nil(pf2)
      assert.are.equal("package preset at index 1 invalid: generators must be a list", err2)

      local filepath_ok = write_preset_file({
        version = 3,
        packagePresets = {
          { name = "pkg-1", generators = { "TGZ" } },
        },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.equal(1, #pf3.package_presets)
      assert.are.equal("pkg-1", pf3.package_presets[1].name)
      assert.are.same({ "TGZ" }, pf3.package_presets[1].generators)
    end)

    it("validates workflowPresets", function()
      local filepath_bad_type = write_preset_file({
        version = 6,
        workflowPresets = "not an array",
      })
      local pf1, err1 = PresetFile.try_from_file(filepath_bad_type)
      assert.is_nil(pf1)
      assert.are.equal("workflowPresets must be an array", err1)

      local filepath_bad_preset = write_preset_file({
        version = 6,
        workflowPresets = {
          { name = "wf-1", steps = { { type = "build", name = "b1" } } },
        },
      })
      local pf2, err2 = PresetFile.try_from_file(filepath_bad_preset)
      assert.is_nil(pf2)
      assert.are.equal("workflow preset at index 1 invalid: The first step in a workflow preset must be configure", err2)

      local filepath_ok = write_preset_file({
        version = 6,
        workflowPresets = {
          { name = "wf-1", steps = { { type = "configure", name = "default" } } },
        },
      })
      local pf3, err3 = PresetFile.try_from_file(filepath_ok)
      assert.is_nil(err3)
      assert.is_not_nil(pf3)
      assert.are.equal(1, #pf3.workflow_presets)
      assert.are.equal("wf-1", pf3.workflow_presets[1].name)
    end)

    it("successfully parses a full preset file with vendor and all preset kinds", function()
      local full_json = {
        version = 6,
        cmakeMinimumRequired = { major = 3, minor = 25, patch = 0 },
        include = { "other.json" },
        vendor = { ide = { enabled = true } },
        configurePresets = {
          { name = "config-1", generator = "Ninja", binaryDir = "build/config-1" },
        },
        buildPresets = {
          { name = "build-1", configurePreset = "config-1" },
        },
        testPresets = {
          { name = "test-1", configurePreset = "config-1" },
        },
        packagePresets = {
          { name = "package-1", configurePreset = "config-1" },
        },
        workflowPresets = {
          { name = "workflow-1", steps = { { type = "configure", name = "config-1" } } },
        },
      }

      local filepath = write_preset_file(full_json)
      local pf, err = PresetFile.try_from_file(filepath)
      assert.is_nil(err)
      assert.is_not_nil(pf)
      assert.are.equal(6, pf.version)
      assert.are.same({ major = 3, minor = 25, patch = 0 }, pf.cmake_minimum_required)
      assert.are.same({ "other.json" }, pf.include)
      assert.are.same({ ide = { enabled = true } }, pf.vendor)
      assert.are.equal(1, #pf.configure_presets)
      assert.are.equal(1, #pf.build_presets)
      assert.are.equal(1, #pf.test_presets)
      assert.are.equal(1, #pf.package_presets)
      assert.are.equal(1, #pf.workflow_presets)
      assert.are.equal("config-1", pf.configure_presets[1].name)
      assert.are.equal("build-1", pf.build_presets[1].name)
      assert.are.equal("test-1", pf.test_presets[1].name)
      assert.are.equal("package-1", pf.package_presets[1].name)
      assert.are.equal("workflow-1", pf.workflow_presets[1].name)
    end)
  end)
end)
