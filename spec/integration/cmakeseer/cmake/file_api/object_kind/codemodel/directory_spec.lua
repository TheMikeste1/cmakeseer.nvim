local Codemodel = require("cmakeseer.cmake.file_api.object_kind.codemodel")
local Directory = require("cmakeseer.cmake.file_api.object_kind.codemodel.directory")
local configured_build = require("spec.fixtures.configured_build")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

--- The codemodel of the configured fixture project.
---@param object_path string The path to the codemodel object file CMake wrote.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel codemodel
local function configured_codemodel(object_path)
  local codemodel, err = Codemodel.try_from_file(object_path)
  assert.is_nil(err)
  return assert(codemodel)
end

--- The object file CMake wrote for the directory of the fixture project with the given source path.
---@param object_path string The path to the codemodel object file CMake wrote.
---@param source string
---@return string
local function json_file_of_directory(object_path, source)
  for _, directory in ipairs(configured_codemodel(object_path).configurations[""].directories) do
    if directory.source == source then
      return directory.json_file
    end
  end
  error("The codemodel has no directory with the source " .. source)
end

--- Parses the directory object CMake wrote for the directory with the given source path.
---@param object_path string The path to the codemodel object file CMake wrote.
---@param source string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory obj
local function configured_directory(object_path, source)
  local json, err = object_kind.try_decode_file(json_file_of_directory(object_path, source))
  assert.is_nil(err)

  local directory
  directory, err = Directory.try_from_json(assert(json))
  assert.is_nil(err)
  return assert(directory)
end

--- The install rules of the directory with the given type.
---@param directory cmakeseer.cmake.file_api.object_kind.Codemodel.Directory
---@param type cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Type
---@return table<string, any>[] installers
local function installers_of_type(directory, type)
  local installers = {}
  for _, installer in ipairs(directory.installers) do
    if installer.type == type then
      table.insert(installers, installer)
    end
  end
  return installers
end

--- The first install rule of the directory with the given type, if it has one.
---@param directory cmakeseer.cmake.file_api.object_kind.Codemodel.Directory
---@param type cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Type
---@return table<string, any>? installer
local function installer_of_type(directory, type)
  return installers_of_type(directory, type)[1]
end

--- The name of the target the codemodel reports with the given id.
---@param codemodel cmakeseer.cmake.file_api.object_kind.Codemodel
---@param id string
---@return string name
local function target_name_with_id(codemodel, id)
  local configuration = assert(codemodel.configurations[""])
  for _, targets in ipairs({ configuration.targets, configuration.abstract_targets }) do
    for name, target in pairs(targets) do
      if target.id == id then
        return name
      end
    end
  end
  error("The codemodel has no target with the id " .. id)
end

--- The line of the first install rule of a fixture CMakeLists.txt.
---@param relative_path string The path of the CMakeLists.txt, relative to the fixture project.
---@return number line
local function install_rule_line(relative_path)
  local path = vim.fs.joinpath("spec", "fixtures", "cmake", "projects", "codemodel", relative_path)
  for number, line in ipairs(vim.fn.readfile(path)) do
    if line:match("^install%(") ~= nil then
      return number
    end
  end
  error("The fixture " .. relative_path .. " has no install rule")
end

describe("object_kind.Codemodel.Directory", function()
  --- The codemodel object file CMake wrote into the build directory.
  ---@type string
  local object_path

  lazy_setup(function()
    local build_dir = configured_build.of_project("codemodel", function(dir)
      assert.is_nil(file_api_query.issue_shared_stateless_query(dir, object_kind.ObjectKindType.Codemodel, 2))
    end)

    object_path = assert(vim.fn.glob(vim.fs.joinpath(file_api.reply_dir(build_dir), "codemodel-v2-*.json"), true, true)[1])
  end)

  describe("try_from_json", function()
    it("parses the directory object CMake writes", function()
      local directory = configured_directory(object_path, ".")

      assert.are.equal(".", directory.source)
      assert.are.equal(".", directory.build)
      assert.is_true(#directory.installers > 0)
      assert.is_true(#directory.backtrace_graph.nodes > 0)
    end)

    it("records the version of the codemodel it is a part of", function()
      local directory = configured_directory(object_path, ".")
      assert.are.same(configured_codemodel(object_path).version, directory.codemodel_version)
    end)

    it("records a nested directory relative to the top-level one", function()
      local directory = configured_directory(object_path, "math")

      assert.are.equal("math", directory.source)
      assert.are.equal("math", directory.build)
    end)

    it("records the install rule of the target the fixture installs", function()
      local directory = configured_directory(object_path, ".")

      local installer = assert(installer_of_type(directory, Directory.InstallerType.Target))
      assert.are.equal("Unspecified", installer.component)
      assert.are.equal("bin", installer.destination)
      assert.is_true(vim.tbl_contains(installer.paths, "cmakeseer_example"))
      assert.is_true(vim.startswith(installer.id, "cmakeseer_example::@"))
      assert.are.equal("number", type(installer.index))
      assert.is_false(installer.exclude_from_all)
      assert.is_false(installer.for_all_components)
      assert.is_false(installer.optional)
    end)

    it("records the file set the fixture installs", function()
      local directory = configured_directory(object_path, "math")

      local installer = assert(installer_of_type(directory, Directory.InstallerType.FileSet))
      assert.are.equal("math_headers", installer.name)
      assert.are.equal("HEADERS", installer.set_type)
      assert.are.equal("include", installer.destination)
      assert.are.same({ "math/." }, installer.directories)
      assert.is_true(vim.startswith(installer.target.id, "codemodel_math::@"))
      assert.are.equal("number", type(installer.target.index))
    end)

    it("records no install rules for the directory the fixture installs nothing in", function()
      local directory = configured_directory(object_path, "nested")

      assert.are.same({}, directory.installers)
      assert.are.same({}, directory.backtrace_graph.nodes)
    end)

    -- CMake reports the file of a backtrace node relative to the top-level source directory it names.
    it("records the file of the install rule of the top-level directory", function()
      local directory = configured_directory(object_path, ".")

      local installer = assert(installer_of_type(directory, Directory.InstallerType.Target))
      local node = assert(directory.backtrace_graph.nodes[assert(installer.backtrace_index)])

      assert.are.equal("CMakeLists.txt", node.file)
      assert.are.equal(install_rule_line("CMakeLists.txt"), assert(node.line))
      assert.are.equal("install", node.command)
      assert.are.equal(1, assert(node.parent))
    end)

    it("records the file of the install rule of a nested directory", function()
      local directory = configured_directory(object_path, "math")

      local installer = assert(installer_of_type(directory, Directory.InstallerType.Target))
      local node = assert(directory.backtrace_graph.nodes[assert(installer.backtrace_index)])

      assert.are.equal("math/CMakeLists.txt", node.file)
      assert.are.equal(install_rule_line("math/CMakeLists.txt"), assert(node.line))
    end)

    it("records the backtrace of every install rule as a node of the graph", function()
      for _, source in ipairs({ ".", "math" }) do
        local directory = configured_directory(object_path, source)
        assert.is_true(#directory.installers > 0)

        for _, installer in ipairs(directory.installers) do
          local node = assert(directory.backtrace_graph.nodes[assert(installer.backtrace_index)])
          assert.are.equal("install", node.command)
          assert.is_true(vim.endswith(node.file, "CMakeLists.txt"))
        end
      end
    end)

    -- The tests above pin the value of every member; this one pins the shape of the whole object, so that a
    -- member CMake writes as a number is not recorded as a string.
    it("parses the type of every member of the object", function()
      for _, source in ipairs({ ".", "math", "nested" }) do
        local directory = configured_directory(object_path, source)

        assert.are.equal("string", type(directory.source))
        assert.are.equal("string", type(directory.build))
        assert.are.equal("table", type(directory.installers))
        for _, installer in ipairs(directory.installers) do
          assert.are.equal("string", type(installer.component))
          assert.are.equal("string", type(installer.type))
          assert.are.equal("boolean", type(installer.exclude_from_all))
          assert.are.equal("boolean", type(installer.for_all_components))
          assert.are.equal("number", type(installer.backtrace_index))
        end

        assert.are.equal("table", type(directory.backtrace_graph.nodes))
        for _, node in ipairs(directory.backtrace_graph.nodes) do
          assert.are.equal("string", type(node.file))
          assert.is_true(node.line == nil or type(node.line) == "number")
          assert.is_true(node.command == nil or type(node.command) == "string")
          assert.is_true(node.parent == nil or (type(node.parent) == "number" and node.parent <= #directory.backtrace_graph.nodes))
        end
      end
    end)
  end)
end)

describe("object_kind.Codemodel.Directory of the installers project", function()
  --- The codemodel object file CMake wrote into the build directory.
  ---@type string
  local object_path

  lazy_setup(function()
    local build_dir = configured_build.of_project("installers", function(dir)
      assert.is_nil(file_api_query.issue_shared_stateless_query(dir, object_kind.ObjectKindType.Codemodel, 2))
    end)

    object_path = assert(vim.fn.glob(vim.fs.joinpath(file_api.reply_dir(build_dir), "codemodel-v2-*.json"), true, true)[1])
  end)

  --- The directory object CMake wrote for the top-level directory of the fixture project.
  ---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Directory obj
  local function top_level_directory()
    return configured_directory(object_path, ".")
  end

  --- The install rules of the top-level directory of the fixture project with the given type.
  ---@param type cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Type
  ---@return table<string, any>[] installers
  local function top_level_installers(type)
    return installers_of_type(top_level_directory(), type)
  end

  --- The single install rule of the top-level directory of the fixture project with the given type.
  ---@param type cmakeseer.cmake.file_api.object_kind.Codemodel.Installer.Type
  ---@return table<string, any> installer
  local function top_level_installer(type)
    return assert(installer_of_type(top_level_directory(), type))
  end

  describe("try_from_json", function()
    -- The fixture writes an install rule of every type, so a type missing from the parsed object is a type the
    -- parser rejects or drops.
    it("records an install rule of every type CMake reports", function()
      local types = {}
      for _, installer in ipairs(top_level_directory().installers) do
        types[installer.type] = true
      end

      local expected = {}
      for _, type in pairs(Directory.InstallerType) do
        expected[type] = true
      end

      assert.are.same(expected, types)
    end)

    it("records the file install rule", function()
      local installer = top_level_installers(Directory.InstallerType.File)[1]

      assert.are.equal("docs", installer.component)
      assert.are.equal("share/installers", installer.destination)
      assert.are.same({ "README.md" }, installer.paths)
      assert.is_false(installer.optional)
    end)

    it("records the optional flag of a file the fixture does not have", function()
      local installers = top_level_installers(Directory.InstallerType.File)
      assert.are.equal(2, #installers)

      local optional = vim.tbl_filter(function(installer)
        return installer.optional
      end, installers)

      assert.are.equal(1, #optional)
      assert.are.same({ "missing.txt" }, optional[1].paths)
    end)

    -- CMake reports a directory installed with a trailing slash as a path with a destination of its own.
    it("records the directory install rule", function()
      local installer = top_level_installer(Directory.InstallerType.Directory)

      assert.are.equal("Unspecified", installer.component)
      assert.are.equal("include/installers", installer.destination)
      assert.are.same({ { from = "headers", to = "." } }, installer.paths)
      assert.is_false(installer.optional)
    end)

    it("records the target install rule", function()
      local installer = top_level_installer(Directory.InstallerType.Target)

      assert.are.equal("lib", installer.destination)
      assert.are.equal("number", type(installer.index))
      assert.is_true(installer.paths[1]:match("installers_math") ~= nil)
      assert.are.equal("installers_math", target_name_with_id(configured_codemodel(object_path), installer.id))
    end)

    it("records the file set install rule", function()
      local installer = top_level_installer(Directory.InstallerType.FileSet)

      assert.are.equal("math_headers", installer.name)
      assert.are.equal("HEADERS", installer.set_type)
      assert.are.equal("include", installer.destination)
      assert.are.same({ "." }, installer.directories)
      assert.are.same({ "math.hpp" }, installer.paths)
      assert.is_false(installer.optional)
      assert.are.equal("installers_math", target_name_with_id(configured_codemodel(object_path), installer.target.id))
      assert.are.equal("number", type(installer.target.index))
    end)

    it("records the C++ module BMI install rule", function()
      local installer = top_level_installer(Directory.InstallerType.CxxModuleBmi)

      assert.are.equal("include", installer.destination)
      assert.is_false(installer.optional)
      assert.are.equal("installers_math", target_name_with_id(configured_codemodel(object_path), installer.target.id))
    end)

    it("records the export install rule", function()
      local installer = top_level_installer(Directory.InstallerType.Export)

      assert.are.equal("InstallersTargets", installer.name)
      assert.are.equal("lib/cmake/Installers", installer.destination)
      assert.is_true(vim.endswith(installer.paths[1], "InstallersTargets.cmake"))
      assert.are.equal(1, #installer.targets)
      assert.are.equal("installers_math", target_name_with_id(configured_codemodel(object_path), installer.targets[1].id))
      assert.are.equal("number", type(installer.targets[1].index))
    end)

    it("records the script install rule", function()
      local installer = top_level_installers(Directory.InstallerType.Script)[1]

      assert.are.equal("cmake/configure.cmake", installer.file)
      assert.is_false(installer.for_all_components)
    end)

    it("records the script the fixture installs for all components", function()
      local installers = vim.tbl_filter(function(installer)
        return installer.for_all_components
      end, top_level_installers(Directory.InstallerType.Script))

      assert.are.equal(1, #installers)
      assert.are.equal("cmake/configure.cmake", assert(installers[1]).file)
    end)

    -- An install rule of code carries no member beyond the ones every install rule has.
    it("records the code install rule without a destination", function()
      local installer = top_level_installers(Directory.InstallerType.Code)[1]

      assert.are.equal("Unspecified", installer.component)
      assert.is_nil(installer.destination)
      assert.is_nil(installer.file)
      assert.is_false(installer.exclude_from_all)
    end)

    it("records the code the fixture excludes from all", function()
      local installers = vim.tbl_filter(function(installer)
        return installer.exclude_from_all
      end, top_level_installers(Directory.InstallerType.Code))

      assert.are.equal(2, #top_level_installers(Directory.InstallerType.Code))
      assert.are.equal(1, #installers)
    end)

    it("records the imported runtime artifacts install rule", function()
      local installer = top_level_installer(Directory.InstallerType.ImportedRuntimeArtifacts)

      assert.are.equal("Unspecified", installer.component)
      assert.are.equal("string", type(installer.destination))
      assert.is_false(installer.optional)
    end)

    it("records the runtime dependency set install rule", function()
      local installer = top_level_installer(Directory.InstallerType.RuntimeDependencySet)

      assert.are.equal("bin", installer.destination)
      assert.are.equal("installers_runtime", installer.set_name)
      assert.are.equal("library", installer.set_type)
    end)

    it("records the backtrace of every install rule as the install command of the fixture", function()
      local directory = top_level_directory()

      for _, installer in ipairs(directory.installers) do
        local node = assert(directory.backtrace_graph.nodes[assert(installer.backtrace_index)])
        assert.are.equal("install", node.command)
        assert.are.equal("CMakeLists.txt", node.file)
        assert.are.equal("number", type(assert(node.line)))
      end
    end)

    it("parses the type of every member of every install rule", function()
      for _, installer in ipairs(top_level_directory().installers) do
        assert.are.equal("string", type(installer.component))
        assert.are.equal("string", type(installer.type))
        assert.are.equal("boolean", type(installer.exclude_from_all))
        assert.are.equal("boolean", type(installer.for_all_components))
        assert.are.equal("number", type(installer.backtrace_index))
      end
    end)
  end)
end)
