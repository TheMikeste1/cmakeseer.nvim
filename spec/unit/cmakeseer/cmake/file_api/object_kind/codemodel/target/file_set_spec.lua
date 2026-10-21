local FileSet = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.file_set")

---A valid file set JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    name = "cmakeseer_example_headers",
    type = "HEADERS",
    visibility = "PUBLIC",
    baseDirectories = { "include" },
  }, overrides or {})
end

---The file set CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet file_set
local function valid_file_set()
  return {
    name = "cmakeseer_example_headers",
    type = "HEADERS",
    visibility = "PUBLIC",
    base_directories = { "include" },
  }
end

---A valid file set JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a file set object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.FileSet? obj, string? err
local function try_from_json(overrides)
  return FileSet.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.FileSet", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "fileSet" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local file_set, err = FileSet.try_from_json(value)
        assert.is_nil(file_set)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local file_set, err = FileSet.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_file_set(), assert(file_set))
    end)

    it("returns an error when name is missing", function()
      local file_set, err = FileSet.try_from_json(json_without("name"))
      assert.is_nil(file_set)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local file_set, err = try_from_json({ name = 42 })
      assert.is_nil(file_set)
      assert.are.equal("name is wrong type: number", err)
    end)

    it("returns an error when type is missing", function()
      local file_set, err = FileSet.try_from_json(json_without("type"))
      assert.is_nil(file_set)
      assert.are.equal("type is wrong type: nil", err)
    end)

    it("returns an error when type is not a string", function()
      local file_set, err = try_from_json({ type = 42 })
      assert.is_nil(file_set)
      assert.are.equal("type is wrong type: number", err)
    end)

    it("returns an error when visibility is missing", function()
      local file_set, err = FileSet.try_from_json(json_without("visibility"))
      assert.is_nil(file_set)
      assert.are.equal("visibility is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "PUBLIC", "PUBLIC" },
      { "PRIVATE", "PRIVATE" },
      { "INTERFACE", "INTERFACE" },
    }) do
      local visibility, expected = entry[1], entry[2]
      it(("records the visibility %s"):format(visibility), function()
        local file_set, err = try_from_json({ visibility = visibility })
        assert.is_nil(err)
        assert.are.equal(expected, assert(file_set).visibility)
      end)
    end

    it("returns an error when visibility is not a value CMake writes", function()
      local file_set, err = try_from_json({ visibility = "INVALID" })
      assert.is_nil(file_set)
      assert.are.equal("visibility is invalid: INVALID", err)
    end)

    it("returns an error when baseDirectories is missing", function()
      local file_set, err = FileSet.try_from_json(json_without("baseDirectories"))
      assert.is_nil(file_set)
      assert.are.equal("baseDirectories is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "baseDirectories" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when baseDirectories is %s"):format(label), function()
        local file_set, err = try_from_json({ baseDirectories = value })
        assert.is_nil(file_set)
        assert.are.equal(("baseDirectories is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when baseDirectories is a dict instead of a list", function()
      local file_set, err = try_from_json({ baseDirectories = { first = "include" } })
      assert.is_nil(file_set)
      assert.are.equal("baseDirectories is wrong type: table", err)
    end)

    it("returns an error when a base directory is not a string", function()
      local file_set, err = try_from_json({ baseDirectories = { 42 } })
      assert.is_nil(file_set)
      assert.are.equal("baseDirectories[1] is wrong type: number", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local file_set, err = FileSet.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(file_set), "futureField"))
    end)
  end)
end)
