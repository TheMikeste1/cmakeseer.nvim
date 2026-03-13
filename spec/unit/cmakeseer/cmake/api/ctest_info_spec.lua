local ctest_info = require("cmakeseer.cmake.api.ctest_info")

describe("cmakeseer.cmake.api.ctest_info", function()
  describe("is_valid", function()
    it("returns true for valid CTestInfo", function()
      local obj = {
        tests = {
          { name = "test1" },
        },
      }
      assert.is_true(ctest_info.is_valid(obj))
    end)

    it("returns false if tests is not an array", function()
      local obj = {
        tests = "not an array",
      }
      assert.is_false(ctest_info.is_valid(obj))
    end)

    it("returns false if any test is invalid", function()
      local obj = {
        tests = {
          { name = "valid" },
          { name = 123 }, -- invalid name
        },
      }
      assert.is_false(ctest_info.is_valid(obj))

      obj = {
        tests = { "not a table" },
      }
      assert.is_false(ctest_info.is_valid(obj))
    end)

    it("returns true for empty tests array", function()
      local obj = {
        tests = {},
      }
      assert.is_true(ctest_info.is_valid(obj))
    end)
  end)
end)
