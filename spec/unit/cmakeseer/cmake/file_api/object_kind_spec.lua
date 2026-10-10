local object_kind = require("cmakeseer.cmake.file_api.object_kind")

describe("object_kind", function()
  describe("ObjectKindType", function()
    it("Codemodel value matches the CMake docs", function()
      assert.are.equal("codemodel", object_kind.ObjectKindType.Codemodel)
    end)
    it("ConfigureLog value matches the CMake docs", function()
      assert.are.equal("configureLog", object_kind.ObjectKindType.ConfigureLog)
    end)
    it("Cache value matches the CMake docs", function()
      assert.are.equal("cache", object_kind.ObjectKindType.Cache)
    end)
    it("CMakeFiles value matches the CMake docs", function()
      assert.are.equal("cmakeFiles", object_kind.ObjectKindType.CMakeFiles)
    end)
    it("Toolchains value matches the CMake docs", function()
      assert.are.equal("toolchains", object_kind.ObjectKindType.Toolchains)
    end)
  end)

  describe("from_string", function()
    for _, value in pairs(object_kind.ObjectKindType) do
      it(("converts %q to an object kind"):format(value), function()
        assert.are.equal(value, object_kind.from_string(value))
      end)
    end

    for _, value in ipairs({ "", "Codemodel", "codemodel ", "cache2" }) do
      it(("returns nil for %q"):format(value), function()
        assert.is_nil(object_kind.from_string(value))
      end)
    end
  end)
end)
