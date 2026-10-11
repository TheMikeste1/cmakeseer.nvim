local Reply = require("cmakeseer.cmake.file_api.reply.types")

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

describe("reply.types", function()
  describe("from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "text" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns a malformed reply when json is a %s"):format(label), function()
        local reply = Reply.from_json(value, INDEX_FILE_PATH)
        assert.are.equal("malformed", reply.kind)
        ---@cast reply cmakeseer.cmake.file_api.reply.Malformed
        assert.are.equal(("Object was not a table. Was a %s"):format(label), reply.why)
        if value ~= nil then
          assert.are.equal(value, reply.json)
        end
      end)
    end

    it("returns an error reply when the object has an error", function()
      local reply = Reply.from_json({ error = "configuration failed" }, INDEX_FILE_PATH)
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("configuration failed", reply.error)
    end)

    it("prefers an error over a valid file reference", function()
      local json = valid_json({ error = "configuration failed" })
      local reply = Reply.from_json(json, INDEX_FILE_PATH)
      assert.are.equal("error", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Error
      assert.are.equal("configuration failed", reply.error)
    end)

    it("returns a valid reply for a file reference", function()
      local reply = Reply.from_json(valid_json(), INDEX_FILE_PATH)
      assert.are.equal("valid", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      assert.are.equal("codemodel", reply.reply.kind)
      assert.are.same({ major = 2, minor = 6 }, reply.reply.version)
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", reply.reply.json_file)
    end)

    it("forwards the index file path when resolving the reference", function()
      local reply = Reply.from_json(valid_json(), "reply/index-2024-01-01.json")
      ---@cast reply cmakeseer.cmake.file_api.reply.Valid
      local expected = vim.fs.joinpath(assert(vim.uv.cwd()), "reply/codemodel-v2@hash.json")
      assert.are.equal(expected, reply.reply.json_file)
    end)

    it("returns a malformed reply when the file reference is invalid", function()
      local json = valid_json({ kind = "notAKind" })
      local reply = Reply.from_json(json, INDEX_FILE_PATH)
      assert.are.equal("malformed", reply.kind)
      ---@cast reply cmakeseer.cmake.file_api.reply.Malformed
      assert.are.equal("kind was an invalid object kind: notAKind", reply.why)
      assert.are.same(json, reply.json)
    end)
  end)
end)
