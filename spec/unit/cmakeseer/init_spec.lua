local main = require("cmakeseer")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.init", function()
  describe("project_is_configured", function()
    it("checks for CMakeCache.txt", function()
      local glob_stub = stub(vim.fn, "glob", function()
        return "found"
      end)
      assert.is_true(main.project_is_configured())
      glob_stub:revert()

      glob_stub = stub(vim.fn, "glob", function()
        return ""
      end)
      assert.is_false(main.project_is_configured())
      glob_stub:revert()
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
    it("returns correct build args", function()
      main.setup({ build_directory = "build" })
      local args = main.get_build_args()
      assert.are.equal("--build", args[1])
      assert.is_not_nil(args[2]:match("/build$"))
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
      local glob_stub = stub(vim.fn, "glob", function()
        return "found"
      end)
      assert.is_true(main.is_cmake_project())
      glob_stub:revert()
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

      main.setup({ should_scan_path = false, scan_paths = { "/test" }, persist_file = "/abs/file.json" })
      main.scan_for_kits()

      local found_kits_msg = false
      local persisting_msg = false
      for _, call in
        ipairs((notify_stub --[[@as any]]).calls)
      do
        if call.refs[1] == "Found 2 kits" then
          found_kits_msg = true
        elseif call.refs[1] == "Persisting kits" then
          persisting_msg = true
        end
      end
      assert.is_true(found_kits_msg)
      assert.is_true(persisting_msg)
      assert.stub(persist_stub).was.called_with("/abs/file.json", match.is_table())

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

      -- Mock vim.env.PATH
      local old_path = vim.env.PATH
      vim.env.PATH = "/bin:/usr/bin"

      main.setup({ should_scan_path = true, scan_paths = { "/test" }, persist_file = nil })
      main.scan_for_kits()

      -- Check that scan_for_kits was called for /bin and /usr/bin
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
