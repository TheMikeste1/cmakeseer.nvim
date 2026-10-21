local Codemodel = require("cmakeseer.cmake.file_api.object_kind.codemodel")
local Target = require("cmakeseer.cmake.file_api.object_kind.codemodel.target")
local configured_build = require("spec.fixtures.configured_build")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

--- The single configuration of the fixture project, which a single configuration generator writes with an empty name.
---@param codemodel cmakeseer.cmake.file_api.object_kind.Codemodel
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration
local function single_configuration(codemodel)
  assert.are.same({ "" }, vim.fn.sort(vim.tbl_keys(codemodel.configurations)))
  return assert(codemodel.configurations[""])
end

--- The target of the fixture project with the given name.
---@param configuration cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration
---@param name string
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Configuration.Target
local function target_of(configuration, name)
  local target = assert(configuration.targets[name], "The fixture project has no target named " .. name)
  return target
end

--- Parses the target object CMake wrote for the target with the given name.
---@param object_path string The path to the codemodel object file CMake wrote.
---@param name string The name of the target.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target target
local function configured_target(object_path, name)
  local configuration = single_configuration(assert(Codemodel.try_from_file(object_path)))
  local target = target_of(configuration, name)

  local json, err = object_kind.try_decode_file(target.json_file)
  assert.is_nil(err)

  local parsed
  parsed, err = Target.try_from_json(assert(json))
  assert.is_nil(err)
  return assert(parsed)
end

describe("object_kind.Codemodel.Target", function()
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
    it("parses the target object CMake writes for the executable", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("cmakeseer_example", target.name)
      assert.is_true(target.id:match("^cmakeseer_example::@") ~= nil)
      assert.are.equal(Target.Type.Executable, target.type)
      assert.is_false(target.imported)
      assert.is_false(target["local"])
      assert.is_false(target.abstract)
      assert.is_false(target.symbolic)
      assert.are.equal(".", target.source)
      assert.are.equal(".", target.build)
    end)

    it("parses the target object CMake writes for the static library", function()
      local target = configured_target(object_path, "codemodel_math")

      assert.are.equal("codemodel_math", target.name)
      assert.are.equal(Target.Type.StaticLibrary, target.type)
      assert.are.equal("math", target.source)
      assert.are.equal("math", target.build)
    end)

    it("parses the target object CMake writes for the shared library", function()
      local target = configured_target(object_path, "codemodel_greeting")

      assert.are.equal("codemodel_greeting", target.name)
      assert.are.equal(Target.Type.SharedLibrary, target.type)
      assert.are.equal("nested", target.source)
      assert.are.equal("nested", target.build)
    end)

    it("parses the target object CMake writes for the module library", function()
      local target = configured_target(object_path, "codemodel_plugin")

      assert.are.equal("codemodel_plugin", target.name)
      assert.are.equal(Target.Type.ModuleLibrary, target.type)
      assert.are.equal("nested", target.source)
    end)

    it("parses the target object CMake writes for the object library", function()
      local target = configured_target(object_path, "codemodel_math_objects")

      assert.are.equal("codemodel_math_objects", target.name)
      assert.are.equal(Target.Type.ObjectLibrary, target.type)
    end)

    it("parses the target object CMake writes for the utility target", function()
      local target = configured_target(object_path, "generate_config")

      assert.are.equal("generate_config", target.name)
      assert.are.equal(Target.Type.Utility, target.type)
      assert.are.equal("Helpers", target.folder)
    end)

    it("records the link step of an executable target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      local link = assert(target.link)
      assert.are.equal("string", type(link.language))
      assert.are.equal("table", type(link.command_fragments))
      assert.are.equal("boolean", type(link.lto))
    end)

    it("records the archive step of a static library target", function()
      local target = configured_target(object_path, "codemodel_math")

      if target.archive ~= nil then
        assert.are.equal("boolean", type(target.archive.lto))
      end
    end)

    it("records the sources of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("table", type(target.sources))
      assert.is_true(#target.sources > 0)
      for _, source in ipairs(target.sources) do
        assert.are.equal("string", type(source.path))
        assert.is_true(source.generated == nil or type(source.generated) == "boolean")
      end
    end)

    it("records the compile groups of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("table", type(target.compile_groups))
      for _, group in ipairs(target.compile_groups) do
        assert.are.equal("string", type(group.language))
        assert.are.equal("table", type(group.source_indexes))
      end
    end)

    it("records the source groups of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("table", type(target.source_groups))
      for _, group in ipairs(target.source_groups) do
        assert.are.equal("string", type(group.name))
        assert.are.equal("table", type(group.source_indexes))
      end
    end)

    it("records the file sets of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      if target.file_sets ~= nil then
        assert.are.equal("table", type(target.file_sets))
      end
    end)

    it("records the dependencies of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("table", type(target.dependencies))
      for _, dep in ipairs(target.dependencies) do
        assert.are.equal("string", type(dep.id))
      end
    end)

    it("records the link libraries of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("table", type(target.link_libraries))
    end)

    it("records the interface link libraries of a target", function()
      local target = configured_target(object_path, "codemodel_greeting")

      if target.interface_link_libraries ~= nil then
        assert.are.equal("table", type(target.interface_link_libraries))
      end
    end)

    it("records the interface includes of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      if target.interface_includes ~= nil then
        assert.are.equal("table", type(target.interface_includes))
      end
    end)

    it("records the backtrace graph of a target", function()
      local target = configured_target(object_path, "cmakeseer_example")

      assert.are.equal("table", type(target.backtrace_graph.nodes))
      assert.is_true(#target.backtrace_graph.nodes > 0)
    end)

    -- The tests above pin the value of every member; this one pins the shape of the whole object, so that a
    -- member CMake writes as a number is not recorded as a string.
    it("parses the type of every member of every target", function()
      single_configuration(assert(Codemodel.try_from_file(object_path)))

      for _, name in ipairs({ "cmakeseer_example", "codemodel_math", "codemodel_greeting", "codemodel_plugin", "codemodel_math_objects", "generate_config" }) do
        local target = configured_target(object_path, name)

        assert.are.equal("string", type(target.name))
        assert.are.equal("string", type(target.id))
        assert.are.equal("string", type(target.type))
        assert.are.equal("boolean", type(target.imported))
        assert.are.equal("boolean", type(target["local"]))
        assert.are.equal("boolean", type(target.abstract))
        assert.are.equal("boolean", type(target.symbolic))
        assert.are.equal("string", type(target.source))
        assert.are.equal("string", type(target.build))
        assert.are.equal("table", type(target.backtrace_graph.nodes))
        if target.dependencies ~= nil then
          for _, dep in ipairs(target.dependencies) do
            assert.are.equal("string", type(dep.id))
          end
        end
        if target.sources ~= nil then
          for _, source in ipairs(target.sources) do
            assert.are.equal("string", type(source.path))
          end
        end
        if target.compile_groups ~= nil then
          for _, group in ipairs(target.compile_groups) do
            assert.are.equal("string", type(group.language))
          end
        end
      end
    end)

    it("records an interface library without artifacts", function()
      local configuration = single_configuration(assert(Codemodel.try_from_file(object_path)))
      local headers = configuration.targets["codemodel_example_headers"]

      if headers ~= nil then
        local target = configured_target(object_path, "codemodel_example_headers")
        assert.are.equal(Target.Type.InterfaceLibrary, target.type)
        assert.is_nil(target.artifacts)
      end
    end)
  end)
end)
