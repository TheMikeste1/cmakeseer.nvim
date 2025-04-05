--- @class Version
--- @field major integer
--- @field minor integer

--- @class ObjectKind
--- @field kind Kind
--- @field version Version

--- @enum Kind The kinds of objects available from the CMake file API.
local M = {
  cache = "cache",
  cmake_files = "cmakeFiles",
  codemodel = "codemodel",
  configure_log = "configureLog",
  toolchains = "toolchains",
}

return M
