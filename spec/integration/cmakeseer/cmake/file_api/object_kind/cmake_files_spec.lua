local CMakeFiles = require("cmakeseer.cmake.file_api.object_kind.cmake_files")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

--- The path of the cmakeFiles object file written by the last configure.
---@param build_dir string
---@return string? path
local function cmake_files_object_path(build_dir)
  local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "cmakeFiles-*.json")
  local matches = vim.fn.glob(pattern, true, true)
  return matches[1]
end

--- Configures a CMake fixture project with a cmakeFiles query issued.
---@param project string The fixture project to configure.
---@param build_dir string
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles obj
local function configure_with_cmake_files_query(project, build_dir)
  assert.is_nil(file_api_query.issue_shared_stateless_query(build_dir, object_kind.ObjectKindType.CMakeFiles, 1))
  cmake_configure(project, build_dir)

  local path = cmake_files_object_path(build_dir)
  assert.is_not_nil(path)

  local cmake_files, err = CMakeFiles.try_from_file(assert(path))
  assert.is_nil(err)
  return assert(cmake_files)
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

--- The input with the given path, if the object has one.
---@param cmake_files cmakeseer.cmake.file_api.object_kind.CMakeFiles
---@param path string
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input?
local function find_input(cmake_files, path)
  for _, input in ipairs(cmake_files.inputs) do
    if input.path == path then
      return input
    end
  end
  return nil
end

--- The input from the CMake installation, if the object has one.
---@param cmake_files cmakeseer.cmake.file_api.object_kind.CMakeFiles
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input?
local function find_cmake_input(cmake_files)
  for _, input in ipairs(cmake_files.inputs) do
    if input.is_cmake then
      return input
    end
  end
  return nil
end

--- The generated input CMake reported, if the object has one.
---@param cmake_files cmakeseer.cmake.file_api.object_kind.CMakeFiles
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Input?
local function find_generated_input(cmake_files)
  for _, input in ipairs(cmake_files.inputs) do
    if input.generated then
      return input
    end
  end
  return nil
end

--- The glob whose expression ends with the given suffix, if the object has one.
---@param cmake_files cmakeseer.cmake.file_api.object_kind.CMakeFiles
---@param suffix string
---@return cmakeseer.cmake.file_api.object_kind.CMakeFiles.Glob?
local function find_glob(cmake_files, suffix)
  for _, glob in ipairs(assert(cmake_files.globs)) do
    if glob.expression:sub(-#suffix) == suffix then
      return glob
    end
  end
  return nil
end

describe("object_kind.CMakeFiles", function()
  local tmp = require("spec.fixtures.tmpdir")()

  describe("try_from_file", function()
    it("parses the cmakeFiles object CMake writes", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)
      assert.are.equal(object_kind.ObjectKindType.CMakeFiles, cmake_files.kind)
      assert.are.equal(1, cmake_files.version.major)
      assert.is_true(#cmake_files.inputs > 0)
    end)

    it("records the source and build directories the configure used", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)
      assert.are.equal(realpath(assert(configured_source_dir(tmp.path))), realpath(cmake_files.source))
      assert.are.equal(realpath(tmp.path), realpath(cmake_files.build))
    end)

    -- CMake reports a file inside the top-level source directory by its path relative to that directory.
    it("records CMakeLists.txt as an input relative to the source directory", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)

      local input = assert(find_input(cmake_files, "CMakeLists.txt"))
      assert.is_false(input.generated)
      assert.is_false(input.external)
      assert.is_false(input.is_cmake)
    end)

    it("records a generated input as an absolute path under the build directory", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)

      local input = assert(find_generated_input(cmake_files))
      assert.is_false(input.external)
      assert.is_false(input.is_cmake)
      assert.are.equal(input.path:sub(1, #tmp.path), tmp.path)
    end)

    it("records a file from the CMake installation as an external CMake input", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)

      local input = assert(find_cmake_input(cmake_files))
      assert.is_true(input.external)
      assert.is_false(input.generated)
      assert.matches("/Modules/[^/]+%.cmake$", input.path)
    end)

    -- CMake writes an input with only the flags that are true, so assert the shape rather than CMake's output.
    it("parses a boolean and a string for every input", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)
      assert.is_true(#cmake_files.inputs > 0)
      for _, input in ipairs(cmake_files.inputs) do
        assert.are.equal("string", type(input.path))
        assert.are.equal("boolean", type(input.generated))
        assert.are.equal("boolean", type(input.external))
        assert.are.equal("boolean", type(input.is_cmake))
      end
    end)

    it("records no globs for a project that never globs", function()
      local cmake_files = configure_with_cmake_files_query("object_kinds", tmp.path)
      assert.is_nil(cmake_files.globs)
    end)

    it("records every glob a project globs with CONFIGURE_DEPENDS", function()
      local cmake_files = configure_with_cmake_files_query("globs", tmp.path)
      assert.are.equal(3, #assert(cmake_files.globs))
    end)

    it("records the paths a recursive glob matched, with recurse set", function()
      local cmake_files = configure_with_cmake_files_query("globs", tmp.path)

      local glob = assert(find_glob(cmake_files, "/headers/*.hpp"))
      assert.is_true(glob.recurse)
      assert.is_false(glob.list_directories)
      assert.is_nil(glob.relative)
      assert.are.same(
        { "/headers/alpha.hpp", "/headers/nested/beta.hpp" },
        vim.tbl_map(function(path)
          return path:sub(#cmake_files.source + 1)
        end, glob.paths)
      )
    end)

    -- A glob written with LIST_DIRECTORIES false is the only kind CMake reports without "listDirectories".
    it("leaves list_directories false for a glob written with LIST_DIRECTORIES false", function()
      local cmake_files = configure_with_cmake_files_query("globs", tmp.path)

      local glob = assert(find_glob(cmake_files, "/headers/nested/*.hpp"))
      assert.is_false(glob.list_directories)
      assert.is_false(glob.recurse)
    end)

    it("records the relative path of a glob written with RELATIVE", function()
      local cmake_files = configure_with_cmake_files_query("globs", tmp.path)
      assert.are.equal("headers", assert(find_glob(cmake_files, "/headers/nested/*.hpp")).relative)
    end)

    it("records no relative path for a glob written without RELATIVE", function()
      local cmake_files = configure_with_cmake_files_query("globs", tmp.path)
      assert.is_nil(assert(find_glob(cmake_files, "/headers/*.txt")).relative)
    end)

    it("parses a string for every glob member and every glob path", function()
      local cmake_files = configure_with_cmake_files_query("globs", tmp.path)
      assert.is_true(#assert(cmake_files.globs) > 0)
      for _, glob in ipairs(assert(cmake_files.globs)) do
        assert.are.equal("string", type(glob.expression))
        assert.are.equal("boolean", type(glob.recurse))
        assert.are.equal("boolean", type(glob.list_directories))
        assert.are.equal("boolean", type(glob.follow_symlinks))
        assert.is_true(glob.relative == nil or type(glob.relative) == "string")
        assert.are.equal("table", type(glob.paths))
        for _, path in ipairs(glob.paths) do
          assert.are.equal("string", type(path))
        end
      end
    end)
  end)
end)
