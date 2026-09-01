local callbacks = require("cmakeseer.callbacks")
local CMakeSeer = require("cmakeseer")
local state = require("cmakeseer.state")
local stub = require("luassert.stub")
local match = require("luassert.match")

describe("cmakeseer.callbacks", function()
  describe("on_pre_configure", function()
    it("issues query for codemodel", function()
      local CMakeApi = require("cmakeseer.cmake.api")
      local ObjectKind = require("cmakeseer.cmake.api.object_kind").Kind
      local resolve_stub = stub(CMakeSeer, "resolve_build_directory", "/build/path")
      local query_stub = stub(CMakeApi, "issue_query")

      callbacks.on_pre_configure()

      assert.stub(query_stub).was.called_with(ObjectKind.codemodel, "/build/path")

      resolve_stub:revert()
      query_stub:revert()
    end)

    it("notifies when query issue returns an error", function()
      local CMakeApi = require("cmakeseer.cmake.api")
      local ObjectKind = require("cmakeseer.cmake.api.object_kind").Kind
      local resolve_stub = stub(CMakeSeer, "resolve_build_directory", "/build/path")
      local query_stub = stub(CMakeApi, "issue_query", CMakeApi.IssueQueryError.FailedToMakeQueryFile)
      local notify_stub = stub(vim, "notify")

      callbacks.on_pre_configure()

      assert.stub(notify_stub).was.called_with(match.matches("Failed to make query file", 1, true), vim.log.levels.ERROR)

      resolve_stub:revert()
      query_stub:revert()
      notify_stub:revert()
    end)
  end)

  describe("on_post_configure_success", function()
    local resolve_stub
    local read_responses_stub

    before_each(function()
      resolve_stub = stub(CMakeSeer, "resolve_build_directory", "/path/to/build")
      read_responses_stub = stub(require("cmakeseer.cmake.api"), "read_responses", {})
    end)

    after_each(function()
      resolve_stub:revert()
      read_responses_stub:revert()
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
