local kit = require("cmakeseer.kit")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.kit", function()
  describe("are_kits_equal", function()
    it("returns true for identical kits", function()
      local a = {
        name = "GCC 11",
        compilers = { C = "/usr/bin/gcc-11", CXX = "/usr/bin/g++-11" },
      }
      local b = {
        name = "GCC 11 (different name)",
        compilers = { C = "/usr/bin/gcc-11", CXX = "/usr/bin/g++-11" },
      }
      assert.is_true(kit.are_kits_equal(a, b))
    end)

    it("returns false for different kits", function()
      local a = {
        name = "GCC 11",
        compilers = { C = "/usr/bin/gcc-11", CXX = "/usr/bin/g++-11" },
      }
      local b = {
        name = "Clang 12",
        compilers = { C = "/usr/bin/clang-12", CXX = "/usr/bin/clang++-12" },
      }
      assert.is_false(kit.are_kits_equal(a, b))
    end)

    it("handles missing compilers", function()
      local a = { name = "Empty" }
      local b = { name = "Empty too" }
      assert.is_true(kit.are_kits_equal(a, b))

      local c = { name = "C only", compilers = { C = "gcc" } }
      assert.is_false(kit.are_kits_equal(a, c))
    end)
  end)

  describe("kit_exists", function()
    it("returns true if kit is in list", function()
      local kits = {
        { name = "A", compilers = { C = "gcc-a" } },
        { name = "B", compilers = { C = "gcc-b" } },
      }
      local target = { name = "B (again)", compilers = { C = "gcc-b" } }
      assert.is_true(kit.kit_exists(kits, target))
    end)

    it("returns false if kit is not in list", function()
      local kits = {
        { name = "A", compilers = { C = "gcc-a" } },
      }
      local target = { name = "B", compilers = { C = "gcc-b" } }
      assert.is_false(kit.kit_exists(kits, target))
    end)
  end)

  describe("remove_duplicate_kits", function()
    it("removes duplicate kits based on compilers", function()
      local kits = {
        { name = "GCC 11", compilers = { C = "gcc-11" } },
        { name = "GCC 11 Alt", compilers = { C = "gcc-11" } },
        { name = "Clang", compilers = { C = "clang" } },
      }
      local result = kit.remove_duplicate_kits(kits)
      assert.are.equal(2, #result)
      assert.are.equal("GCC 11", result[1].name)
      assert.are.equal("Clang", result[2].name)
    end)
  end)

  describe("load_all_kits", function()
    local open_stub
    local notify_stub
    local filereadable_stub
    local old_io_open = io.open

    before_each(function()
      notify_stub = stub(vim, "notify")
      filereadable_stub = stub(vim.fn, "filereadable")
    end)

    after_each(function()
      if open_stub then
        open_stub:revert()
        open_stub = nil
      end
      notify_stub:revert()
      filereadable_stub:revert()
    end)

    it("loads kits from multiple files", function()
      local mock_files = {
        ["file1.json"] = '[{"name": "Kit 1", "compilers": {"C": "gcc1"}}]',
        ["file2.json"] = '[{"name": "Kit 2", "compilers": {"C": "gcc2"}}]',
      }

      filereadable_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if mode == "r" and mock_files[path] then
          return {
            read = function()
              return mock_files[path]
            end,
            close = function() end,
          }
        end
        return old_io_open(path, mode)
      end)

      local kits = kit.load_all_kits({ "file1.json", "file2.json" })
      assert.are.equal(2, #kits)
      assert.are.equal("Kit 1", kits[1].name)
      assert.are.equal("Kit 2", kits[2].name)
    end)

    it("handles non-readable files", function()
      filereadable_stub.returns(0)

      local kits = kit.load_all_kits({ "missing.json" })
      assert.are.equal(0, #kits)
      assert.stub(notify_stub).was.called_with(match.matches("is not readable", 1, true), match._)
    end)

    it("handles empty files", function()
      filereadable_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if path == "empty.json" and mode == "r" then
          return {
            read = function()
              return ""
            end,
            close = function() end,
          }
        end
        return old_io_open(path, mode)
      end)

      local kits = kit.load_all_kits({ "empty.json" })
      assert.are.equal(0, #kits)
      assert.stub(notify_stub).was.called_with(match.matches("is empty", 1, true), match._)
    end)

    it("handles invalid JSON", function()
      filereadable_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if path == "invalid.json" and mode == "r" then
          return {
            read = function()
              return "not json"
            end,
            close = function() end,
          }
        end
        return old_io_open(path, mode)
      end)

      local kits = kit.load_all_kits({ "invalid.json" })
      assert.are.equal(0, #kits)
      assert.stub(notify_stub).was.called_with(match.matches("Failed to decode kit file", 1, true), match._)
    end)

    it("handles nil kit_paths", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      local kits = kit.load_all_kits(nil)
      assert.are.equal(0, #kits)
      assert.stub(notify_stub).was.called_with(match.matches("List of kit files was nil", 1, true), match._)
    end)

    it("handles io.open failure even if filereadable is true", function()
      filereadable_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if path == "unopenable.json" and mode == "r" then
          return nil
        end
        return old_io_open(path, mode)
      end)

      local kits = kit.load_all_kits({ "unopenable.json" })
      assert.are.equal(0, #kits)
      assert.stub(notify_stub).was.called_with(match.matches("Unable to read kit file", 1, true), match._)
    end)
  end)

  describe("persist_kits", function()
    local open_stub
    local mkdir_stub
    local isdirectory_stub
    local expand_stub
    local notify_stub
    local old_io_open = io.open

    before_each(function()
      mkdir_stub = stub(vim.fn, "mkdir")
      isdirectory_stub = stub(vim.fn, "isdirectory")
      expand_stub = stub(vim.fn, "expand", function(f)
        return f
      end)
      notify_stub = stub(vim, "notify")
    end)

    after_each(function()
      if open_stub then
        open_stub:revert()
        open_stub = nil
      end
      mkdir_stub:revert()
      isdirectory_stub:revert()
      expand_stub:revert()
      notify_stub:revert()
    end)

    it("persists kits to file", function()
      local written_content = ""
      open_stub = stub(io, "open", function(path, mode)
        if mode == "w" and not string.match(path, "luacov") then
          return {
            write = function(_, content)
              written_content = written_content .. content
            end,
            close = function() end,
          }
        end
        return old_io_open(path, mode)
      end)
      isdirectory_stub.returns(1)

      local kits = { { name = "Kit 1", compilers = { C = "gcc" } } }
      kit.persist_kits("kits.json", kits)

      local decoded = vim.json.decode(written_content)
      assert.are.equal(1, #decoded)
      assert.are.equal("Kit 1", decoded[1].name)
    end)

    it("creates directories if missing", function()
      isdirectory_stub.returns(0)
      mkdir_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if mode == "w" and not string.match(path, "luacov") then
          return {
            write = function() end,
            close = function() end,
          }
        end
        return old_io_open(path, mode)
      end)

      kit.persist_kits("dir/kits.json", {})
      assert.stub(mkdir_stub).was.called(1)
    end)

    it("handles mkdir failure", function()
      isdirectory_stub.returns(0)
      mkdir_stub.returns(0)

      kit.persist_kits("dir/kits.json", {})
      assert.stub(notify_stub).was.called_with(match.matches("Failed to create parent path", 1, true), match._)
    end)

    it("handles io.open failure with message", function()
      isdirectory_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if path == "kits.json" and mode == "w" then
          return nil, "permission denied"
        end
        return old_io_open(path, mode)
      end)

      kit.persist_kits("kits.json", {})
      assert.stub(notify_stub).was.called_with(match.matches("permission denied", 1, true), match._)
    end)

    it("handles io.open failure without message", function()
      isdirectory_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if path == "kits.json" and mode == "w" then
          return nil
        end
        return old_io_open(path, mode)
      end)

      kit.persist_kits("kits.json", {})
      assert.stub(notify_stub).was.called_with(match.matches("Unknown error", 1, true), match._)
    end)

    it("handles file write failure", function()
      isdirectory_stub.returns(1)
      open_stub = stub(io, "open", function(path, mode)
        if path == "kits.json" and mode == "w" then
          return {
            write = function()
              return nil, "disk full"
            end,
            close = function() end,
          }
        end
        return old_io_open(path, mode)
      end)

      kit.persist_kits("kits.json", {})
      assert.stub(notify_stub).was.called_with(match.matches("disk full", 1, true), match._)
    end)
  end)

  describe("scan_for_kits", function()
    local glob_stub
    local filereadable_stub
    local system_stub

    before_each(function()
      filereadable_stub = stub(vim.fn, "filereadable")
    end)

    after_each(function()
      if glob_stub then
        glob_stub:revert()
        glob_stub = nil
      end
      filereadable_stub:revert()
      if system_stub then
        system_stub:revert()
        system_stub = nil
      end
    end)

    it("scans directory for gcc and clang kits", function()
      glob_stub = stub(vim.fn, "glob", function(pattern)
        if pattern:match("gcc") then
          return "/usr/bin/gcc-11"
        elseif pattern:match("clang") then
          return "/usr/bin/clang-12"
        end
        return ""
      end)

      filereadable_stub.returns(1)

      system_stub = stub(vim, "system", function(cmd)
        return {
          wait = function()
            if cmd[2] == "--version" then
              return { code = 0, stdout = "gcc-11 (Ubuntu 11.4.0-1ubuntu1~22.04) 11.4.0\n" }
            elseif cmd[2] == "-dumpmachine" then
              return { code = 0, stdout = "x86_64-linux-gnu\n" }
            end
            return { code = 0, stdout = "" }
          end,
        }
      end)

      local kits = kit.scan_for_kits("/usr/bin")
      assert.are.equal(2, #kits)

      local gcc_kit = nil
      local clang_kit = nil
      for _, k in ipairs(kits) do
        if k.compilers.C:match("gcc") then
          gcc_kit = k
        elseif k.compilers.C:match("clang") then
          clang_kit = k
        end
      end

      assert.is_not_nil(gcc_kit)
      ---@cast gcc_kit -nil
      assert.are.equal("GCC 11.4.0 x86_64-linux-gnu", gcc_kit.name)
      assert.are.equal("/usr/bin/gcc-11", gcc_kit.compilers.C)
      assert.are.equal("/usr/bin/g++-11", gcc_kit.compilers.CXX)

      assert.is_not_nil(clang_kit)
      ---@cast clang_kit -nil
      assert.are.equal("clang-12", clang_kit.name)
      assert.are.equal("/usr/bin/clang-12", clang_kit.compilers.C)
    end)

    it("handles missing CXX compiler for GCC", function()
      glob_stub = stub(vim.fn, "glob", function(pattern)
        if pattern:match("gcc") then
          return "/usr/bin/gcc"
        end
        return ""
      end)

      filereadable_stub = stub(vim.fn, "filereadable", function(path)
        if path == "/usr/bin/g++" then
          return 0
        end
        return 1
      end)

      system_stub = stub(vim, "system", function()
        return {
          wait = function()
            return { code = 0, stdout = "11.4.0\n" }
          end,
        }
      end)

      local kits = kit.scan_for_kits("/usr/bin")
      assert.are.equal(1, #kits)
      assert.is_nil(kits[1].compilers.CXX)
    end)

    it("ignores paths that do not match kit patterns", function()
      glob_stub = stub(vim.fn, "glob", function(pattern)
        if pattern:match("gcc") then
          return "/usr/bin/gcc-not-a-kit\n/usr/bin/gcc-ar\n/usr/bin/gcc-nm"
        elseif pattern:match("clang") then
          return "/usr/bin/clang-not-a-kit\n/usr/bin/clang-format\n/usr/bin/clang-tidy"
        end
        return ""
      end)

      local kits = kit.scan_for_kits("/usr/bin")
      assert.are.equal(0, #kits)
    end)

    it("handles no kits found", function()
      glob_stub = stub(vim.fn, "glob", "")

      local kits = kit.scan_for_kits("/empty")
      assert.are.equal(0, #kits)
    end)
  end)
end)
