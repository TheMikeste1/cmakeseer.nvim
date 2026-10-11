local file_api_reply = require("cmakeseer.cmake.file_api.reply")
local spec_utils = require("spec.utils")

---A reply index file, as CMake writes it, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    cmake = {
      version = { major = 3, minor = 20, patch = 0, string = "3.20.0", suffix = "", isDirty = false },
      paths = { cmake = "/usr/bin/cmake", ctest = "/usr/bin/ctest", cpack = "/usr/bin/cpack", root = "/usr/share/cmake-3.20" },
      generator = { multiConfig = false, name = "Unix Makefiles" },
    },
    objects = {
      { kind = "codemodel", version = { major = 2, minor = 6 }, jsonFile = "codemodel-v2-abc123.json" },
    },
    reply = {
      codemodel = { kind = "codemodel", version = { major = 2, minor = 6 }, jsonFile = "codemodel-v2-abc123.json" },
    },
  }, overrides or {})
end

describe("file_api.reply", function()
  local tmp = require("spec.fixtures.tmpdir")()

  ---The path a reply file would occupy in the temporary build directory.
  ---@param name string The reply file name.
  ---@return string path
  local function reply_path(name)
    return vim.fs.joinpath(tmp.path, ".cmake", "api", "v1", "reply", name)
  end

  ---Writes a reply file into the temporary build directory.
  ---@param name string The reply file name.
  ---@param contents string The exact bytes to write.
  local function write_reply(name, contents)
    spec_utils.write_file(reply_path(name), contents)
  end

  describe("find_reply_file", function()
    it("returns nil when there are no reply files", function()
      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(reply_file)
      assert.is_nil(err)
    end)

    it("parses the index file", function()
      write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))

      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(err)
      local index = assert(assert(reply_file).index)
      assert.are.equal(3, index.cmake.version.major)
      assert.are.equal("Unix Makefiles", index.cmake.generator.name)
      assert.are.equal(1, #index.objects)
      assert.are.equal(reply_path("codemodel-v2-abc123.json"), index.objects[1].json_file)
      assert.are.equal("valid", index.replies.codemodel.kind)
    end)

    it("returns the index file with the highest identifier", function()
      local newer = valid_json()
      newer.cmake.generator.name = "Ninja Multi-Config"
      write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))
      write_reply("index-2024-06-01.json", vim.json.encode(newer))

      local index = assert(assert(file_api_reply.find_reply_file(tmp.path)).index)
      assert.are.equal("Ninja Multi-Config", index.cmake.generator.name)
    end)

    it("prefers a newer index over an older error", function()
      write_reply("error-2024-01-01.json", "{}")
      write_reply("index-2024-06-01.json", vim.json.encode(valid_json()))

      local reply_file = assert(file_api_reply.find_reply_file(tmp.path))
      assert.is_not_nil(reply_file.index)
      assert.is_nil(reply_file.error)
    end)

    it("parses an index file whose generator platform is null", function()
      -- CMake emits `"platform": null` for single-config generators.
      local json = valid_json()
      json.cmake.generator.platform = vim.NIL
      write_reply("index-2024-01-01.json", vim.json.encode(json))

      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(err)
      local index = assert(assert(reply_file).index)
      assert.is_nil(index.cmake.generator.platform)
    end)

    it("returns the error path when only an error file exists", function()
      write_reply("error-2024-01-01.json", "{}")

      local reply_file, err = file_api_reply.find_reply_file(tmp.path)
      assert.is_nil(err)
      local found = assert(reply_file)
      assert.is_nil(found.index)
      assert.are.equal(reply_path("error-2024-01-01.json"), found.error.error)
      assert.is_nil(found.error.get_last_index)
    end)

    it("prefers a newer error over an older index", function()
      write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))
      write_reply("error-2024-06-01.json", "{}")

      local found = assert(file_api_reply.find_reply_file(tmp.path))
      assert.is_nil(found.index)
      assert.are.equal(reply_path("error-2024-06-01.json"), found.error.error)
      assert.is_function(found.error.get_last_index)
    end)

    describe("get_last_index", function()
      it("returns the index file that precedes the error", function()
        write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))
        write_reply("error-2024-06-01.json", "{}")

        local found = assert(file_api_reply.find_reply_file(tmp.path))
        local index, err = found.error.get_last_index()
        assert.is_nil(err)
        assert(index)
        assert.are.equal(3, index.cmake.version.major)
      end)
    end)

    describe("index file errors", function()
      it("returns an error when the index file cannot be decoded", function()
        write_reply("index-2024-01-01.json", "{not json")

        local reply_file, err = file_api_reply.find_reply_file(tmp.path)
        assert.is_nil(reply_file)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to decode index file: ", err)
      end)

      it("returns an error when the index file cannot be parsed", function()
        write_reply("index-2024-01-01.json", vim.json.encode({ cmake = {} }))

        local reply_file, err = file_api_reply.find_reply_file(tmp.path)
        assert.is_nil(reply_file)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to parse index file: cmake version json is wrong type: nil$", err)
      end)
    end)
  end)
end)
