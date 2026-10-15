local CMakeFiles = require("cmakeseer.cmake.file_api.object_kind.cmake_files")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local tmpdir = require("spec.fixtures.tmpdir")

---A valid cmakeFiles object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    kind = "cmakeFiles",
    version = { major = 1, minor = 1 },
    paths = { source = "/tmp/source", build = "/tmp/build" },
    inputs = {
      { path = "CMakeLists.txt" },
      { path = "sub/CMakeLists.txt" },
      { path = "/tmp/build/CMakeFiles/4.4.0/CMakeSystem.cmake", isGenerated = true },
      { path = "/tmp/third-party/module.cmake", isExternal = true },
      { path = "/tmp/cmake/Modules/CMakeGenericSystem.cmake", isCMake = true, isExternal = true },
    },
    globsDependent = {
      {
        expression = "/tmp/source/src/*.cxx",
        paths = { "/tmp/source/src/foo.cxx", "/tmp/source/src/bar.cxx" },
      },
      {
        expression = "/tmp/source/include/*.hxx",
        recurse = true,
        listDirectories = true,
        followSymlinks = true,
        relative = "include",
        paths = { "alpha.hxx" },
      },
    },
  }, overrides or {})
end

---The input files CMake writes, as parsed from their json.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input[]
local function valid_inputs()
  return {
    { path = "CMakeLists.txt", generated = false, external = false, is_cmake = false },
    { path = "sub/CMakeLists.txt", generated = false, external = false, is_cmake = false },
    { path = "/tmp/build/CMakeFiles/4.4.0/CMakeSystem.cmake", generated = true, external = false, is_cmake = false },
    { path = "/tmp/third-party/module.cmake", generated = false, external = true, is_cmake = false },
    { path = "/tmp/cmake/Modules/CMakeGenericSystem.cmake", generated = false, external = true, is_cmake = true },
  }
end

---The globs CMake writes, as parsed from their json.
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob[]
local function valid_globs()
  return {
    {
      expression = "/tmp/source/src/*.cxx",
      recurse = false,
      list_directories = false,
      follow_symlinks = false,
      relative = nil,
      paths = { "/tmp/source/src/foo.cxx", "/tmp/source/src/bar.cxx" },
    },
    {
      expression = "/tmp/source/include/*.hxx",
      recurse = true,
      list_directories = true,
      follow_symlinks = true,
      relative = "include",
      paths = { "alpha.hxx" },
    },
  }
end

---A valid cmakeFiles object with a single top-level field removed.
---@param field string The field to remove.
---@return table<string, any> json
local function json_without(field)
  local json = valid_json()
  json[field] = nil
  return json
end

---A valid cmakeFiles object with a single version field removed.
---@param field string The version field to remove.
---@return table<string, any> json
local function json_without_version_field(field)
  local json = valid_json()
  json.version[field] = nil
  return json
end

---A valid cmakeFiles object with a single paths field removed.
---@param field string The paths field to remove.
---@return table<string, any> json
local function json_without_paths_field(field)
  local json = valid_json()
  json.paths[field] = nil
  return json
end

describe("CMakeFiles", function()
  local tmp = tmpdir()

  describe("new", function()
    it("initializes correctly", function()
      local cmake_files = CMakeFiles.new({ major = 1, minor = 1 }, "/tmp/source", "/tmp/build", valid_inputs(), valid_globs())
      assert.are.equal(object_kind.ObjectKindType.CMakeFiles, cmake_files.kind)
      assert.are.same({ major = 1, minor = 1 }, cmake_files.version)
      assert.are.equal("/tmp/source", cmake_files.source)
      assert.are.equal("/tmp/build", cmake_files.build)
      assert.are.same(valid_inputs(), cmake_files.inputs)
      assert.are.same(valid_globs(), cmake_files.globs)
    end)

    it("does not share the version, inputs, or globs with the caller", function()
      local version = { major = 1, minor = 1 }
      local inputs, globs = valid_inputs(), valid_globs()

      local cmake_files = CMakeFiles.new(version, "/tmp/source", "/tmp/build", inputs, globs)
      version.major = 9
      inputs[1].path = "GoodbyeLists.txt"
      inputs[3].generated = false
      globs[1].expression = "/tmp/source/src/*.hxx"
      globs[1].paths[1] = "/tmp/source/src/baz.cxx"

      assert.are.equal(1, cmake_files.version.major)
      assert.are.same(valid_inputs(), cmake_files.inputs)
      assert.are.same(valid_globs(), cmake_files.globs)
    end)

    it("accepts an empty list of inputs", function()
      local cmake_files = CMakeFiles.new({ major = 1, minor = 1 }, "/tmp/source", "/tmp/build", {}, {})
      assert.are.same({}, cmake_files.inputs)
      assert.are.same({}, cmake_files.globs)
    end)

    it("leaves the globs absent when they are not passed", function()
      local cmake_files = CMakeFiles.new({ major = 1, minor = 1 }, "/tmp/source", "/tmp/build", valid_inputs())
      assert.is_nil(cmake_files.globs)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local cmake_files = CMakeFiles.take({ major = 1, minor = 1 }, "/tmp/source", "/tmp/build", valid_inputs(), valid_globs())
      assert.are.equal(object_kind.ObjectKindType.CMakeFiles, cmake_files.kind)
      assert.are.same({ major = 1, minor = 1 }, cmake_files.version)
      assert.are.equal("/tmp/source", cmake_files.source)
      assert.are.equal("/tmp/build", cmake_files.build)
      assert.are.same(valid_inputs(), cmake_files.inputs)
      assert.are.same(valid_globs(), cmake_files.globs)
    end)

    -- `take` exists so that a caller that just built the inputs does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local version = { major = 1, minor = 1 }
      local inputs, globs = valid_inputs(), valid_globs()

      local cmake_files = CMakeFiles.take(version, "/tmp/source", "/tmp/build", inputs, globs)
      version.major = 9
      inputs[1].path = "GoodbyeLists.txt"
      globs[1].paths[1] = "/tmp/source/src/baz.cxx"

      assert.are.equal(9, cmake_files.version.major)
      assert.are.equal("GoodbyeLists.txt", cmake_files.inputs[1].path)
      assert.are.equal("/tmp/source/src/baz.cxx", cmake_files.globs[1].paths[1])
    end)

    it("leaves the globs absent when they are not passed", function()
      local cmake_files = CMakeFiles.take({ major = 1, minor = 1 }, "/tmp/source", "/tmp/build", valid_inputs())
      assert.is_nil(cmake_files.globs)
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
        local cmake_files, err = CMakeFiles.try_from_json(value)
        assert.is_nil(cmake_files)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json())
      assert.is_nil(err)
      local instance = assert(cmake_files)
      assert.are.equal(object_kind.ObjectKindType.CMakeFiles, instance.kind)
      assert.are.same({ major = 1, minor = 1 }, instance.version)
      assert.are.equal("/tmp/source", instance.source)
      assert.are.equal("/tmp/build", instance.build)
      assert.are.same(valid_inputs(), instance.inputs)
      assert.are.same(valid_globs(), instance.globs)
    end)

    -- CMake writes a minor of 0 when the project uses no globbing with CONFIGURE_DEPENDS.
    it("accepts a version with a minor of 0", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ version = { major = 1, minor = 0 } }))
      assert.is_nil(err)
      assert.are.same({ major = 1, minor = 0 }, assert(cmake_files).version)
    end)

    -- CMake omits "globsDependent" entirely when the project uses no globbing with CONFIGURE_DEPENDS.
    it("leaves the globs absent when the json has no globsDependent", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without("globsDependent"))
      assert.is_nil(err)
      assert.is_nil(assert(cmake_files).globs)
    end)

    it("accepts an empty list of inputs", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ inputs = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(cmake_files).inputs)
    end)

    it("accepts an empty list of globs", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ globsDependent = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(cmake_files).globs)
    end)

    it("accepts an empty list of glob paths", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({
        globsDependent = { { expression = "/tmp/source/src/*.cxx", paths = {} } },
      }))
      assert.is_nil(err)
      assert.are.same({}, assert(cmake_files).globs[1].paths)
    end)

    -- CMake writes an input with only the flags that are true, leaving the rest out.
    it("defaults the flags an input does not report to false", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({
        inputs = { { path = "CMakeLists.txt" }, { path = "CMakeLists.txt", isGenerated = true } },
      }))
      assert.is_nil(err)
      assert.are.same({
        { path = "CMakeLists.txt", generated = false, external = false, is_cmake = false },
        { path = "CMakeLists.txt", generated = true, external = false, is_cmake = false },
      }, assert(cmake_files).inputs)
    end)

    -- A glob lists only the flags that are true, and only reports "relative" when written with RELATIVE.
    it("defaults the flags a glob does not report to false", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({
        globsDependent = { { expression = "/tmp/source/*.cxx", paths = { "/tmp/source/a.cxx" } } },
      }))
      assert.is_nil(err)
      local glob = assert(cmake_files).globs[1]
      assert.is_false(glob.recurse)
      assert.is_false(glob.list_directories)
      assert.is_false(glob.follow_symlinks)
      assert.is_nil(glob.relative)
    end)

    it("preserves the order of the inputs", function()
      local json = valid_json()
      json.inputs = { json.inputs[3], json.inputs[1], json.inputs[2] }

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(err)
      local inputs = assert(cmake_files).inputs
      assert.are.equal("/tmp/build/CMakeFiles/4.4.0/CMakeSystem.cmake", inputs[1].path)
      assert.are.equal("CMakeLists.txt", inputs[2].path)
      assert.are.equal("sub/CMakeLists.txt", inputs[3].path)
    end)

    it("preserves the order of the globs", function()
      local json = valid_json()
      json.globsDependent = { json.globsDependent[2], json.globsDependent[1] }

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(err)
      local globs = assert(assert(cmake_files).globs)
      assert.are.equal("/tmp/source/include/*.hxx", globs[1].expression)
      assert.are.equal("/tmp/source/src/*.cxx", globs[2].expression)
    end)

    it("preserves the order of a glob's paths", function()
      local json = valid_json()
      json.globsDependent[1].paths = { json.globsDependent[1].paths[2], json.globsDependent[1].paths[1] }

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(err)
      assert.are.same({ "/tmp/source/src/bar.cxx", "/tmp/source/src/foo.cxx" }, assert(cmake_files).globs[1].paths)
    end)

    it("does not share the inputs or the globs with the json", function()
      local json = valid_json()
      local cmake_files = assert(CMakeFiles.try_from_json(json))

      json.inputs[1].path = "GoodbyeLists.txt"
      json.inputs[3].isGenerated = nil
      table.remove(json.inputs, 2)
      json.globsDependent[1].expression = "/tmp/source/src/*.hxx"
      table.remove(json.globsDependent, 1)

      assert.are.same(valid_inputs(), cmake_files.inputs)
      assert.are.same(valid_globs(), cmake_files.globs)
    end)

    it("ignores unknown top-level fields", function()
      local json = vim.tbl_extend("force", valid_json(), { futureField = "ignored" })
      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(cmake_files), "futureField"))
    end)

    it("ignores unknown fields on an input", function()
      local json = valid_json({ inputs = { { path = "CMakeLists.txt", futureField = "ignored" } } })
      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(cmake_files).inputs[1], "futureField"))
    end)

    it("ignores unknown fields on a glob", function()
      local json = valid_json({
        globsDependent = { { expression = "/tmp/source/*.cxx", paths = {}, futureField = "ignored" } },
      })
      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(err)
      assert.is_nil(rawget(assert(cmake_files).globs[1], "futureField"))
    end)

    it("returns an error when the kind is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without("kind"))
      assert.is_nil(cmake_files)
      assert.are.equal("Incorrect kind: nil", err)
    end)

    it("returns an error when the kind is a different object kind", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ kind = "codemodel" }))
      assert.is_nil(cmake_files)
      assert.are.equal('Incorrect kind: "codemodel"', err)
    end)

    it("returns an error when version is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without("version"))
      assert.is_nil(cmake_files)
      assert.are.equal("version is wrong type: nil", err)
    end)

    it("returns an error when version is not a table", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ version = 1 }))
      assert.is_nil(cmake_files)
      assert.are.equal("version is wrong type: number", err)
    end)

    it("returns an error when version.major is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without_version_field("major"))
      assert.is_nil(cmake_files)
      assert.are.equal("version.major is wrong type: nil", err)
    end)

    it("returns an error when version.major is not a number", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ version = { major = "1", minor = 1 } }))
      assert.is_nil(cmake_files)
      assert.are.equal("version.major is wrong type: string", err)
    end)

    it("returns an error when version.minor is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without_version_field("minor"))
      assert.is_nil(cmake_files)
      assert.are.equal("version.minor is wrong type: nil", err)
    end)

    it("returns an error when version.minor is not a number", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ version = { major = 1, minor = "1" } }))
      assert.is_nil(cmake_files)
      assert.are.equal("version.minor is wrong type: string", err)
    end)

    it("validates the version before the paths", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ version = "1", paths = 42 }))
      assert.is_nil(cmake_files)
      assert.are.equal("version is wrong type: string", err)
    end)

    it("returns an error when paths is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without("paths"))
      assert.is_nil(cmake_files)
      assert.are.equal("paths is wrong type: nil", err)
    end)

    it("returns an error when paths is not a table", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ paths = "/tmp/build" }))
      assert.is_nil(cmake_files)
      assert.are.equal("paths is wrong type: string", err)
    end)

    it("returns an error when paths.source is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without_paths_field("source"))
      assert.is_nil(cmake_files)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("returns an error when paths.source is not a string", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ paths = { source = 42, build = "/tmp/build" } }))
      assert.is_nil(cmake_files)
      assert.are.equal("paths.source is wrong type: number", err)
    end)

    it("returns an error when paths.build is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without_paths_field("build"))
      assert.is_nil(cmake_files)
      assert.are.equal("paths.build is wrong type: nil", err)
    end)

    it("returns an error when paths.build is not a string", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ paths = { source = "/tmp/source", build = 42 } }))
      assert.is_nil(cmake_files)
      assert.are.equal("paths.build is wrong type: number", err)
    end)

    it("validates the source before the build", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ paths = { build = 42 } }))
      assert.is_nil(cmake_files)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("validates the paths before the inputs", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ paths = 42, inputs = "CMakeLists.txt" }))
      assert.is_nil(cmake_files)
      assert.are.equal("paths is wrong type: number", err)
    end)

    it("returns an error when inputs is missing", function()
      local cmake_files, err = CMakeFiles.try_from_json(json_without("inputs"))
      assert.is_nil(cmake_files)
      assert.are.equal("inputs is wrong type: nil", err)
    end)

    it("returns an error when inputs is not a table", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ inputs = "CMakeLists.txt" }))
      assert.is_nil(cmake_files)
      assert.are.equal("inputs is wrong type: string", err)
    end)

    it("returns an error when inputs is a dict instead of a list", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ inputs = { CMakeLists = { path = "CMakeLists.txt" } } }))
      assert.is_nil(cmake_files)
      assert.are.equal("inputs is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "string", "CMakeLists.txt" },
      { "null", vim.NIL },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when an input is a %s"):format(label), function()
        local cmake_files, err = CMakeFiles.try_from_json(valid_json({ inputs = { valid_json().inputs[1], value } }))
        assert.is_nil(cmake_files)
        assert.are.equal(("input at index 2: json is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("reports the index of the invalid input", function()
      local json = valid_json()
      json.inputs[3] = 42

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("input at index 3: json is wrong type: number", err)
    end)

    --- A value of the wrong type to assign to an input member, and the type name to expect in the error.
    for _, entry in ipairs({
      { "path", nil, "nil" },
      { "path", 42, "number" },
      { "isGenerated", "true", "string" },
      { "isGenerated", vim.NIL, "userdata" },
      { "isExternal", "true", "string" },
      { "isCMake", 42, "number" },
    }) do
      local field, value, type_name = entry[1], entry[2], entry[3]
      it(("returns an error when input.%s is %s"):format(field, type_name), function()
        local json = valid_json()
        json.inputs[1][field] = value

        local cmake_files, err = CMakeFiles.try_from_json(json)
        assert.is_nil(cmake_files)
        assert.are.equal(("input at index 1: %s is wrong type: %s"):format(field, type_name), err)
      end)
    end

    it("validates the inputs before the globs", function()
      local json = valid_json()
      json.inputs[1].path = nil
      json.globsDependent[1].expression = nil

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("input at index 1: path is wrong type: nil", err)
    end)

    it("returns an error when globsDependent is not a list", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({ globsDependent = "src/*.cxx" }))
      assert.is_nil(cmake_files)
      assert.are.equal("globsDependent is wrong type: string", err)
    end)

    it("returns an error when globsDependent is a dict instead of a list", function()
      local cmake_files, err = CMakeFiles.try_from_json(valid_json({
        globsDependent = { src = { expression = "src/*.cxx", paths = {} } },
      }))
      assert.is_nil(cmake_files)
      assert.are.equal("globsDependent is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "string", "src/*.cxx" },
      { "null", vim.NIL },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when a glob is a %s"):format(label), function()
        local globsDependent = { valid_json().globsDependent[1], value }
        local cmake_files, err = CMakeFiles.try_from_json(valid_json({ globsDependent = globsDependent }))
        assert.is_nil(cmake_files)
        assert.are.equal(("glob at index 2: json is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("reports the index of the invalid glob", function()
      local json = valid_json()
      json.globsDependent[1] = 42

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("glob at index 1: json is wrong type: number", err)
    end)

    --- A value of the wrong type to assign to a glob member, or nil to remove it, with the type to expect in the error.
    for _, entry in ipairs({
      { "expression", nil, "nil" },
      { "expression", 42, "number" },
      { "recurse", "true", "string" },
      { "listDirectories", 42, "number" },
      { "followSymlinks", "true", "string" },
      { "relative", 42, "number" },
      { "paths", nil, "nil" },
      { "paths", "/tmp/source/src/foo.cxx", "string" },
    }) do
      local field, value, type_name = entry[1], entry[2], entry[3]
      it(("returns an error when glob.%s is %s"):format(field, type_name), function()
        local json = valid_json()
        json.globsDependent[1][field] = value

        local cmake_files, err = CMakeFiles.try_from_json(json)
        assert.is_nil(cmake_files)
        assert.are.equal(("glob at index 1: %s is wrong type: %s"):format(field, type_name), err)
      end)
    end

    it("returns an error when glob.paths is a dict instead of a list", function()
      local json = valid_json()
      json.globsDependent[1].paths = { src = "/tmp/source/src/foo.cxx" }

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("glob at index 1: paths is wrong type: table", err)
    end)

    for _, entry in ipairs({
      { "number", 42 },
      { "boolean", true },
      { "null", vim.NIL },
      { "table", {} },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when a glob path is a %s"):format(label), function()
        local json = valid_json()
        table.insert(json.globsDependent[1].paths, value)

        local cmake_files, err = CMakeFiles.try_from_json(json)
        assert.is_nil(cmake_files)
        assert.are.equal(("glob at index 1: path at index 3 is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("reports the index of the invalid glob path", function()
      local json = valid_json()
      json.globsDependent[2].paths[1] = 42

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("glob at index 2: path at index 1 is wrong type: number", err)
    end)

    it("validates the glob expression before its flags", function()
      local json = valid_json()
      json.globsDependent[1].expression = nil
      json.globsDependent[1].recurse = "true"

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("glob at index 1: expression is wrong type: nil", err)
    end)

    it("validates the glob flags before the relative path", function()
      local json = valid_json()
      json.globsDependent[2].followSymlinks = "true"
      json.globsDependent[2].relative = 42

      local cmake_files, err = CMakeFiles.try_from_json(json)
      assert.is_nil(cmake_files)
      assert.are.equal("glob at index 2: followSymlinks is wrong type: string", err)
    end)
  end)

  describe("try_from_file", function()
    --- Writes JSON to a file in the test's temporary directory.
    ---@param contents string The exact bytes to write.
    ---@return string path The path to the written file.
    local function write(contents)
      local path = vim.fs.joinpath(tmp.path, "cmakeFiles-v1-0123456789abcdef.json")
      require("spec.utils").write_file(path, contents)
      return path
    end

    it("creates an instance from a valid file", function()
      local path = write(vim.json.encode(valid_json()))

      local cmake_files, err = CMakeFiles.try_from_file(path)
      assert.is_nil(err)
      local instance = assert(cmake_files)
      assert.are.equal(object_kind.ObjectKindType.CMakeFiles, instance.kind)
      assert.are.same({ major = 1, minor = 1 }, instance.version)
      assert.are.equal("/tmp/source", instance.source)
      assert.are.equal("/tmp/build", instance.build)
      assert.are.same(valid_inputs(), instance.inputs)
      assert.are.same(valid_globs(), instance.globs)
    end)

    it("returns the input error of the file it could not parse", function()
      local json = vim.json.encode(valid_json({ inputs = { { isGenerated = true } } }))

      local cmake_files, err = CMakeFiles.try_from_file(write(json))
      assert.is_nil(cmake_files)
      assert.are.equal("input at index 1: path is wrong type: nil", err)
    end)

    it("returns an error when the file does not exist", function()
      local cmake_files, err = CMakeFiles.try_from_file(vim.fs.joinpath(tmp.path, "missing.json"))
      assert.is_nil(cmake_files)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("missing%.json", err)
    end)

    it("returns an error when the path is a directory", function()
      local dir = vim.fs.joinpath(tmp.path, "directory")
      vim.fn.mkdir(dir, "p")

      local cmake_files, err = CMakeFiles.try_from_file(dir)
      assert.is_nil(cmake_files)
      assert.are.equal(("Failed to read %s: Is a directory"):format(dir), err)
    end)

    it("returns an error when the file is not JSON", function()
      local cmake_files, err = CMakeFiles.try_from_file(write("not json"))
      assert.is_nil(cmake_files)
      assert.is_not_nil(err)
      ---@cast err string
      assert.matches("^vim%.json%.decode: ", err)
    end)

    it("returns an error when the JSON does not describe a cmakeFiles object", function()
      local cmake_files, err = CMakeFiles.try_from_file(write(vim.json.encode(valid_json({ kind = "codemodel" }))))
      assert.is_nil(cmake_files)
      assert.are.equal('Incorrect kind: "codemodel"', err)
    end)
  end)
end)
