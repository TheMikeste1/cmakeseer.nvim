local config_mod = require("cmakeseer.config")
local Configuration = config_mod.Configuration

describe("cmakeseer.config", function()
  describe("Configuration.new", function()
    it("creates configuration with defaults", function()
      local config = Configuration.new()
      assert.are.equal("cmake", config.cmake_command)
      assert.are.equal("./build", config.build_directory)
      assert.is_true(config.should_scan_path)
    end)

    it("overrides default fields when options provided", function()
      local config = Configuration.new({ cmake_command = "my-cmake", build_directory = "/custom/build" })
      assert.are.equal("my-cmake", config.cmake_command)
      assert.are.equal("/custom/build", config.build_directory)
    end)

    it("preserves persist_file option in Configuration.new", function()
      local config = Configuration.new({ persist_file = "/my/kits.json" })
      assert.are.equal("/my/kits.json", config.persist_file)
    end)
  end)

  describe("Configuration:with", function()
    it("merges new config with existing instance", function()
      local config = Configuration.new({ cmake_command = "cmake1" })
      local new_config = config:with({ cmake_command = "cmake2" })
      assert.are.equal("cmake2", new_config.cmake_command)
      assert.are.equal("./build", new_config.build_directory)
    end)

    it("handles empty options in with()", function()
      local config = Configuration.new()
      local new_config = config:with()
      assert.are.equal(config.cmake_command, new_config.cmake_command)
    end)
  end)

  describe("Configuration:resolve_build_directory", function()
    it("resolves function build_directory relative to project root", function()
      local config = Configuration.new({
        build_directory = function()
          return "dynamic_build"
        end,
        project_root = function()
          return "/project"
        end,
      })
      assert.are.equal("/project/dynamic_build", config:resolve_build_directory())
    end)

    it("resolves relative string build_directory", function()
      local config = Configuration.new({
        build_directory = "rel_build",
        project_root = function()
          return "/project"
        end,
      })
      assert.are.equal("/project/rel_build", config:resolve_build_directory())
    end)

    it("handles absolute build_directory", function()
      local config = Configuration.new({
        build_directory = "/abs/build",
        project_root = function()
          return "/project"
        end,
      })
      assert.are.equal("/abs/build", config:resolve_build_directory())
    end)
  end)

  describe("Configuration:get_project_root and reset_project_root", function()
    it("caches project root until reset", function()
      local call_count = 0
      local config = Configuration.new({
        project_root = function()
          call_count = call_count + 1
          return "/root" .. call_count
        end,
      })

      assert.are.equal("/root1", config:get_project_root())
      assert.are.equal("/root1", config:get_project_root())
      assert.are.equal(1, call_count)

      assert.are.equal("/root2", config:reset_project_root())
      assert.are.equal("/root2", config:get_project_root())
      assert.are.equal(2, call_count)
    end)

    it("uses default project_root resolution function", function()
      local config = Configuration.new()
      assert.is_string(config:get_project_root())
    end)
  end)

  describe("default project_root", function()
    local CMAKE_LISTS = "cmake_minimum_required(VERSION 3.20)\nproject(Foo)\n"

    local root
    local cwd_stub

    --- Creates a directory under the temporary root.
    ---@param rel string The path, relative to the root.
    ---@return string dir The absolute path that was created.
    local function mkdir(rel)
      local dir = vim.fs.joinpath(root, rel)
      vim.fn.mkdir(dir, "p")
      return dir
    end

    --- Writes a file under the temporary root, creating its parent directory.
    ---@param rel string The path, relative to the root.
    ---@param contents string The contents to write.
    ---@return string dir The absolute path of the directory holding the file.
    local function write(rel, contents)
      local path = vim.fs.joinpath(root, rel)
      local dir = vim.fs.dirname(path)
      vim.fn.mkdir(dir, "p")
      local f = assert(io.open(path, "w"))
      f:write(contents)
      f:close()
      return dir
    end

    --- Resolves the project root from a directory relative to the root.
    ---@param rel string The cwd, relative to the root.
    ---@return string project_root
    local function resolve(rel)
      cwd_stub.returns(vim.fs.joinpath(root, rel))
      return Configuration.new():get_project_root()
    end

    before_each(function()
      root = vim.fn.tempname()
      vim.fn.mkdir(root, "p")
      cwd_stub = stub(vim.uv, "cwd")
    end)

    after_each(function()
      cwd_stub:revert()
      vim.fn.delete(root, "rf")
    end)

    it("returns the cwd when it holds the preset files", function()
      local project = write("r/CMakePresets.json", "{}")
      assert.are.equal(project, resolve("r"))
    end)

    it("returns the root from a directory directly below it", function()
      local project = write("r/CMakePresets.json", "{}")
      mkdir("r/a")
      assert.are.equal(project, resolve("r/a"))
    end)

    it("walks past nested directories that hold no CMakeLists.txt", function()
      local project = write("r/CMakePresets.json", "{}")
      write("r/CMakeLists.txt", CMAKE_LISTS)
      mkdir("r/a/b")
      assert.are.equal(project, resolve("r/a/b"))
    end)

    it("walks past a nested build directory", function()
      local project = write("r/CMakePresets.json", "{}")
      write("r/CMakeLists.txt", CMAKE_LISTS)
      mkdir("r/build/debug")
      assert.are.equal(project, resolve("r/build/debug"))
    end)

    it("returns the top level CMakeLists.txt when there is no .git", function()
      local project = write("r/CMakeLists.txt", CMAKE_LISTS)
      assert.are.equal(project, resolve("r"))
    end)

    it("returns the nearest nested repository declaring its own project", function()
      write("r/CMakePresets.json", "{}")
      write("r/CMakeLists.txt", CMAKE_LISTS)
      local nested = write("r/inner/CMakeLists.txt", CMAKE_LISTS)
      mkdir("r/inner/.git")
      mkdir("r/inner/src")
      assert.are.equal(nested, resolve("r/inner/src"))
    end)

    it("keeps walking up when a nested repository declares no project first", function()
      local project = write("r/CMakePresets.json", "{}")
      write("r/CMakeLists.txt", CMAKE_LISTS)
      write("r/inner/CMakeLists.txt", "add_subdirectory(deps)\n" .. CMAKE_LISTS)
      mkdir("r/inner/.git")
      mkdir("r/inner/src")
      assert.are.equal(project, resolve("r/inner/src"))
    end)

    it("ignores a .git without a CMakeLists.txt", function()
      local project = write("r/CMakePresets.json", "{}")
      write("r/CMakeLists.txt", CMAKE_LISTS)
      mkdir("r/inner/.git")
      mkdir("r/inner/src")
      assert.are.equal(project, resolve("r/inner/src"))
    end)

    it("does not read a CMakeLists.txt that is a directory", function()
      local project = write("r/CMakeLists.txt", CMAKE_LISTS)
      mkdir("r/inner/CMakeLists.txt")
      mkdir("r/inner/.git")
      assert.are.equal(project, resolve("r/inner"))
    end)

    it("falls back to the cwd when nothing is found", function()
      local dir = mkdir("empty")
      assert.are.equal(dir, resolve("empty"))
    end)
  end)
end)
