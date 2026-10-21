local CompileGroup = require("cmakeseer.cmake.file_api.object_kind.codemodel.target.compile_group")

---A valid command fragment, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function command_fragment_json(overrides)
  return vim.tbl_extend("force", { fragment = "/usr/bin/gcc", role = "flags" }, overrides or {})
end

---A valid language standard, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function language_standard_json(overrides)
  return vim.tbl_extend("force", { standard = "20", backtraces = { 0 } }, overrides or {})
end

---A valid include, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function include_json(overrides)
  return vim.tbl_extend("force", { path = "/usr/include", isSystem = false, backtrace = 0 }, overrides or {})
end

---A valid framework, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function framework_json(overrides)
  return vim.tbl_extend("force", { path = "/System/Library/Frameworks", isSystem = true, backtrace = 0 }, overrides or {})
end

---A valid precompile header, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function precompile_header_json(overrides)
  return vim.tbl_extend("force", { header = "/tmp/pch.hpp", backtrace = 0 }, overrides or {})
end

---A valid define, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function define_json(overrides)
  return vim.tbl_extend("force", { define = "CMAKESEER_DEBUG", backtrace = 0 }, overrides or {})
end

---A valid compile group JSON object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    sourceIndexes = { 0 },
    language = "CXX",
    languageStandard = language_standard_json(),
    compileCommandFragments = { command_fragment_json() },
    includes = { include_json() },
    frameworks = { framework_json() },
    precompileHeaders = { precompile_header_json() },
    defines = { define_json() },
    sysroot = { path = "/" },
  }, overrides or {})
end

---The compile group CMake writes, as parsed from its json.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup compile_group
local function valid_compile_group()
  return {
    source_indexes = { 0 },
    language = "CXX",
    language_standard = { standard = "20", backtraces = { 0 } },
    compile_command_fragments = { { fragment = "/usr/bin/gcc", backtrace = nil } },
    includes = { { path = "/usr/include", is_system = false, backtrace = 0 } },
    frameworks = { { path = "/System/Library/Frameworks", is_system = true, backtrace = 0 } },
    precompile_headers = { { header = "/tmp/pch.hpp", backtrace = 0 } },
    defines = { { define = "CMAKESEER_DEBUG", backtrace = 0 } },
    sysroot = "/",
  }
end

---A valid compile group JSON object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

--- Parses a compile group object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.CompileGroup? obj, string? err
local function try_from_json(overrides)
  return CompileGroup.try_from_json(valid_json(overrides))
end

describe("object_kind.Codemodel.Target.CompileGroup", function()
  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "compileGroup" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local group, err = CompileGroup.try_from_json(value)
        assert.is_nil(group)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local group, err = CompileGroup.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_compile_group(), assert(group))
    end)

    it("leaves the language standard absent when the json omits it", function()
      local group, err = CompileGroup.try_from_json(json_without("languageStandard"))
      assert.is_nil(err)
      assert.is_nil(assert(group).language_standard)
    end)

    it("returns an error when the language standard is not a table", function()
      local group, err = try_from_json({ languageStandard = "20" })
      assert.is_nil(group)
      assert.are.equal("languageStandard is wrong type: string", err)
    end)

    it("returns an error when the language standard standard is missing", function()
      local group, err = try_from_json({ languageStandard = {} })
      assert.is_nil(group)
      assert.are.equal("languageStandard.standard is wrong type: nil", err)
    end)

    it("returns an error when the language standard backtraces is not a list", function()
      local group, err = try_from_json({ languageStandard = { standard = "20", backtraces = "traces" } })
      assert.is_nil(group)
      assert.are.equal("languageStandard.backtraces is wrong type: string", err)
    end)

    it("returns an error when sourceIndexes is missing", function()
      local group, err = CompileGroup.try_from_json(json_without("sourceIndexes"))
      assert.is_nil(group)
      assert.are.equal("sourceIndexes is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "sourceIndexes" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when sourceIndexes is %s"):format(label), function()
        local group, err = try_from_json({ sourceIndexes = value })
        assert.is_nil(group)
        assert.are.equal(("sourceIndexes is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when sourceIndexes is a dict instead of a list", function()
      local group, err = try_from_json({ sourceIndexes = { first = 0 } })
      assert.is_nil(group)
      assert.are.equal("sourceIndexes is wrong type: table", err)
    end)

    it("returns an error when a source index is not a number", function()
      local group, err = try_from_json({ sourceIndexes = { "0" } })
      assert.is_nil(group)
      assert.are.equal("sourceIndexes[1] is wrong type: string", err)
    end)

    it("returns an error when language is missing", function()
      local group, err = CompileGroup.try_from_json(json_without("language"))
      assert.is_nil(group)
      assert.are.equal("language is wrong type: nil", err)
    end)

    it("returns an error when language is not a string", function()
      local group, err = try_from_json({ language = 42 })
      assert.is_nil(group)
      assert.are.equal("language is wrong type: number", err)
    end)

    it("leaves the compile command fragments absent when the json omits them", function()
      local group, err = CompileGroup.try_from_json(json_without("compileCommandFragments"))
      assert.is_nil(err)
      assert.is_nil(assert(group).compile_command_fragments)
    end)

    it("returns an error when a command fragment is not a table", function()
      local group, err = try_from_json({ compileCommandFragments = { "fragment" } })
      assert.is_nil(group)
      assert.are.equal("compileCommandFragments[1] is wrong type: string", err)
    end)

    it("returns an error when the fragment of a command fragment is missing", function()
      local group, err = try_from_json({ compileCommandFragments = { { role = "flags" } } })
      assert.is_nil(group)
      assert.are.equal("compileCommandFragments[1].fragment is wrong type: nil", err)
    end)

    it("returns an error when the backtrace of a command fragment is not a number", function()
      local group, err = try_from_json({ compileCommandFragments = { { fragment = "/usr/bin/gcc", backtrace = "0" } } })
      assert.is_nil(group)
      assert.are.equal("compileCommandFragments[1].backtrace is wrong type: string", err)
    end)

    it("leaves the includes absent when the json omits them", function()
      local group, err = CompileGroup.try_from_json(json_without("includes"))
      assert.is_nil(err)
      assert.is_nil(assert(group).includes)
    end)

    it("returns an error when the path of an include is missing", function()
      local group, err = try_from_json({ includes = { { isSystem = false } } })
      assert.is_nil(group)
      assert.are.equal("includes[1].path is wrong type: nil", err)
    end)

    it("returns an error when the isSystem of an include is not a boolean", function()
      local group, err = try_from_json({ includes = { { path = "/usr/include", isSystem = "yes" } } })
      assert.is_nil(group)
      assert.are.equal("includes[1].isSystem is wrong type: string", err)
    end)

    it("leaves the frameworks absent when the json omits them", function()
      local group, err = CompileGroup.try_from_json(json_without("frameworks"))
      assert.is_nil(err)
      assert.is_nil(assert(group).frameworks)
    end)

    it("returns an error when the path of a framework is missing", function()
      local group, err = try_from_json({ frameworks = { { isSystem = true } } })
      assert.is_nil(group)
      assert.are.equal("frameworks[1].path is wrong type: nil", err)
    end)

    it("leaves the precompile headers absent when the json omits them", function()
      local group, err = CompileGroup.try_from_json(json_without("precompileHeaders"))
      assert.is_nil(err)
      assert.is_nil(assert(group).precompile_headers)
    end)

    it("returns an error when the header of a precompile header is missing", function()
      local group, err = try_from_json({ precompileHeaders = { {} } })
      assert.is_nil(group)
      assert.are.equal("precompileHeaders[1].header is wrong type: nil", err)
    end)

    it("leaves the defines absent when the json omits them", function()
      local group, err = CompileGroup.try_from_json(json_without("defines"))
      assert.is_nil(err)
      assert.is_nil(assert(group).defines)
    end)

    it("returns an error when the define of a define is missing", function()
      local group, err = try_from_json({ defines = { {} } })
      assert.is_nil(group)
      assert.are.equal("defines[1].define is wrong type: nil", err)
    end)

    it("leaves the sysroot absent when the json omits it", function()
      local group, err = CompileGroup.try_from_json(json_without("sysroot"))
      assert.is_nil(err)
      assert.is_nil(assert(group).sysroot)
    end)

    it("returns an error when the sysroot path is missing", function()
      local group, err = try_from_json({ sysroot = {} })
      assert.is_nil(group)
      assert.are.equal("sysroot.path is wrong type: nil", err)
    end)

    it("returns an error when the sysroot is not a table", function()
      local group, err = try_from_json({ sysroot = "/" })
      assert.is_nil(group)
      assert.are.equal("sysroot is wrong type: string", err)
    end)

    it("ignores unknown fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local group, err = CompileGroup.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(group), "futureField"))
    end)
  end)
end)
