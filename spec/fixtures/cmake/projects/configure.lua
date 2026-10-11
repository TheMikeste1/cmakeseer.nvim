local try_configure = require("spec.fixtures.cmake.projects.try_configure")

--- Configures one of the CMake fixture projects.
---@param project string The name of the project to configure.
---@param build_dir string The path to the build directory to use for the project.
return function(project, build_dir)
  local code, stdout, stderr = try_configure(project, build_dir)
  if code ~= 0 then
    error("Failed to configure project " .. project .. ": " .. stdout .. "\n" .. stderr)
  end
end
