local FileReference = require("cmakeseer.cmake.file_api.reply.file_reference")

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

---A valid file reference object with a single field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

local INDEX_FILE_PATH = "/tmp/build/.cmake/api/v1/reply/index-2024-01-01.json"

describe("FileReference", function()
  describe("new", function()
    it("initializes correctly", function()
      local reference, err = FileReference.new("codemodel", { major = 2, minor = 6 }, "/build/codemodel-v2.json")
      assert.is_nil(err)
      assert.is_not_nil(reference)
      assert(reference)
      assert.are.equal("codemodel", reference.kind)
      assert.are.same({ major = 2, minor = 6 }, reference.version)
      assert.are.equal("/build/codemodel-v2.json", reference.json_file)
    end)

    it("copies the version table", function()
      local version = { major = 2, minor = 6 }
      local reference = assert(FileReference.new("codemodel", version, "/build/codemodel-v2.json"))
      version.major = 9
      assert.are.equal(2, reference.version.major)
    end)

    it("returns an error when json_file is not an absolute path", function()
      local reference, err = FileReference.new("codemodel", { major = 2, minor = 6 }, "relative/codemodel-v2.json")
      assert.is_nil(reference)
      assert.are.equal("`relative/codemodel-v2.json` is not an absolute path", err)
    end)
  end)

  describe("new_unchecked", function()
    it("copies the version table", function()
      local version = { major = 2, minor = 6 }
      local reference = FileReference.new_unchecked("codemodel", version, "/build/codemodel-v2.json")
      version.major = 9
      assert.are.equal(2, reference.version.major)
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
        local reference, err = FileReference.try_from_json(value, INDEX_FILE_PATH)
        assert.is_nil(reference)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local reference, err = FileReference.try_from_json(valid_json(), INDEX_FILE_PATH)
      assert.is_nil(err)
      assert.is_not_nil(reference)
      assert(reference)
      assert.are.equal("codemodel", reference.kind)
      assert.are.same({ major = 2, minor = 6 }, reference.version)
    end)

    it("resolves jsonFile relative to the index file", function()
      local reference = assert(FileReference.try_from_json(valid_json(), INDEX_FILE_PATH))
      assert.are.equal("/tmp/build/.cmake/api/v1/reply/codemodel-v2@hash.json", reference.json_file)
    end)

    it("does not share the version table with the json", function()
      local json = valid_json()
      local reference = assert(FileReference.try_from_json(json, INDEX_FILE_PATH))
      json.version.major = 9
      assert.are.equal(2, reference.version.major)
    end)

    it("returns an error when kind is missing", function()
      local reference, err = FileReference.try_from_json(json_without("kind"), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("kind is wrong type: nil", err)
    end)

    it("returns an error when kind is not a string", function()
      local reference, err = FileReference.try_from_json(valid_json({ kind = 1 }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("kind is wrong type: number", err)
    end)

    it("returns an error when kind is not a known object kind", function()
      local reference, err = FileReference.try_from_json(valid_json({ kind = "notAKind" }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("kind was an invalid object kind: notAKind", err)
    end)

    it("returns an error when version is missing", function()
      local reference, err = FileReference.try_from_json(json_without("version"), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("version is wrong type: nil", err)
    end)

    it("returns an error when version is not a table", function()
      local reference, err = FileReference.try_from_json(valid_json({ version = "2.6" }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("version is wrong type: string", err)
    end)

    it("returns an error when version.major is missing", function()
      local reference, err = FileReference.try_from_json(valid_json({ version = { minor = 6 } }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("version.major is wrong type: nil", err)
    end)

    it("returns an error when version.major is not a number", function()
      local reference, err = FileReference.try_from_json(valid_json({ version = { major = "2", minor = 6 } }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("version.major is wrong type: string", err)
    end)

    it("returns an error when version.minor is missing", function()
      local reference, err = FileReference.try_from_json(valid_json({ version = { major = 2 } }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("version.minor is wrong type: nil", err)
    end)

    it("returns an error when version.minor is not a number", function()
      local reference, err = FileReference.try_from_json(valid_json({ version = { major = 2, minor = "6" } }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("version.minor is wrong type: string", err)
    end)

    it("returns an error when jsonFile is not a string", function()
      local reference, err = FileReference.try_from_json(valid_json({ jsonFile = 1 }), INDEX_FILE_PATH)
      assert.is_nil(reference)
      assert.are.equal("jsonFile is wrong type: number", err)
    end)

    it("resolves a missing jsonFile to the index file's directory", function()
      local reference = assert(FileReference.try_from_json(json_without("jsonFile"), INDEX_FILE_PATH))
      assert.are.equal("/tmp/build/.cmake/api/v1/reply", reference.json_file)
    end)

    it("resolves a relative index file path against the cwd", function()
      local reference = assert(FileReference.try_from_json(valid_json(), "reply/index-2024-01-01.json"))
      local expected = vim.fs.joinpath(assert(vim.uv.cwd()), "reply/codemodel-v2@hash.json")
      assert.are.equal(expected, reference.json_file)
    end)

    it("raises when jsonFile is absolute", function()
      -- The CMake file API guarantees `jsonFile` is relative to the index file, so an
      -- absolute path is malformed input rather than a recoverable error.
      local json = valid_json({ jsonFile = "/other/codemodel-v2@hash.json" })
      local ok, err = pcall(function()
        FileReference.try_from_json(json, INDEX_FILE_PATH)
      end)
      assert.is_false(ok)
      assert.matches("assertion failed", tostring(err))
    end)
  end)
end)
