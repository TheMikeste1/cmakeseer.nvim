local function read_json(filepath)
  local file = io.open(filepath, "r")
  if file == nil then
    return nil
  end

  local content = file:read("*a")
  file:close()
  return vim.json.decode(content)
end

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
  local expanded = path:gsub("(%${(.+)})", function(match, var)
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

  expanded = expanded:gsub("(%$env{(.+)})", function(match, var)
    -- TODO: Check the environment field of the preset and prefer it instead
    local maybe_env = vim.env[var]
    if maybe_env ~= nil then
      return maybe_env
    end
    -- Not recognized; return the match.
    return match
  end)

  expanded = expanded:gsub("(%$penv{(.+)})", function(match, var)
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
---@return string? filepath The filepath to the file containing the preset.
function M.file_for(preset, dir, preset_type)
  local function file_has_preset(filepath)
    local function is_preset(entry)
      return entry["name"] == preset
    end

    local function list_has_preset(list)
      for _, entry in ipairs(list) do
        if is_preset(entry) then
          return true
        end
      end
      return false
    end

    local maybe_json = read_json(filepath)
    if maybe_json == nil then
      return false
    end

    local preset_list = maybe_json[preset_type .. "Presets"]
    return preset_list ~= nil and list_has_preset(preset_list)
  end

  local cmake_preset_path = vim.fs.joinpath(dir, "CMakePresets.json")
  if file_has_preset(cmake_preset_path) then
    return cmake_preset_path
  end

  cmake_preset_path = vim.fs.joinpath(dir, "CMakeUserPresets.json")
  if file_has_preset(cmake_preset_path) then
    return cmake_preset_path
  end

  return nil
end

--- Gets the binary directory for the given preset, if it has one.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@param opts table? Additional options. TODO: Document the options.
---@return string? binary_dir The binary directory for the preset, if it exists and has one.
function M.preset_binary_dir(preset, dir, preset_type, opts)
  opts = opts or { resolve_path = false }

  -- Workflows are unique and may not have one specific binary dir
  -- TODO: Add a workflow template to the Overseer templates
  if preset_type == PresetTypes.Workflow then
    return nil
  end

  local file_for_preset = M.file_for(preset, dir, preset_type)
  if file_for_preset == nil then
    return nil
  end

  local json = read_json(file_for_preset)
  if json == nil then
    return nil
  end

  local presets = json[preset_type .. "Presets"]

  -- Fetch the entry
  local preset_entry = nil
  for _, entry in ipairs(presets) do
    if entry["name"] == preset then
      preset_entry = entry
      break
    end
  end

  if preset_entry == nil then
    return nil
  end

  local binary_dir = nil
  if preset_type == PresetTypes.Configure then
    binary_dir = preset_entry["binaryDir"]
    if binary_dir == nil and preset_entry["inherits"] ~= nil then
      binary_dir = M.preset_binary_dir(preset_entry["inherits"], dir, PresetTypes.Configure)
    end
  else
    local configure_preset = preset_entry["configurePreset"]
    if configure_preset ~= nil then
      binary_dir = M.preset_binary_dir(configure_preset, dir, PresetTypes.Configure)
    end

    if binary_dir == nil and preset_entry["inherits"] ~= nil then
      binary_dir = M.preset_binary_dir(preset_entry["inherits"], dir, preset_type)
    end
  end

  if binary_dir ~= nil and opts.resolve_path then
    binary_dir = M.resolve_path(binary_dir, dir)
  end

  return binary_dir
end

return M
