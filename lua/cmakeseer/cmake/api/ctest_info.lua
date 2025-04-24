--[[
-- Source: https://cmake.org/cmake/help/latest/manual/ctest.1.html#show-as-json-object-model
--]]

local Utils = require("cmakeseer.utils")

---@class cmakeseer.cmake.api.Node
---@field file number The index of the associated file.
---@field command number? The index of the associated command.
---@field line number? The line number in `file`.
---@field parent number? The parent node.

---@class cmakeseer.cmake.api.BacktraceGraph
---@field commands string[] The commands used to create the tests.
---@field files string[] The files containing the tests.
---@field nodes cmakeseer.cmake.api.Node[] Information about where tests are.

---@class cmakeseer.cmake.api.TestProperty
---@field name string
---@field value string

---@class cmakeseer.cmake.api.Test
---@field name string
---@field config string?
---@field command string[]?
---@field backtrace number
---@field properties cmakeseer.cmake.api.TestProperty[]

---@class cmakeseer.cmake.api.CTestInfo: cmakeseer.cmake.api.ObjectKind
---@field backtraceGraph cmakeseer.cmake.api.BacktraceGraph
---@field tests cmakeseer.cmake.api.Test[]

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
