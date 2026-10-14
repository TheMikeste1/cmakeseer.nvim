local CMake = require("cmakeseer.cmake.file_api.reply.index.cmake")
local Client = require("cmakeseer.cmake.file_api.reply.client")
local File = require("cmakeseer.cmake.file_api.reply.index.file")
local FileReference = require("cmakeseer.cmake.file_api.reply.file_reference")
local Reply = require("cmakeseer.cmake.file_api.reply.types")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

---A valid cmake object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_cmake_json(overrides)
  return vim.tbl_extend("force", {
    version = { major = 3, minor = 20, patch = 0, suffix = "", isDirty = false },
    paths = { cmake = "/usr/bin/cmake", ctest = "/usr/bin/ctest", cpack = "/usr/bin/cpack", root = "/usr/share/cmake-3.20" },
    generator = { multiConfig = true, name = "Ninja Multi-Config", platform = "x64" },
  }, overrides or {})
end

---A valid file reference object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_reference_json(overrides)
  return vim.tbl_extend("force", {
    kind = "codemodel",
    version = { major = 2, minor = 6 },
    jsonFile = "codemodel-v2@hash.json",
  }, overrides or {})
end

---A valid index file object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    cmake = valid_cmake_json(),
    objects = { valid_reference_json() },
    reply = { codemodel = valid_reference_json() },
  }, overrides or {})
end

---A valid index file object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

local INDEX_FILE_PATH = "/tmp/build/.cmake/api/v1/reply/index-2024-01-01.json"
local ERROR_FILE_PATH = "/tmp/build/.cmake/api/v1/reply/error-2024-01-01.json"

---Builds an index file around the given replies, bypassing JSON parsing.
---@param replies table<string, cmakeseer.cmake.file_api.reply.index.FileReply>
---@return cmakeseer.cmake.file_api.reply.index.File file
local function file_with_replies(replies)
  return File.take(true, assert(CMake.try_from_json(valid_cmake_json())), {}, replies)
end

---Builds an index file whose only client reply holds the given stateless replies.
---@param replies table<string, table<string, any>> The replies, keyed the way CMake keys them.
---@return cmakeseer.cmake.file_api.reply.index.File file
local function file_with_client_stateless(replies)
  return assert(File.try_from_json(
    valid_json({
      reply = { ["client-cmakeseer"] = replies },
    }),
    INDEX_FILE_PATH
  ))
end

---Builds an index file whose only client reply is the given stateful `query.json` reply object.
---@param query_json table<string, any> The `query.json` reply object.
---@return cmakeseer.cmake.file_api.reply.index.File file
local function file_with_client_stateful(query_json)
  return assert(File.try_from_json(
    valid_json({
      reply = { ["client-cmakeseer"] = { ["query.json"] = query_json } },
    }),
    INDEX_FILE_PATH
  ))
end

describe("index.File", function()
  describe("new", function()
    it("does not share the cmake information, objects, or replies with the caller", function()
      local cmake = assert(CMake.try_from_json(valid_cmake_json()))
      ---@type cmakeseer.cmake.file_api.reply.FileReference[]
      local objects = { assert(FileReference.try_from_json(valid_reference_json(), INDEX_FILE_PATH)) }
      ---@type table<string, cmakeseer.cmake.file_api.reply.index.FileReply>
      local replies = { codemodel = Reply.from_json(valid_reference_json(), INDEX_FILE_PATH) }

      local file = File.new(true, cmake, objects, replies)
      cmake.version.major = 9
      objects[1].kind = "cache"
      local reply = assert(replies.codemodel)
      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      reply.reply.version.major = 9

      assert.are.equal(3, file.cmake.version.major)
      assert.are.equal("codemodel", file.objects[1].kind)
      local copied_reply = assert(file.replies.codemodel)
      assert.are.equal("valid", copied_reply.kind)
      ---@cast copied_reply cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal(2, copied_reply.reply.version.major)
    end)
  end)

  describe("take", function()
    it("stores the provided values without copying", function()
      local cmake = assert(CMake.try_from_json(valid_cmake_json()))
      ---@type cmakeseer.cmake.file_api.reply.FileReference[]
      local objects = {}
      ---@type table<string, cmakeseer.cmake.file_api.reply.index.FileReply>
      local replies = {}

      local file = File.take(false, cmake, objects, replies)
      assert.are.equal(false, file.succeeded)
      assert.are.equal(cmake, file.cmake)
      assert.are.equal(objects, file.objects)
      assert.are.equal(replies, file.replies)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "text" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local file, err = File.try_from_json(value, INDEX_FILE_PATH)
        assert.is_nil(file)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local file, err = File.try_from_json(valid_json(), INDEX_FILE_PATH)
      assert.is_nil(err)
      local instance = assert(file)
      assert.are.equal(3, instance.cmake.version.major)
      assert.are.equal("Ninja Multi-Config", instance.cmake.generator.name)
      assert.are.equal(1, #instance.objects)
      assert.are.equal("codemodel", instance.objects[1].kind)
      assert.are.equal("valid", instance.replies.codemodel.kind)
    end)

    it("marks a successful configure from an index file path", function()
      local file, err = File.try_from_json(valid_json(), INDEX_FILE_PATH)
      assert.is_nil(err)
      assert.is_true(assert(file).succeeded)
    end)

    it("marks a failed configure from an error file path", function()
      local file, err = File.try_from_json(valid_json(), ERROR_FILE_PATH)
      assert.is_nil(err)
      assert.is_false(assert(file).succeeded)
    end)

    it("returns an error when the path has neither prefix", function()
      local file, err = File.try_from_json(valid_json(), "/tmp/build/.cmake/api/v1/reply/bogus-2024-01-01.json")
      assert.is_nil(file)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^index file name has neither an 'index%-' nor an 'error%-' prefix: bogus%-2024%-01%-01%.json$", err)
    end)

    it("resolves object file references against the index file", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", file.objects[1].json_file)
    end)

    it("resolves reply references against the index file", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      local reply = assert(file.replies.codemodel)
      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", reply.reply.json_file)
    end)

    it("resolves references nested in a client reply", function()
      local json = valid_json({ reply = { ["client-cmakeseer"] = { codemodel = valid_reference_json() } } })
      local file = assert(File.try_from_json(json, INDEX_FILE_PATH))
      local reply = assert(file.replies["client-cmakeseer"])
      assert.are.equal("client", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.ClientReply
      local stateless_reply = assert(reply.client_reply.stateless.codemodel)
      assert.are.equal("valid", stateless_reply.kind)
      ---@cast stateless_reply cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", stateless_reply.reply.json_file)
    end)

    it("parses every reply", function()
      local json = valid_json({
        reply = {
          codemodel = valid_reference_json({ kind = "codemodel" }),
          cache = valid_reference_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
          ["client-cmakeseer"] = { codemodel = valid_reference_json() },
        },
      })
      local file = assert(File.try_from_json(json, INDEX_FILE_PATH))
      assert.are.equal("valid", file.replies.codemodel.kind)
      assert.are.equal("valid", file.replies.cache.kind)
      assert.are.equal("client", file.replies["client-cmakeseer"].kind)
    end)

    it("does not treat a bare client key as a client reply", function()
      local json = valid_json({ reply = { ["client"] = valid_reference_json() } })
      local file = assert(File.try_from_json(json, INDEX_FILE_PATH))
      local reply = assert(file.replies.client)
      assert.are.equal("valid", reply.kind)
    end)

    it("wraps client replies", function()
      local json = valid_json({ reply = { ["client-cmakeseer"] = { codemodel = valid_reference_json() } } })
      local file = assert(File.try_from_json(json, INDEX_FILE_PATH))
      local reply = assert(file.replies["client-cmakeseer"])
      assert.are.equal("client", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.ClientReply
      assert.are.equal("valid", reply.client_reply.stateless.codemodel.kind)
    end)

    it("parses a non-client error reply", function()
      local json = valid_json({ reply = { codemodel = { error = "unsupported" } } })
      local file = assert(File.try_from_json(json, INDEX_FILE_PATH))
      local reply = assert(file.replies.codemodel)
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unsupported", reply.error)
    end)

    it("returns an error when cmake is missing", function()
      local file, err = File.try_from_json(json_without("cmake"), INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("cmake json is wrong type: nil", err)
    end)

    it("returns an error when objects is missing", function()
      local file, err = File.try_from_json(json_without("objects"), INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("objects is wrong type: nil", err)
    end)

    it("returns an error when objects is not a table", function()
      local file, err = File.try_from_json(valid_json({ objects = 42 }), INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("objects is wrong type: number", err)
    end)

    it("returns an error when objects is a dict instead of a list", function()
      local json = valid_json({ objects = { codemodel = valid_reference_json() } })
      local file, err = File.try_from_json(json, INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("objects is a dict instead of a list", err)
    end)

    it("returns an error when reply is missing", function()
      local file, err = File.try_from_json(json_without("reply"), INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("reply is wrong type: nil", err)
    end)

    it("returns an error when reply is not a table", function()
      local file, err = File.try_from_json(valid_json({ reply = 42 }), INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("reply is wrong type: number", err)
    end)

    it("returns an error for an invalid object", function()
      local json = valid_json({ objects = { { kind = "notAKind", version = { major = 2, minor = 6 } } } })
      local file, err = File.try_from_json(json, INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("object at 1 kind was an invalid object kind: notAKind", err)
    end)

    it("reports the failing object index", function()
      local json = valid_json({
        objects = {
          valid_reference_json(),
          { kind = "notAKind", version = { major = 2, minor = 6 } },
        },
      })
      local file, err = File.try_from_json(json, INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("object at 2 kind was an invalid object kind: notAKind", err)
    end)

    it("returns an error when a client reply is malformed", function()
      local json = valid_json({ reply = { ["client-cmakeseer"] = { ["query.json"] = "nope" } } })
      local file, err = File.try_from_json(json, INDEX_FILE_PATH)
      assert.is_nil(file)
      assert.are.equal("reply for client-cmakeseer: query.json is wrong type: string", err)
    end)
  end)

  describe("get_shared_stateless_reply", function()
    it("returns the reply for the requested kind and version", function()
      local json = valid_json({
        reply = {
          ["codemodel-v2"] = valid_reference_json(),
          ["cache-v2"] = valid_reference_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
        },
      })
      local file = assert(File.try_from_json(json, INDEX_FILE_PATH))

      local codemodel = assert(file:get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, 2))
      assert.are.equal("valid", codemodel.kind)
      ---@cast codemodel cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", codemodel.reply.json_file)

      local cache = assert(file:get_shared_stateless_reply(object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", cache.kind)
      ---@cast cache cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/cache-v2@hash.json", cache.reply.json_file)
    end)

    it("returns an error reply rather than nothing", function()
      local file = assert(File.try_from_json(valid_json({ reply = { ["codemodel-v99"] = { error = "unknown query file" } } }), INDEX_FILE_PATH))

      local reply = assert(file:get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, 99))
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unknown query file", reply.error)
    end)

    it("returns nothing for a kind that was not queried", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.is_nil(file:get_shared_stateless_reply(object_kind.ObjectKindType.Cache, 2))
    end)

    it("returns nothing for a version that was not queried", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.is_nil(file:get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, 1))
    end)

    -- Unreachable through `try_from_json`: an object kind id never starts with "client-", so the
    -- parser never stores a client reply under one. Guards the invariant if that dispatch changes.
    it("refuses to return a client reply", function()
      local file = file_with_replies({
        ["codemodel-v2"] = { kind = "client", client_reply = Client.new() },
      })

      assert.has_error(function()
        file:get_shared_stateless_reply(object_kind.ObjectKindType.Codemodel, 2)
      end)
    end)
  end)

  describe("shared and client replies are kept apart", function()
    --- An index in which the same kind was queried both shared and per-client, each answering
    --- with a different object kind file.
    ---@return cmakeseer.cmake.file_api.reply.index.File file
    local function file_with_both_namespaces()
      return assert(File.try_from_json(
        valid_json({
          reply = {
            ["cache-v2"] = valid_reference_json({ kind = "cache", jsonFile = "shared-cache-v2.json" }),
            ["client-cmakeseer"] = {
              ["cache-v2"] = valid_reference_json({ kind = "cache", jsonFile = "client-cache-v2.json" }),
            },
          },
        }),
        INDEX_FILE_PATH
      ))
    end

    it("returns the shared reply for the shared lookup", function()
      local shared = assert(file_with_both_namespaces():get_shared_stateless_reply(object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", shared.kind)
      ---@cast shared cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/shared-cache-v2.json", shared.reply.json_file)
    end)

    it("returns the client reply for the client lookup", function()
      local client = assert(file_with_both_namespaces():get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", client.kind)
      ---@cast client cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/client-cache-v2.json", client.reply.json_file)
    end)
  end)

  describe("get_client_replies", function()
    it("returns the replies of the client", function()
      local file = assert(File.try_from_json(
        valid_json({
          reply = {
            ["client-cmakeseer"] = {
              ["cache-v2"] = valid_reference_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
              ["query.json"] = { responses = { valid_reference_json() } },
            },
          },
        }),
        INDEX_FILE_PATH
      ))

      local replies = assert(file:get_client_replies("cmakeseer"))
      assert.is_nil(replies.stateful_error)
      assert.are.equal("valid", assert(replies.stateless["cache-v2"]).kind)
      assert.is_not_nil(replies.stateful)
    end)

    it("returns nothing when the client did not query", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.is_nil(file:get_client_replies("cmakeseer"))
    end)

    it("does not return the replies of another client", function()
      local file = file_with_client_stateless({ ["cache-v2"] = valid_reference_json() })
      assert.is_nil(file:get_client_replies("another-client"))
    end)

    it("refuses to return a reply that is not a client reply", function()
      local file = file_with_replies({
        ["client-cmakeseer"] = Reply.from_json(valid_reference_json(), INDEX_FILE_PATH),
      })

      assert.has_error(function()
        file:get_client_replies("cmakeseer")
      end)
    end)

    -- CMake reports a rejected stateful query inside `responses.error`, but the parser also accepts
    -- a `query.json.error`, which drops the stateful reply while keeping the stateless ones.
    it("reports an error that replaced the stateful reply", function()
      local file = assert(File.try_from_json(
        valid_json({
          reply = {
            ["client-cmakeseer"] = {
              ["cache-v2"] = valid_reference_json(),
              ["query.json"] = { error = "bad request" },
            },
          },
        }),
        INDEX_FILE_PATH
      ))

      local replies = assert(file:get_client_replies("cmakeseer"))
      assert.are.equal("bad request", replies.stateful_error)
      assert.is_nil(replies.stateful)
      assert.is_nil(file:get_client_stateful("cmakeseer"))
      assert.is_not_nil(file:get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Cache, 2))
    end)
  end)

  describe("get_client_stateless_reply", function()
    it("returns the reply for the requested kind and version", function()
      local file = file_with_client_stateless({
        ["cache-v2"] = valid_reference_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
      })

      local reply = assert(file:get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/cache-v2@hash.json", reply.reply.json_file)
    end)

    it("returns an error reply rather than nothing", function()
      local file = file_with_client_stateless({ ["codemodel-v99"] = { error = "unknown query file" } })

      local reply = assert(file:get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Codemodel, 99))
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unknown query file", reply.error)
    end)

    it("returns nothing for a kind that was not queried", function()
      local file = file_with_client_stateless({ ["cache-v2"] = valid_reference_json() })
      assert.is_nil(file:get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Codemodel, 2))
    end)

    it("returns nothing when the client did not query", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.is_nil(file:get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Cache, 2))
    end)

    it("returns nothing when the client only made a stateful query", function()
      local file = file_with_client_stateful({ responses = {} })
      assert.is_nil(file:get_client_stateless_reply("cmakeseer", object_kind.ObjectKindType.Cache, 2))
    end)
  end)

  describe("get_client_stateful", function()
    it("returns the stateful reply of the client", function()
      local file = file_with_client_stateful({
        requests = { { kind = "codemodel", version = 2 } },
        responses = { valid_reference_json() },
      })

      local stateful = assert(file:get_client_stateful("cmakeseer"))
      assert.are.same({ { kind = "codemodel", version = 2 } }, stateful.requests)
      assert.are.equal("valid", assert(stateful.responses[1]).kind)
    end)

    it("returns the errored stateful reply when the query was rejected", function()
      local file = file_with_client_stateful({ responses = { error = "'requests' member missing" } })

      local stateful = assert(file:get_client_stateful("cmakeseer"))
      assert.are.equal("'requests' member missing", stateful.error)
      assert.is_nil(stateful.responses)
    end)

    it("returns nothing when the client did not make a stateful query", function()
      local file = file_with_client_stateless({ ["cache-v2"] = valid_reference_json() })
      assert.is_nil(file:get_client_stateful("cmakeseer"))
    end)

    it("returns nothing when the client did not query", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.is_nil(file:get_client_stateful("cmakeseer"))
    end)
  end)

  describe("get_client_stateful_response", function()
    it("returns the response of the requested kind", function()
      local file = file_with_client_stateful({
        requests = {
          { kind = "codemodel", version = 2 },
          { kind = "cache", version = 2 },
        },
        responses = {
          valid_reference_json(),
          valid_reference_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
        },
      })

      local codemodel = assert(file:get_client_stateful_response("cmakeseer", { kind = "codemodel", version = 2 }))
      assert.are.equal("valid", codemodel.kind)
      ---@cast codemodel cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", codemodel.reply.json_file)

      local cache = assert(file:get_client_stateful_response("cmakeseer", { kind = "cache", version = 2 }))
      assert.are.equal("valid", cache.kind)
      ---@cast cache cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/cache-v2@hash.json", cache.reply.json_file)
    end)

    it("returns nothing for a kind that was not requested", function()
      local file = file_with_client_stateful({
        requests = { { kind = "codemodel", version = 2 } },
        responses = { valid_reference_json() },
      })
      assert.is_nil(file:get_client_stateful_response("cmakeseer", { kind = "cache", version = 2 }))
    end)

    it("returns nothing when the stateful query was rejected", function()
      local file = file_with_client_stateful({ responses = { error = "'requests' member missing" } })
      assert.is_nil(file:get_client_stateful_response("cmakeseer", { kind = "codemodel", version = 2 }))
    end)

    it("returns nothing when the client did not make a stateful query", function()
      local file = file_with_client_stateless({ ["cache-v2"] = valid_reference_json() })
      assert.is_nil(file:get_client_stateful_response("cmakeseer", { kind = "cache", version = 2 }))
    end)

    it("returns nothing when the client did not query", function()
      local file = assert(File.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.is_nil(file:get_client_stateful_response("cmakeseer", { kind = "codemodel", version = 2 }))
    end)
  end)
end)
