local File = require("cmakeseer.cmake.file_api.reply.index.file")
local QueryStateful = require("cmakeseer.cmake.file_api.query.stateful")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local read_file = require("spec.utils").read_file
local write_file = require("spec.utils").write_file

--- An object kind version no CMake release will ever support, to exercise the error replies.
local UNSUPPORTED_VERSION = 99

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

--- Groups the object kind references of an index file by kind.
---@param index cmakeseer.cmake.file_api.reply.index.File
---@return table<string, cmakeseer.cmake.file_api.reply.FileReference> objects
local function objects_by_kind(index)
  ---@type table<string, cmakeseer.cmake.file_api.reply.FileReference>
  local objects = {}
  for _, object in ipairs(index.objects) do
    objects[object.kind] = object
  end
  return objects
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
    assert.is_true(assert(index).succeeded)
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

      local objects = objects_by_kind(index)
      for _, object in ipairs(index.objects) do
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
      ---@cast reply cmakeseer.cmake.file_api.reply.ClientReply
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
      ---@cast reply cmakeseer.cmake.file_api.reply.ClientReply

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

  describe("get_shared_stateless_reply", function()
    it("returns the reply CMake wrote for the queried kind", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()
      local reply = assert(index:get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, 2))

      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      local objects = objects_by_kind(index)
      assert.are.equal(objects[object_kind.ObjectKindType.Codemodel].json_file, reply.reply.json_file)
      assert_reference_is_on_disk(reply.reply, 2)
    end)

    it("returns the error reply when CMake does not support the queried version", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, UNSUPPORTED_VERSION))
      cmake_configure("object_kinds", tmp.path)

      local reply = assert(parse_configured_index():get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, UNSUPPORTED_VERSION))
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unknown query file", reply.error)
    end)

    it("returns nothing when a different kind was queried", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_shared_stateless_reply(object_kind.ObjectKindType.Cache, 2))
    end)

    it("returns nothing when a different version was queried", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, 1))
    end)
  end)

  describe("get_client_replies", function()
    it("returns the stateless and stateful replies of the client", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      local query = QueryStateful.default()
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = 2 })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      local replies = assert(parse_configured_index():get_client_replies(client))
      assert.is_nil(replies.stateful_error)

      local stateless_id = file_api.build_stateless_id(object_kind.ObjectKindType.Cache, 2)
      assert.are.equal("valid", assert(assert(replies.stateless)[stateless_id]).kind)
      assert.are.equal("valid", assert(assert(replies.stateful).responses[1]).kind)
    end)

    it("returns nothing when no client queried", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_replies(client))
    end)
  end)

  describe("get_client_stateless_reply", function()
    it("returns the reply CMake wrote for the client", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()
      local reply = assert(index:get_client_stateless_reply(client, object_kind.ObjectKindType.Cache, 2))

      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      local objects = objects_by_kind(index)
      assert.are.equal(objects[object_kind.ObjectKindType.Cache].json_file, reply.reply.json_file)
      assert_reference_is_on_disk(reply.reply, 2)
    end)

    it("returns the error reply when CMake does not support the queried version", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Codemodel, UNSUPPORTED_VERSION))
      cmake_configure("object_kinds", tmp.path)

      local reply = assert(parse_configured_index():get_client_stateless_reply(client, object_kind.ObjectKindType.Codemodel, UNSUPPORTED_VERSION))
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unknown query file", reply.error)
    end)

    it("returns nothing when the client did not query that kind", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_stateless_reply(client, object_kind.ObjectKindType.Codemodel, 2))
    end)

    it("returns nothing when no client queried", function()
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Codemodel, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_stateless_reply(client, object_kind.ObjectKindType.Cache, 2))
    end)
  end)

  describe("shared and client replies in one index", function()
    it("resolves the same kind queried both ways", function()
      -- CMake writes a single object kind file for a kind, so both replies point at the same file.
      assert.is_nil(file_api_query.issue_shared_stateless_query(tmp.path, object_kind.ObjectKindType.Cache, 2))
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()
      local shared = assert(index:get_shared_stateless_reply(object_kind.ObjectKindType.Cache, 2))
      local client_reply = assert(index:get_client_stateless_reply(client, object_kind.ObjectKindType.Cache, 2))

      assert.are.equal("valid", shared.kind)
      assert.are.equal("valid", client_reply.kind)
      ---@cast shared cmakeseer.cmake.file_api.reply.Valid
      ---@cast client_reply cmakeseer.cmake.file_api.reply.Valid
      assert_reference_is_on_disk(shared.reply, 2)
      assert.are.equal(shared.reply.json_file, client_reply.reply.json_file)
    end)
  end)

  describe("get_client_stateful", function()
    it("returns the stateful reply CMake echoed", function()
      local query = QueryStateful.default()
      query.client = { name = client }
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = 2 })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      local stateful = assert(parse_configured_index():get_client_stateful(client))
      assert.are.same({ name = client }, stateful.client)
      assert.are.same({ { kind = object_kind.ObjectKindType.Codemodel, version = 2 } }, stateful.requests)
      assert.are.equal(1, #stateful.responses)
      assert.are.equal("valid", stateful.responses[1].kind)
    end)

    it("returns nothing when the client made no stateful query", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_stateful(client))
    end)

    it("returns an errored stateful reply when CMake rejected the query", function()
      -- A query.json without a `requests` member makes CMake answer with an error in place of the
      -- responses. The stateless replies of the same client are still answered.
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, QueryStateful.default()))
      local query_path = vim.fs.joinpath(file_api.query_dir(tmp.path), file_api.build_client_id(client), "query.json")
      write_file(query_path, ('{"client":{"name":"%s"}}'):format(client))
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()
      local stateful = assert(index:get_client_stateful(client))
      assert.are.equal("'requests' member missing", stateful.error)
      assert.is_nil(stateful.responses)
      assert.is_nil(index:get_client_stateful_response(client, { kind = object_kind.ObjectKindType.Cache, version = 2 }))

      local stateless_reply = assert(index:get_client_stateless_reply(client, object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", stateless_reply.kind)
    end)

    it("returns nothing when CMake could not read the stateful query", function()
      -- A query.json that is not a JSON object makes CMake report the error beside the query
      -- itself rather than in place of its responses, so there is no stateful reply at all. The
      -- stateless replies of the same client are still answered.
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, QueryStateful.default()))
      local query_path = vim.fs.joinpath(file_api.query_dir(tmp.path), file_api.build_client_id(client), "query.json")
      write_file(query_path, "not json at all")
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()
      local replies = assert(index:get_client_replies(client))
      -- The wording is CMake's JSON parser, so only assert that it reported something.
      assert.is_string(replies.stateful_error)
      assert.is_not.equal("", replies.stateful_error)
      assert.is_nil(replies.stateful)
      assert.is_nil(index:get_client_stateful(client))
      assert.is_nil(index:get_client_stateful_response(client, { kind = object_kind.ObjectKindType.Cache, version = 2 }))

      local stateless_reply = assert(index:get_client_stateless_reply(client, object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", stateless_reply.kind)
    end)
  end)

  describe("get_client_stateful_response", function()
    it("returns the response of the requested kind", function()
      local query = QueryStateful.default()
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = 2 })
      query:add_request({ kind = object_kind.ObjectKindType.Cache, version = 2 })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      local index = parse_configured_index()
      local objects = objects_by_kind(index)

      for _, kind in ipairs({ object_kind.ObjectKindType.Codemodel, object_kind.ObjectKindType.Cache }) do
        local reply = assert(index:get_client_stateful_response(client, { kind = kind, version = 2 }))
        assert.are.equal("valid", reply.kind, ("no valid response for %s"):format(kind))
        ---@cast reply cmakeseer.cmake.file_api.reply.Valid
        assert.are.equal(objects[kind].json_file, reply.reply.json_file)
        assert_reference_is_on_disk(reply.reply, 2)
      end
    end)

    it("returns the error response when CMake does not support the requested version", function()
      local query = QueryStateful.default()
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = UNSUPPORTED_VERSION })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      local reply = assert(parse_configured_index():get_client_stateful_response(client, { kind = object_kind.ObjectKindType.Codemodel, version = UNSUPPORTED_VERSION }))
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal(("no supported version specified among: %d.0"):format(UNSUPPORTED_VERSION), reply.error)
    end)

    it("returns nothing when the kind was not requested", function()
      local query = QueryStateful.default()
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = 2 })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_stateful_response(client, { kind = object_kind.ObjectKindType.Cache, version = 2 }))
    end)

    it("returns nothing when the version was not requested", function()
      local query = QueryStateful.default()
      query:add_request({ kind = object_kind.ObjectKindType.Codemodel, version = 2 })
      assert.is_nil(file_api_query.issue_client_stateful_query(client, tmp.path, query))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_stateful_response(client, { kind = object_kind.ObjectKindType.Codemodel, version = 1 }))
    end)

    it("returns nothing when the client made no stateful query", function()
      assert.is_nil(file_api_query.issue_client_stateless_query(client, tmp.path, object_kind.ObjectKindType.Cache, 2))
      cmake_configure("object_kinds", tmp.path)

      assert.is_nil(parse_configured_index():get_client_stateful_response(client, { kind = object_kind.ObjectKindType.Cache, version = 2 }))
    end)
  end)
end)
