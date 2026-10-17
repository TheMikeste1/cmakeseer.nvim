local Toolchains = require("cmakeseer.cmake.file_api.object_kind.toolchains")
local cmake_configure = require("spec.fixtures.cmake.projects.configure")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

--- The path of the toolchains object file written by the last configure.
---@param build_dir string
---@return string? path
local function toolchains_object_path(build_dir)
  local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "toolchains-*.json")
  local matches = vim.fn.glob(pattern, true, true)
  return matches[1]
end

--- Configures the `object_kinds` project with a toolchains query issued.
---@param build_dir string
---@return cmakeseer.cmake.file_api.object_kind.Toolchains obj
local function configure_with_toolchains_query(build_dir)
  assert.is_nil(file_api_query.issue_shared_stateless_query(build_dir, object_kind.ObjectKindType.Toolchains, 1))
  cmake_configure("object_kinds", build_dir)

  local path = toolchains_object_path(build_dir)
  assert.is_not_nil(path)

  local toolchains, err = Toolchains.try_from_file(assert(path))
  assert.is_nil(err)
  return assert(toolchains)
end

--- Finds a toolchain entry for the given language, if present.
---@param toolchains cmakeseer.cmake.file_api.object_kind.Toolchains
---@param language string
---@return cmakeseer.cmake.file_api.object_kind.Toolchains.Entry?
local function find_toolchain(toolchains, language)
  for _, entry in ipairs(toolchains.toolchains) do
    if entry.language == language then
      return entry
    end
  end
  return nil
end

describe("object_kind.Toolchains", function()
  local tmp = require("spec.fixtures.tmpdir")()

  describe("try_from_file", function()
    it("parses the toolchains object CMake writes", function()
      local toolchains = configure_with_toolchains_query(tmp.path)
      assert.are.equal(object_kind.ObjectKindType.Toolchains, toolchains.kind)
      assert.are.equal(1, toolchains.version.major)
      assert.is_true(#toolchains.toolchains > 0)
    end)

    -- The fixture enables CXX, so CMake must report at least a CXX toolchain.
    it("records the CXX toolchain the fixture declares", function()
      local toolchains = configure_with_toolchains_query(tmp.path)
      local cxx = assert(find_toolchain(toolchains, "CXX"))
      assert.are.equal("CXX", cxx.language)
    end)

    -- CMake writes only the compiler fields that are defined; assert the shape rather than
    -- the exact compiler paths and IDs, which vary by host.
    it("parses only strings for every compiler field that is present", function()
      local toolchains = configure_with_toolchains_query(tmp.path)
      assert.is_true(#toolchains.toolchains > 0)
      for _, entry in ipairs(toolchains.toolchains) do
        assert.are.equal("string", type(entry.language))
        local compiler = entry.compiler
        assert.is_true(compiler.path == nil or type(compiler.path) == "string")
        assert.is_true(compiler.command_fragment == nil or type(compiler.command_fragment) == "string")
        assert.is_true(compiler.id == nil or type(compiler.id) == "string")
        assert.is_true(compiler.version == nil or type(compiler.version) == "string")
        assert.is_true(compiler.target == nil or type(compiler.target) == "string")
      end
    end)

    it("parses only strings inside every implicit directory and library list", function()
      local toolchains = configure_with_toolchains_query(tmp.path)
      for _, entry in ipairs(toolchains.toolchains) do
        local implicit = entry.compiler.implicit
        for _, list in ipairs({
          implicit.include_directories or {},
          implicit.link_directories or {},
          implicit.link_framework_directories or {},
          implicit.link_libraries or {},
        }) do
          for _, item in ipairs(list) do
            assert.are.equal("string", type(item))
          end
        end
      end
    end)

    it("parses only strings for sourceFileExtensions when present", function()
      local toolchains = configure_with_toolchains_query(tmp.path)
      for _, entry in ipairs(toolchains.toolchains) do
        if entry.source_file_extensions ~= nil then
          assert.is_true(#entry.source_file_extensions > 0)
          for _, ext in ipairs(entry.source_file_extensions) do
            assert.are.equal("string", type(ext))
          end
        end
      end
    end)
  end)
end)
