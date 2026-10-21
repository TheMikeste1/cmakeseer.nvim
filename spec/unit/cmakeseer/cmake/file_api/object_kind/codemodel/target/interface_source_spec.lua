local InterfaceSource = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.interface_source")

---A valid interface source JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    path = "interface.hpp",
    sourceGroupIndex = 0,
    isGenerated = false,
    fileSetIndexes = { 0 },
  }, overrides or {})
end

---The interface source CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource interface_source
local function valid_interface_source()
  return {
    path = "interface.hpp",
    source_group_index = 0,
    generated = false,
    file_set_indexes = { 0 },
  }
end

---A valid interface source JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses an interface source object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceSource? obj, string? err
local function try_from_json(overrides)
  return InterfaceSource.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.InterfaceSource", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "interfaceSource" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local interface_source, err = InterfaceSource.try_from_json(value)
        assert.is_nil(interface_source)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local interface_source, err = InterfaceSource.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_interface_source(), assert(interface_source))
    end)

    it("returns an error when path is missing", function()
      local interface_source, err = InterfaceSource.try_from_json(json_without("path"))
      assert.is_nil(interface_source)
      assert.are.equal("path is wrong type: nil", err)
    end)

    it("returns an error when path is not a string", function()
      local interface_source, err = try_from_json({ path = 42 })
      assert.is_nil(interface_source)
      assert.are.equal("path is wrong type: number", err)
    end)

    it("leaves the source group index absent when the json omits it", function()
      local interface_source, err = InterfaceSource.try_from_json(json_without("sourceGroupIndex"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_source).source_group_index)
    end)

    it("returns an error when sourceGroupIndex is not a number", function()
      local interface_source, err = try_from_json({ sourceGroupIndex = "0" })
      assert.is_nil(interface_source)
      assert.are.equal("sourceGroupIndex is wrong type: string", err)
    end)

    it("leaves the generated flag false when the json omits it", function()
      local interface_source, err = InterfaceSource.try_from_json(json_without("isGenerated"))
      assert.is_nil(err)
      assert.is_false(assert(interface_source).generated)
    end)

    it("returns an error when isGenerated is not a boolean", function()
      local interface_source, err = try_from_json({ isGenerated = "yes" })
      assert.is_nil(interface_source)
      assert.are.equal("isGenerated is wrong type: string", err)
    end)

    it("leaves the file set indexes absent when the json omits them", function()
      local interface_source, err = InterfaceSource.try_from_json(json_without("fileSetIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_source).file_set_indexes)
    end)

    it("supports the legacy fileSetIndex field", function()
      local interface_source, err = InterfaceSource.try_from_json({ path = "interface.hpp", fileSetIndex = 0 })
      assert.is_nil(err)
      assert.are.same({ { path = "interface.hpp", source_group_index = nil, generated = false, file_set_indexes = { 0 } } }, { assert(interface_source) })
    end)

    it("returns an error when fileSetIndexes is not a list", function()
      local interface_source, err = try_from_json({ fileSetIndexes = "indexes" })
      assert.is_nil(interface_source)
      assert.are.equal("fileSetIndexes is wrong type: string", err)
    end)

    it("returns an error when a file set index is not a number", function()
      local interface_source, err = try_from_json({ fileSetIndexes = { "0" } })
      assert.is_nil(interface_source)
      assert.are.equal("fileSetIndexes[1] is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local interface_source, err = InterfaceSource.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(interface_source), "futureField"))
    end)
  end)
end)
