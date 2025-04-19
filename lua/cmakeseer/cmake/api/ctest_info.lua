--[[
-- Source: https://cmake.org/cmake/help/latest/manual/ctest.1.html#show-as-json-object-model
--]]

local Utils = require("cmakeseer.utils")

---@class BacktraceGraph

---@class TestProperty
---@field name string
---@field value string

---@class Test
---@field name string
---@field config string?
---@field command string[]?
---@field backtrace number
---@field properties TestProperty[]

---@class CTestInfo: ObjectKind
---@field backtraceGraph BacktraceGraph
---@field tests Test[]

--- Checks if the provided object is a valid Test.
---@param obj table<string, any> The object to check.
---@return boolean is_valid If the provided object is a valid Test.
local function is_valid_test(obj)
  -- TODO
  return true
end

--- Checks if the tests in the provided array are valid.
---@param tests any[] The tests to check.
---@return boolean are_valid If all the tests in the array are valid.
local function has_valid_tests(tests)
  for _, test in ipairs(tests) do
    if not is_valid_test(test) then
      return false
    end
  end
  return true
end

local M = {}

--- Checks if an object is a valid CodeModel.
---@param obj table<string, any> The object to check.
---@return boolean is_ctest_info If the object is a CTestInfo.
function M.is_valid(obj)
  if not Utils.is_array(obj.tests) then
    return false
  end

  return has_valid_tests(obj.tests)
end

return M
