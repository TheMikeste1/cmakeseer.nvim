local LinkLibrary = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.link_library")

---A valid link library JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    id = "codemodel_math::@1",
    fragment = "-lmath",
    backtrace = 0,
    fromDependency = { id = "codemodel_math::@1" },
  }, overrides or {})
end

---The link library CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary link_library
local function valid_link_library()
  return {
    id = "codemodel_math::@1",
    fragment = "-lmath",
    backtrace = 0,
    from_dependency = { id = "codemodel_math::@1" },
  }
end

---A valid link library JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a link library object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.LinkLibrary? obj, string? err
local function try_from_json(overrides)
  return LinkLibrary.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.LinkLibrary", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "linkLibrary" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local link_library, err = LinkLibrary.try_from_json(value)
        assert.is_nil(link_library)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local link_library, err = LinkLibrary.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_link_library(), assert(link_library))
    end)

    it("leaves the id absent when the json omits it", function()
      local link_library, err = LinkLibrary.try_from_json(json_without("id"))
      assert.is_nil(err)
      assert.is_nil(assert(link_library).id)
    end)

    it("returns an error when id is not a string", function()
      local link_library, err = try_from_json({ id = 42 })
      assert.is_nil(link_library)
      assert.are.equal("id is wrong type: number", err)
    end)

    it("leaves the fragment absent when the json omits it", function()
      local link_library, err = LinkLibrary.try_from_json(json_without("fragment"))
      assert.is_nil(err)
      assert.is_nil(assert(link_library).fragment)
    end)

    it("returns an error when fragment is not a string", function()
      local link_library, err = try_from_json({ fragment = 42 })
      assert.is_nil(link_library)
      assert.are.equal("fragment is wrong type: number", err)
    end)

    it("leaves the backtrace absent when the json omits it", function()
      local link_library, err = LinkLibrary.try_from_json(json_without("backtrace"))
      assert.is_nil(err)
      assert.is_nil(assert(link_library).backtrace)
    end)

    it("returns an error when backtrace is not a number", function()
      local link_library, err = try_from_json({ backtrace = "0" })
      assert.is_nil(link_library)
      assert.are.equal("backtrace is wrong type: string", err)
    end)

    it("leaves the from dependency absent when the json omits it", function()
      local link_library, err = LinkLibrary.try_from_json(json_without("fromDependency"))
      assert.is_nil(err)
      assert.is_nil(assert(link_library).from_dependency)
    end)

    it("returns an error when fromDependency is not a table", function()
      local link_library, err = try_from_json({ fromDependency = "id" })
      assert.is_nil(link_library)
      assert.are.equal("fromDependency is wrong type: string", err)
    end)

    it("returns an error when the id of fromDependency is missing", function()
      local link_library, err = try_from_json({ fromDependency = {} })
      assert.is_nil(link_library)
      assert.are.equal("fromDependency.id is wrong type: nil", err)
    end)

    it("returns an error when the id of fromDependency is not a string", function()
      local link_library, err = try_from_json({ fromDependency = { id = 42 } })
      assert.is_nil(link_library)
      assert.are.equal("fromDependency.id is wrong type: number", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local link_library, err = LinkLibrary.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(link_library), "futureField"))
    end)
  end)
end)
