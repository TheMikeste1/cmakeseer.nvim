---@param path string The directory to look in.
---@param name string The name of the entry to look for.
---@return boolean exists Whether `path` contains an entry named `name`.
local function has(path, name)
  return vim.uv.fs_stat(vim.fs.joinpath(path, name)) ~= nil
end

---@param path string The path to look at.
---@return boolean is_file Whether `path` is an existing file.
local function is_file(path)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

---@return string project_root
local function project_root()
  --- Whether `path` is the root of a CMake project.
  --- We want whichever comes first, from the path:
  --- - Preset files
  --- - Top level CMakeLists.txt
  --- - CMakeLists.txt with a .git (folder or file) that contains a
  ---  `cmake_minimum_required` as the first command and a `project` soon after
  ---@param path string The directory to check.
  ---@return boolean
  local function is_root(path)
    if is_file(vim.fs.joinpath(path, "CMakePresets.json")) or is_file(vim.fs.joinpath(path, "CMakeUserPresets.json")) then
      return true
    end

    local path_list_path = vim.fs.joinpath(path, "CMakeLists.txt")
    local path_list_path_exists = is_file(path_list_path)
    if path_list_path_exists and not is_file(vim.fs.joinpath(vim.fs.dirname(path), "CMakeLists.txt")) then
      return true
    end

    if not path_list_path_exists or not has(path, ".git") then
      return false
    end

    local fin = io.open(path_list_path, "r")
    if fin == nil then
      return false
    end

    local is_project_list = false
    local got_cmake_minimum_required = false
    for line in fin:lines() do
      line = line:match("^%s*(.*)")
      if line ~= "" and line:sub(1, 1) ~= "#" then
        if got_cmake_minimum_required then
          if line:match("^project%s*%(") ~= nil then
            is_project_list = true
            break
          end
        elseif line:match("^cmake_minimum_required%s*%(") ~= nil then
          got_cmake_minimum_required = true
        else
          -- `cmake_minimum_required` is not the first command, so this
          -- `CMakeLists.txt` belongs to a project rooted further up.
          break
        end
      end
    end
    fin:close()

    return is_project_list
  end

  local cwd = vim.uv.cwd() or vim.fn.getcwd()
  if is_root(cwd) then
    return cwd
  end

  for dir in vim.fs.parents(cwd) do
    if is_root(dir) then
      return dir
    end
  end

  return cwd
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
  local self = setmetatable(vim.deepcopy(o), Configuration)
  for k, v in pairs(_defaults) do
    if self[k] == nil then
      if type(v) == "table" then
        self[k] = vim.deepcopy(v)
      else
        self[k] = v
      end
    end
  end

  return self
end

function Configuration:with(o)
  o = o or {}
  o = vim.tbl_deep_extend("keep", o, self)
  o._project_root = nil
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
