local function get_script_dir()
  local str = debug.getinfo(1, "S").source
  if str:sub(1, 1) == "@" then
    return str:sub(2):match("^(.*[/\\])") or "./"
  end
  return "./"
end

--- Configures one of the CMake fixture projects.
---@param project string The name of the project to configure.
---@param build_dir string The path to the build directory to use for the project.
return function(project, build_dir)
  local script_dir = get_script_dir()
  local project_dir = vim.fs.joinpath(script_dir, project)
  local result = vim
    .system({
      "cmake",
      "-S",
      project_dir,
      "-B",
      build_dir,
    })
    :wait(60000)
  if result.code ~= 0 then
    result.stdout = result.stdout or ""
    result.stderr = result.stderr or ""
    error("Failed to configure project " .. project .. ": " .. result.stdout .. "\n" .. result.stderr)
  end
end
