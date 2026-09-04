--- A container for CMake's preset files. See <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html>.
---@class cmakeseer.cmake.preset.PresetFile
local PresetFile = {}
PresetFile.__index = PresetFile

---@class cmakeseer.cmake.preset.PresetFile.CMakeVersion
---@field major? integer The major version.
---@field minor? integer The minor version.
---@field patch? integer The patch version.

---@class cmakeseer.cmake.preset.PresetFile
---@field path string Path to this PresetFile.
---@field version integer The version of the preset schema.
---@field cmake_minimum_required? cmakeseer.cmake.preset.PresetFile.CMakeVersion The minimum version of CMake to build this project.
---@field include? string[] Relative paths to other include files.
---@field vendor? table<string, any> Vendor-specific information not used by CMake.
---@field configure_presets? cmakeseer.cmake.preset.ConfigurePreset[] Optional array of configure presets.
---@field build_presets? cmakeseer.cmake.preset.BuildPreset[] Optional array of build presets.
---@field test_presets? cmakeseer.cmake.preset.TestPreset[] Optional array of test presets.
---@field package_presets? cmakeseer.cmake.preset.PackagePreset[] Optional array of package presets.
---@field workflow_presets? cmakeseer.cmake.preset.WorkflowPreset[] Optional array of workflow presets.
local _PresetFileDefaults = {}

-- TODO: When resolving includes:
-- > If CMakePresets.json and CMakeUserPresets.json are both present, CMakeUserPresets.json implicitly includes CMakePresets.json, even with no include field, in all versions of the format.
-- > <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#includes>

--- Creates a new PresetFile instance.
---@param o cmakeseer.cmake.preset.PresetFile Initial values.
---@return cmakeseer.cmake.preset.PresetFile obj The new instance.
function PresetFile.new(o)
  local self = setmetatable(vim.deepcopy(o), PresetFile)
  for k, v in pairs(_PresetFileDefaults) do
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

--- Creates a new PresetFile instance from a preset file on disk.
---@param path string The path to the preset file.
---@return cmakeseer.cmake.preset.PresetFile? obj, string? error_msg The new instance, if one was successfully created.
function PresetFile.try_from_file(path)
  path = vim.fs.normalize(path)
  local file, error = io.open(path, "r")
  if file == nil then
    return nil, error
  end

  local contents = file:read("*a")
  file:close()
  local success, preset_json = pcall(vim.json.decode, contents)
  if not success then
    return nil, preset_json
  end

  local version = preset_json["version"]
  if version == nil then
    return nil, "Could not find version in file"
  end

  if type(version) ~= "number" then
    return nil, "Version was not a number"
  end

  local cmake_minimum_required = preset_json["cmakeMinimumRequired"]
  if cmake_minimum_required ~= nil then
    if cmake_minimum_required.major ~= nil and type(cmake_minimum_required.major) ~= "number" then
      return nil, "cmakeMinimumRequired.major must be a number"
    end
    if cmake_minimum_required.minor ~= nil and type(cmake_minimum_required.minor) ~= "number" then
      return nil, "cmakeMinimumRequired.minor must be a number"
    end
    if cmake_minimum_required.patch ~= nil and type(cmake_minimum_required.patch) ~= "number" then
      return nil, "cmakeMinimumRequired.patch must be a number"
    end
  end

  local include = preset_json["include"]
  if include ~= nil then
    if type(include) ~= "table" then
      return nil, "include must be a list"
    end
    for i, x in ipairs(include) do
      if type(x) ~= "string" then
        return nil, ("include object at index %d should be a string"):format(i)
      end
    end
    ---@cast include string[]
  end

  local configure_presets = preset_json["configurePresets"]
  if configure_presets ~= nil then
    if type(configure_presets) ~= "table" then
      return nil, "configurePresets must be an array"
    end

    local try_from_json = require("cmakeseer.cmake.preset.configure_preset").try_from_json
    for i, json in ipairs(configure_presets) do
      local preset, error_msg = try_from_json(json)
      if preset == nil then
        return nil, ("configure preset at index %d invalid: %s"):format(i, error_msg)
      end
      configure_presets[i] = preset
    end
  end

  local build_presets = preset_json["buildPresets"]
  if build_presets ~= nil then
    if type(build_presets) ~= "table" then
      return nil, "buildPresets must be an array"
    end

    local try_from_json = require("cmakeseer.cmake.preset.build_preset").try_from_json
    for i, json in ipairs(build_presets) do
      local preset, error_msg = try_from_json(json)
      if preset == nil then
        return nil, ("build preset at index %d invalid: %s"):format(i, error_msg)
      end
      build_presets[i] = preset
    end
  end

  local test_presets = preset_json["testPresets"]
  if test_presets ~= nil then
    if type(test_presets) ~= "table" then
      return nil, "testPresets must be an array"
    end

    local try_from_json = require("cmakeseer.cmake.preset.test_preset").try_from_json
    for i, json in ipairs(test_presets) do
      local preset, error_msg = try_from_json(json)
      if preset == nil then
        return nil, ("test preset at index %d invalid: %s"):format(i, error_msg)
      end
      test_presets[i] = preset
    end
  end

  local package_presets = preset_json["packagePresets"]
  if package_presets ~= nil then
    if type(package_presets) ~= "table" then
      return nil, "packagePresets must be an array"
    end

    local try_from_json = require("cmakeseer.cmake.preset.package_preset").try_from_json
    for i, json in ipairs(package_presets) do
      local preset, error_msg = try_from_json(json)
      if preset == nil then
        return nil, ("package preset at index %d invalid: %s"):format(i, error_msg)
      end
      package_presets[i] = preset
    end
  end

  local workflow_presets = preset_json["workflowPresets"]
  if workflow_presets ~= nil then
    if type(workflow_presets) ~= "table" then
      return nil, "workflowPresets must be an array"
    end

    local try_from_json = require("cmakeseer.cmake.preset.workflow_preset").try_from_json
    for i, json in ipairs(workflow_presets) do
      local preset, error_msg = try_from_json(json)
      if preset == nil then
        return nil, ("workflow preset at index %d invalid: %s"):format(i, error_msg)
      end
      workflow_presets[i] = preset
    end
  end

  return PresetFile.new({
    path = path,
    version = version,
    cmake_minimum_required = cmake_minimum_required,
    include = include,
    vendor = preset_json["vendor"],
    configure_presets = configure_presets,
    build_presets = build_presets,
    test_presets = test_presets,
    package_presets = package_presets,
    workflow_presets = workflow_presets,
  })
end

return PresetFile
