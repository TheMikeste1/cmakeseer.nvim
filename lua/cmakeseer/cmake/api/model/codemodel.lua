--[[
-- Source: https://cmake.org/cmake/help/latest/manual/cmake-file-api.7.html#codemodel-version-2
--]]

-- TODO: Fill out descriptions
-- TODO: Create camel-to-snakecase functions

--- @class Paths Contains information about the paths in the CMake projects.
--- @field source string The path to the top-level source directory for the CMake project.
--- @field build string The path to the top-level build directory for the CMake project.

--- @class CMakeVersion
--- @field string string
--- TODO: Add methods to get major/minor/etc.

--- @class Directory
--- @field source string
--- @field parent_index integer?
--- @field child_indexes integer[]?
--- @field project_index integer
--- @field target_indexes integer[]?
--- @field minimum_c_make_version CMakeVersion?
--- @field has_install_rule boolean?
--- @field json_file string

--- @class Project
--- @field name string
--- @field parent_index integer?
--- @field child_indexes integer[]?
--- @field directory_indexes integer[]
--- @field target_indexes integer[]?

--- @class Target
--- @field name string
--- @field id string?
--- @field directory_index integer
--- @field project_index integer
--- @field json_file string

--- @class Configuration
--- @field name string
--- @field directories Directory[]
--- @field projects Project[]
--- @field targets Target[]

--- @class CodeModel: ObjectKind
--- @field paths Paths
--- @field configurations Configuration[]

local M = {}

return M
