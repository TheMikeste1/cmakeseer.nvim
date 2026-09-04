local main = require("cmakeseer")
local CMakePreset = require("cmakeseer.cmake.preset")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.init", function()
  before_each(function()
    main.setup({})
    main.state.selections.build_preset = nil
    main.state.selections.configure_preset = nil
    main.state.selections.kit = nil
    main.state.selections.variant = main.Variant.Debug
  end)

  describe("get_project_cache_file", function()
    it("returns cache file path using build_preset if set", function()
      local bin_stub = stub(CMakePreset, "preset_binary_dir", "/build/preset_dir")
      main.state.selections.build_preset = "my-build-preset"

      local cache_file = main.get_project_cache_file()
      assert.are.equal(vim.fs.joinpath("/build/preset_dir", "CMakeCache.txt"), cache_file)
      assert.stub(bin_stub).was.called_with("my-build-preset", match.is_string(), CMakePreset.PresetTypes.Build, { resolve_path = true })

      bin_stub:revert()
    end)

    it("returns cache file path using configure_preset if set and build_preset is nil", function()
      local bin_stub = stub(CMakePreset, "preset_binary_dir", "/config/preset_dir")
      main.state.selections.configure_preset = "my-config-preset"

      local cache_file = main.get_project_cache_file()
      assert.are.equal(vim.fs.joinpath("/config/preset_dir", "CMakeCache.txt"), cache_file)
      assert.stub(bin_stub).was.called_with("my-config-preset", match.is_string(), CMakePreset.PresetTypes.Configure, { resolve_path = true })

      bin_stub:revert()
    end)

    it("falls back to default build directory when no presets set", function()
      local cache_file = main.get_project_cache_file()
      assert.are.equal(vim.fs.joinpath(main.get_config():resolve_build_directory(), "CMakeCache.txt"), cache_file)
    end)
  end)

  describe("project_is_configured", function()
    it("checks for CMakeCache.txt", function()
      local stat_stub = stub(vim.uv, "fs_stat", function()
        return {}
      end)
      assert.is_true(main.project_is_configured())
      stat_stub:revert()

      stat_stub = stub(vim.uv, "fs_stat", function()
        return nil
      end)
      assert.is_false(main.project_is_configured())
      stat_stub:revert()
    end)
  end)

  describe("load_if_configured", function()
    it("schedules on_post_configure_success when project is configured and client query succeeds", function()
      local is_conf_stub = stub(main, "project_is_configured", true)
      local fs_stat_stub = stub(vim.uv, "fs_stat", function(path, cb)
        if type(cb) == "function" then
          cb(nil, {})
        end
        return {}
      end)
      local notify_stub = stub(vim, "notify")
      local schedule_stub = stub(vim, "schedule")

      main.load_if_configured()

      assert.stub(notify_stub).was.called_with("Project is already configured; attempting to load targets. . .")
      assert.stub(schedule_stub).was.called(1)

      is_conf_stub:revert()
      fs_stat_stub:revert()
      notify_stub:revert()
      schedule_stub:revert()
    end)

    it("notifies warning when project is configured but client query fails", function()
      local is_conf_stub = stub(main, "project_is_configured", true)
      local fs_stat_stub = stub(vim.uv, "fs_stat", function(path, cb)
        if type(cb) == "function" then
          cb("fs_stat error", nil)
        end
        return nil
      end)
      local notify_stub = stub(vim, "notify")

      main.load_if_configured()

      assert.stub(notify_stub).was.called_with(match.matches("CMakeSeer is not a client", 1, true))

      is_conf_stub:revert()
      fs_stat_stub:revert()
      notify_stub:revert()
    end)

    it("does nothing when project is not configured", function()
      local is_conf_stub = stub(main, "project_is_configured", false)
      local notify_stub = stub(vim, "notify")

      main.load_if_configured()

      assert.stub(notify_stub).was.not_called()

      is_conf_stub:revert()
      notify_stub:revert()
    end)
  end)

  describe("resolve_build_directory", function()
    it("resolves via build_preset when present", function()
      local bin_stub = stub(CMakePreset, "preset_binary_dir", "/resolved/build_preset")
      main.state.selections.build_preset = "b_preset"

      assert.are.equal("/resolved/build_preset", main.resolve_build_directory())

      bin_stub:revert()
    end)

    it("resolves via configure_preset when build_preset nil", function()
      local bin_stub = stub(CMakePreset, "preset_binary_dir", "/resolved/config_preset")
      main.state.selections.configure_preset = "c_preset"

      assert.are.equal("/resolved/config_preset", main.resolve_build_directory())

      bin_stub:revert()
    end)

    it("falls back to default resolve_build_directory", function()
      main.setup({ build_directory = "/custom/dir" })
      assert.are.equal("/custom/dir", main.resolve_build_directory())
    end)
  end)

  describe("get_basic_configure_args", function()
    it("returns args without preset", function()
      local args = main.get_basic_configure_args()
      assert.are.equal("-S", args[1])
      assert.are.equal("-B", args[3])
      assert.is_true(vim.tbl_contains(args, "-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON"))
    end)

    it("returns args with preset and preset binary dir", function()
      local bin_stub = stub(CMakePreset, "preset_binary_dir", "/preset/bdir")
      main.state.selections.configure_preset = "my_preset"

      local args = main.get_basic_configure_args()
      assert.is_true(vim.tbl_contains(args, "--preset"))
      assert.is_true(vim.tbl_contains(args, "my_preset"))
      assert.is_false(vim.tbl_contains(args, "-B"))

      bin_stub:revert()
    end)
  end)

  describe("get_configure_args", function()
    it("includes default args", function()
      local args = main.get_configure_args()
      local found = false
      for _, a in ipairs(args) do
        if a == "-DCMAKE_EXPORT_COMPILE_COMMANDS:BOOL=ON" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("includes variant if specified", function()
      main.state.selections.variant = main.Variant.Release
      local args = main.get_configure_args()
      local found = false
      for _, a in ipairs(args) do
        if a == "-DCMAKE_BUILD_TYPE:STRING=Release" then
          found = true
          break
        end
      end
      assert.is_true(found)
    end)

    it("includes compilers if kit selected", function()
      main.state.selections.kit = {
        name = "Test kit",
        compilers = { C = "/usr/bin/gcc", CXX = "/usr/bin/g++" },
      }
      local args = main.get_configure_args()
      local found_c = false
      local found_cxx = false
      for _, a in ipairs(args) do
        if a == "-DCMAKE_C_COMPILER:FILEPATH=/usr/bin/gcc" then
          found_c = true
        end
        if a == "-DCMAKE_CXX_COMPILER:FILEPATH=/usr/bin/g++" then
          found_cxx = true
        end
      end
      assert.is_true(found_c)
      assert.is_true(found_cxx)
    end)
  end)

  describe("get_build_args", function()
    it("returns correct build args without presets", function()
      main.setup({ build_directory = "build" })
      local args = main.get_build_args()
      assert.are.equal("--build", args[1])
      assert.is_not_nil(args[2]:match("/build$"))
    end)

    it("returns build args with build_preset", function()
      local bin_stub = stub(CMakePreset, "preset_binary_dir", nil)
      main.state.selections.build_preset = "b_preset"

      local args = main.get_build_args()
      assert.are.equal("--build", args[1])
      assert.is_true(vim.tbl_contains(args, "--preset"))
      assert.is_true(vim.tbl_contains(args, "b_preset"))

      bin_stub:revert()
    end)

    it("includes parallel flag when parallel setting specified", function()
      local settings_stub = stub(require("cmakeseer.settings"), "get_settings", {
        parallel = 4,
        configureArgs = {},
        configureSettings = {},
      })

      local args = main.get_build_args()
      assert.is_true(vim.tbl_contains(args, "--parallel"))
      assert.is_true(vim.tbl_contains(args, "4"))

      settings_stub:revert()
    end)

    it("includes parallel flag when parallel is function", function()
      local settings_stub = stub(require("cmakeseer.settings"), "get_settings", {
        parallel = function()
          return 0
        end,
        configureArgs = {},
        configureSettings = {},
      })

      local args = main.get_build_args()
      assert.is_true(vim.tbl_contains(args, "--parallel"))
      assert.is_false(vim.tbl_contains(args, "0"))

      settings_stub:revert()
    end)
  end)

  describe("get_all_kits", function()
    it("returns all kits from config and discovered", function()
      local kit_mod = require("cmakeseer.kit")
      local load_stub = stub(kit_mod, "load_all_kits", function()
        return { { name = "FileKit", compilers = { C = "f" } } }
      end)

      main.setup({ kits = { { name = "ConfigKit", compilers = { C = "c" } } }, kit_paths = { "p" } })
      main.state.set_discovered_kits({ { name = "DiscoveredKit", compilers = { C = "d" } } })

      local kits = main.get_all_kits()
      assert.are.equal(3, #kits)

      load_stub:revert()
    end)
  end)

  describe("helper functions", function()
    it("get_configure_command", function()
      assert.is_table(main.get_configure_command())
    end)

    it("is_cmake_project", function()
      local stat_stub = stub(vim.uv, "fs_stat", function()
        return {}
      end)
      assert.is_true(main.is_cmake_project())
      stat_stub:revert()
    end)

    it("is_ctest_project", function()
      local ctest_api = require("cmakeseer.ctest.api")
      local is_ctest_stub = stub(ctest_api, "is_ctest_project", function()
        return true
      end)
      assert.is_true(main.is_ctest_project())
      is_ctest_stub:revert()
    end)
  end)

  describe("scan_for_kits", function()
    it("scans paths and discovered kits", function()
      local kit_mod = require("cmakeseer.kit")
      local scan_stub = stub(kit_mod, "scan_for_kits", function()
        return { { name = "K1", compilers = { C = "g1" } }, { name = "K2", compilers = { C = "g2" } } }
      end)
      local persist_stub = stub(kit_mod, "persist_kits")
      local notify_stub = stub(vim, "notify")
      local get_all_kits_stub = stub(main, "get_all_kits", function()
        return {}
      end)

      local isdir_stub = stub(vim.fn, "isdirectory", 1)
      main.state.set_discovered_kits({})
      main.setup({ should_scan_path = false, scan_paths = { "/test" }, persist_file = "/abs/file.json" })
      main.scan_for_kits()

      assert.stub(notify_stub).was.called_with("Found 2 kits")

      isdir_stub:revert()
      scan_stub:revert()
      persist_stub:revert()
      notify_stub:revert()
      get_all_kits_stub:revert()
    end)

    it("scans paths and discovered kits (with PATH)", function()
      local kit_mod = require("cmakeseer.kit")
      local scan_stub = stub(kit_mod, "scan_for_kits", function()
        return {}
      end)
      local persist_stub = stub(kit_mod, "persist_kits")
      local notify_stub = stub(vim, "notify")
      local get_all_kits_stub = stub(main, "get_all_kits", function()
        return {}
      end)

      local old_path = vim.env.PATH
      vim.env.PATH = "/bin:/usr/bin"

      main.setup({ should_scan_path = true, scan_paths = { "/test" }, persist_file = nil })
      main.scan_for_kits()

      assert.stub(scan_stub).was.called_with("/test")
      assert.stub(scan_stub).was.called_with("/bin")
      assert.stub(scan_stub).was.called_with("/usr/bin")

      vim.env.PATH = old_path
      scan_stub:revert()
      persist_stub:revert()
      notify_stub:revert()
      get_all_kits_stub:revert()
    end)
  end)
end)
