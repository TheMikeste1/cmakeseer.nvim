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
end)
