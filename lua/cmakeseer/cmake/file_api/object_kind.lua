local M = {
  ---@enum cmakeseer.cmake.file_api.object_kind.ObjectKindType The possible Object Kind types.
  ObjectKindType = {
    Codemodel = "codemodel",
    ConfigureLog = "configureLog",
    Cache = "cache",
    CMakeFiles = "cmakeFiles",
    Toolchains = "toolchains",
  },
}

--- Converts a string to an ObjectKindType.
---@param str string
---@return cmakeseer.cmake.file_api.object_kind.ObjectKindType? maybe_type The type, if it was a valid type.
function M.from_string(str)
  for _, value in pairs(M.ObjectKindType) do
    if value == str then
      return value
    end
  end
  return nil
end

return M
