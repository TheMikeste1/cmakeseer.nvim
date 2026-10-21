local InterfaceInclude = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.interface_include")

---A valid interface include JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    path = "/usr/include",
    isSystem = true,
    languages = { "CXX" },
    backtrace = 0,
  }, overrides or {})
end

---The interface include CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude interface_include
local function valid_interface_include()
  return {
    path = "/usr/include",
    is_system = true,
    languages = { "CXX" },
    backtrace = 0,
  }
end

---A valid interface include JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses an interface include object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceInclude? obj, string? err
local function try_from_json(overrides)
  return InterfaceInclude.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.InterfaceInclude", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "interfaceInclude" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local interface_include, err = InterfaceInclude.try_from_json(value)
        assert.is_nil(interface_include)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local interface_include, err = InterfaceInclude.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_interface_include(), assert(interface_include))
    end)

    it("returns an error when path is missing", function()
      local interface_include, err = InterfaceInclude.try_from_json(json_without("path"))
      assert.is_nil(interface_include)
      assert.are.equal("path is wrong type: nil", err)
    end)

    it("returns an error when path is not a string", function()
      local interface_include, err = try_from_json({ path = 42 })
      assert.is_nil(interface_include)
      assert.are.equal("path is wrong type: number", err)
    end)

    it("leaves the is system flag false when the json omits it", function()
      local interface_include, err = InterfaceInclude.try_from_json(json_without("isSystem"))
      assert.is_nil(err)
      assert.is_false(assert(interface_include).is_system)
    end)

    it("returns an error when isSystem is not a boolean", function()
      local interface_include, err = try_from_json({ isSystem = "yes" })
      assert.is_nil(interface_include)
      assert.are.equal("isSystem is wrong type: string", err)
    end)

    it("leaves the languages absent when the json omits them", function()
      local interface_include, err = InterfaceInclude.try_from_json(json_without("languages"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_include).languages)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "languages" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when languages is %s"):format(label), function()
        local interface_include, err = try_from_json({ languages = value })
        assert.is_nil(interface_include)
        assert.are.equal(("languages is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when a language is not a string", function()
      local interface_include, err = try_from_json({ languages = { "CXX", 42 } })
      assert.is_nil(interface_include)
      assert.are.equal("languages[2] is wrong type: number", err)
    end)

    it("leaves the backtrace absent when the json omits it", function()
      local interface_include, err = InterfaceInclude.try_from_json(json_without("backtrace"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_include).backtrace)
    end)

    it("returns an error when backtrace is not a number", function()
      local interface_include, err = try_from_json({ backtrace = "0" })
      assert.is_nil(interface_include)
      assert.are.equal("backtrace is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local interface_include, err = InterfaceInclude.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(interface_include), "futureField"))
    end)
  end)
end)
