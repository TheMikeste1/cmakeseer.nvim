local File = require("cmakeseer.cmake.file_api.reply.index.file")
local QueryStateful = require("cmakeseer.cmake.file_api.query.stateful")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local read_file = require("spec.utils").read_file

--- Gets a valid version for an Object Kind.
---@param kind cmakeseer.cmake.file_api.object_kind.ObjectKindType
---@return integer version
local function get_valid_object_kind_version(kind)
  local version = 1
  if kind == object_kind.ObjectKindType.Codemodel or kind == object_kind.ObjectKindType.Cache then
    version = 2
  end
  return version
end

--- Parses a reply index file straight from disk, the way a file API client does.
---@param path string
---@return cmakeseer.cmake.file_api.reply.index.File? file, string? err
local function parse_index_file(path)
  local json = vim.json.decode(read_file(path), { luanil = { object = true } })
  return File.try_from_json(json, path)
end

--- Asserts that a reference points at an object kind file CMake actually wrote.
---@param reference cmakeseer.cmake.file_api.reply.FileReference
---@param major_version integer The major version that was requested.
local function assert_reference_is_on_disk(reference, major_version)
  assert.are.equal(major_version, reference.version.major)
  assert.is_true(vim.fn.isabsolutepath(reference.json_file) == 1)
  assert.are.equal(1, vim.fn.filereadable(reference.json_file), ("missing object kind file %s"):format(reference.json_file))
end

describe("reply.index.File", function()
  local tmp = require("spec.fixtures.tmpdir")()
  local client = "cmakeseer"

  --- Parses the single reply index file a configure produced in the build directory.
  ---@return cmakeseer.cmake.file_api.reply.index.File file
  local function parse_configured_index()
    local pattern = vim.fs.joinpath(file_api.reply_dir(tmp.path), "index-*.json")
    local paths = vim.fn.glob(pattern, true, true)
    assert.are.equal(1, #paths)
    local index, err = parse_index_file(paths[1])
    assert.is_nil(err)
    return assert(index)
  end

  describe("try_from_json", function()
    it("parses the CMake information CMake reported", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()

      local reported = vim.trim(assert(vim.system({ "cmake", "--version" }):wait(60000).stdout))
      local major, minor, patch = reported:match("^cmake version (%d+)%.(%d+)%.(%d+)")
      assert.is_true(major ~= nil)
      assert.are.equal(tonumber(major), index.cmake.version.major)
      assert.are.equal(tonumber(minor), index.cmake.version.minor)
      assert.are.equal(tonumber(patch), index.cmake.version.patch)

      assert.are.equal(1, vim.fn.executable(index.cmake.paths.cmake))
      assert.are.equal(1, vim.fn.executable(index.cmake.paths.ctest))
      assert.are.equal(1, vim.fn.executable(index.cmake.paths.cpack))
      assert.are.equal(1, vim.fn.isdirectory(index.cmake.paths.root))

      assert.is_string(index.cmake.generator.name)
      assert.is_not.equal("", index.cmake.generator.name)
      assert.is_boolean(index.cmake.generator.multi_config)
    end)

    it("parses an index written for shared stateless queries", function()
      for _, kind in pairs(object_kind.ObjectKindType) do
        assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, kind, get_valid_object_kind_version(kind)))
      end
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()

      ---@type table<string, cmakeseer.cmake.file_api.reply.FileReference>
      local objects = {}
      for _, object in ipairs(index.objects) do
        objects[object.kind] = object
        assert_reference_is_on_disk(object, get_valid_object_kind_version(object.kind))
      end
      for _, kind in pairs(object_kind.ObjectKindType) do
        assert.is_not_nil(objects[kind])
      end

      for kind, major_version in pairs({
        [object_kind.ObjectKindType.Codemodel] = 2,
        [object_kind.ObjectKindType.Cache] = 2,
        [object_kind.ObjectKindType.ConfigureLog] = 1,
        [object_kind.ObjectKindType.CMakeFiles] = 1,
        [object_kind.ObjectKindType.Toolchains] = 1,
      }) do
        local reply = assert(index.replies[("%s-v%d"):format(kind, major_version)])
        assert.are.equal("valid", reply.kind)
        ---@cast reply cmakeseer.cmake.file_api.reply.Valid
        assert.are.equal(objects[kind].json_file, reply.reply.json_file)
      end
    end)

    it("parses a client stateless reply", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      local reply = assert(parse_configured_index().replies[("client-%s"):format(client)])
      assert.are.equal("client", reply.kind)
      ---@cast reply { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }
      assert.is_nil(reply.client_reply.stateful_error)

      local cache_reply = assert(reply.client_reply.stateless["cache-v2"])
      assert.are.equal("valid", cache_reply.kind)
      ---@cast cache_reply cmakeseer.cmake.file_api.reply.Valid
      assert_reference_is_on_disk(cache_reply.reply, 2)
    end)

    it("parses a client stateful reply", function()
      local query = QueryStateful.default()
      query.client = { name = client }
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = 2 })
      query:add_request({ kind = object_kind.ObjectKindType.Cache, version = 2 })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      local reply = assert(parse_configured_index().replies[("client-%s"):format(client)])
      assert.are.equal("client", reply.kind)
      ---@cast reply { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }

      local stateful = assert(reply.client_reply.stateful)
      assert.are.same({ name = client }, stateful.client)
      assert.are.same({
        { kind = object_kind.ObjectKindType.Codemodel, version = 2 },
        { kind = object_kind.ObjectKindType.Cache, version = 2 },
      }, stateful.requests)

      assert.are.equal(2, #stateful.responses)
      local codemodel_reply = assert(stateful.responses[1])
      local cache_reply = assert(stateful.responses[2])
      assert.are.equal("valid", codemodel_reply.kind)
      assert.are.equal("valid", cache_reply.kind)
      ---@cast codemodel_reply cmakeseer.cmake.file_api.reply.Valid
      ---@cast cache_reply cmakeseer.cmake.file_api.reply.Valid
      assert_reference_is_on_disk(codemodel_reply.reply, 2)
      assert_reference_is_on_disk(cache_reply.reply, 2)
    end)
  end)
end)
