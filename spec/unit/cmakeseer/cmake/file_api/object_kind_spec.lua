local object_kind = require("cmakeseer.cmake.file_api.object_kind")

describe("object_kind", function()
  describe("ObjectKindType", function()
    it("Codemodel value matches the CMake docs", function()
      assert.are.equal("codemodel", object_kind.ObjectKindType.Codemodel)
    end)
    it("ConfigureLog value matches the CMake docs", function()
      assert.are.equal("configureLog", object_kind.ObjectKindType.ConfigureLog)
    end)
    it("Cache value matches the CMake docs", function()
      assert.are.equal("cache", object_kind.ObjectKindType.Cache)
    end)
    it("CMakeFiles value matches the CMake docs", function()
      assert.are.equal("cmakeFiles", object_kind.ObjectKindType.CMakeFiles)
    end)
    it("Toolchains value matches the CMake docs", function()
      assert.are.equal("toolchains", object_kind.ObjectKindType.Toolchains)
    end)
  end)

  describe("from_string", function()
    for _, value in pairs(object_kind.ObjectKindType) do
      it(("converts %q to an object kind"):format(value), function()
        assert.are.equal(value, object_kind.from_string(value))
      end)
    end

    for _, value in ipairs({ "", "Codemodel", "codemodel ", "cache2" }) do
      it(("returns nil for %q"):format(value), function()
        assert.is_nil(object_kind.from_string(value))
      end)
    end
  end)

  describe("try_version_from_json", function()
    ---A valid version object, with optional overrides.
    ---@param overrides? table<string, any> Values to override.
    ---@return table<string, any> json
    local function valid_json(overrides)
      return vim.tbl_extend("force", { major = 2, minor = 6 }, overrides or {})
    end

    it("extracts the version from a valid object", function()
      local version, err = object_kind.try_version_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same({ major = 2, minor = 6 }, version)
    end)

    it("keeps a multi digit version", function()
      local version, err = object_kind.try_version_from_json(valid_json({ major = 12, minor = 34 }))
      assert.is_nil(err)
      assert.are.same({ major = 12, minor = 34 }, version)
    end)

    it("keeps a zero minor version", function()
      local version, err = object_kind.try_version_from_json(valid_json({ major = 2, minor = 0 }))
      assert.is_nil(err)
      assert.are.same({ major = 2, minor = 0 }, version)
    end)

    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "2.6" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local version, err = object_kind.try_version_from_json(value)
        assert.is_nil(version)
        assert.are.equal(("version is wrong type: %s"):format(label), err)
      end)
    end

    for _, entry in ipairs({
      { "major", "nil" },
      { "major", "string" },
      { "minor", "nil" },
      { "minor", "string" },
    }) do
      local field, label = entry[1], entry[2]
      it(("returns an error when version.%s is %s"):format(field, label), function()
        local json = valid_json()
        if label == "nil" then
          json[field] = nil
        else
          json[field] = "2"
        end
        local version, err = object_kind.try_version_from_json(json)
        assert.is_nil(version)
        assert.are.equal(("version.%s is wrong type: %s"):format(field, label), err)
      end)
    end

    it("reports the major version before the minor version", function()
      local version, err = object_kind.try_version_from_json({})
      assert.is_nil(version)
      assert.are.equal("version.major is wrong type: nil", err)
    end)

    it("returns a new table rather than the json", function()
      local json = valid_json()
      local version = assert(object_kind.try_version_from_json(json))

      json.major = 9
      assert.are.equal(2, version.major)
    end)
  end)

  describe("try_decode_file", function()
    local tmp = require("spec.fixtures.tmpdir")()

    --- Writes contents to a file in the test's temporary directory.
    ---@param contents string The exact bytes to write.
    ---@return string path The path to the written file.
    local function write(contents)
      local path = vim.fs.joinpath(tmp.path, "codemodel-v2-0123456789abcdef.json")
      require("spec.utils").write_file(path, contents)
      return path
    end

    it("decodes an object", function()
      local json, err = object_kind.try_decode_file(write('{"kind":"codemodel","version":{"major":2,"minor":11}}'))
      assert.is_nil(err)
      assert.are.same({ kind = "codemodel", version = { major = 2, minor = 11 } }, json)
    end)

    it("returns an error when the file does not exist", function()
      local json, err = object_kind.try_decode_file(vim.fs.joinpath(tmp.path, "missing.json"))
      assert.is_nil(json)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)

    it("returns an error when the path is a directory", function()
      local dir = vim.fs.joinpath(tmp.path, "directory")
      vim.fn.mkdir(dir, "p")

      local json, err = object_kind.try_decode_file(dir)
      assert.is_nil(json)
      assert.are.equal(("Failed to read %s: Is a directory"):format(dir), err)
    end)

    it("returns an error when the file is empty", function()
      local json, err = object_kind.try_decode_file(write(""))
      assert.is_nil(json)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)

    it("returns an error when the file is not JSON", function()
      local json, err = object_kind.try_decode_file(write("not json"))
      assert.is_nil(json)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)
  end)
end)
