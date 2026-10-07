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

return M
