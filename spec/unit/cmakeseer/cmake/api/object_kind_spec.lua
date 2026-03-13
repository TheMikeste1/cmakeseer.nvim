local ObjectKind = require("cmakeseer.cmake.api.object_kind")
local CodeModel = require("cmakeseer.cmake.api.codemodel")
local CTestInfo = require("cmakeseer.cmake.api.ctest_info")
local stub = require("luassert.stub")

describe("cmakeseer.cmake.api.object_kind", function()
  describe("is_valid", function()
    it("returns false if obj is not a table", function()
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.is_false(ObjectKind.is_valid("not a table"))
    end)

    it("returns false if kind is missing or not a string", function()
      assert.is_false(ObjectKind.is_valid({}))
      assert.is_false(ObjectKind.is_valid({ kind = 123 }))
    end)

    it("returns false if version is missing or invalid", function()
      assert.is_false(ObjectKind.is_valid({ kind = "test" }))
      assert.is_false(ObjectKind.is_valid({ kind = "test", version = "not a table" }))
      assert.is_false(ObjectKind.is_valid({ kind = "test", version = {} }))
      assert.is_false(ObjectKind.is_valid({ kind = "test", version = { major = "1", minor = 0 } }))
    end)

    it("returns false if expected_kind does not match", function()
      local obj = { kind = "wrong", version = { major = 1, minor = 0 } }
      ---@diagnostic disable-next-line: param-type-mismatch
      assert.is_false(ObjectKind.is_valid(obj, "correct"))
    end)

    it("calls CodeModel.is_valid for codemodel kind", function()
      local obj = { kind = ObjectKind.Kind.codemodel, version = { major = 1, minor = 0 } }
      local s = stub(CodeModel, "is_valid", true)
      assert.is_true(ObjectKind.is_valid(obj))
      assert.stub(s).was.called_with(obj)
      s:revert()
    end)

    it("calls CTestInfo.is_valid for ctest_info kind", function()
      local obj = { kind = ObjectKind.Kind.ctest_info, version = { major = 1, minor = 0 } }
      local s = stub(CTestInfo, "is_valid", true)
      assert.is_true(ObjectKind.is_valid(obj))
      assert.stub(s).was.called_with(obj)
      s:revert()
    end)

    it("errors for unimplemented kind", function()
      local obj = { kind = "unimplemented", version = { major = 1, minor = 0 } }
      assert.has_error(function()
        ObjectKind.is_valid(obj)
      end, "Unimplemented ObjectKind: unimplemented")
    end)
  end)
end)
