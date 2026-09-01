local CMakeSeer = require("cmakeseer")
local CMakePreset = require("cmakeseer.cmake.preset")
local stub = require("luassert.stub")

describe("overseer templates", function()
  before_each(function()
    require("cmakeseer.settings").reset_settings()
    CMakeSeer.state.selections.build_preset = nil
    CMakeSeer.state.selections.configure_preset = nil
  end)

  describe("cmake_build template", function()
    local t = require("overseer.cmakeseer.template.cmake_build")

    it("returns task definition without preset", function()
      local task = t.builder()
      assert.are.equal("CMake Build", task.name)
      assert.are.equal("cmake", task.cmd)
    end)

    it("returns task definition with build_preset name", function()
      CMakeSeer.state.selections.build_preset = "my_build_preset"
      local task = t.builder()
      assert.are.equal("CMake Build (my_build_preset)", task.name)
    end)
  end)

  describe("cmake_configure template", function()
    local t = require("overseer.cmakeseer.template.cmake_configure")

    it("returns task definition without preset", function()
      local task = t.builder()
      assert.are.equal("CMake Configure", task.name)
      assert.are.equal("cmake", task.cmd)
    end)

    it("returns task definition with configure_preset name", function()
      CMakeSeer.state.selections.configure_preset = "my_config_preset"
      local task = t.builder()
      assert.are.equal("CMake Configure (my_config_preset)", task.name)
    end)
  end)

  describe("cmake_configure_no_defines template", function()
    local t = require("overseer.cmakeseer.template.cmake_configure_no_defines")

    it("returns template definition and task definition using basic args", function()
      assert.are.equal("CMake Configure [no defines]", t.name)
      assert.is_function(t.builder)

      local task = t.builder()
      assert.are.equal("CMake Configure", task.name)
      assert.are.equal("cmake", task.cmd)
    end)

    it("includes configure preset name in task name when set", function()
      CMakeSeer.state.selections.configure_preset = "fast"
      local task = t.builder()
      assert.are.equal("CMake Configure (fast)", task.name)
    end)
  end)

  describe("workflow_builder", function()
    local workflow_builder = require("overseer.template.cmakeseer.workflow_builder")

    it("builds template definition for a workflow preset", function()
      local t_def = workflow_builder.build_template_for("ci-workflow")
      assert.are.equal("CMake Workflow ci-workflow", t_def.name)
      assert.are.equal("Runs the `ci-workflow` workflow", t_def.desc)

      local task = t_def.builder()
      assert.are.equal("CMake Workflow ci-workflow", task.name)
      assert.are.equal("cmake", task.cmd)
      assert.are.same({ "--workflow", "--preset", "ci-workflow" }, task.args)
    end)
  end)

  describe("overseer.template.cmakeseer init generator", function()
    local main_template = require("overseer.template.cmakeseer.init")

    it("returns message if project is not a CMake project", function()
      local is_proj_stub = stub(CMakeSeer, "is_cmake_project", false)

      local res = main_template.generator({ dir = "/non/cmake" })
      assert.are.equal("Project is not a CMake project", res)

      is_proj_stub:revert()
    end)

    it("invokes callback with templates list if project is a CMake project", function()
      local is_proj_stub = stub(CMakeSeer, "is_cmake_project", true)
      local fetch_stub = stub(CMakePreset, "fetch_presets", { "wf1" })
      local is_configured_stub = stub(CMakeSeer, "project_is_configured", false)

      local returned_templates = nil
      main_template.generator({ dir = "/cmake/project" }, function(templates)
        returned_templates = templates
      end)

      assert.is_table(returned_templates)
      assert.is_true(#returned_templates >= 4)

      is_proj_stub:revert()
      fetch_stub:revert()
      is_configured_stub:revert()
    end)

    it("returns cache_key from CMakeSeer.get_project_cache_file()", function()
      local get_cache_stub = stub(CMakeSeer, "get_project_cache_file", "/my/build/CMakeCache.txt")

      local key = main_template.cache_key({})
      assert.are.equal("/my/build/CMakeCache.txt", key)

      get_cache_stub:revert()
    end)
  end)
end)
