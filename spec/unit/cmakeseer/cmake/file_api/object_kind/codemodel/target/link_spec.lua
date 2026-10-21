local Link = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.link")

---A valid command fragment, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function command_fragment_json(overrides)
  return vim.tbl_extend("force", { fragment = "/usr/bin/ld", role = "flags" }, overrides or {})
end

---A valid link JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    language = "CXX",
    commandFragments = { command_fragment_json() },
    lto = true,
    sysroot = { path = "/" },
  }, overrides or {})
end

---The link CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link link
local function valid_link()
  return {
    language = "CXX",
    command_fragments = { { fragment = "/usr/bin/ld", role = "flags", backtrace = nil } },
    lto = true,
    sysroot = "/",
  }
end

---A valid link JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a link object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Link? obj, string? err
local function try_from_json(overrides)
  return Link.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.Link", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "link" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local link, err = Link.try_from_json(value)
        assert.is_nil(link)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local link, err = Link.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_link(), assert(link))
    end)

    it("returns an error when language is missing", function()
      local link, err = Link.try_from_json(json_without("language"))
      assert.is_nil(link)
      assert.are.equal("language is wrong type: nil", err)
    end)

    it("returns an error when language is not a string", function()
      local link, err = try_from_json({ language = 42 })
      assert.is_nil(link)
      assert.are.equal("language is wrong type: number", err)
    end)

    it("leaves the command fragments absent when the json omits them", function()
      local link, err = Link.try_from_json(json_without("commandFragments"))
      assert.is_nil(err)
      assert.is_nil(assert(link).command_fragments)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "commandFragments" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when commandFragments is %s"):format(label), function()
        local link, err = try_from_json({ commandFragments = value })
        assert.is_nil(link)
        assert.are.equal(("commandFragments is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when commandFragments is a dict instead of a list", function()
      local link, err = try_from_json({ commandFragments = { first = command_fragment_json() } })
      assert.is_nil(link)
      assert.are.equal("commandFragments is wrong type: table", err)
    end)

    it("reports the index of the command fragment it could not parse", function()
      local link, err = try_from_json({
        commandFragments = { command_fragment_json(), { fragment = 42, role = "flags" } },
      })
      assert.is_nil(link)
      assert.are.equal("commandFragments[2].fragment is wrong type: number", err)
    end)

    it("returns an error when a command fragment is not a table", function()
      local link, err = try_from_json({ commandFragments = { "fragment" } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1] is wrong type: string", err)
    end)

    it("returns an error when the fragment of a command fragment is missing", function()
      local link, err = try_from_json({ commandFragments = { { role = "flags" } } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1].fragment is wrong type: nil", err)
    end)

    it("returns an error when the fragment of a command fragment is not a string", function()
      local link, err = try_from_json({ commandFragments = { { fragment = 42, role = "flags" } } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1].fragment is wrong type: number", err)
    end)

    it("returns an error when the role of a command fragment is missing", function()
      local link, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ld" } } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1].role is wrong type: nil", err)
    end)

    it("returns an error when the role of a command fragment is not a string", function()
      local link, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ld", role = 42 } } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1].role is wrong type: number", err)
    end)

    for _, entry in ipairs({
      { "flags", "flags" },
      { "libraries", "libraries" },
      { "libraryPath", "libraryPath" },
      { "frameworkPath", "frameworkPath" },
    }) do
      local role, expected = entry[1], entry[2]
      it(("records the role %s"):format(role), function()
        local link, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ld", role = role } } })
        assert.is_nil(err)
        assert.are.equal(expected, assert(link).command_fragments[1].role)
      end)
    end

    it("returns an error when the role of a command fragment is not a value CMake writes", function()
      local link, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ld", role = "invalid" } } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1].role is invalid: invalid", err)
    end)

    it("returns an error when the backtrace of a command fragment is not a number", function()
      local link, err = try_from_json({ commandFragments = { { fragment = "/usr/bin/ld", role = "flags", backtrace = "0" } } })
      assert.is_nil(link)
      assert.are.equal("commandFragments[1].backtrace is wrong type: string", err)
    end)

    it("records the lto flag the json reports", function()
      local link, err = try_from_json({ lto = false })
      assert.is_nil(err)
      assert.is_false(assert(link).lto)
    end)

    it("leaves the lto flag false when the json omits it", function()
      local link, err = Link.try_from_json(json_without("lto"))
      assert.is_nil(err)
      assert.is_false(assert(link).lto)
    end)

    it("returns an error when lto is not a boolean", function()
      local link, err = try_from_json({ lto = "yes" })
      assert.is_nil(link)
      assert.are.equal("lto is wrong type: string", err)
    end)

    it("leaves the sysroot absent when the json omits it", function()
      local link, err = Link.try_from_json(json_without("sysroot"))
      assert.is_nil(err)
      assert.is_nil(assert(link).sysroot)
    end)

    it("returns an error when the sysroot is not a table", function()
      local link, err = try_from_json({ sysroot = "/" })
      assert.is_nil(link)
      assert.are.equal("sysroot is wrong type: string", err)
    end)

    it("returns an error when the sysroot path is missing", function()
      local link, err = try_from_json({ sysroot = {} })
      assert.is_nil(link)
      assert.are.equal("sysroot.path is wrong type: nil", err)
    end)

    it("returns an error when the sysroot path is not a string", function()
      local link, err = try_from_json({ sysroot = { path = 42 } })
      assert.is_nil(link)
      assert.are.equal("sysroot.path is wrong type: number", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local link, err = Link.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(link), "futureField"))
    end)
  end)
end)
