local Archive = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.archive")

---A valid command fragment, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function command_fragment_json(overrides)
  return vim.tbl_extend("force", { fragment = "/usr/bin/ar", role = "flags" }, overrides or {})
end

---A valid archive JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    commandFragments = { command_fragment_json() },
    lto = false,
  }, overrides or {})
end

---The archive CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive archive
local function valid_archive()
  return {
    command_fragments = { { fragment = "/usr/bin/ar", role = "flags", backtrace = nil } },
    lto = false,
  }
end

---A valid archive JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses an archive object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Archive? obj, string? err
local function try_from_json(overrides)
  return Archive.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.Archive", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "archive" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local archive, err = Archive.try_from_json(value)
        assert.is_nil(archive)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local archive, err = Archive.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_archive(), assert(archive))
    end)

    it("leaves command fragments absent when the json omits them", function()
      local archive, err = Archive.try_from_json(json_without("commandFragments"))
      assert.is_nil(err)
      assert.is_nil(assert(archive).command_fragments)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "commandFragments" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when commandFragments is %s"):format(label), function()
        local archive, err = try_from_json({ commandFragments = value })
        assert.is_nil(archive)
        assert.are.equal(("commandFragments is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when commandFragments is a dict instead of a list", function()
      local archive, err = try_from_json({ commandFragments = { first = command_fragment_json() } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments is wrong type: table", err)
    end)

    it("reports the index of the command fragment it could not parse", function()
      local archive, err = try_from_json({
        commandFragments = { command_fragment_json(), { fragment = 42, role = "flags" } },
      })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[2].fragment is wrong type: number", err)
    end)

    it("returns an error when a command fragment is not a table", function()
      local archive, err = try_from_json({ commandFragments = { "fragment" } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[1] is wrong type: string", err)
    end)

    it("returns an error when the fragment of a command fragment is missing", function()
      local archive, err = try_from_json({ commandFragments = { { role = "flags" } } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[1].fragment is wrong type: nil", err)
    end)

    it("returns an error when the fragment of a command fragment is not a string", function()
      local archive, err = try_from_json({ commandFragments = { { fragment = 42, role = "flags" } } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[1].fragment is wrong type: number", err)
    end)

    it("returns an error when the role of a command fragment is missing", function()
      local archive, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ar" } } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[1].role is wrong type: nil", err)
    end)

    it("returns an error when the role of a command fragment is not a string", function()
      local archive, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ar", role = 42 } } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[1].role is wrong type: number", err)
    end)

    it("returns an error when the role of a command fragment is not a value CMake writes", function()
      local archive, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ar", role = "libraries" } } })
      assert.is_nil(archive)
      assert.are.equal("commandFragments[1].role is invalid: libraries", err)
    end)

    it("records the lto flag the json reports", function()
      local archive, err = try_from_json({ lto = true })
      assert.is_nil(err)
      assert.is_true(assert(archive).lto)
    end)

    it("leaves the lto flag false when the json omits it", function()
      local archive, err = Archive.try_from_json(json_without("lto"))
      assert.is_nil(err)
      assert.is_false(assert(archive).lto)
    end)

    it("returns an error when lto is not a boolean", function()
      local archive, err = try_from_json({ lto = "yes" })
      assert.is_nil(archive)
      assert.are.equal("lto is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local archive, err = Archive.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(archive), "futureField"))
    end)
  end)
end)
