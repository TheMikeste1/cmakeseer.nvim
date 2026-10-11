local Reply = require("cmakeseer.cmake.file_api.reply.types")
local Stateful = require("cmakeseer.cmake.file_api.reply.stateful")

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

---A valid request for an object kind.
---@return cmakeseer.cmake.file_api.query.ObjectKind request
local function valid_request()
  return { kind = "codemodel", version = 2 }
end

local INDEX_FILE_PATH = "/tmp/build/.cmake/api/v1/reply/index-2024-01-01.json"

describe("reply.Stateful", function()
  describe("new", function()
    it("initializes correctly", function()
      local requests = { valid_request() }
      local responses = { Reply.from_json(valid_json(), INDEX_FILE_PATH) }
      local client = { name = "cmakeseer" }

      local stateful = Stateful.new(requests, responses, client)
      assert.are.same(requests, stateful.requests)
      assert.are.same(responses, stateful.responses)
      assert.are.same(client, stateful.client)
    end)

    it("allows omitted requests and client", function()
      local stateful = Stateful.new(nil, {})
      assert.is_nil(stateful.requests)
      assert.are.same({}, stateful.responses)
      assert.is_nil(stateful.client)
    end)

    it("does not share the requests, responses, or client with the caller", function()
      local requests = { valid_request() }
      local response = Reply.from_json({ error = "boom" }, INDEX_FILE_PATH)
      local responses = { response }
      local client = { nested = { value = 1 } }

      local stateful = Stateful.new(requests, responses, client)
      requests[1].version = 9
      ---@cast response cmakeseer.cmake.file_api.reply.Error
      response.error = "changed"
      client.nested.value = 9

      assert.are.equal(2, stateful.requests[1].version)
      local copied = assert(stateful.responses[1])
      assert.are.equal("error", copied.kind)
      ---@cast copied cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("boom", copied.error)
      assert.are.equal(1, stateful.client.nested.value)
    end)
  end)

  describe("new_with_error", function()
    it("initializes correctly", function()
      local requests = { valid_request() }
      local stateful = Stateful.new_with_error(requests, "bad request", { name = "cmakeseer" })
      assert.are.equal("bad request", stateful.error)
      assert.are.same(requests, stateful.requests)
      assert.are.same({ name = "cmakeseer" }, stateful.client)
      assert.is_nil(stateful.responses)
    end)

    it("allows omitted requests and client", function()
      local stateful = Stateful.new_with_error(nil, "bad request")
      assert.is_nil(stateful.requests)
      assert.is_nil(stateful.client)
    end)

    it("does not share the requests or client with the caller", function()
      local requests = { valid_request() }
      local client = { nested = { value = 1 } }

      local stateful = Stateful.new_with_error(requests, "bad request", client)
      requests[1].version = 9
      client.nested.value = 9

      assert.are.equal(2, stateful.requests[1].version)
      assert.are.equal(1, stateful.client.nested.value)
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
        local stateful, err = Stateful.try_from_json(value, INDEX_FILE_PATH)
        assert.is_nil(stateful)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("parses requests, responses, and client", function()
      local stateful, err = Stateful.try_from_json({
        requests = { valid_request() },
        client = { name = "cmakeseer" },
        responses = { valid_json() },
      }, INDEX_FILE_PATH)
      assert.is_nil(err)
      local instance = assert(stateful)
      assert.are.same({ valid_request() }, instance.requests)
      assert.are.same({ name = "cmakeseer" }, instance.client)
      assert.are.equal(1, #instance.responses)
      assert.are.equal("valid", instance.responses[1].kind)
    end)

    it("resolves responses against the index file", function()
      local stateful = assert(Stateful.try_from_json({ responses = { valid_json() } }, INDEX_FILE_PATH))
      local responses = stateful.responses
      ---@cast responses cmakeseer.cmake.file_api.reply.Valid[]
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", responses[1].reply.json_file)
    end)

    it("preserves the response order", function()
      local stateful = assert(Stateful.try_from_json({
        responses = {
          valid_json({ kind = "codemodel" }),
          valid_json({ kind = "cache", jsonFile = "cache-v2@hash.json" }),
        },
      }, INDEX_FILE_PATH))
      local responses = stateful.responses
      ---@cast responses cmakeseer.cmake.file_api.reply.Valid[]
      assert.are.equal("codemodel", responses[1].reply.kind)
      assert.are.equal("cache", responses[2].reply.kind)
    end)

    it("marks an invalid response as malformed", function()
      local stateful = assert(Stateful.try_from_json({ responses = { { kind = "notAKind" } } }, INDEX_FILE_PATH))
      local response = assert(stateful.responses[1])
      assert.are.equal("malformed", response.kind)
      ---@cast response cmakeseer.cmake.file_api.reply.Malformed
      assert.are.equal("kind was an invalid object kind: notAKind", response.why)
    end)

    it("parses an error response", function()
      local stateful = assert(Stateful.try_from_json({ responses = { { error = "unsupported" } } }, INDEX_FILE_PATH))
      local response = assert(stateful.responses[1])
      assert.are.equal("error", response.kind)
      ---@cast response cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("unsupported", response.error)
    end)

    it("accepts a missing requests field", function()
      local stateful = assert(Stateful.try_from_json({ responses = {} }, INDEX_FILE_PATH))
      assert.is_nil(stateful.requests)
    end)

    it("accepts an empty responses list", function()
      local stateful = assert(Stateful.try_from_json({ responses = {} }, INDEX_FILE_PATH))
      assert.are.same({}, stateful.responses)
    end)

    it("creates an error instance when responses has an error", function()
      local stateful = assert(Stateful.try_from_json({
        requests = { valid_request() },
        client = { name = "cmakeseer" },
        responses = { error = "bad request" },
      }, INDEX_FILE_PATH))
      assert.are.equal("bad request", stateful.error)
      assert.is_nil(stateful.responses)
      assert.are.same({ valid_request() }, stateful.requests)
      assert.are.same({ name = "cmakeseer" }, stateful.client)
    end)

    it("returns an error when requests is not a table", function()
      local stateful, err = Stateful.try_from_json({ requests = "nope", responses = {} }, INDEX_FILE_PATH)
      assert.is_nil(stateful)
      assert.are.equal("requests is wrong type: string", err)
    end)

    it("returns an error when responses is missing", function()
      local stateful, err = Stateful.try_from_json({}, INDEX_FILE_PATH)
      assert.is_nil(stateful)
      assert.are.equal("responses is wrong type: nil", err)
    end)

    it("returns an error when responses is not a table", function()
      local stateful, err = Stateful.try_from_json({ responses = 42 }, INDEX_FILE_PATH)
      assert.is_nil(stateful)
      assert.are.equal("responses is wrong type: number", err)
    end)

    it("returns an error when responses is a dict instead of a list", function()
      local stateful, err = Stateful.try_from_json({ responses = { codemodel = valid_json() } }, INDEX_FILE_PATH)
      assert.is_nil(stateful)
      assert.are.equal("responses is a dict instead of a list", err)
    end)
  end)
end)
