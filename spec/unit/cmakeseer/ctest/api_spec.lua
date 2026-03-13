local api = require("cmakeseer.ctest.api")
local ObjectKind = require("cmakeseer.cmake.api.object_kind")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.ctest.api", function()
  local glob_stub
  local system_stub
  local is_valid_stub

  before_each(function()
    glob_stub = stub(vim.fn, "glob", "")
    system_stub = stub(vim, "system")
    is_valid_stub = stub(ObjectKind, "is_valid")
  end)

  after_each(function()
    glob_stub:revert()
    system_stub:revert()
    is_valid_stub:revert()
  end)

  describe("issue_query", function()
    it("returns CTest info on success", function()
      local build_dir = "/path/to/build"
      local json_data = { kind = "ctestInfo", version = { major = 1, minor = 0 }, tests = {} }
      local stdout = vim.fn.json_encode(json_data)

      glob_stub.on_call_with(build_dir).returns(build_dir)
      glob_stub.on_call_with(match.matches("CTestTestfile%.cmake$", 1, false)).returns("found")

      system_stub.returns({
        wait = function()
          return { code = 0, stdout = stdout }
        end,
      })
      is_valid_stub.returns(true)

      local result = api.issue_query(build_dir)
      assert.are.same(json_data, result)
      assert.stub(system_stub).was.called_with({ "ctest", "--test-dir", build_dir, "--show-only=json-v1" })
    end)

    it("returns NotConfigured if build directory does not exist", function()
      glob_stub.on_call_with("/nonexistent").returns("")
      local result = api.issue_query("/nonexistent")
      assert.are.equal(api.IssueQueryError.NotConfigured, result)
    end)

    it("returns NotCTestProject if CTestTestfile.cmake is missing", function()
      local build_dir = "/path/to/build"
      glob_stub.on_call_with(build_dir).returns(build_dir)
      glob_stub.on_call_with(match.matches("CTestTestfile%.cmake$", 1, false)).returns("")

      local result = api.issue_query(build_dir)
      assert.are.equal(api.IssueQueryError.NotCTestProject, result)
    end)

    it("returns SpawnProcess if ctest fails", function()
      local build_dir = "/path/to/build"
      glob_stub.on_call_with(build_dir).returns(build_dir)
      glob_stub.on_call_with(match.matches("CTestTestfile%.cmake$", 1, false)).returns("found")

      system_stub.returns({
        wait = function()
          return { code = 1, stdout = "" }
        end,
      })

      local result = api.issue_query(build_dir)
      assert.are.equal(api.IssueQueryError.SpawnProcess, result)
    end)

    it("returns SpawnProcess if stdout is nil", function()
      local build_dir = "/path/to/build"
      glob_stub.on_call_with(build_dir).returns(build_dir)
      glob_stub.on_call_with(match.matches("CTestTestfile%.cmake$", 1, false)).returns("found")

      system_stub.returns({
        wait = function()
          return { code = 0, stdout = nil }
        end,
      })

      local result = api.issue_query(build_dir)
      assert.are.equal(api.IssueQueryError.SpawnProcess, result)
    end)

    it("returns InvalidJson if stdout is not valid JSON", function()
      local build_dir = "/path/to/build"
      glob_stub.on_call_with(build_dir).returns(build_dir)
      glob_stub.on_call_with(match.matches("CTestTestfile%.cmake$", 1, false)).returns("found")

      system_stub.returns({
        wait = function()
          return { code = 0, stdout = "not json" }
        end,
      })

      local result = api.issue_query(build_dir)
      assert.are.equal(api.IssueQueryError.InvalidJson, result)
    end)

    it("returns InvalidCTestInfo if ObjectKind.is_valid returns false", function()
      local build_dir = "/path/to/build"
      glob_stub.on_call_with(build_dir).returns(build_dir)
      glob_stub.on_call_with(match.matches("CTestTestfile%.cmake$", 1, false)).returns("found")

      system_stub.returns({
        wait = function()
          return { code = 0, stdout = "{}" }
        end,
      })
      is_valid_stub.returns(false)

      local result = api.issue_query(build_dir)
      assert.are.equal(api.IssueQueryError.InvalidCTestInfo, result)
    end)
  end)

  describe("is_ctest_project", function()
    it("returns true if CTestTestfile.cmake exists", function()
      glob_stub.returns("found")
      assert.is_true(api.is_ctest_project("/path/to/build"))
    end)

    it("returns false if CTestTestfile.cmake is missing", function()
      glob_stub.returns("")
      assert.is_false(api.is_ctest_project("/path/to/build"))
    end)
  end)
end)
