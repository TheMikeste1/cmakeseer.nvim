---@alias cmakeseer.cmake.Preset cmakeseer.cmake.preset.BuildPreset|cmakeseer.cmake.preset.ConfigurePreset|cmakeseer.cmake.preset.PackagePreset|cmakeseer.cmake.preset.TestPreset|cmakeseer.cmake.preset.WorkflowPreset

---@enum cmakeseer.cmake.PresetType
local PresetTypes = {
  Configure = "configure",
  Build = "build",
  Test = "test",
  Package = "package",
  Workflow = "workflow",
}

local M = {
  PresetTypes = PresetTypes,
}

--- Resolves CMake-preset style paths, filling in variables like ${source_dir} and ${hostSystemName}.
--- See also <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion>
---@param path string The path to resolve.
---@param dir string Source directory to use when resolving paths.
---@return string resolved_path The resolved path.
function M.resolve_path(path, dir)
  -- TODO: This probably needs to be made more generic so it can resolve the macros in any preset value. . .
  local expanded = path:gsub("(%${([^}]+)})", function(match, var)
    -- TODO: Support more. We probably need more info about the preset we're resolving.
    -- It might actually be better to create a Preset class that has a resolve path method on it.
    if var == "sourceDir" then
      return dir
    elseif var == "sourceParentDir" then
      return vim.fs.dirname(dir)
    elseif var == "sourceDirName" then
      return vim.fs.basename(dir)
    elseif var == "presetName" then
      vim.notify("Preset variable `presetName` not yet supported", vim.log.levels.ERROR)
    elseif var == "generator" then
      vim.notify("Preset variable `generator` not yet supported", vim.log.levels.ERROR)
    elseif var == "hostSystemName" then
      local system_name = vim.uv.os_uname().sysname
      if system_name == "Windows_NT" then
        return "Windows"
      end
      return system_name
    elseif var == "fileDir" then
      vim.notify("Preset variable `fileDir` not yet supported", vim.log.levels.ERROR)
    elseif var == "dollar" then
      return "$"
    elseif var == "pathListSep" then
      local system_name = vim.uv.os_uname().sysname
      if system_name == "Windows_NT" then
        return ";"
      end
      return ":"
    end

    -- Not recognized; return the match.
    return match
  end)

  expanded = expanded:gsub("(%$env{([^}]+)})", function(match, var)
    -- TODO: Check the environment field of the preset and prefer it instead
    local maybe_env = vim.env[var]
    if maybe_env ~= nil then
      return maybe_env
    end
    -- Not recognized; return the match.
    return match
  end)

  expanded = expanded:gsub("(%$penv{([^}]+)})", function(match, var)
    local maybe_env = vim.env[var]
    if maybe_env ~= nil then
      return maybe_env
    end
    -- Not recognized; return the match.
    return match
  end)

  expanded = vim.fs.normalize(expanded)
  return expanded
end

--- Fetches the available presets.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@return string[] presets The list of presets.
function M.fetch_presets(dir, preset_type)
  local presets = {}
  local command = { "cmake", "-S", dir, "--list-presets", preset_type }
  local preset_str = vim.system(command):wait().stdout or ""
  for preset in string.gmatch(preset_str, '"([^"]+)"') do
    table.insert(presets, preset)
  end
  return presets
end

--- Finds the file for the given preset.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@param opts table? Additional options. TODO: Document the options.
---@return cmakeseer.cmake.preset.PresetFile? file The preset file containing the preset.
function M.file_for(preset, dir, preset_type, opts)
  ---@param file cmakeseer.cmake.preset.PresetFile
  ---@return boolean
  local function file_has_preset(file)
    ---@param list { name: string }[]
    ---@return boolean
    local function list_has_preset(list)
      for _, entry in ipairs(list) do
        if entry.name == preset then
          return true
        end
      end
      return false
    end

    local preset_list = nil
    if preset_type == PresetTypes.Configure then
      preset_list = file.configure_presets
    elseif preset_type == PresetTypes.Build then
      preset_list = file.build_presets
    elseif preset_type == PresetTypes.Test then
      preset_list = file.test_presets
    elseif preset_type == PresetTypes.Package then
      preset_list = file.package_presets
    elseif preset_type == PresetTypes.Workflow then
      preset_list = file.workflow_presets
    end

    return preset_list ~= nil and list_has_preset(preset_list)
  end

  opts = opts or { check_includes = true, safe_check_includes = true }

  local safe_check_includes = opts.check_includes and opts.safe_check_includes
  local files_to_check = {
    "CMakePresets.json",
    "CMakeUserPresets.json",
  }
  local already_checked = {}
  while #files_to_check > 0 do
    local includes = {}
    for _, file in ipairs(files_to_check) do
      local cmake_preset_path = vim.fs.joinpath(dir, file)
      local preset_file = require("cmakeseer.cmake.preset.preset_file").try_from_file(cmake_preset_path)
      if preset_file ~= nil then
        if file_has_preset(preset_file) then
          return preset_file
        end

        if preset_file.include ~= nil and opts.check_includes then
          local new_includes = preset_file:resolve_includes()
          if safe_check_includes then
            new_includes = vim
              .iter(new_includes)
              :filter(function(include)
                return not vim.list_contains(already_checked, include)
              end)
              :unique()
              :totable()
            ---@cast new_includes string[]
          end

          vim.list_extend(includes, new_includes)
        end
      end
    end

    if safe_check_includes then
      vim.list_extend(already_checked, files_to_check)
    end
    files_to_check = includes
  end

  return nil
end

--- Finds the file for the given preset.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@return cmakeseer.cmake.Preset? entry The preset, if it was found. Guaranteed to be the given type when it is fond.
function M.entry_for(preset, dir, preset_type)
  local preset_file = M.file_for(preset, dir, preset_type)
  if preset_file == nil then
    return nil
  end

  local preset_list = nil
  if preset_type == PresetTypes.Configure then
    preset_list = preset_file.configure_presets
  elseif preset_type == PresetTypes.Build then
    preset_list = preset_file.build_presets
  elseif preset_type == PresetTypes.Test then
    preset_list = preset_file.test_presets
  elseif preset_type == PresetTypes.Package then
    preset_list = preset_file.package_presets
  elseif preset_type == PresetTypes.Workflow then
    preset_list = preset_file.workflow_presets
  end

  assert(preset_list ~= nil, "file_for would only have returned if the preset list was not nil")

  -- Fetch the entry
  for _, entry in ipairs(preset_list) do
    if entry.name == preset then
      return entry
    end
  end

  error("UNREACHABLE: file_for would only have returned if the preset existed")
end

--- Gets the binary directory for the given preset, if it has one.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@param opts table? Additional options. TODO: Document the options.
---@return string? binary_dir The binary directory for the preset, if it exists and has one.
function M.try_determine_binary_dir(preset, dir, preset_type, opts)
  opts = opts or { resolve_path = false }

  -- Workflows are unique and may not have one specific binary dir
  if preset_type == PresetTypes.Workflow then
    return nil
  end

  local preset_entry = M.entry_for(preset, dir, preset_type)
  if preset_entry == nil then
    return nil
  end

  local binary_dir = nil
  if preset_type == PresetTypes.Configure then
    ---@cast preset_entry cmakeseer.cmake.preset.ConfigurePreset
    binary_dir = preset_entry.binary_dir
    if binary_dir == nil and preset_entry.inherits ~= nil then
      ---@type string[]
      local inherits = preset_entry.inherits
      for _, inheritted in ipairs(inherits) do
        binary_dir = M.try_determine_binary_dir(inheritted, dir, PresetTypes.Configure)
        if binary_dir ~= nil then
          -- Break on the first to have a binary dir.
          break
        end
      end
    end
  else
    local configure_preset = preset_entry.configure_preset
    if configure_preset ~= nil then
      binary_dir = M.try_determine_binary_dir(configure_preset, dir, PresetTypes.Configure)
    end

    if binary_dir == nil and preset_entry.inherits ~= nil then
      ---@type string[]
      local inherits = preset_entry.inherits
      for _, inheritted in ipairs(inherits) do
        binary_dir = M.try_determine_binary_dir(inheritted, dir, preset_type)
        if binary_dir ~= nil then
          -- Break on the first to have a binary dir.
          break
        end
      end
    end
  end

  if binary_dir ~= nil and opts.resolve_path then
    binary_dir = M.resolve_path(binary_dir, dir)
  end

  return binary_dir
end

return M
