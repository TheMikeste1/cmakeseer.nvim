local CMake = require("cmakeseer.cmake.file_api.reply.index.cmake")
local File = require("cmakeseer.cmake.file_api.reply.index.file")
local FileReference = require("cmakeseer.cmake.file_api.reply.file_reference")
local Reply = require("cmakeseer.cmake.file_api.reply.types")

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

describe("index.File", function()
  describe("new", function()
    it("does not share the cmake information, objects, or replies with the caller", function()
      local cmake = assert(CMake.try_from_json(valid_cmake_json()))
      ---@type cmakeseer.cmake.file_api.reply.FileReference[]
      local objects = { assert(FileReference.try_from_json(valid_reference_json(), INDEX_FILE_PATH)) }
      ---@type table<string, cmakeseer.cmake.file_api.index.FileReply>
      local replies = { codemodel = Reply.from_json(valid_reference_json(), INDEX_FILE_PATH) }

      local file = File.new(cmake, objects, replies)
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
      ---@type table<string, cmakeseer.cmake.file_api.index.FileReply>
      local replies = {}

      local file = File.take(cmake, objects, replies)
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
      ---@cast reply { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }
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
      ---@cast reply { kind: "client", client_reply: cmakeseer.cmake.file_api.reply.Client }
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
end)
