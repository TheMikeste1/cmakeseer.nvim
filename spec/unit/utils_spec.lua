local utils = require("cmakeseer.utils")

describe("cmakeseer._core.utils", function()
  describe("is_object", function()
    it("should return false for a table (object)", function()
      assert.is_false(utils.is_object({}))
    end)

    it("should return false for an array", function()
      assert.is_false(utils.is_object({ 1, 2, 3 }))
    end)

    it("should return false for a string", function()
      assert.is_false(utils.is_object("hello"))
    end)

    it("should return false for a number", function()
      assert.is_false(utils.is_object(123))
    end)

    it("should return false for nil", function()
      assert.is_false(utils.is_object(nil))
    end)
  end)

  describe("remove_duplicates", function()
    it("should remove duplicate elements from an array", function()
      local array = { 1, 2, 2, 3, 4, 4, 4, 5 }
      local expected = { 1, 2, 3, 4, 5 }
      assert.same(expected, utils.remove_duplicates(array))
    end)

    it("should return the same array if no duplicates exist", function()
      local array = { 1, 2, 3, 4, 5 }
      local expected = { 1, 2, 3, 4, 5 }
      assert.same(expected, utils.remove_duplicates(array))
    end)

    it("should handle an empty array", function()
      local array = {}
      local expected = {}
      assert.same(expected, utils.remove_duplicates(array))
    end)
  end)

  describe("merge_sets", function()
    it("should merge two sets with no common elements", function()
      local a = { 1, 2, 3 }
      local b = { 4, 5, 6 }
      local expected = { 1, 2, 3, 4, 5, 6 }
      assert.same(expected, utils.merge_sets(a, b))
    end)

    it("should merge two sets with common elements", function()
      local a = { 1, 2, 3 }
      local b = { 3, 4, 5 }
      local expected = { 1, 2, 3, 4, 5 }
      assert.same(expected, utils.merge_sets(a, b))
    end)

    it("should handle one nil set", function()
      local a = { 1, 2, 3 }
      local b = nil
      local expected = { 1, 2, 3 }
      assert.same(expected, utils.merge_sets(a, b))
    end)

    it("should handle both nil sets", function()
      local a = nil
      local b = nil
      local expected = {}
      assert.same(expected, utils.merge_sets(a, b))
    end)
  end)

  describe("exists", function()
    it("should return true if element exists in array", function()
      local array = { 10, 20, 30 }
      assert.is_true(utils.exists(array, 20))
    end)

    it("should return false if element does not exist in array", function()
      local array = { 10, 20, 30 }
      assert.is_false(utils.exists(array, 40))
    end)

    it("should handle empty array", function()
      local array = {}
      assert.is_false(utils.exists(array, 1))
    end)
  end)
end)
