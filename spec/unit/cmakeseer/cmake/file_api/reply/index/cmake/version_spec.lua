local CMakeVersion = require("cmakeseer.cmake.file_api.reply.index.cmake.version")

---A valid CMake version object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    major = 3,
    minor = 20,
    patch = 0,
    suffix = "",
    isDirty = false,
  }, overrides or {})
end

---A valid CMake version object with a single field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

describe("CMakeVersion", function()
  describe("new", function()
    it("initializes correctly", function()
      local version = CMakeVersion.new(3, 20, 1, "rc1", true)
      assert.are.equal(3, version.major)
      assert.are.equal(20, version.minor)
      assert.are.equal(1, version.patch)
      assert.are.equal("rc1", version.suffix)
      assert.is_true(version.is_dirty)
    end)

    it("defaults a missing suffix to an empty string", function()
      assert.are.equal("", CMakeVersion.new(3, 20, 0, nil, false).suffix)
    end)

    it("preserves an explicit empty suffix", function()
      assert.are.equal("", CMakeVersion.new(3, 20, 0, "", false).suffix)
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
        local version, err = CMakeVersion.try_from_json(value)
        assert.is_nil(version)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ suffix = "rc1", isDirty = true }))
      assert.is_nil(err)
      assert.is_not_nil(version)
      assert(version)
      assert.are.equal(3, version.major)
      assert.are.equal(20, version.minor)
      assert.are.equal(0, version.patch)
      assert.are.equal("rc1", version.suffix)
      assert.is_true(version.is_dirty)
    end)

    it("defaults a missing suffix to an empty string", function()
      local version, err = CMakeVersion.try_from_json(json_without("suffix"))
      assert.is_nil(err)
      assert.is_not_nil(version)
      assert(version)
      assert.are.equal("", version.suffix)
    end)

    it("preserves a false isDirty", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ isDirty = false }))
      assert.is_nil(err)
      assert.is_not_nil(version)
      assert.is_false(assert(version).is_dirty)
    end)

    it("preserves an empty suffix", function()
      local version, err = CMakeVersion.try_from_json(valid_json())
      assert.is_nil(err)
      assert.is_not_nil(version)
      assert(version)
      assert.are.equal("", version.suffix)
    end)

    it("returns an error when major is missing", function()
      local version, err = CMakeVersion.try_from_json(json_without("major"))
      assert.is_nil(version)
      assert.are.equal("major is wrong type: nil", err)
    end)

    it("returns an error when major is not a number", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ major = "3" }))
      assert.is_nil(version)
      assert.are.equal("major is wrong type: string", err)
    end)

    it("returns an error when minor is missing", function()
      local version, err = CMakeVersion.try_from_json(json_without("minor"))
      assert.is_nil(version)
      assert.are.equal("minor is wrong type: nil", err)
    end)

    it("returns an error when minor is not a number", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ minor = "20" }))
      assert.is_nil(version)
      assert.are.equal("minor is wrong type: string", err)
    end)

    it("returns an error when patch is missing", function()
      local version, err = CMakeVersion.try_from_json(json_without("patch"))
      assert.is_nil(version)
      assert.are.equal("patch is wrong type: nil", err)
    end)

    it("returns an error when patch is not a number", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ patch = "0" }))
      assert.is_nil(version)
      assert.are.equal("patch is wrong type: string", err)
    end)

    it("returns an error when suffix is not a string", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ suffix = 1 }))
      assert.is_nil(version)
      assert.are.equal("suffix is wrong type: number", err)
    end)

    it("returns an error when isDirty is missing", function()
      local version, err = CMakeVersion.try_from_json(json_without("isDirty"))
      assert.is_nil(version)
      assert.are.equal("isDirty is wrong type: nil", err)
    end)

    it("returns an error when isDirty is not a boolean", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ isDirty = "false" }))
      assert.is_nil(version)
      assert.are.equal("isDirty is wrong type: string", err)
    end)
  end)

  describe("version_string", function()
    it("formats a version without a suffix", function()
      assert.are.equal("3.20.0", CMakeVersion.new(3, 20, 0, "", false):version_string())
    end)

    it("formats a version with a suffix", function()
      assert.are.equal("3.20.0-rc1", CMakeVersion.new(3, 20, 0, "rc1", false):version_string())
    end)

    it("formats a version whose suffix was omitted", function()
      assert.are.equal("3.20.0", CMakeVersion.new(3, 20, 0, nil, false):version_string())
    end)

    it("formats a version parsed from JSON", function()
      local version, err = CMakeVersion.try_from_json(valid_json({ suffix = "rc1" }))
      assert.is_nil(err)
      assert.is_not_nil(version)
      assert.are.equal("3.20.0-rc1", assert(version):version_string())
    end)
  end)
end)
