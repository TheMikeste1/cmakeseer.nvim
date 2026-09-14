local CMakePreset = require("cmakeseer.cmake.preset")
local CMakeSeer = require("cmakeseer")
local stub = require("luassert.stub")

describe("cmakeseer.cmake.preset", function()
  describe("PresetTypes", function()
    it("defines valid preset types", function()
      assert.are.equal("configure", CMakePreset.PresetTypes.Configure)
      assert.are.equal("build", CMakePreset.PresetTypes.Build)
      assert.are.equal("test", CMakePreset.PresetTypes.Test)
      assert.are.equal("package", CMakePreset.PresetTypes.Package)
      assert.are.equal("workflow", CMakePreset.PresetTypes.Workflow)
    end)
  end)

  describe("fetch_presets", function()
    it("fetches list of presets using cmake --list-presets", function()
      local system_stub = stub(vim, "system", function(cmd)
        return {
          wait = function()
            return { code = 0, stdout = 'Available configure presets:\n  "default"\n  "release"\n' }
          end,
        }
      end)

      local presets = CMakePreset.fetch_presets("/my/project", CMakePreset.PresetTypes.Configure)
      assert.are.same({ "default", "release" }, presets)

      assert.stub(system_stub).was.called_with({ "cmake", "-S", "/my/project", "--list-presets", "configure" })
      system_stub:revert()
    end)
  end)

  describe("file_for and try_determine_binary_dir", function()
    local test_dir
    local get_config_stub

    before_each(function()
      test_dir = vim.fn.tempname()
      vim.fn.mkdir(test_dir, "p")
      get_config_stub = stub(CMakeSeer, "get_config", {
        get_project_root = function()
          return test_dir
        end,
      })
    end)

    after_each(function()
      vim.fn.delete(test_dir, "rf")
      if get_config_stub ~= nil then
        get_config_stub:revert()
        get_config_stub = nil
      end
    end)

    it("finds preset in CMakePresets.json", function()
      local cmake_presets = {
        version = 1,
        configurePresets = {
          { name = "default", binaryDir = "${sourceDir}/build/default" },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_presets))
      file:close()

      local preset_file = CMakePreset.file_for("default", test_dir, CMakePreset.PresetTypes.Configure)
      assert.is_not_nil(preset_file)
      ---@cast preset_file -nil
      assert.are.equal(vim.fs.joinpath(test_dir, "CMakePresets.json"), preset_file.path)

      local bdir = CMakePreset.try_determine_binary_dir("default", test_dir, CMakePreset.PresetTypes.Configure, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/default"), bdir)
    end)

    it("finds preset in CMakeUserPresets.json", function()
      local cmake_user_presets = {
        version = 1,
        configurePresets = {
          { name = "user-preset", binaryDir = "${sourceDir}/build/user" },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakeUserPresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_user_presets))
      file:close()

      local preset_file = CMakePreset.file_for("user-preset", test_dir, CMakePreset.PresetTypes.Configure)
      assert.is_not_nil(preset_file)
      ---@cast preset_file -nil
      assert.are.equal(vim.fs.joinpath(test_dir, "CMakeUserPresets.json"), preset_file.path)
    end)

    it("returns nil when preset not found or files missing", function()
      assert.is_nil(CMakePreset.file_for("missing", test_dir, CMakePreset.PresetTypes.Configure))
      assert.is_nil(CMakePreset.try_determine_binary_dir("missing", test_dir, CMakePreset.PresetTypes.Configure))
    end)

    it("safely handles invalid JSON in CMakePresets.json without error", function()
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write("{ invalid json }")
      file:close()

      assert.has_no.errors(function()
        CMakePreset.file_for("preset", test_dir, CMakePreset.PresetTypes.Configure)
      end)
    end)

    it("returns nil for Workflow presets in try_determine_binary_dir", function()
      assert.is_nil(CMakePreset.try_determine_binary_dir("my-workflow", test_dir, CMakePreset.PresetTypes.Workflow))
    end)

    it("resolves binaryDir via inherits string in Configure preset", function()
      local cmake_presets = {
        version = 1,
        configurePresets = {
          { name = "base", binaryDir = "${sourceDir}/build/base" },
          { name = "derived", inherits = "base" },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_presets))
      file:close()

      local bdir = CMakePreset.try_determine_binary_dir("derived", test_dir, CMakePreset.PresetTypes.Configure, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/base"), bdir)
    end)

    it("resolves binaryDir from Build preset with configurePreset or inherits", function()
      local cmake_presets = {
        version = 1,
        configurePresets = {
          { name = "config-base", binaryDir = "${sourceDir}/build/config-base" },
        },
        buildPresets = {
          { name = "build-derived", configurePreset = "config-base" },
          { name = "build-inherited", inherits = "build-derived" },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_presets))
      file:close()

      local bdir1 = CMakePreset.try_determine_binary_dir("build-derived", test_dir, CMakePreset.PresetTypes.Build, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/config-base"), bdir1)

      local bdir2 = CMakePreset.try_determine_binary_dir("build-inherited", test_dir, CMakePreset.PresetTypes.Build, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/config-base"), bdir2)
    end)

    it("resolves try_determine_binary_dir when inherits is an array of strings", function()
      local cmake_presets = {
        version = 1,
        configurePresets = {
          { name = "base", binaryDir = "${sourceDir}/build/base" },
          { name = "derived", inherits = { "base" } },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_presets))
      file:close()

      local bdir = CMakePreset.try_determine_binary_dir("derived", test_dir, CMakePreset.PresetTypes.Configure, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/base"), bdir)
    end)
  end)
end)
