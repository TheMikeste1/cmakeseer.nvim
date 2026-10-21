local BacktraceGraph = require("cmakeseer.cmake.file_api.object_kind.codemodel.backtrace_graph")
local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.directory")

local InstallerType = Directory.InstallerType

---A valid backtrace graph object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function backtrace_graph_json(overrides)
  return vim.tbl_extend("force", {
    nodes = {
      { file = 0 },
      { file = 0, line = 48, command = 0, parent = 0 },
    },
    commands = { "install" },
    files = { "CMakeLists.txt" },
  }, overrides or {})
end

---The backtrace graph the fixture json describes.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.BacktraceGraph graph
local function backtrace_graph()
  return BacktraceGraph.take({
    { file = "CMakeLists.txt", line = nil, command = nil, parent = nil },
    { file = "CMakeLists.txt", line = 48, command = "install", parent = 1 },
  })
end

---The members CMake writes for every install rule, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function installer_json(overrides)
  return vim.tbl_extend("force", {
    component = "Unspecified",
    backtrace = 1,
  }, overrides or {})
end

---The members every parsed install rule has, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> installer
local function common_installer(overrides)
  return vim.tbl_extend("force", {
    component = "Unspecified",
    exclude_from_all = false,
    for_all_components = false,
    backtrace_index = 2,
  }, overrides or {})
end

---The install rule of the target the fixture installs.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function target_installer_json(overrides)
  return installer_json(vim.tbl_extend("force", {
    type = InstallerType.Target,
    destination = "bin",
    paths = { "cmakeseer_example" },
    targetId = "cmakeseer_example::@6890427a1f51a3e7e1df",
    targetIndex = 0,
  }, overrides or {}))
end

---A valid directory object, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function valid_json(overrides)
  return vim.tbl_extend("force", {
    codemodelVersion = { major = 2, minor = 11 },
    paths = { source = ".", build = "." },
    installers = { target_installer_json() },
    backtraceGraph = backtrace_graph_json(),
  }, overrides or {})
end

--- A valid directory object.
---@return table<string, any> obj
local function valid_directory()
  return Directory.take({ major = 2, minor = 11 }, ".", ".", {
    common_installer({
      type = InstallerType.Target,
      destination = "bin",
      paths = { "cmakeseer_example" },
      optional = false,
      id = "cmakeseer_example::@6890427a1f51a3e7e1df",
      index = 0,
      is_import_library = false,
      install_namelink = nil,
    }),
  }, backtrace_graph())
end

--- Parses a directory object with the given overrides.
---@param overrides? table<string, any> Values to override.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory? obj, string? err
local function try_from_json(overrides)
  return Directory.try_from_json(valid_json(overrides))
end

--- Parses a directory object whose only install rule is the given one.
---@param installer any The raw json for the install rule.
---@return table<string, any>? obj, string? err
local function try_installer(installer)
  local directory, err = try_from_json({ installers = { installer } })
  if directory == nil then
    return nil, err
  end
  return directory.installers[1], nil
end

--- The install rules of the directory.
---@param directory cmakeseer.cmake.file_api.object_kind.Codemodel.Directory
---@return table<string, any>[] installers
local function installers_of(directory)
  return directory.installers
end

--- The given json, with the given fields removed.
---@param json table<string, any> The json to remove the fields from.
---@param ... string The fields to remove.
---@return table<string, any> json
local function json_without(json, ...)
  for _, field in ipairs({ ... }) do
    json[field] = nil
  end
  return json
end

--- A valid install rule of the script type, with optional overrides.
---@param overrides? table<string, any> Values to override.
---@return table<string, any> json
local function simple_installer_json(overrides)
  return installer_json(vim.tbl_extend("force", {
    type = InstallerType.Script,
    scriptFile = "cmake/install.cmake",
  }, overrides or {}))
end

describe("Codemodel.Directory", function()
  describe("new", function()
    it("initializes correctly", function()
      local directory = Directory.new({ major = 2, minor = 11 }, ".", ".", valid_directory().installers, backtrace_graph())
      assert.are.same({ major = 2, minor = 11 }, assert(directory.codemodel_version))
      assert.are.equal(".", directory.source)
      assert.are.equal(".", directory.build)
      assert.are.equal(1, #directory.installers)
      assert.are.same(backtrace_graph().nodes, directory.backtrace_graph.nodes)
    end)

    it("leaves the codemodel version absent when it is not passed", function()
      local directory = Directory.new(nil, ".", ".", {}, backtrace_graph())
      assert.is_nil(directory.codemodel_version)
    end)

    it("does not share the codemodel version, the installers, or the backtrace graph with the caller", function()
      local version = { major = 2, minor = 11 }
      local installers = valid_directory().installers
      local graph = backtrace_graph()

      local directory = Directory.new(version, ".", ".", installers, graph)
      version.major = 9
      installers[1].destination = "lib"
      graph.nodes[1].file = "other/CMakeLists.txt"

      assert.are.equal(2, assert(directory.codemodel_version).major)
      assert.are.equal("bin", installers_of(directory)[1].destination)
      assert.are.equal("CMakeLists.txt", directory.backtrace_graph.nodes[1].file)
    end)
  end)

  describe("take", function()
    it("initializes correctly", function()
      local directory = Directory.take(nil, "math", "math", {}, backtrace_graph())
      assert.is_nil(directory.codemodel_version)
      assert.are.equal("math", directory.source)
      assert.are.equal("math", directory.build)
      assert.are.same({}, directory.installers)
      assert.are.same(backtrace_graph().nodes, directory.backtrace_graph.nodes)
    end)

    -- `take` exists so that a caller that just parsed the installers does not pay for a second copy.
    it("takes ownership instead of copying", function()
      local installers = valid_directory().installers

      local directory = Directory.take(nil, ".", ".", installers, backtrace_graph())
      installers[1].destination = "lib"

      assert.are.equal("lib", installers_of(directory)[1].destination)
    end)
  end)

  describe("try_from_json", function()
    for _, entry in ipairs({
      { "nil", nil },
      { "number", 42 },
      { "boolean", true },
      { "string", "directory" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when json is a %s"):format(label), function()
        local directory, err = Directory.try_from_json(value)
        assert.is_nil(directory)
        assert.are.equal(("json is wrong type: %s"):format(label), err)
      end)
    end

    it("creates an instance from a valid object", function()
      local directory, err = Directory.try_from_json(valid_json())
      assert.is_nil(err)
      assert.are.same(valid_directory(), assert(directory))
    end)

    it("records the version of the codemodel it is a part of", function()
      local directory, err = try_from_json({ codemodelVersion = { major = 2, minor = 3 } })
      assert.is_nil(err)
      assert.are.same({ major = 2, minor = 3 }, assert(directory).codemodel_version)
    end)

    it("leaves the codemodel version absent when the json omits it", function()
      local directory, err = Directory.try_from_json(json_without(valid_json(), "codemodelVersion"))
      assert.is_nil(err)
      assert.is_nil(assert(directory).codemodel_version)
    end)

    it("returns an error when the codemodel version is not a table", function()
      local directory, err = try_from_json({ codemodelVersion = "2.11" })
      assert.is_nil(directory)
      assert.are.equal("version is wrong type: string", err)
    end)

    it("returns an error when the major version of the codemodel is not a number", function()
      local directory, err = try_from_json({ codemodelVersion = { major = "2", minor = 11 } })
      assert.is_nil(directory)
      assert.are.equal("version.major is wrong type: string", err)
    end)

    it("returns an error when the minor version of the codemodel is missing", function()
      local directory, err = try_from_json({ codemodelVersion = { major = 2 } })
      assert.is_nil(directory)
      assert.are.equal("version.minor is wrong type: nil", err)
    end)

    it("records the source and build paths the json reports", function()
      local directory, err = try_from_json({ paths = { source = "math", build = "math" } })
      assert.is_nil(err)
      assert.are.equal("math", assert(directory).source)
      assert.are.equal("math", assert(directory).build)
    end)

    it("returns an error when paths is missing", function()
      local directory, err = Directory.try_from_json(json_without(valid_json(), "paths"))
      assert.is_nil(directory)
      assert.are.equal("paths is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "." },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when paths is %s"):format(label), function()
        local directory, err = try_from_json({ paths = value })
        assert.is_nil(directory)
        assert.are.equal(("paths is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when paths.source is missing", function()
      local directory, err = try_from_json({ paths = { build = "." } })
      assert.is_nil(directory)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("returns an error when paths.source is not a string", function()
      local directory, err = try_from_json({ paths = { source = 42, build = "." } })
      assert.is_nil(directory)
      assert.are.equal("paths.source is wrong type: number", err)
    end)

    it("returns an error when paths.build is missing", function()
      local directory, err = try_from_json({ paths = { source = "." } })
      assert.is_nil(directory)
      assert.are.equal("paths.build is wrong type: nil", err)
    end)

    it("returns an error when paths.build is not a string", function()
      local directory, err = try_from_json({ paths = { source = ".", build = true } })
      assert.is_nil(directory)
      assert.are.equal("paths.build is wrong type: boolean", err)
    end)

    it("validates the source before the build", function()
      local directory, err = try_from_json({ paths = { build = 42 } })
      assert.is_nil(directory)
      assert.are.equal("paths.source is wrong type: nil", err)
    end)

    it("accepts a directory with no install rules", function()
      local directory, err = try_from_json({ installers = {} })
      assert.is_nil(err)
      assert.are.same({}, assert(directory).installers)
    end)

    it("returns an error when installers is missing", function()
      local directory, err = Directory.try_from_json(json_without(valid_json(), "installers"))
      assert.is_nil(directory)
      assert.are.equal("installers is wrong type: nil", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a string", "install" },
      { "a boolean", true },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when installers is %s"):format(label), function()
        local directory, err = try_from_json({ installers = value })
        assert.is_nil(directory)
        assert.are.equal(("installers is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when installers is a dict instead of a list", function()
      local directory, err = try_from_json({ installers = { Unspecified = target_installer_json() } })
      assert.is_nil(directory)
      assert.are.equal("installers is wrong type: table", err)
    end)

    it("reports the index of the install rule it could not parse", function()
      local directory, err = try_from_json({ installers = { target_installer_json(), installer_json({ type = "rule" }) } })
      assert.is_nil(directory)
      assert.are.equal("installer at index 2: unknown installer type: rule", err)
    end)

    for _, entry in ipairs({
      { "a number", 42 },
      { "a boolean", true },
      { "a string", "install" },
    }) do
      local label, value = entry[1], entry[2]
      it(("returns an error when an install rule is %s"):format(label), function()
        local installer, err = try_installer(value)
        assert.is_nil(installer)
        assert.are.equal(("installer at index 1: json is wrong type: %s"):format(type(value)), err)
      end)
    end

    it("returns an error when the component of an install rule is missing", function()
      local installer, err = try_installer(json_without(installer_json({ type = InstallerType.Code }), "component"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: component is wrong type: nil", err)
    end)

    it("returns an error when the type of an install rule is missing", function()
      local installer, err = try_installer(json_without(installer_json(), "type"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: type is wrong type: nil", err)
    end)

    it("returns an error when isExcludeFromAll is not a boolean", function()
      local installer, err = try_installer(installer_json({ type = InstallerType.Code, isExcludeFromAll = "yes" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: isExcludeFromAll is wrong type: string", err)
    end)

    it("returns an error when isForAllComponents is not a boolean", function()
      local installer, err = try_installer(installer_json({ type = InstallerType.Code, isForAllComponents = 42 }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: isForAllComponents is wrong type: number", err)
    end)

    it("returns an error when the backtrace of an install rule is not a number", function()
      local installer, err = try_installer(installer_json({ type = InstallerType.Code, backtrace = "1" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: backtrace is wrong type: string", err)
    end)

    it("leaves the backtrace of an install rule absent when the json omits it", function()
      local installer, err = try_installer(json_without(simple_installer_json(), "backtrace"))
      assert.is_nil(err)
      assert.is_nil(assert(installer).backtrace_index)
    end)

    -- CMake writes the backtrace index of an install rule zero-based and it addresses Lua tables one-based.
    it("resolves the backtrace index of an install rule into the node it names", function()
      for _, index in ipairs({ 0, 1 }) do
        local installer, err = try_installer(simple_installer_json({ backtrace = index }))
        assert.is_nil(err)
        assert.are.equal(index + 1, assert(installer).backtrace_index)
      end
    end)

    -- CMake reports an install(CODE) rule as the type "code", which carries no members beyond the common ones.
    it("records the members an install rule of code has", function()
      local installer, err = try_installer(installer_json({ type = InstallerType.Code, isExcludeFromAll = true }))
      assert.is_nil(err)
      assert.are.same(common_installer({ type = InstallerType.Code, exclude_from_all = true }), assert(installer))
    end)

    it("records the flags an install rule CMake writes as false", function()
      local installer, err = try_installer(simple_installer_json({ isExcludeFromAll = false, isForAllComponents = false }))
      assert.is_nil(err)
      assert.is_false(assert(installer).exclude_from_all)
      assert.is_false(assert(installer).for_all_components)
    end)

    it("returns an error when the backtrace graph is missing", function()
      local directory, err = Directory.try_from_json(json_without(valid_json(), "backtraceGraph"))
      assert.is_nil(directory)
      assert.are.equal("backtraceGraph is invalid: json is wrong type: nil", err)
    end)

    it("returns the error of the backtrace graph it could not parse", function()
      local directory, err = try_from_json({ backtraceGraph = backtrace_graph_json({ nodes = { {} } }) })
      assert.is_nil(directory)
      assert.are.equal("backtraceGraph is invalid: node at index 1: file is wrong type: nil", err)
    end)
  end)

  describe("try_from_json of a file installer", function()
    local function file_installer_json(overrides)
      return installer_json(vim.tbl_extend("force", {
        type = InstallerType.File,
        destination = "share/cmakeseer",
        paths = { "docs/CMakeLists.txt" },
      }, overrides or {}))
    end

    it("records the destination, the paths, and the optional flag", function()
      local installer, err = try_installer(file_installer_json())
      assert.is_nil(err)
      assert.are.same(common_installer({ type = InstallerType.File, destination = "share/cmakeseer", paths = { "docs/CMakeLists.txt" }, optional = false }), assert(installer))
    end)

    it("leaves the optional flag false when the json omits it", function()
      local installer, err = try_installer(file_installer_json({ isOptional = false }))
      assert.is_nil(err)
      assert.is_false(assert(installer).optional)
    end)

    it("records the optional flag the json reports", function()
      local installer, err = try_installer(file_installer_json({ isOptional = true }))
      assert.is_nil(err)
      assert.is_true(assert(installer).optional)
    end)

    it("records a path written with a destination of its own", function()
      local installer, err = try_installer(file_installer_json({ paths = { { from = "docs/index.html", to = "html/index.html" } } }))
      assert.is_nil(err)
      assert.are.same({ { from = "docs/index.html", to = "html/index.html" } }, assert(installer).paths)
    end)

    it("does not share the paths of an install rule with the json", function()
      local json = valid_json({ installers = { file_installer_json({ paths = { "docs/CMakeLists.txt" } }) } })

      local directory, err = Directory.try_from_json(json)
      assert.is_nil(err)
      json.installers[1].paths[1] = "other/CMakeLists.txt"

      assert.are.same({ "docs/CMakeLists.txt" }, installers_of(assert(directory))[1].paths)
    end)

    it("accepts a file installer with no paths", function()
      local installer, err = try_installer(file_installer_json({ paths = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(installer).paths)
    end)

    it("records the destination and the paths of a directory installer", function()
      local installer, err = try_installer(installer_json({
        type = InstallerType.Directory,
        destination = "share/cmakeseer",
        paths = { "docs" },
        isOptional = true,
      }))
      assert.is_nil(err)
      assert.are.same(common_installer({ type = InstallerType.Directory, destination = "share/cmakeseer", paths = { "docs" }, optional = true }), assert(installer))
    end)

    it("returns an error when the destination is missing", function()
      local installer, err = try_installer(json_without(file_installer_json(), "destination"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)

    it("returns an error when the paths are missing", function()
      local installer, err = try_installer(json_without(file_installer_json(), "paths"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: paths is wrong type: nil", err)
    end)

    it("returns an error when a path is not a string or a table", function()
      local installer, err = try_installer(file_installer_json({ paths = { 42 } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: path at index 1: wrong type: number", err)
    end)

    it("returns an error when the from of a path is missing", function()
      local installer, err = try_installer(file_installer_json({ paths = { { to = "html/index.html" } } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: path at index 1: from wrong type: nil", err)
    end)

    it("returns an error when the to of a path is not a string", function()
      local installer, err = try_installer(file_installer_json({ paths = { { from = "docs/index.html", to = 42 } } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: path at index 1: to wrong type: number", err)
    end)

    it("returns an error when the optional flag is not a boolean", function()
      local installer, err = try_installer(file_installer_json({ isOptional = "yes" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: isOptional is wrong type: string", err)
    end)

    it("validates the destination before the paths", function()
      local installer, err = try_installer(json_without(file_installer_json(), "destination", "paths"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)

    it("validates the paths before the optional flag", function()
      local installer, err = try_installer(file_installer_json({ paths = { 42 }, isOptional = "yes" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: path at index 1: wrong type: number", err)
    end)
  end)

  describe("try_from_json of a target installer", function()
    it("records the destination, the paths, and the target", function()
      local installer, err = try_installer(target_installer_json())
      assert.is_nil(err)
      assert.are.same(
        common_installer({
          type = InstallerType.Target,
          destination = "bin",
          paths = { "cmakeseer_example" },
          optional = false,
          id = "cmakeseer_example::@6890427a1f51a3e7e1df",
          index = 0,
          is_import_library = false,
        }),
        assert(installer)
      )
    end)

    it("records the target the installer installs", function()
      local installer, err = try_installer(target_installer_json({ targetIndex = 7, targetId = "codemodel_math::@1" }))
      assert.is_nil(err)
      assert.are.equal("codemodel_math::@1", assert(installer).id)
      assert.are.equal(7, assert(installer).index)
    end)

    it("records that the installer is for an import library", function()
      local installer, err = try_installer(target_installer_json({ targetIsImportLibrary = true }))
      assert.is_nil(err)
      assert.is_true(assert(installer).is_import_library)
    end)

    it("leaves the import library flag false when the json omits it", function()
      local installer, err = try_installer(target_installer_json())
      assert.is_nil(err)
      assert.is_false(assert(installer).is_import_library)
    end)

    for _, namelink in ipairs({ "skip", "only" }) do
      it(("records the %s name link handling the json reports"):format(namelink), function()
        local installer, err = try_installer(target_installer_json({ targetInstallNamelink = namelink }))
        assert.is_nil(err)
        assert.are.equal(namelink, assert(installer).install_namelink)
      end)
    end

    it("leaves the name link handling absent when the json omits it", function()
      local installer, err = try_installer(target_installer_json())
      assert.is_nil(err)
      assert.is_nil(assert(installer).install_namelink)
    end)

    it("returns an error when the target id is missing", function()
      local installer, err = try_installer(json_without(target_installer_json(), "targetId"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: targetId is wrong type: nil", err)
    end)

    it("returns an error when the target index is not a number", function()
      local installer, err = try_installer(target_installer_json({ targetIndex = "0" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: targetIndex is wrong type: string", err)
    end)

    it("returns an error when the import library flag is not a boolean", function()
      local installer, err = try_installer(target_installer_json({ targetIsImportLibrary = 1 }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: targetIsImportLibrary is wrong type: number", err)
    end)

    it("returns an error when the name link handling is not a string", function()
      local installer, err = try_installer(target_installer_json({ targetInstallNamelink = 1 }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: targetInstallNamelink is wrong type: number", err)
    end)

    it("returns an error when the name link handling is not a value CMake writes", function()
      local installer, err = try_installer(target_installer_json({ targetInstallNamelink = "maybe" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: targetInstallNamelink is invalid: maybe", err)
    end)

    it("validates the destination before the target", function()
      local installer, err = try_installer(json_without(target_installer_json(), "destination", "targetId"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)
  end)

  describe("try_from_json of an export installer", function()
    local function export_installer_json(overrides)
      return installer_json(vim.tbl_extend("force", {
        type = InstallerType.Export,
        exportName = "CodemodelTargets",
        destination = "lib/cmake/Codemodel",
        paths = { "CodemodelTargets.cmake" },
        exportTargets = {
          { id = "codemodel_math::@1", index = 0 },
          { id = "codemodel_greeting::@2", index = 1 },
        },
      }, overrides or {}))
    end

    it("records the name, the destination, the paths, and the targets", function()
      local installer, err = try_installer(export_installer_json())
      assert.is_nil(err)
      assert.are.same(
        common_installer({
          type = InstallerType.Export,
          name = "CodemodelTargets",
          destination = "lib/cmake/Codemodel",
          paths = { "CodemodelTargets.cmake" },
          targets = {
            { id = "codemodel_math::@1", index = 0 },
            { id = "codemodel_greeting::@2", index = 1 },
          },
        }),
        assert(installer)
      )
    end)

    it("accepts an export with no targets", function()
      local installer, err = try_installer(export_installer_json({ exportTargets = {} }))
      assert.is_nil(err)
      assert.are.same({}, assert(installer).targets)
    end)

    it("returns an error when the name of the export is missing", function()
      local installer, err = try_installer(json_without(export_installer_json(), "exportName"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: exportName is wrong type: nil", err)
    end)

    it("returns an error when the destination is missing", function()
      local installer, err = try_installer(json_without(export_installer_json(), "destination"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)

    it("returns an error when the paths are missing", function()
      local installer, err = try_installer(json_without(export_installer_json(), "paths"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: paths is wrong type: nil", err)
    end)

    it("returns an error when the targets are missing", function()
      local installer, err = try_installer(json_without(export_installer_json(), "exportTargets"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: exportTargets is wrong type: nil", err)
    end)

    it("returns an error when a target of the export is not a table", function()
      local installer, err = try_installer(export_installer_json({ exportTargets = { "codemodel_math::@1" } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: exportTarget at index 1 is wrong type: string", err)
    end)

    it("returns an error when the id of a target of the export is missing", function()
      local installer, err = try_installer(export_installer_json({ exportTargets = { { index = 0 } } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: exportTarget.id at index 1 is wrong type: nil", err)
    end)

    it("returns an error when the index of a target of the export is not a number", function()
      local installer, err = try_installer(export_installer_json({ exportTargets = { { id = "codemodel_math::@1", index = "0" } } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: exportTarget.index at index 1 is wrong type: string", err)
    end)

    it("validates the name of the export before its destination", function()
      local installer, err = try_installer(json_without(export_installer_json(), "exportName", "destination"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: exportName is wrong type: nil", err)
    end)
  end)

  describe("try_from_json of a script installer", function()
    it("records the script the installer runs", function()
      local installer, err = try_installer(installer_json({ type = InstallerType.Script, scriptFile = "cmake/install.cmake" }))
      assert.is_nil(err)
      assert.are.same(common_installer({ type = InstallerType.Script, file = "cmake/install.cmake" }), assert(installer))
    end)

    it("returns an error when the script is missing", function()
      local installer, err = try_installer(installer_json({ type = InstallerType.Script }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: scriptFile is wrong type: nil", err)
    end)
  end)

  describe("try_from_json of an imported runtime artifacts installer", function()
    local function artifacts_installer_json(overrides)
      return installer_json(vim.tbl_extend("force", {
        type = InstallerType.ImportedRuntimeArtifacts,
        destination = "bin",
      }, overrides or {}))
    end

    it("records the destination and the optional flag", function()
      local installer, err = try_installer(artifacts_installer_json())
      assert.is_nil(err)
      assert.are.same(common_installer({ type = InstallerType.ImportedRuntimeArtifacts, destination = "bin", optional = false }), assert(installer))
    end)

    it("records the optional flag the json reports", function()
      local installer, err = try_installer(artifacts_installer_json({ isOptional = true }))
      assert.is_nil(err)
      assert.is_true(assert(installer).optional)
    end)

    it("returns an error when the destination is missing", function()
      local installer, err = try_installer(json_without(artifacts_installer_json(), "destination"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)

    it("returns an error when the optional flag is not a boolean", function()
      local installer, err = try_installer(artifacts_installer_json({ isOptional = "yes" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: isOptional is wrong type: string", err)
    end)
  end)

  describe("try_from_json of a runtime dependency set installer", function()
    local function dependency_set_installer_json(overrides)
      return installer_json(vim.tbl_extend("force", {
        type = InstallerType.RuntimeDependencySet,
        destination = "bin",
        runtimeDependencySetName = "MySet",
        runtimeDependencySetType = "library",
      }, overrides or {}))
    end

    it("records the destination, the name, and the type of the set", function()
      local installer, err = try_installer(dependency_set_installer_json())
      assert.is_nil(err)
      assert.are.same(common_installer({ type = InstallerType.RuntimeDependencySet, destination = "bin", set_name = "MySet", set_type = "library" }), assert(installer))
    end)

    it("leaves the name of the set absent when the json omits it", function()
      local installer, err = try_installer(json_without(dependency_set_installer_json(), "runtimeDependencySetName"))
      assert.is_nil(err)
      assert.is_nil(assert(installer).set_name)
    end)

    it("records a framework dependency set", function()
      local installer, err = try_installer(dependency_set_installer_json({ runtimeDependencySetType = "framework" }))
      assert.is_nil(err)
      assert.are.equal("framework", assert(installer).set_type)
    end)

    it("returns an error when the destination is missing", function()
      local installer, err = try_installer(json_without(dependency_set_installer_json(), "destination"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)

    it("returns an error when the name of the set is not a string", function()
      local installer, err = try_installer(dependency_set_installer_json({ runtimeDependencySetName = 42 }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: runtimeDependencySetName is wrong type: number", err)
    end)

    it("returns an error when the type of the set is missing", function()
      local installer, err = try_installer(json_without(dependency_set_installer_json(), "runtimeDependencySetType"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: runtimeDependencySetType is wrong type: nil", err)
    end)

    it("returns an error when the type of the set is not a value CMake writes", function()
      local installer, err = try_installer(dependency_set_installer_json({ runtimeDependencySetType = "static" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: runtimeDependencySetType has invalid value: static", err)
    end)
  end)

  describe("try_from_json of a file set installer", function()
    local function file_set_installer_json(overrides)
      return installer_json(vim.tbl_extend("force", {
        type = InstallerType.FileSet,
        destination = "include",
        paths = { "math/math.hpp" },
        fileSetName = "math_headers",
        fileSetType = "HEADERS",
        fileSetDirectories = { "math/." },
        fileSetTarget = { id = "codemodel_math::@1", index = 3 },
      }, overrides or {}))
    end

    it("records the name, the type, the directories, and the target of the set", function()
      local installer, err = try_installer(file_set_installer_json())
      assert.is_nil(err)
      assert.are.same(
        common_installer({
          type = InstallerType.FileSet,
          destination = "include",
          paths = { "math/math.hpp" },
          optional = false,
          name = "math_headers",
          set_type = "HEADERS",
          directories = { "math/." },
          target = { id = "codemodel_math::@1", index = 3 },
        }),
        assert(installer)
      )
    end)

    it("leaves the directories of the set empty when the json omits them", function()
      local installer, err = try_installer(json_without(file_set_installer_json(), "fileSetDirectories"))
      assert.is_nil(err)
      assert.are.same({}, assert(installer).directories)
    end)

    it("returns an error when the name of the set is missing", function()
      local installer, err = try_installer(json_without(file_set_installer_json(), "fileSetName"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: fileSetName is wrong type: nil", err)
    end)

    it("returns an error when the type of the set is missing", function()
      local installer, err = try_installer(json_without(file_set_installer_json(), "fileSetType"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: fileSetType is wrong type: nil", err)
    end)

    it("returns an error when the directories of the set are not a list", function()
      local installer, err = try_installer(file_set_installer_json({ fileSetDirectories = "math" }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: fileSetDirectories is wrong type: string", err)
    end)

    it("returns an error when the target of the set is missing", function()
      local installer, err = try_installer(json_without(file_set_installer_json(), "fileSetTarget"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: fileSetTarget is wrong type: nil", err)
    end)

    it("returns an error when the id of the target of the set is missing", function()
      local installer, err = try_installer(file_set_installer_json({ fileSetTarget = { index = 3 } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: fileSetTarget.id is wrong type: nil", err)
    end)

    it("returns an error when the index of the target of the set is not a number", function()
      local installer, err = try_installer(file_set_installer_json({ fileSetTarget = { id = "codemodel_math::@1", index = "3" } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: fileSetTarget.index is wrong type: string", err)
    end)

    it("validates the destination before the name of the set", function()
      local installer, err = try_installer(json_without(file_set_installer_json(), "destination", "fileSetName"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)
  end)

  describe("try_from_json of a C++ module BMI installer", function()
    local function bmi_installer_json(overrides)
      return installer_json(vim.tbl_extend("force", {
        type = InstallerType.CxxModuleBmi,
        destination = "include",
        cxxModuleBmiTarget = { id = "codemodel_math::@1", index = 3 },
      }, overrides or {}))
    end

    it("records the destination, the optional flag, and the target", function()
      local installer, err = try_installer(bmi_installer_json())
      assert.is_nil(err)
      assert.are.same(
        common_installer({
          type = InstallerType.CxxModuleBmi,
          destination = "include",
          optional = false,
          target = { id = "codemodel_math::@1", index = 3 },
        }),
        assert(installer)
      )
    end)

    it("records the optional flag the json reports", function()
      local installer, err = try_installer(bmi_installer_json({ isOptional = true }))
      assert.is_nil(err)
      assert.is_true(assert(installer).optional)
    end)

    it("returns an error when the destination is missing", function()
      local installer, err = try_installer(json_without(bmi_installer_json(), "destination"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: destination is wrong type: nil", err)
    end)

    it("returns an error when the optional flag is not a boolean", function()
      local installer, err = try_installer(bmi_installer_json({ isOptional = 1 }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: isOptional is wrong type: number", err)
    end)

    it("returns an error when the target is missing", function()
      local installer, err = try_installer(json_without(bmi_installer_json(), "cxxModuleBmiTarget"))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: cxxModuleBmiTarget is wrong type: nil", err)
    end)

    it("returns an error when the id of the target is missing", function()
      local installer, err = try_installer(bmi_installer_json({ cxxModuleBmiTarget = { index = 3 } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: cxxModuleBmiTarget.id is wrong type: nil", err)
    end)

    it("returns an error when the index of the target is not a number", function()
      local installer, err = try_installer(bmi_installer_json({ cxxModuleBmiTarget = { id = "codemodel_math::@1", index = "3" } }))
      assert.is_nil(installer)
      assert.are.equal("installer at index 1: cxxModuleBmiTarget.index is wrong type: string", err)
    end)
  end)
end)
