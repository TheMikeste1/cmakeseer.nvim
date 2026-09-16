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

--- Expands macros. Does not expand preset-specific macros nor ${fileDir} without `additional_matchers`.
--- Look for "preset-specific" to see which macros this does NOT expand:
--- <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#macro-expansion>
---@param str string The string to expand.
---@param additional_matchers? table<string, (fun(): string)?> Optional additional matchers.
---@return string str The expanded string.
function M.expand_macros(str, additional_matchers)
  additional_matchers = additional_matchers or {}
  str = str:gsub("(%${([^}]+)})", function(match, var)
    if var == "sourceDir" then
      return require("cmakeseer").get_config():get_project_root()
    elseif var == "sourceParentDir" then
      return vim.fs.dirname(require("cmakeseer").get_config():get_project_root())
    elseif var == "sourceDirName" then
      return vim.fs.basename(require("cmakeseer").get_config():get_project_root())
    elseif var == "hostSystemName" then
      local system_name = vim.uv.os_uname().sysname
      if system_name == "Windows_NT" then
        return "Windows"
      end
      return system_name
    elseif var == "dollar" then
      return "$"
    elseif var == "pathListSep" then
      local system_name = vim.uv.os_uname().sysname
      if system_name == "Windows_NT" then
        return ";"
      end
      return ":"
    end

    if additional_matchers[var] ~= nil then
      return additional_matchers[var]()
    end

    -- Not recognized; return the match.
    return match
  end)

  str = str:gsub("%$penv{([^}]+)}", function(var)
    local maybe_env = vim.env[var]
    if maybe_env == nil then
      return ""
    end
    return maybe_env
  end)
  return str
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

--- Options for `file_for`.
---@class cmakeseer.cmake.preset.FileForOpts
---@field check_includes? boolean Whether to follow `include` fields and search included preset files. Defaults to `true`.
---@field safe_check_includes? boolean Whether to guard against infinite include loops by tracking already-checked files. Defaults to `true`.

--- Finds the file for the given preset.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@param opts cmakeseer.cmake.preset.FileForOpts? Additional options.
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

--- Gets the value of a field for the given preset, if it has one.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@param field cmakeseer.cmake.preset.ConfigurePresetField The field to fetch.
---@param empty_value string? The value to return when the preset does not have the field.
---@return string? value The value of the field, or `empty_value` if it does not have one.
local function try_determine_value(preset, dir, preset_type, field, empty_value)
  -- Workflows are unique and may not have the value
  if preset_type == PresetTypes.Workflow then
    return empty_value
  end

  local preset_entry = M.entry_for(preset, dir, preset_type)
  if preset_entry == nil then
    return empty_value
  end

  local value = empty_value
  if preset_type == PresetTypes.Configure then
    ---@cast preset_entry cmakeseer.cmake.preset.ConfigurePreset
    value = preset_entry[field] or empty_value
    if value == empty_value and preset_entry.inherits ~= nil then
      ---@type string[]
      local inherits = preset_entry.inherits
      for _, inheritted in ipairs(inherits) do
        value = try_determine_value(inheritted, dir, PresetTypes.Configure, field, empty_value)
        if value ~= empty_value then
          -- Break on the first to have a value.
          break
        end
      end
    end
  else
    local configure_preset = preset_entry.configure_preset
    if configure_preset ~= nil then
      value = try_determine_value(configure_preset, dir, PresetTypes.Configure, field, empty_value)
    end

    if value == empty_value and preset_entry.inherits ~= nil then
      ---@type string[]
      local inherits = preset_entry.inherits
      for _, inheritted in ipairs(inherits) do
        value = try_determine_value(inheritted, dir, preset_type, field, empty_value)
        if value ~= empty_value then
          -- Break on the first to have a value.
          break
        end
      end
    end
  end

  return value
end

--- Options for `try_determine_binary_dir`.
---@class cmakeseer.cmake.preset.TryDetermineBinaryDirOpts
---@field resolve_path? boolean Whether to resolve path macros (e.g. `${sourceDir}`) in the returned binary directory. Defaults to `false`.

--- Gets the binary directory for the given preset, if it has one.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@param opts cmakeseer.cmake.preset.TryDetermineBinaryDirOpts? Additional options.
---@return string? binary_dir The binary directory for the preset, if it exists and has one.
function M.try_determine_binary_dir(preset, dir, preset_type, opts)
  opts = opts or { resolve_path = false }

  local binary_dir = try_determine_value(preset, dir, preset_type, "binary_dir", nil)
  if binary_dir ~= nil and opts.resolve_path then
    local preset_file = M.file_for(preset, dir, preset_type)
    if preset_file ~= nil then
      binary_dir = preset_file:expand_macros(binary_dir)
      binary_dir = vim.fs.normalize(binary_dir)
    end
  end

  return binary_dir
end

--- Gets the generator for the given preset, if it has one.
---@param preset string The preset to check.
---@param dir string Directory for fetching presets from another directory.
---@param preset_type cmakeseer.cmake.PresetType The type of preset to fetch.
---@return string generator The generator for the preset, or "" if it does not have one.
function M.try_determine_generator(preset, dir, preset_type)
  return try_determine_value(preset, dir, preset_type, "generator", "") or ""
end

return M
