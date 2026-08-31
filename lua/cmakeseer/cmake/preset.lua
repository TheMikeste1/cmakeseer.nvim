local function read_json(filepath)
  local file = io.open(filepath, "r")
  if file == nil then
    return nil
  end

  local content = file:read("*a")
  file:close()
  return vim.json.decode(content)
end

local PRESET_TYPES = {
  "configurePresets",
  "buildPresets",
  "testPresets",
  "packagePresets",
  "workflowPresets",
}

local M = {}

--- Fetches the available presets.
---@param dir string Directory for fetching presets from another directory.
---@return string[] presets The list of presets.
function M.fetch_presets(dir)
  local presets = {}
  local command = { "cmake", "--list-presets", "-S", dir }
  local preset_str = vim.system(command):wait().stdout or ""
  for preset in string.gmatch(preset_str, '"([^"]+)"') do
    table.insert(presets, preset)
  end
  return presets
end

--- Finds the file for the given preset.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@return string? filepath The filepath to the file containing the preset.
function M.file_for(preset, dir)
  local function file_has_preset(filepath)
    local function has_preset(entry)
      return entry["name"] == preset
    end

    local function list_has_preset(list)
      for _, entry in ipairs(list) do
        if has_preset(entry) then
          return true
        end
      end
      return false
    end

    local maybe_json = read_json(filepath)
    if maybe_json == nil then
      return false
    end

    -- TODO: Multiple presets in different files may have this preset
    -- We'll need to caller to tell us which preset type they want.
    for _, preset_type in ipairs(PRESET_TYPES) do
      local preset_list = maybe_json[preset_type]
      if preset_list ~= nil and list_has_preset(preset_list) then
        return true
      end
    end

    return false
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
---@return string? binary_dir The binary directory for the preset, if it exists and has one.
function M.preset_binary_dir(preset, dir)
  local file_for_preset = M.file_for(preset, dir)
  if file_for_preset == nil then
    return nil
  end

  local json = read_json(file_for_preset)
  if json == nil then
    return nil
  end

  -- The binaryDir is always in the associated configurePreset.
  -- If this preset IS a configurePreset, we can check that and be done.
  -- If it's a workflow preset, it might not have one or it might be in a step. I'm not going to support these right now.
  -- In all other cases, the preset must either have a configurePreset field or inherit it.

  -- TODO: We actually need the user to select multiple presets, since they may configure with one and build with the other.
  -- As such, we probably want calls to specify which preset type they're targetting, possibly even chop it out into separate
  -- functions/modules.
  -- See also the TODO in `file_for`
end

return M
