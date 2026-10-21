local Toolchains = require("cmakeseer.cmake.file_api.object_kind.toolchains")
local configured_build = require("spec.fixtures.configured_build")
local file_api = require("cmakeseer.cmake.file_api")
local file_api_query = require("cmakeseer.cmake.file_api.query")
local object_kind = require("cmakeseer.cmake.file_api.object_kind")

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
  --- The path of the toolchains object file CMake wrote into the build directory.
  ---@type string
  local object_path

  lazy_setup(function()
    local build_dir = configured_build.of_project("object_kinds", function(dir)
      assert.is_nil(file_api_query.issue_shared_stateless_query(dir, object_kind.ObjectKindType.Toolchains, 1))
    end)

    local pattern = vim.fs.joinpath(file_api.reply_dir(build_dir), "toolchains-*.json")
    object_path = assert(vim.fn.glob(pattern, true, true)[1])
  end)

  --- Parses the toolchains object CMake wrote, so that every test reads the same reply file of its own.
  ---@return cmakeseer.cmake.file_api.object_kind.Toolchains toolchains
  local function configured_toolchains()
    local toolchains, err = Toolchains.try_from_file(object_path)
    assert.is_nil(err)
    return assert(toolchains)
  end

  describe("try_from_file", function()
    it("parses the toolchains object CMake writes", function()
      local toolchains = configured_toolchains()
      assert.are.equal(object_kind.ObjectKindType.Toolchains, toolchains.kind)
      assert.are.equal(1, toolchains.version.major)
      assert.is_true(#toolchains.toolchains > 0)
    end)

    -- The fixture enables CXX, so CMake must report at least a CXX toolchain.
    it("records the CXX toolchain the fixture declares", function()
      local toolchains = configured_toolchains()
      local cxx = assert(find_toolchain(toolchains, "CXX"))
      assert.are.equal("CXX", cxx.language)
    end)

    -- CMake writes only the compiler fields that are defined; assert the shape rather than
    -- the exact compiler paths and IDs, which vary by host.
    it("parses only strings for every compiler field that is present", function()
      local toolchains = configured_toolchains()
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
      local toolchains = configured_toolchains()
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
      local toolchains = configured_toolchains()
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
