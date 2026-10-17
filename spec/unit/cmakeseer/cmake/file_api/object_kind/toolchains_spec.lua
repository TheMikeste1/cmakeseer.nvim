local Toolchains = require("cmakeseer.cmake.file_api.object_kind.toolchains")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local tmpdir = require("spec.fixtures.tmpdir")

---A valid toolchains object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    kind = "toolchains",
    version = { major = 1, minor = 0 },
    toolchains = {
      {
        language = "C",
        compiler = {
          path = "/usr/bin/cc",
          id = "GNU",
          version = "9.3.0",
          implicit = {
            includeDirectories = { "/usr/include" },
            linkDirectories = { "/usr/lib" },
            linkFrameworkDirectories = {},
            linkLibraries = { "gcc", "c" },
          },
        },
        sourceFileExtensions = { "c", "m" },
      },
      {
        language = "CXX",
        compiler = {
          path = "/usr/bin/c++",
          id = "GNU",
          version = "9.3.0",
          implicit = {
            includeDirectories = { "/usr/include/c++/9", "/usr/include" },
            linkDirectories = { "/usr/lib" },
            linkFrameworkDirectories = {},
            linkLibraries = { "stdc++", "gcc", "c" },
          },
        },
        sourceFileExtensions = { "C", "cc", "cpp", "cxx" },
      },
    },
  }, overrides or {})
end

---The toolchain entries as they should parse from valid_json().
---@return cmakeseer.cmake.file_api.object_kind.Toolchains.Entry[]
local function valid_toolchains()
  return {
    {
      language = "C",
      compiler = {
        path = "/usr/bin/cc",
        command_fragment = nil,
        id = "GNU",
        version = "9.3.0",
        target = nil,
        implicit = {
          include_directories = { "/usr/include" },
          link_directories = { "/usr/lib" },
          link_framework_directories = {},
          link_libraries = { "gcc", "c" },
        },
      },
      source_file_extensions = { "c", "m" },
    },
    {
      language = "CXX",
      compiler = {
        path = "/usr/bin/c++",
        command_fragment = nil,
        id = "GNU",
        version = "9.3.0",
        target = nil,
        implicit = {
          include_directories = { "/usr/include/c++/9", "/usr/include" },
          link_directories = { "/usr/lib" },
          link_framework_directories = {},
          link_libraries = { "stdc++", "gcc", "c" },
        },
      },
      source_file_extensions = { "C", "cc", "cpp", "cxx" },
    },
  }
end

---A valid toolchains object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

---A valid toolchains object with a single version field removed.
---@param field string The version field to remove.
---@return table<string, any> json
local function json_without_version_field(field)
  local json = valid_json()
  json.version[field] = nil
  return json
end

describe("Toolchains", function()
  local tmp = tmpdir()

  describe("new", function()
    it("initializes correctly", function()
      local toolchains = Toolchains.new({ major = 1, minor = 0 }, valid_toolchains())
      assert.are.equal(object_kind.ObjectKindType.Toolchains, toolchains.kind)
      assert.are.equal(1, toolchains.version.major)
      assert.are.equal(0, toolchains.version.minor)
      assert.are.same(valid_toolchains(), toolchains.toolchains)
    end)

    it("does not share the version or toolchains with the caller", function()
      local version = { major = 1, minor = 0 }
      local entries = valid_toolchains()

      local toolchains = Toolchains.new(version, entries)
      version.major = 9
      entries[1].language = "FORTRAN"

      assert.are.equal(1, toolchains.version.major)
      assert.are.equal("C", toolchains.toolchains[1].language)
    end)

    it("accepts an empty list of toolchains", function()
      local toolchains = Toolchains.new({ major = 1, minor = 0 }, {})
      assert.are.same({}, toolchains.toolchains)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local toolchains = Toolchains.take({ major = 1, minor = 0 }, valid_toolchains())
      assert.are.equal(object_kind.ObjectKindType.Toolchains, toolchains.kind)
      assert.are.same({ major = 1, minor = 0 }, toolchains.version)
      assert.are.same(valid_toolchains(), toolchains.toolchains)
    end)

    it("takes ownership instead of copying", function()
      local version = { major = 1, minor = 0 }
      local entries = valid_toolchains()

      local toolchains = Toolchains.take(version, entries)
      version.major = 9
      entries[1].language = "FORTRAN"

      assert.are.equal(9, toolchains.version.major)
      assert.are.equal("FORTRAN", toolchains.toolchains[1].language)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "text" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local result, err = Toolchains.try_from_json(value)
        assert.is_nil(result)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local toolchains, err = Toolchains.try_from_json(valid_json())
      assert.is_nil(err)
      local instance = assert(toolchains)
      assert.are.equal(object_kind.ObjectKindType.Toolchains, instance.kind)
      assert.are.equal(1, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.same(valid_toolchains(), instance.toolchains)
    end)

    it("accepts an empty list of toolchains", function()
      local toolchains, err = Toolchains.try_from_json(valid_json({ toolchains = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(toolchains).toolchains)
    end)

    it("preserves the order of the toolchains", function()
      local json = valid_json()
      json.toolchains = { json.toolchains[2], json.toolchains[1] }

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      local entries = assert(toolchains).toolchains
      assert.are.equal("CXX", entries[1].language)
      assert.are.equal("C", entries[2].language)
    end)

    it("returns an error when the kind is missing", function()
      local toolchains, err = Toolchains.try_from_json(json_without("kind"))
      assert.is_nil(toolchains)
      assert.are.equal("Incorrect kind: nil", err)
    end)

    it("returns an error when the kind is a different object kind", function()
      local toolchains, err = Toolchains.try_from_json(valid_json({ kind = "cache" }))
      assert.is_nil(toolchains)
      assert.are.equal('Incorrect kind: "cache"', err)
    end)

    it("returns an error when version is missing", function()
      local toolchains, err = Toolchains.try_from_json(json_without("version"))
      assert.is_nil(toolchains)
      assert.are.equal("version is wrong type: nil", err)
    end)

    it("returns an error when version is not a table", function()
      local toolchains, err = Toolchains.try_from_json(valid_json({ version = 1 }))
      assert.is_nil(toolchains)
      assert.are.equal("version is wrong type: number", err)
    end)

    it("returns an error when version.major is missing", function()
      local toolchains, err = Toolchains.try_from_json(json_without_version_field("major"))
      assert.is_nil(toolchains)
      assert.are.equal("version.major is wrong type: nil", err)
    end)

    it("returns an error when version.minor is missing", function()
      local toolchains, err = Toolchains.try_from_json(json_without_version_field("minor"))
      assert.is_nil(toolchains)
      assert.are.equal("version.minor is wrong type: nil", err)
    end)

    it("returns an error when toolchains is missing", function()
      local toolchains, err = Toolchains.try_from_json(json_without("toolchains"))
      assert.is_nil(toolchains)
      assert.are.equal("toolchains is wrong type: nil", err)
    end)

    it("returns an error when toolchains is not a list", function()
      local toolchains, err = Toolchains.try_from_json(valid_json({ toolchains = { C = {} } }))
      assert.is_nil(toolchains)
      assert.are.equal("toolchains is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "string", "C" },
      { "userdata", vim.NIL },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when a toolchain entry is a %s"):format(label), function()
        local toolchains, err = Toolchains.try_from_json(valid_json({ toolchains = { value } }))
        assert.is_nil(toolchains)
        assert.are.equal(("toolchain at index 1: json is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("reports the index of the invalid toolchain entry", function()
      local json = valid_json()
      json.toolchains[3] = 42

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 3: json is wrong type: number", err)
    end)

    it("returns an error when language is missing", function()
      local json = valid_json()
      json.toolchains[1].language = nil

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: language is wrong type: nil", err)
    end)

    it("returns an error when language is not a string", function()
      local json = valid_json()
      json.toolchains[1].language = 42

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: language is wrong type: number", err)
    end)

    it("returns an error when compiler is missing", function()
      local json = valid_json()
      json.toolchains[1].compiler = nil

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler is wrong type: nil", err)
    end)

    it("returns an error when compiler is not a table", function()
      local json = valid_json()
      json.toolchains[1].compiler = "gcc"

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler is wrong type: string", err)
    end)

    it("returns an error when compiler.implicit is missing", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit = nil

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit is wrong type: nil", err)
    end)

    it("returns an error when compiler.implicit is not a table", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit = "implicit"

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit is wrong type: string", err)
    end)

    -- Optional compiler fields: present when non-nil, absent when nil.
    it("accepts a compiler with no optional fields", function()
      local json = valid_json({
        toolchains = {
          {
            language = "C",
            compiler = { implicit = {} },
          },
        },
      })

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      local compiler = assert(toolchains).toolchains[1].compiler
      assert.is_nil(compiler.path)
      assert.is_nil(compiler.command_fragment)
      assert.is_nil(compiler.id)
      assert.is_nil(compiler.version)
      assert.is_nil(compiler.target)
    end)

    it("accepts compiler.path when present", function()
      local json = valid_json()
      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("/usr/bin/cc", assert(toolchains).toolchains[1].compiler.path)
    end)

    it("returns an error when compiler.path is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.path = 42

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.path is wrong type: number", err)
    end)

    it("accepts compiler.commandFragment when present", function()
      local json = valid_json()
      json.toolchains[1].compiler.commandFragment = "--config x86_64.cfg"

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("--config x86_64.cfg", assert(toolchains).toolchains[1].compiler.command_fragment)
    end)

    it("returns an error when compiler.commandFragment is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.commandFragment = true

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.commandFragment is wrong type: boolean", err)
    end)

    it("accepts compiler.id when present", function()
      local json = valid_json()
      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("GNU", assert(toolchains).toolchains[1].compiler.id)
    end)

    it("returns an error when compiler.id is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.id = 42

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.id is wrong type: number", err)
    end)

    it("accepts compiler.version when present", function()
      local json = valid_json()
      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("9.3.0", assert(toolchains).toolchains[1].compiler.version)
    end)

    it("returns an error when compiler.version is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.version = 9

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.version is wrong type: number", err)
    end)

    it("accepts compiler.target when present", function()
      local json = valid_json()
      json.toolchains[1].compiler.target = "x86_64-linux-gnu"

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.are.equal("x86_64-linux-gnu", assert(toolchains).toolchains[1].compiler.target)
    end)

    it("returns an error when compiler.target is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.target = true

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.target is wrong type: boolean", err)
    end)

    it("accepts an empty implicit object", function()
      local json = valid_json({
        toolchains = { { language = "C", compiler = { implicit = {} } } },
      })

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      local implicit = assert(toolchains).toolchains[1].compiler.implicit
      assert.is_nil(implicit.include_directories)
      assert.is_nil(implicit.link_directories)
      assert.is_nil(implicit.link_framework_directories)
      assert.is_nil(implicit.link_libraries)
    end)

    it("parses implicit.includeDirectories", function()
      local toolchains, err = Toolchains.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same({ "/usr/include" }, assert(toolchains).toolchains[1].compiler.implicit.include_directories)
    end)

    it("returns an error when implicit.includeDirectories is not a list", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit.includeDirectories = "/usr/include"

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit.includeDirectories is wrong type: string", err)
    end)

    it("returns an error when an implicit.includeDirectories element is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit.includeDirectories = { "/usr/include", 42 }

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit.includeDirectories at index 2 is wrong type: number", err)
    end)

    it("parses implicit.linkDirectories", function()
      local toolchains, err = Toolchains.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same({ "/usr/lib" }, assert(toolchains).toolchains[1].compiler.implicit.link_directories)
    end)

    it("returns an error when an implicit.linkDirectories element is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit.linkDirectories = { "/usr/lib", true }

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit.linkDirectories at index 2 is wrong type: boolean", err)
    end)

    it("parses implicit.linkFrameworkDirectories as an empty list", function()
      local toolchains, err = Toolchains.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same({}, assert(toolchains).toolchains[1].compiler.implicit.link_framework_directories)
    end)

    it("returns an error when an implicit.linkFrameworkDirectories element is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit.linkFrameworkDirectories = { 99 }

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit.linkFrameworkDirectories at index 1 is wrong type: number", err)
    end)

    it("parses implicit.linkLibraries", function()
      local toolchains, err = Toolchains.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same({ "gcc", "c" }, assert(toolchains).toolchains[1].compiler.implicit.link_libraries)
    end)

    it("returns an error when an implicit.linkLibraries element is not a string", function()
      local json = valid_json()
      json.toolchains[1].compiler.implicit.linkLibraries = { "gcc", {} }

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: compiler.implicit.linkLibraries at index 2 is wrong type: table", err)
    end)

    it("accepts absent sourceFileExtensions", function()
      local json = valid_json()
      json.toolchains[1].sourceFileExtensions = nil

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(assert(toolchains).toolchains[1].source_file_extensions)
    end)

    it("parses sourceFileExtensions when present", function()
      local toolchains, err = Toolchains.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same({ "c", "m" }, assert(toolchains).toolchains[1].source_file_extensions)
    end)

    it("returns an error when sourceFileExtensions is not a list", function()
      local json = valid_json()
      json.toolchains[1].sourceFileExtensions = "c"

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: sourceFileExtensions is wrong type: string", err)
    end)

    it("returns an error when a sourceFileExtensions element is not a string", function()
      local json = valid_json()
      json.toolchains[1].sourceFileExtensions = { "c", 42 }

      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: sourceFileExtensions at index 2 is wrong type: number", err)
    end)

    it("does not share toolchains with the json", function()
      local json = valid_json()
      local toolchains = assert(Toolchains.try_from_json(json))

      json.toolchains[1].language = "FORTRAN"
      json.toolchains[1].compiler.path = "/usr/bin/gfortran"
      table.remove(json.toolchains, 2)

      assert.are.equal("C", toolchains.toolchains[1].language)
      assert.are.equal(2, #toolchains.toolchains)
    end)

    it("ignores unknown top-level fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(toolchains), "futureField"))
    end)

    it("validates the version before the toolchains", function()
      local json = valid_json({ version = "1", toolchains = 42 })
      local toolchains, err = Toolchains.try_from_json(json)
      assert.is_nil(toolchains)
      assert.are.equal("version is wrong type: string", err)
    end)
  end)

  describe("try_from_file", function()
    --- Writes JSON to a file in the test's temporary directory.
    ---@param contents string The exact bytes to write.
    ---@return string path The path to the written file.
    local function write(contents)
      local path = vim.fs.joinpath(tmp.path, "toolchains-v1-0123456789abcdef.json")
      require("spec.utils").write_file(path, contents)
      return path
    end

    it("creates an instance from a valid file", function()
      local path = write(vim.json.encode(valid_json()))

      local toolchains, err = Toolchains.try_from_file(path)
      assert.is_nil(err)
      local instance = assert(toolchains)
      assert.are.equal(object_kind.ObjectKindType.Toolchains, instance.kind)
      assert.are.equal(1, instance.version.major)
      assert.are.equal(0, instance.version.minor)
      assert.are.same(valid_toolchains(), instance.toolchains)
    end)

    it("returns the entry error of the file it could not parse", function()
      local json = vim.json.encode(valid_json({ toolchains = { { language = 42 } } }))

      local toolchains, err = Toolchains.try_from_file(write(json))
      assert.is_nil(toolchains)
      assert.are.equal("toolchain at index 1: language is wrong type: number", err)
    end)

    it("returns an error when the file does not exist", function()
      local toolchains, err = Toolchains.try_from_file(vim.fs.joinpath(tmp.path, "missing.json"))
      assert.is_nil(toolchains)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)

    it("returns an error when the path is a directory", function()
      local dir = vim.fs.joinpath(tmp.path, "directory")
      vim.fn.mkdir(dir, "p")

      local toolchains, err = Toolchains.try_from_file(dir)
      assert.is_nil(toolchains)
      assert.are.equal(("Failed to read %s: Is a directory"):format(dir), err)
    end)

    it("returns an error when the file is not JSON", function()
      local toolchains, err = Toolchains.try_from_file(write("not json"))
      assert.is_nil(toolchains)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)

    it("returns an error when the JSON does not describe a toolchains object", function()
      local toolchains, err = Toolchains.try_from_file(write(vim.json.encode(valid_json({ kind = "cache" }))))
      assert.is_nil(toolchains)
      assert.are.equal('Incorrect kind: "cache"', err)
    end)
  end)
end)
