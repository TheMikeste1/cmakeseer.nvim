local SourceGroup = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.source_group")

---A valid source group JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    name = "Source Files",
    sourceIndexes = { 0 },
    interfaceSourceIndexes = { 0 },
  }, overrides or {})
end

---The source group CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup source_group
local function valid_source_group()
  return {
    name = "Source Files",
    source_indexes = { 0 },
    interface_source_indexes = { 0 },
  }
end

---A valid source group JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a source group object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.SourceGroup? obj, string? err
local function try_from_json(overrides)
  return SourceGroup.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.SourceGroup", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "sourceGroup" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local source_group, err = SourceGroup.try_from_json(value)
        assert.is_nil(source_group)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local source_group, err = SourceGroup.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_source_group(), assert(source_group))
    end)

    it("returns an error when name is missing", function()
      local source_group, err = SourceGroup.try_from_json(json_without("name"))
      assert.is_nil(source_group)
      assert.are.equal("name is wrong type: nil", err)
    end)

    it("returns an error when name is not a string", function()
      local source_group, err = try_from_json({ name = 42 })
      assert.is_nil(source_group)
      assert.are.equal("name is wrong type: number", err)
    end)

    it("returns an error when sourceIndexes is missing", function()
      local source_group, err = SourceGroup.try_from_json(json_without("sourceIndexes"))
      assert.is_nil(source_group)
      assert.are.equal("sourceIndexes is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "sourceIndexes" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when sourceIndexes is %s"):format(label), function()
        local source_group, err = try_from_json({ sourceIndexes = value })
        assert.is_nil(source_group)
        assert.are.equal(("sourceIndexes is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when sourceIndexes is a dict instead of a list", function()
      local source_group, err = try_from_json({ sourceIndexes = { first = 0 } })
      assert.is_nil(source_group)
      assert.are.equal("sourceIndexes is wrong type: table", err)
    end)

    it("returns an error when a source index is not a number", function()
      local source_group, err = try_from_json({ sourceIndexes = { "0" } })
      assert.is_nil(source_group)
      assert.are.equal("sourceIndexes[1] is wrong type: string", err)
    end)

    it("leaves the interface source indexes absent when the json omits them", function()
      local source_group, err = SourceGroup.try_from_json(json_without("interfaceSourceIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(source_group).interface_source_indexes)
    end)

    it("returns an error when interfaceSourceIndexes is not a list", function()
      local source_group, err = try_from_json({ interfaceSourceIndexes = "indexes" })
      assert.is_nil(source_group)
      assert.are.equal("interfaceSourceIndexes is wrong type: string", err)
    end)

    it("returns an error when an interface source index is not a number", function()
      local source_group, err = try_from_json({ interfaceSourceIndexes = { "0" } })
      assert.is_nil(source_group)
      assert.are.equal("interfaceSourceIndexes[1] is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local source_group, err = SourceGroup.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(source_group), "futureField"))
    end)
  end)
end)
