local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local file_api_reply = require("cmakeseer.cmake.file_api.reply")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local try_configure = require("spec.fixtures.cmake.projects.try_configure")
local write_file = require("spec.utils").write_file

--- The paths of the reply files of a kind in a build directory, oldest first.
---@param build_dir string
---@param prefix "index"|"error"
---@return string[] paths
local function reply_file_paths(build_dir, prefix)
  local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), ("%s-*.json"):format(prefix))
  local paths = vim.fn.glob(pattern, true, true)
  table.sort(paths)
  return paths
end

--- Makes the next configure of the `failing` project fail, to exercise the reply error path.
---@param build_dir string
local function fail_next_configure(build_dir)
  write_file(vim.fs.joinpath(build_dir, "FAIL_CONFIGURE"), "")
end

describe("file_api.reply", function()
  local tmp = require("spec.fixtures.tmpdir")()
  local client = "cmakeseer"

  describe("find_reply_file", function()
    it("returns nothing when the build directory has no replies", function()
      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(reply_file)
      assert.is_nil(err)
    end)

    it("returns the index of a successful configure", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(err)
      assert(reply_file)
      assert.is_nil(reply_file.error)
      local index = assert(reply_file.index)

      assert.are.equal(1, #index.objects)
      assert.are.equal(object_kind.ObjectKindType.Codemodel, index.objects[1].kind)
      assert.are.equal(1, vim.fn.filereadable(index.objects[1].json_file))

      local codemodel = assert(index.replies["codemodel-v2"])
      assert.are.equal("valid", codemodel.kind)
      ---@cast codemodel cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal(index.objects[1].json_file, codemodel.reply.json_file)
    end)

    it("returns the index of the latest configure", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.are.equal(1, #reply_file_paths(tmp.path, "index"))
      local index = assert(assert(file_api_reply.find_reply_file(tmp.path)).index)

      local reply = assert(index.replies[("client-%s"):format(client)])
      assert.are.equal("client", reply.kind)
      ---@cast reply { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }
      assert.are.equal("valid", assert(reply.client_reply.stateless["cache-v2"]).kind)
    end)

    it("returns the error of a failed configure", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      fail_next_configure(tmp.path)
      local code = try_configure("failing", tmp.path)
      assert.are_not.equal(0, code)

      local paths = reply_file_paths(tmp.path, "error")
      assert.are.equal(1, #paths)
      assert.are.equal(0, #reply_file_paths(tmp.path, "index"))

      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(err)
      assert.is_nil(assert(reply_file).index)
      local error_file = assert(assert(reply_file).error)
      assert.are.equal(paths[1], error_file.error)
      assert.is_nil(error_file.get_last_index)
    end)

    it("offers the previous index when a reconfigure fails", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("failing", tmp.path)
      vim.uv.sleep(1100)
      fail_next_configure(tmp.path)
      local code = try_configure("failing", tmp.path)
      assert.are_not.equal(0, code)

      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(err)
      assert.is_nil(assert(reply_file).index)
      assert.are.equal(reply_file_paths(tmp.path, "error")[1], assert(assert(reply_file).error).error)

      local index, index_err = assert(assert(reply_file).error).get_last_index()
      assert.is_nil(index_err)
      assert.are.equal(1, #reply_file_paths(tmp.path, "index"))
      assert.are.equal(object_kind.ObjectKindType.Codemodel, assert(index).objects[1].kind)
      assert.are.equal("valid", assert(index).replies["codemodel-v2"].kind)
    end)
  end)
end)
