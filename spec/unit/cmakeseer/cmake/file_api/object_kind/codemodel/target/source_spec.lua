local Source = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.source")

---A valid source JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    path = "main.cpp",
    compileGroupIndex = 0,
    sourceGroupIndex = 0,
    isGenerated = false,
    fileSetIndexes = { 0 },
    backtraces = { 0 },
    backtrace = 0,
  }, overrides or {})
end

---The source CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source source
local function valid_source()
  return {
    path = "main.cpp",
    compile_group_index = 0,
    source_group_index = 0,
    generated = false,
    file_set_indexes = { 0 },
    backtraces = { 0, 0 },
  }
end

---A valid source JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a source object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Source? obj, string? err
local function try_from_json(overrides)
  return Source.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.Source", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "source" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local source, err = Source.try_from_json(value)
        assert.is_nil(source)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local source, err = Source.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_source(), assert(source))
    end)

    it("returns an error when path is missing", function()
      local source, err = Source.try_from_json(json_without("path"))
      assert.is_nil(source)
      assert.are.equal("path is wrong type: nil", err)
    end)

    it("returns an error when path is not a string", function()
      local source, err = try_from_json({ path = 42 })
      assert.is_nil(source)
      assert.are.equal("path is wrong type: number", err)
    end)

    it("leaves the compile group index absent when the json omits it", function()
      local source, err = Source.try_from_json(json_without("compileGroupIndex"))
      assert.is_nil(err)
      assert.is_nil(assert(source).compile_group_index)
    end)

    it("returns an error when compileGroupIndex is not a number", function()
      local source, err = try_from_json({ compileGroupIndex = "0" })
      assert.is_nil(source)
      assert.are.equal("compileGroupIndex is wrong type: string", err)
    end)

    it("leaves the source group index absent when the json omits it", function()
      local source, err = Source.try_from_json(json_without("sourceGroupIndex"))
      assert.is_nil(err)
      assert.is_nil(assert(source).source_group_index)
    end)

    it("returns an error when sourceGroupIndex is not a number", function()
      local source, err = try_from_json({ sourceGroupIndex = "0" })
      assert.is_nil(source)
      assert.are.equal("sourceGroupIndex is wrong type: string", err)
    end)

    it("leaves the generated flag false when the json omits it", function()
      local source, err = Source.try_from_json(json_without("isGenerated"))
      assert.is_nil(err)
      assert.is_false(assert(source).generated)
    end)

    it("returns an error when isGenerated is not a boolean", function()
      local source, err = try_from_json({ isGenerated = "yes" })
      assert.is_nil(source)
      assert.are.equal("isGenerated is wrong type: string", err)
    end)

    it("leaves the file set indexes absent when the json omits them", function()
      local source, err = Source.try_from_json(json_without("fileSetIndexes"))
      assert.is_nil(err)
      assert.is_nil(assert(source).file_set_indexes)
    end)

    it("supports the legacy fileSetIndex field", function()
      local source, err = Source.try_from_json({ path = "main.cpp", fileSetIndex = 0 })
      assert.is_nil(err)
      assert.are.same({ path = "main.cpp", compile_group_index = nil, source_group_index = nil, generated = false, file_set_indexes = { 0 }, backtraces = nil }, assert(source))
    end)

    it("returns an error when fileSetIndexes is not a list", function()
      local source, err = try_from_json({ fileSetIndexes = "indexes" })
      assert.is_nil(source)
      assert.are.equal("fileSetIndexes is wrong type: string", err)
    end)

    it("returns an error when a file set index is not a number", function()
      local source, err = try_from_json({ fileSetIndexes = { "0" } })
      assert.is_nil(source)
      assert.are.equal("fileSetIndexes[1] is wrong type: string", err)
    end)

    it("leaves the backtraces absent when the json omits them", function()
      local json = json_without("backtraces")
      json.backtrace = nil
      local source, err = Source.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(assert(source).backtraces)
    end)

    it("returns an error when backtraces is not a list", function()
      local source, err = try_from_json({ backtraces = "traces" })
      assert.is_nil(source)
      assert.are.equal("backtraces is wrong type: string", err)
    end)

    it("returns an error when a backtrace is not a number", function()
      local source, err = try_from_json({ backtraces = { "0" } })
      assert.is_nil(source)
      assert.are.equal("backtraces[1] is wrong type: string", err)
    end)

    it("combines the backtrace field into backtraces", function()
      local source, err = Source.try_from_json({ path = "main.cpp", backtrace = 0 })
      assert.is_nil(err)
      assert.are.same({ { path = "main.cpp", compile_group_index = nil, source_group_index = nil, generated = false, file_set_indexes = nil, backtraces = { 0 } } }, { assert(source) })
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local source, err = Source.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(source), "futureField"))
    end)
  end)
end)
