local InterfaceLinkLibrary = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.interface_link_library")

---A valid interface link library JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    id = "codemodel_example_headers::@2",
    fragment = "-lheaders",
    backtrace = 0,
  }, overrides or {})
end

---The interface link library CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary interface_link_library
local function valid_interface_link_library()
  return {
    id = "codemodel_example_headers::@2",
    fragment = "-lheaders",
    backtrace = 0,
  }
end

---A valid interface link library JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses an interface link library object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.InterfaceLinkLibrary? obj, string? err
local function try_from_json(overrides)
  return InterfaceLinkLibrary.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.InterfaceLinkLibrary", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "interfaceLinkLibrary" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local interface_link_library, err = InterfaceLinkLibrary.try_from_json(value)
        assert.is_nil(interface_link_library)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local interface_link_library, err = InterfaceLinkLibrary.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_interface_link_library(), assert(interface_link_library))
    end)

    it("leaves the id absent when the json omits it", function()
      local interface_link_library, err = InterfaceLinkLibrary.try_from_json(json_without("id"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_link_library).id)
    end)

    it("returns an error when id is not a string", function()
      local interface_link_library, err = try_from_json({ id = 42 })
      assert.is_nil(interface_link_library)
      assert.are.equal("id is wrong type: number", err)
    end)

    it("leaves the fragment absent when the json omits it", function()
      local interface_link_library, err = InterfaceLinkLibrary.try_from_json(json_without("fragment"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_link_library).fragment)
    end)

    it("returns an error when fragment is not a string", function()
      local interface_link_library, err = try_from_json({ fragment = 42 })
      assert.is_nil(interface_link_library)
      assert.are.equal("fragment is wrong type: number", err)
    end)

    it("leaves the backtrace absent when the json omits it", function()
      local interface_link_library, err = InterfaceLinkLibrary.try_from_json(json_without("backtrace"))
      assert.is_nil(err)
      assert.is_nil(assert(interface_link_library).backtrace)
    end)

    it("returns an error when backtrace is not a number", function()
      local interface_link_library, err = try_from_json({ backtrace = "0" })
      assert.is_nil(interface_link_library)
      assert.are.equal("backtrace is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local interface_link_library, err = InterfaceLinkLibrary.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(interface_link_library), "futureField"))
    end)
  end)
end)
