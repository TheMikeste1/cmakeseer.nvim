local function get_script_dir()
  local str = debug.getinfo(1, "S").source
  if str:sub(1, 1) == "@" then
    return str:sub(2):match("^(.*[/\\])") or "./"
  end
  return "./"
end

--- Configures one of the CMake fixture projects, returning the result instead of erroring when it fails.
---@param project string The name of the project to configure.
---@param build_dir string The path to the build directory to use for the project.
---@return integer code, string stdout, string stderr
return function(project, build_dir)
  local project_dir = vim.fs.joinpath(get_script_dir(), project)
  local result = vim
    .system({
      "cmake",
      "-S",
      project_dir,
      "-B",
      build_dir,
    })
    :wait(60000)
  return result.code, result.stdout or "", result.stderr or ""
end
