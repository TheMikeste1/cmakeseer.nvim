local CMakePreset = require("cmakeseer.cmake.preset")
local stub = require("luassert.stub")
local match = require("luassert.match")

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

  describe("resolve_path", function()
    it("expands ${sourceDir}", function()
      local res = CMakePreset.resolve_path("${sourceDir}/build", "/my/project")
      assert.are.equal("/my/project/build", res)
    end)

    it("expands ${sourceParentDir}", function()
      local res = CMakePreset.resolve_path("${sourceParentDir}/other", "/my/project")
      assert.are.equal("/my/other", res)
    end)

    it("expands ${sourceDirName}", function()
      local res = CMakePreset.resolve_path("/out/${sourceDirName}", "/my/project")
      assert.are.equal("/out/project", res)
    end)

    it("expands ${dollar}", function()
      local res = CMakePreset.resolve_path("/path/${dollar}var", "/dir")
      assert.are.equal("/path/$var", res)
    end)

    it("expands ${pathListSep}", function()
      local res = CMakePreset.resolve_path("/a${pathListSep}/b", "/dir")
      local expected_sep = vim.uv.os_uname().sysname == "Windows_NT" and ";" or ":"
      assert.are.equal("/a" .. expected_sep .. "/b", res)
    end)

    it("expands ${hostSystemName}", function()
      local res = CMakePreset.resolve_path("/out/${hostSystemName}", "/dir")
      local sysname = vim.uv.os_uname().sysname
      if sysname == "Windows_NT" then
        sysname = "Windows"
      end
      assert.are.equal("/out/" .. sysname, res)
    end)

    pending("expands ${presetName} once supported", function()
      local res = CMakePreset.resolve_path("/path/${presetName}", "/dir")
      assert.are.equal("/path/my-preset", res)
    end)

    pending("expands ${generator} once supported", function()
      local res = CMakePreset.resolve_path("/path/${generator}", "/dir")
      assert.are.equal("/path/Ninja", res)
    end)

    pending("expands ${fileDir} once supported", function()
      local res = CMakePreset.resolve_path("${fileDir}/build", "/dir")
      assert.are.equal("/dir/build", res)
    end)

    it("expands $env{VAR} and $penv{VAR}", function()
      vim.env.MY_TEST_VAR = "custom_env_val"

      local res1 = CMakePreset.resolve_path("/out/$env{MY_TEST_VAR}", "/dir")
      assert.are.equal("/out/custom_env_val", res1)

      local res2 = CMakePreset.resolve_path("/out/$penv{MY_TEST_VAR}", "/dir")
      assert.are.equal("/out/custom_env_val", res2)

      local res3 = CMakePreset.resolve_path("/out/$env{NONEXISTENT_VAR_XYZ}", "/dir")
      assert.are.equal("/out/$env{NONEXISTENT_VAR_XYZ}", res3)

      vim.env.MY_TEST_VAR = nil
    end)

    it("leaves unrecognized variable unchanged", function()
      local res = CMakePreset.resolve_path("/out/${unrecognizedVar}", "/dir")
      assert.are.equal("/out/${unrecognizedVar}", res)
    end)

    it("expands multiple macros in a single path", function()
      local res = CMakePreset.resolve_path("${sourceDir}/build/${sourceDirName}", "/my/project")
      assert.are.equal("/my/project/build/project", res)
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

  describe("file_for and preset_binary_dir", function()
    local test_dir

    before_each(function()
      test_dir = vim.fn.tempname()
      vim.fn.mkdir(test_dir, "p")
    end)

    after_each(function()
      vim.fn.delete(test_dir, "rf")
    end)

    it("finds preset in CMakePresets.json", function()
      local cmake_presets = {
        configurePresets = {
          { name = "default", binaryDir = "${sourceDir}/build/default" },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakePresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_presets))
      file:close()

      local filepath = CMakePreset.file_for("default", test_dir, CMakePreset.PresetTypes.Configure)
      assert.are.equal(vim.fs.joinpath(test_dir, "CMakePresets.json"), filepath)

      local bdir = CMakePreset.preset_binary_dir("default", test_dir, CMakePreset.PresetTypes.Configure, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/default"), bdir)
    end)

    it("finds preset in CMakeUserPresets.json", function()
      local cmake_user_presets = {
        configurePresets = {
          { name = "user-preset", binaryDir = "${sourceDir}/build/user" },
        },
      }
      local file = io.open(vim.fs.joinpath(test_dir, "CMakeUserPresets.json"), "w")
      assert.is_not_nil(file)
      ---@cast file -nil
      file:write(vim.json.encode(cmake_user_presets))
      file:close()

      local filepath = CMakePreset.file_for("user-preset", test_dir, CMakePreset.PresetTypes.Configure)
      assert.are.equal(vim.fs.joinpath(test_dir, "CMakeUserPresets.json"), filepath)
    end)

    it("returns nil when preset not found or files missing", function()
      assert.is_nil(CMakePreset.file_for("missing", test_dir, CMakePreset.PresetTypes.Configure))
      assert.is_nil(CMakePreset.preset_binary_dir("missing", test_dir, CMakePreset.PresetTypes.Configure))
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

    it("returns nil for Workflow presets in preset_binary_dir", function()
      assert.is_nil(CMakePreset.preset_binary_dir("my-workflow", test_dir, CMakePreset.PresetTypes.Workflow))
    end)

    it("resolves binaryDir via inherits string in Configure preset", function()
      local cmake_presets = {
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

      local bdir = CMakePreset.preset_binary_dir("derived", test_dir, CMakePreset.PresetTypes.Configure, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/base"), bdir)
    end)

    it("resolves binaryDir from Build preset with configurePreset or inherits", function()
      local cmake_presets = {
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

      local bdir1 = CMakePreset.preset_binary_dir("build-derived", test_dir, CMakePreset.PresetTypes.Build, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/config-base"), bdir1)

      local bdir2 = CMakePreset.preset_binary_dir("build-inherited", test_dir, CMakePreset.PresetTypes.Build, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/config-base"), bdir2)
    end)

    it("resolves preset_binary_dir when inherits is an array of strings", function()
      local cmake_presets = {
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

      local bdir = CMakePreset.preset_binary_dir("derived", test_dir, CMakePreset.PresetTypes.Configure, { resolve_path = true })
      assert.are.equal(vim.fs.joinpath(test_dir, "build/base"), bdir)
    end)
  end)
end)
