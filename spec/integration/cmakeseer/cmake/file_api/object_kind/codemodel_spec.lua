local Codemodel = require("cmakeseer.cmake.file_api.object_kind.codemodel")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local configured_build = require("spec.fixtures.configured_build")

--- The single configuration of the fixture project, which a single configuration generator writes with an empty name.
---@param codemodel cmakeseer.cmake.file_api.object_kind.Codemodel
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration
local function single_configuration(codemodel)
  assert.are.same({ "" }, vim.fn.sort(vim.tbl_keys(codemodel.configurations)))
  return assert(codemodel.configurations[""])
end

--- The directory of the fixture project with the given source path, if the configuration has one.
---@param configuration cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration
---@param source string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Directory?
local function find_directory(configuration, source)
  for _, directory in ipairs(configuration.directories) do
    if directory.source == source then
      return directory
    end
  end
  return nil
end

--- The source directory CMake configured, as recorded in the cache it generated.
---@param build_dir string
---@return string? source_dir
local function configured_source_dir(build_dir)
  local cache = vim.fn.readfile(vim.fs.joinpath(build_dir, "CMakeCache.txt"))
  for _, line in ipairs(cache) do
    local source_dir = line:match("^CMAKE_HOME_DIRECTORY:INTERNAL=(.*)$")
    if source_dir ~= nil then
      return source_dir
    end
  end
  return nil
end

--- The path with symlinks resolved, so that it can be compared to a path CMake reported.
---@param path string
---@return string
local function realpath(path)
  return vim.fs.normalize(assert(vim.uv.fs_realpath(path)))
end

--- The names CMake writes for the targets the fixture project builds.
local BUILDABLE_TARGETS = {
  "cmakeseer_example",
  "codemodel_greet",
  "codemodel_greeting",
  "codemodel_math",
  "codemodel_math_objects",
  "codemodel_plugin",
  "generate_config",
}

describe("object_kind.Codemodel", function()
  describe("try_from_file", function()
    --- The build directory the fixture project was configured into.
    ---@type string
    local build_dir

    --- The codemodel object file CMake wrote into the build directory.
    ---@type string
    local object_path

    --- Parses the codemodel CMake wrote, so that every test reads the same reply file of its own.
    ---@return cmakeseer.cmake.file_api.object_kind.Codemodel codemodel
    local function codemodel_from_configure()
      local codemodel, err = Codemodel.try_from_file(object_path)
      assert.is_nil(err)
      return assert(codemodel)
    end

    lazy_setup(function()
      build_dir = configured_build.of_project("codemodel", function(dir)
        assert.is_nil(file_api_query.issue_shared_stateless_query(dir, object_kind.ObjectKindType.Codemodel, 2))
      end)

      local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "codemodel-v2-*.json")
      object_path = assert(vim.fn.glob(pattern, true, true)[1])
    end)

    it("parses the codemodel object CMake writes", function()
      local codemodel = codemodel_from_configure()
      assert.are.equal(object_kind.ObjectKindType.Codemodel, codemodel.kind)
      assert.are.equal(2, codemodel.version.major)
    end)

    it("writes the configuration of a single configuration generator with an empty name", function()
      local configuration = single_configuration(codemodel_from_configure())
      assert.are.equal("", configuration.name)
    end)

    it("records the source and build directories the configure used", function()
      local codemodel = codemodel_from_configure()
      assert.are.equal(realpath(assert(configured_source_dir(build_dir))), realpath(codemodel.source))
      assert.are.equal(realpath(build_dir), realpath(codemodel.build))
    end)

    it("records every directory the fixture project configures", function()
      local configuration = single_configuration(codemodel_from_configure())
      assert.are.same(
        { ".", "math", "nested" },
        vim.tbl_map(function(directory)
          return directory.source
        end, configuration.directories)
      )
    end)

    -- CMake reports a directory inside the top-level one by its path relative to that one.
    it("records a nested directory relative to the top-level one", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "math"))
      assert.are.equal("math", directory.source)
      assert.are.equal("math", directory.build)
    end)

    it("records the top-level directory as the source and build directory itself", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "."))
      assert.are.equal(".", directory.source)
      assert.are.equal(".", directory.build)
    end)

    it("records the version the fixture project requires as the minimum CMake version", function()
      local configuration = single_configuration(codemodel_from_configure())
      for _, directory in ipairs(configuration.directories) do
        assert.are.same({ major = 3, minor = 28 }, assert(directory.minimum_cmake_version))
      end
    end)

    it("records the install rule of a directory that has one", function()
      local configuration = single_configuration(codemodel_from_configure())

      assert.is_true(assert(find_directory(configuration, ".")).has_install_rule)
      assert.is_true(assert(find_directory(configuration, "math")).has_install_rule)
    end)

    it("records no install rule for a directory that has none", function()
      local configuration = single_configuration(codemodel_from_configure())
      assert.is_false(assert(find_directory(configuration, "nested")).has_install_rule)
    end)

    it("records the parent of a nested directory", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "nested"))
      assert.are.equal(find_directory(configuration, ".").source, configuration.directories[assert(directory.parent_index) + 1].source)
      assert.are.equal("NestedExample", directory.project)
    end)

    it("records the children of the top-level directory", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "."))
      assert.are.same(
        { "math", "nested" },
        vim.tbl_map(function(index)
          return configuration.directories[index + 1].source
        end, assert(directory.child_indices))
      )
    end)

    it("records the project of the top-level directory", function()
      local configuration = single_configuration(codemodel_from_configure())
      assert.are.equal("CodemodelExample", assert(find_directory(configuration, ".")).project)
    end)

    it("records the top-level project without a parent", function()
      local configuration = single_configuration(codemodel_from_configure())

      local project = assert(configuration.projects["CodemodelExample"])
      assert.is_nil(project.parent)
      assert.are.same({ "NestedExample" }, project.children)
      assert.are.same(
        { ".", "math" },
        vim.tbl_map(function(index)
          return configuration.directories[index + 1].source
        end, assert(project.directory_indices))
      )
    end)

    it("records the parent of the nested project", function()
      local configuration = single_configuration(codemodel_from_configure())

      local project = assert(configuration.projects["NestedExample"])
      assert.are.equal("CodemodelExample", project.parent)
      assert.are.same({}, project.children)
      assert.are.same(
        { "nested" },
        vim.tbl_map(function(index)
          return configuration.directories[index + 1].source
        end, assert(project.directory_indices))
      )
    end)

    it("records every target the fixture project builds", function()
      local configuration = single_configuration(codemodel_from_configure())
      for _, name in ipairs(BUILDABLE_TARGETS) do
        assert.is_not_nil(configuration.targets[name])
      end
    end)

    it("records the directory a target is defined in", function()
      local configuration = single_configuration(codemodel_from_configure())

      local target = assert(configuration.targets["codemodel_math"])
      assert.are.equal("math", configuration.directories[target.directory_index + 1].source)
    end)

    it("records the project a target belongs to", function()
      local configuration = single_configuration(codemodel_from_configure())

      assert.are.equal("CodemodelExample", assert(configuration.targets["cmakeseer_example"]).project)
      assert.are.equal("NestedExample", assert(configuration.targets["codemodel_plugin"]).project)
    end)

    -- CMake reports a target it imported from a find_package as abstract rather than buildable.
    it("records an imported target as abstract", function()
      local configuration = single_configuration(codemodel_from_configure())
      assert.is_not_nil(configuration.abstract_targets["Threads::Threads"])
      assert.is_nil(configuration.targets["Threads::Threads"])
    end)

    it("records an explicitly imported target as abstract", function()
      local configuration = single_configuration(codemodel_from_configure())
      assert.is_not_nil(configuration.abstract_targets["codemodel_imported_math"])
      assert.is_nil(configuration.targets["codemodel_imported_math"])
    end)

    it("records every target of the fixture project in exactly one of the two target lists", function()
      local configuration = single_configuration(codemodel_from_configure())

      local names = vim.list_extend(vim.tbl_keys(configuration.targets), vim.tbl_keys(configuration.abstract_targets))
      for _, name in ipairs(BUILDABLE_TARGETS) do
        assert.is_truthy(vim.tbl_contains(names, name))
      end

      -- The interface library of the fixture is abstract in current CMake and buildable in older ones.
      assert.is_truthy(vim.tbl_contains(names, "codemodel_example_headers"))
    end)

    it("keeps the targets and the abstract targets disjoint", function()
      local configuration = single_configuration(codemodel_from_configure())

      for name, target in pairs(configuration.targets) do
        assert.are.equal(name, target.name)
        assert.is_nil(configuration.abstract_targets[name])
      end
      for name, target in pairs(configuration.abstract_targets) do
        assert.are.equal(name, target.name)
        assert.is_nil(configuration.targets[name])
      end
    end)

    it("records the targets of a directory as names the configuration resolves", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "nested"))
      assert.is_true(#directory.targets > 0)
      for _, name in ipairs(directory.targets) do
        assert.are.equal(name, assert(configuration.targets[name]).name)
      end
    end)

    it("records the abstract targets of a directory as names the configuration resolves", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "."))
      assert.is_true(#directory.abstract_targets > 0)
      for _, name in ipairs(directory.abstract_targets) do
        assert.are.equal(name, assert(configuration.abstract_targets[name]).name)
      end
    end)

    -- CMake writes the jsonFile of every member as a file name next to the codemodel that reports it.
    it("resolves the jsonFile of a target into the reply directory", function()
      local configuration = single_configuration(codemodel_from_configure())

      local target = assert(configuration.targets["cmakeseer_example"])
      assert.is_true(vim.startswith(target.json_file, file_api.reply_dir(build_dir)))
      assert.are.equal(1, vim.fn.filereadable(target.json_file))
    end)

    it("resolves the jsonFile of a directory into the reply directory", function()
      local configuration = single_configuration(codemodel_from_configure())

      local directory = assert(find_directory(configuration, "nested"))
      assert.is_true(vim.startswith(directory.json_file, file_api.reply_dir(build_dir)))
      assert.are.equal(1, vim.fn.filereadable(directory.json_file))
    end)

    -- The tests above pin the value of every member; this one pins the shape of the whole reply, so that a member
    -- CMake writes as a number or a boolean is not recorded as a string, and a member it writes as a string is
    -- not recorded as a number.
    it("parses the type of every member of the reply", function()
      local configuration = single_configuration(codemodel_from_configure())

      for _, project in pairs(configuration.projects) do
        assert.are.equal("string", type(project.name))
        for _, field in ipairs({ "children", "targets", "abstract_targets", "directory_indices" }) do
          assert.are.equal("table", type(project[field]))
        end
      end
      for _, directory in ipairs(configuration.directories) do
        assert.are.equal("string", type(directory.source))
        assert.are.equal("string", type(directory.build))
        assert.are.equal("string", type(directory.project))
        assert.are.equal("string", type(directory.json_file))
        assert.are.equal("boolean", type(directory.has_install_rule))
        assert.are.equal("table", type(directory.minimum_cmake_version))
      end
      for _, targets in ipairs({ configuration.targets, configuration.abstract_targets }) do
        for _, target in pairs(targets) do
          assert.are.equal("string", type(target.name))
          assert.are.equal("string", type(target.id))
          assert.are.equal("string", type(target.project))
          assert.are.equal("string", type(target.json_file))
          assert.are.equal("number", type(target.directory_index))
        end
      end
    end)
  end)
end)
