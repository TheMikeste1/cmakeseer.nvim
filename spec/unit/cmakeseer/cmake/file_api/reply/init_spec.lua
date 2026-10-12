local file_api_reply = require("cmakeseer.cmake.file_api.reply")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
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

---An error index file, as CMake writes it when a configure fails, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function error_json(overrides)
  return vim.tbl_extend("force", {
    cmake = {
      version = { major = 3, minor = 20, patch = 0, string = "3.20.0", suffix = "", isDirty = false },
      paths = { cmake = "/usr/bin/cmake", ctest = "/usr/bin/ctest", cpack = "/usr/bin/cpack", root = "/usr/share/cmake-3.20" },
      generator = { multiConfig = false, name = "Unix Makefiles" },
    },
    objects = {},
    reply = {
      ["codemodel-v2"] = { error = "no buildsystem generated" },
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

  describe("find_latest_reply_index", function()
    it("returns nil when there are no reply files", function()
      local index, err = file_api_reply.find_latest_reply_index(tmp.path)
      assert.is_nil(index)
      assert.is_nil(err)
    end)

    it("parses the index file", function()
      write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))

      local index, err = file_api_reply.find_latest_reply_index(tmp.path)
      assert.is_nil(err)
      assert(index)
      assert.are.equal(3, index.cmake.version.major)
      assert.are.equal("Unix Makefiles", index.cmake.generator.name)
      assert.are.equal(1, #index.objects)
      assert.are.equal(reply_path("codemodel-v2-abc123.json"), index.objects[1].json_file)
      assert.are.equal("valid", index.replies.codemodel.kind)
      assert.is_true(index.succeeded)
    end)

    it("returns the index file with the highest identifier", function()
      local newer = valid_json()
      newer.cmake.generator.name = "Ninja Multi-Config"
      write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))
      write_reply("index-2024-06-01.json", vim.json.encode(newer))

      local index = assert(file_api_reply.find_latest_reply_index(tmp.path))
      assert.are.equal("Ninja Multi-Config", index.cmake.generator.name)
    end)

    it("orders indices differing only in the trailing counter", function()
      local newer = valid_json()
      newer.cmake.generator.name = "Ninja Multi-Config"
      write_reply("index-2024-01-01T01-02-03-0456.json", vim.json.encode(valid_json()))
      write_reply("index-2024-01-01T01-02-03-0467.json", vim.json.encode(newer))

      local index = assert(file_api_reply.find_latest_reply_index(tmp.path))
      assert.are.equal("Ninja Multi-Config", index.cmake.generator.name)
    end)

    it("parses an index file whose generator platform is null", function()
      -- CMake emits `"platform": null` for single-config generators.
      local json = valid_json()
      json.cmake.generator.platform = vim.NIL
      write_reply("index-2024-01-01.json", vim.json.encode(json))

      local index, err = file_api_reply.find_latest_reply_index(tmp.path)
      assert.is_nil(err)
      assert(index)
      assert.is_nil(index.cmake.generator.platform)
    end)

    describe("error index files", function()
      it("parses an error index file", function()
        write_reply("error-2024-01-01.json", vim.json.encode(error_json()))

        local index, err = file_api_reply.find_latest_reply_index(tmp.path)
        assert.is_nil(err)
        assert(index)
        assert.are.equal(3, index.cmake.version.major)
        assert.are.equal(0, #index.objects)
        assert.is_false(index.succeeded)

        local reply = assert(index.replies["codemodel-v2"])
        assert.are.equal("error", reply.kind)
        ---@cast reply cmakeseer.cmake.file_api.reply.Error
        assert.are.equal("no buildsystem generated", reply.error)
      end)

      it("parses an error index file that carries a configureLog object", function()
        local reference = {
          kind = "configureLog",
          version = { major = 1, minor = 0 },
          jsonFile = "configureLog-v1-abc123.json",
        }
        write_reply(
          "error-2024-01-01.json",
          vim.json.encode(error_json({
            objects = { reference },
            reply = {
              ["codemodel-v2"] = { error = "no buildsystem generated" },
              ["configureLog-v1"] = reference,
            },
          }))
        )

        local index = assert(file_api_reply.find_latest_reply_index(tmp.path))
        assert.are.equal(1, #index.objects)
        assert.are.equal(object_kind.ObjectKindType.ConfigureLog, index.objects[1].kind)
        assert.are.equal(reply_path("configureLog-v1-abc123.json"), index.objects[1].json_file)
        assert.are.equal("error", index.replies["codemodel-v2"].kind)
        assert.are.equal("valid", index.replies["configureLog-v1"].kind)
      end)

      it("parses an error index file carrying a client query", function()
        write_reply(
          "error-2024-01-01.json",
          vim.json.encode(error_json({
            reply = {
              ["client-cmakeseer"] = { ["cache-v2"] = { error = "no buildsystem generated" } },
            },
          }))
        )

        local index = assert(file_api_reply.find_latest_reply_index(tmp.path))
        local reply = assert(index.replies["client-cmakeseer"])
        assert.are.equal("client", reply.kind)
        ---@cast reply cmakeseer.cmake.file_api.reply.ClientReply

        local cache_reply = assert(assert(reply.client_reply.stateless)["cache-v2"])
        assert.are.equal("error", cache_reply.kind)
        ---@cast cache_reply cmakeseer.cmake.file_api.reply.Error
        assert.are.equal("no buildsystem generated", cache_reply.error)
      end)

      it("prefers a newer index over an older error", function()
        write_reply("error-2024-01-01.json", vim.json.encode(error_json()))
        write_reply("index-2024-06-01.json", vim.json.encode(valid_json()))

        local index = assert(file_api_reply.find_latest_reply_index(tmp.path))
        assert.are.equal("valid", index.replies.codemodel.kind)
        assert.is_true(index.succeeded)
      end)

      it("prefers a newer error over an older index", function()
        write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))
        write_reply("error-2024-06-01.json", vim.json.encode(error_json()))

        local index = assert(file_api_reply.find_latest_reply_index(tmp.path))
        assert.are.equal("error", index.replies["codemodel-v2"].kind)
        assert.is_false(index.succeeded)
      end)
    end)

    describe("index file errors", function()
      it("returns an error when the index file cannot be decoded", function()
        write_reply("index-2024-01-01.json", "{not json")

        local index, err = file_api_reply.find_latest_reply_index(tmp.path)
        assert.is_nil(index)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to decode index file: ", err)
      end)

      it("returns an error when the index file cannot be parsed", function()
        write_reply("index-2024-01-01.json", vim.json.encode({ cmake = {} }))

        local index, err = file_api_reply.find_latest_reply_index(tmp.path)
        assert.is_nil(index)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to parse index file: cmake version json is wrong type: nil$", err)
      end)

      it("returns an error when the error index file cannot be parsed", function()
        write_reply("error-2024-06-01.json", vim.json.encode({ cmake = {} }))

        local index, err = file_api_reply.find_latest_reply_index(tmp.path)
        assert.is_nil(index)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to parse index file: cmake version json is wrong type: nil$", err)
      end)
    end)
  end)

  describe("find_last_successful_reply_index", function()
    it("returns nil when there are no reply files", function()
      local index, err = file_api_reply.find_last_successful_reply_index(tmp.path)
      assert.is_nil(index)
      assert.is_nil(err)
    end)

    it("returns the index file with the highest identifier", function()
      local newer = valid_json()
      newer.cmake.generator.name = "Ninja Multi-Config"
      write_reply("index-2024-01-01.json", vim.json.encode(valid_json()))
      write_reply("index-2024-06-01.json", vim.json.encode(newer))

      local index = assert(file_api_reply.find_last_successful_reply_index(tmp.path))
      assert.are.equal("Ninja Multi-Config", index.cmake.generator.name)
    end)

    it("returns nil when only an error file exists", function()
      write_reply("error-2024-01-01.json", vim.json.encode(error_json()))

      local index, err = file_api_reply.find_last_successful_reply_index(tmp.path)
      assert.is_nil(index)
      assert.is_nil(err)
    end)

    it("returns the index preceding a newer error", function()
      local newer = valid_json()
      newer.cmake.generator.name = "Ninja Multi-Config"
      write_reply("index-2024-01-01.json", vim.json.encode(newer))
      write_reply("error-2024-06-01.json", vim.json.encode(error_json()))

      local index, err = file_api_reply.find_last_successful_reply_index(tmp.path)
      assert.is_nil(err)
      assert(index)
      assert.are.equal("Ninja Multi-Config", index.cmake.generator.name)
      assert.is_true(index.succeeded)
    end)

    describe("index file errors", function()
      it("returns an error when the index file cannot be decoded", function()
        write_reply("index-2024-01-01.json", "{not json")

        local index, err = file_api_reply.find_last_successful_reply_index(tmp.path)
        assert.is_nil(index)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to decode index file: ", err)
      end)

      it("returns an error when the index file cannot be parsed", function()
        write_reply("index-2024-01-01.json", vim.json.encode({ cmake = {} }))

        local index, err = file_api_reply.find_last_successful_reply_index(tmp.path)
        assert.is_nil(index)
        assert.is_not_nil(err)
        ---@cast err string
        assert.matches("^Failed to parse index file: cmake version json is wrong type: nil$", err)
      end)
    end)
  end)
end)
