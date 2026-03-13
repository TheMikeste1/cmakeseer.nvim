local callbacks = require("cmakeseer.callbacks")
local CMakeSeer = require("cmakeseer")
local CTestApi = require("cmakeseer.ctest.api")
local state = require("cmakeseer.state")
local stub = require("luassert.stub")

describe("cmakeseer.callbacks", function()
  describe("on_post_configure_success", function()
    local is_ctest_stub
    local issue_query_stub
    local set_info_stub
    local get_build_dir_stub

    local read_responses_stub

    before_each(function()
      is_ctest_stub = stub(CMakeSeer, "is_ctest_project")
      issue_query_stub = stub(CTestApi, "issue_query")
      set_info_stub = stub(state, "set_ctest_info")
      get_build_dir_stub = stub(CMakeSeer, "get_build_directory", "/path/to/build")
      -- Mocking CMakeApi.read_responses as it is also called in on_post_configure_success via load_targets
      read_responses_stub = stub(require("cmakeseer.cmake.api"), "read_responses", {})
    end)

    after_each(function()
      is_ctest_stub:revert()
      issue_query_stub:revert()
      set_info_stub:revert()
      get_build_dir_stub:revert()
      read_responses_stub:revert()
    end)

    it("loads CTest info if it is a CTest project", function()
      is_ctest_stub.returns(true)
      local info = { tests = {} }
      issue_query_stub.returns(info)

      callbacks.on_post_configure_success()

      assert.stub(issue_query_stub).was.called_with("/path/to/build")
      assert.stub(set_info_stub).was.called_with(info)
    end)

    it("does not load CTest info if it is not a CTest project", function()
      is_ctest_stub.returns(false)

      callbacks.on_post_configure_success()

      assert.stub(issue_query_stub).was.not_called()
      assert.stub(set_info_stub).was.not_called()
    end)

    it("notifies on CTest query error", function()
      is_ctest_stub.returns(true)
      issue_query_stub.returns(CTestApi.IssueQueryError.NotConfigured)
      local notify_stub = stub(vim, "notify")

      callbacks.on_post_configure_success()

      assert.stub(notify_stub).was.called_with("Unable to load CTest info: NotConfigured", vim.log.levels.ERROR)
      notify_stub:revert()
    end)

    it("loads targets on success", function()
      local CMakeApi = require("cmakeseer.cmake.api")
      local Target = require("cmakeseer.cmake.api.codemodel.target")
      local ObjectKind = require("cmakeseer.cmake.api.object_kind").Kind

      local responses = {
        { kind = ObjectKind.codemodel, jsonFile = "codemodel.json" },
      }
      read_responses_stub.returns(responses)

      local codemodel = {
        kind = ObjectKind.codemodel,
        configurations = {
          {
            targets = {
              { name = "Target1", jsonFile = "target1.json" },
            },
          },
        },
      }
      local parse_object_stub = stub(CMakeApi, "parse_object_kind_file", codemodel)
      local parse_target_stub = stub(Target, "parse", { name = "Target1" })
      local set_targets_stub = stub(state, "set_targets")
      local notify_stub = stub(vim, "notify")

      callbacks.on_post_configure_success()

      assert.stub(parse_object_stub).was.called(1)
      assert.stub(parse_target_stub).was.called(1)
      assert.stub(set_targets_stub).was.called(1)
      assert.stub(notify_stub).was.called_with(match.matches("Found 1 targets", 1, true))

      parse_object_stub:revert()
      parse_target_stub:revert()
      set_targets_stub:revert()
      notify_stub:revert()
    end)
  end)
end)
