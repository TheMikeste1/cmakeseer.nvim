local function project_root()
  return vim.fs.root(0, "CMakePresets.json")
    or vim.fs.root(0, "CMakeUserPresets.json")
    -- TODO: We might want this to be more nuanced by finding the git root,
    -- then working our way back down to the current file's directory to find a CMakeLists.txt
    or vim.fs.root(0, ".git")
    or vim.fs.root(0, "CMakeLists.txt") -- fallback to nearest CMakeLists. It's probably be better to keep going up until there are no more.
    or vim.uv.cwd()
    or vim.fn.getcwd()
end

---@private
---@class cmakeseer.Configuration._Fields
local _defaults = {
  ---@type string The command used to run CMake. Defaults to `cmake`.
  cmake_command = "cmake",
  ---@type string|fun(): string The path (or a function that generates a path) to the build directory. Can be relative to the project root.
  build_directory = "./build",
  ---@type fun(): string A function that generates the path to the project root. Can be relative to the current working directory.
  project_root = project_root,
  ---@type cmakeseer.CMakeSettings Contains definition:value pairs to be used when configuring the project.
  default_cmake_settings = {
    configureSettings = {},
    configureArgs = {},
    kit_name = nil,
    parallel = nil,
  },
  ---@type boolean If the PATH environment variable directories should be scanned for kits.
  should_scan_path = true,
  ---@type string[] Additional paths to scan for kits.
  scan_paths = {
    "/usr/bin",
    "/usr/local/bin",
  },
  ---@type string[] Paths to files containing CMake kit definitions. These will not be expanded.
  kit_paths = {},
  ---@type cmakeseer.Kit[] Global user-defined kits.
  kits = {},
  ---@type string? The file to which kit information should be persisted. If nil, kits will not be persisted. Kits will be automatically loaded from this file.
  persist_file = nil,
}

---@class cmakeseer.Configuration: cmakeseer.Configuration._Fields
local Configuration = {
  ---@type string Cached project root.
  _project_root = nil,
}
Configuration.__index = Configuration
---@alias cmakeseer.Config cmakeseer.Configuration

function Configuration.new(o)
  o = o or {}
  local self = setmetatable({}, Configuration)
  for k, v in pairs(_defaults) do
    if o[k] ~= nil then
      self[k] = o[k]
    elseif type(v) == "table" then
      self[k] = vim.deepcopy(v)
    else
      self[k] = v
    end
  end

  return self
end

function Configuration:with(o)
  o = o or {}
  o = vim.tbl_deep_extend("keep", o, self)
  return Configuration.new(o)
end

---@return string
function Configuration:resolve_build_directory()
  local build_dir = self.build_directory
  if type(build_dir) == "function" then
    build_dir = build_dir()
  end

  build_dir = vim.fs.normalize(build_dir)
  if vim.fs.abspath(build_dir) ~= build_dir then
    -- Set relative to the project root
    build_dir = vim.fs.joinpath(self:get_project_root(), build_dir)
  end

  return build_dir
end

function Configuration:reset_project_root()
  self._project_root = self.project_root()
  return self._project_root
end

function Configuration:get_project_root()
  if self._project_root == nil then
    self:reset_project_root()
  end

  return self._project_root
end

return {
  Configuration = Configuration,
  Config = Configuration,
}
