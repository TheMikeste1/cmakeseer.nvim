local Client = require("cmakeseer.cmake.file_api.reply.client")
local Reply = require("cmakeseer.cmake.file_api.reply.types")
local Stateful = require("cmakeseer.cmake.file_api.reply.stateful")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

---A valid file reference object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    kind = "codemodel",
    version = { major = 2, minor = 6 },
    jsonFile = "codemodel-v2@hash.json",
  }, overrides or {})
end

local INDEX_FILE_PATH = "/tmp/build/.cmake/api/v1/reply/index-2024-01-01.json"

describe("reply.Client", function()
  describe("new", function()
    it("initializes correctly", function()
      local stateless = { codemodel = Reply.from_json(valid_json(), INDEX_FILE_PATH) }
      local stateful = assert(Stateful.try_from_json({ responses = { valid_json() } }, INDEX_FILE_PATH))

      local client = Client.new(stateless, stateful)
      assert.are.same(stateless, client.stateless)
      assert.are.same(stateful, client.stateful)
    end)

    it("allows omitted replies", function()
      local client = Client.new()
      assert.is_nil(client.stateless)
      assert.is_nil(client.stateful)
    end)

    it("does not share the stateless or stateful replies with the caller", function()
      local stateless_reply = Reply.from_json(valid_json(), INDEX_FILE_PATH)
      local stateless = { codemodel = stateless_reply }
      local stateful = assert(Stateful.try_from_json({ responses = { valid_json() } }, INDEX_FILE_PATH))

      local client = Client.new(stateless, stateful)

      ---@cast stateless_reply cmakeseer.cmake.file_api.reply.Valid
      stateless_reply.reply.version.major = 9
      local stateful_reply = assert(stateful.responses[1])
      assert.are.equal("valid", stateful_reply.kind)
      ---@cast stateful_reply cmakeseer.cmake.file_api.reply.Valid
      stateful_reply.reply.version.major = 9

      local copied_stateless = assert(client.stateless.codemodel)
      assert.are.equal("valid", copied_stateless.kind)
      ---@cast copied_stateless cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal(2, copied_stateless.reply.version.major)

      local copied_response = assert(client.stateful.responses[1])
      assert.are.equal("valid", copied_response.kind)
      ---@cast copied_response cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal(2, copied_response.reply.version.major)
    end)

    it("preserves the stateful metatable", function()
      local stateful = assert(Stateful.try_from_json({ responses = {} }, INDEX_FILE_PATH))
      local client = Client.new(nil, stateful)
      assert.are.equal(Stateful, getmetatable(client.stateful))
    end)
  end)

  describe("new_with_error", function()
    it("initializes correctly", function()
      local stateless = { codemodel = Reply.from_json(valid_json(), INDEX_FILE_PATH) }
      local client = Client.new_with_error(stateless, "bad request")
      assert.are.same(stateless, client.stateless)
      assert.are.equal("bad request", client.stateful_error)
      assert.is_nil(client.stateful)
    end)

    it("allows omitted stateless replies", function()
      local client = Client.new_with_error(nil, "bad request")
      assert.is_nil(client.stateless)
    end)

    it("does not share the stateless replies with the caller", function()
      local stateless_reply = Reply.from_json(valid_json(), INDEX_FILE_PATH)
      local stateless = { codemodel = stateless_reply }
      local client = Client.new_with_error(stateless, "bad request")

      ---@cast stateless_reply cmakeseer.cmake.file_api.reply.Valid
      stateless_reply.reply.version.major = 9

      local copied = assert(client.stateless.codemodel)
      assert.are.equal("valid", copied.kind)
      ---@cast copied cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal(2, copied.reply.version.major)
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
        local client, err = Client.try_from_json(value, INDEX_FILE_PATH)
        assert.is_nil(client)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("returns an empty client for an empty object", function()
      local client, err = Client.try_from_json({}, INDEX_FILE_PATH)
      assert.is_nil(err)
      local instance = assert(client)
      assert.is_nil(instance.stateless)
      assert.is_nil(instance.stateful)
    end)

    it("parses stateless replies", function()
      local client = assert(Client.try_from_json({ codemodel = valid_json() }, INDEX_FILE_PATH))
      assert.are.equal("valid", client.stateless.codemodel.kind)
    end)

    it("resolves stateless replies against the index file", function()
      local client = assert(Client.try_from_json({ codemodel = valid_json() }, INDEX_FILE_PATH))
      local reply = assert(client.stateless.codemodel)
      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", reply.reply.json_file)
    end)

    it("marks an invalid stateless reply as malformed", function()
      local client = assert(Client.try_from_json({ codemodel = { kind = "notAKind" } }, INDEX_FILE_PATH))
      local reply = assert(client.stateless.codemodel)
      assert.are.equal("malformed", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Malformed
      assert.are.equal("kind was an invalid object kind: notAKind", reply.why)
    end)

    it("parses a stateless error reply", function()
      local client = assert(Client.try_from_json({ codemodel = { error = "unsupported" } }, INDEX_FILE_PATH))
      local reply = assert(client.stateless.codemodel)
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unsupported", reply.error)
    end)

    it("excludes query.json from the stateless replies", function()
      local client = assert(Client.try_from_json({
        codemodel = valid_json(),
        ["query.json"] = { responses = {} },
      }, INDEX_FILE_PATH))
      assert.is_not_nil(client.stateless.codemodel)
      assert.is_nil(client.stateless["query.json"])
      assert.is_not_nil(client.stateful)
    end)

    it("parses a stateful reply", function()
      local client = assert(Client.try_from_json({ ["query.json"] = { responses = { valid_json() } } }, INDEX_FILE_PATH))
      assert.is_nil(client.stateless)
      assert.are.equal(1, #client.stateful.responses)
      assert.are.equal("valid", client.stateful.responses[1].kind)
    end)

    it("resolves stateful responses against the index file", function()
      local client = assert(Client.try_from_json({ ["query.json"] = { responses = { valid_json() } } }, INDEX_FILE_PATH))
      local response = assert(client.stateful.responses[1])
      assert.are.equal("valid", response.kind)
      ---@cast response cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", response.reply.json_file)
    end)

    it("creates an error client when query.json has an error", function()
      local client = assert(Client.try_from_json({ ["query.json"] = { error = "bad request" } }, INDEX_FILE_PATH))
      assert.are.equal("bad request", client.stateful_error)
      assert.is_nil(client.stateful)
    end)

    it("preserves the stateless replies when query.json has an error", function()
      local client = assert(Client.try_from_json({
        codemodel = valid_json(),
        ["query.json"] = { error = "bad request" },
      }, INDEX_FILE_PATH))
      assert.are.equal("bad request", client.stateful_error)
      assert.are.equal("valid", client.stateless.codemodel.kind)
    end)

    it("prefers query.json.error over a valid stateful reply", function()
      local client = assert(Client.try_from_json({
        ["query.json"] = { error = "boom", responses = { valid_json() } },
      }, INDEX_FILE_PATH))
      assert.are.equal("boom", client.stateful_error)
      assert.is_nil(client.stateful)
    end)

    it("returns an error when query.json.error is not a string", function()
      for _, entry in ipairs({
        { "boolean", false },
        { "number", 42 },
        { "table", {} },
      }) do
        local label, value = entry[1], entry[2]
        local client, err = Client.try_from_json({ ["query.json"] = { error = value } }, INDEX_FILE_PATH)
        assert.is_nil(client)
        assert.are.equal(("stateful.error is wrong type: %s"):format(label), err)
      end
    end)

    it("returns an error when query.json is not a table", function()
      local client, err = Client.try_from_json({ ["query.json"] = "nope" }, INDEX_FILE_PATH)
      assert.is_nil(client)
      assert.are.equal("query.json is wrong type: string", err)
    end)

    it("returns an error when the stateful reply is malformed", function()
      local client, err = Client.try_from_json({ ["query.json"] = {} }, INDEX_FILE_PATH)
      assert.is_nil(client)
      assert.are.equal("query.json responses is wrong type: nil", err)
    end)
  end)

  describe("get_stateless_reply", function()
    it("returns the reply for the requested kind and version", function()
      local client = assert(Client.try_from_json({
        ["codemodel-v2"] = valid_json(),
        ["cache-v2"] = valid_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
      }, INDEX_FILE_PATH))

      local codemodel = assert(client:get_stateless_reply(object_kind.ObjectKindType.Codemodel, 2))
      assert.are.equal("valid", codemodel.kind)
      ---@cast codemodel cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", codemodel.reply.json_file)

      local cache = assert(client:get_stateless_reply(object_kind.ObjectKindType.Cache, 2))
      assert.are.equal("valid", cache.kind)
      ---@cast cache cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/cache-v2@hash.json", cache.reply.json_file)
    end)

    it("returns an error reply rather than nothing", function()
      local client = assert(Client.try_from_json({ ["codemodel-v99"] = { error = "unknown query file" } }, INDEX_FILE_PATH))

      local reply = assert(client:get_stateless_reply(object_kind.ObjectKindType.Codemodel, 99))
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unknown query file", reply.error)
    end)

    it("returns nothing for a kind that was not queried", function()
      local client = assert(Client.try_from_json({ ["codemodel-v2"] = valid_json() }, INDEX_FILE_PATH))
      assert.is_nil(client:get_stateless_reply(object_kind.ObjectKindType.Cache, 2))
    end)

    it("returns nothing for a version that was not queried", function()
      local client = assert(Client.try_from_json({ ["codemodel-v2"] = valid_json() }, INDEX_FILE_PATH))
      assert.is_nil(client:get_stateless_reply(object_kind.ObjectKindType.Codemodel, 1))
    end)

    it("returns nothing when the client only made a stateful query", function()
      local client = assert(Client.try_from_json({ ["query.json"] = { responses = {} } }, INDEX_FILE_PATH))
      assert.is_nil(client.stateless)
      assert.is_nil(client:get_stateless_reply(object_kind.ObjectKindType.Codemodel, 2))
    end)

    it("returns nothing when the stateful query was rejected", function()
      local client = Client.new_with_error(nil, "'requests' member missing")
      assert.is_nil(client:get_stateless_reply(object_kind.ObjectKindType.Codemodel, 2))
    end)
  end)
end)
