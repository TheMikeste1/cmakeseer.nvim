--- A container for CMake's workflow preset. See <https://cmake.org/cmake/help/latest/manual/cmake-presets.7.html#workflow-preset>.
---@class cmakeseer.cmake.preset.WorkflowPreset
local WorkflowPreset = {}
WorkflowPreset.__index = WorkflowPreset

---@class cmakeseer.cmake.preset.WorkflowPreset.Step
---@field type "configure"|"build"|"test"|"package" The step type.
---@field name string The name of the configure, build, test, or package preset to run.

---@class cmakeseer.cmake.preset.WorkflowPreset
---@field name string Machine-friendly name of the preset.
---@field steps cmakeseer.cmake.preset.WorkflowPreset.Step[] Array of objects describing the steps of the workflow.
---@field vendor? table<string, any> Vendor-specific information.
---@field display_name? string Human-friendly name of the preset.
---@field description? string Human-friendly description of the preset.
local _WorkflowPresetDefaults = {}

--- Creates a new WorkflowPreset instance.
---@param o cmakeseer.cmake.preset.WorkflowPreset Initial values.
---@return cmakeseer.cmake.preset.WorkflowPreset obj The new instance.
function WorkflowPreset.new(o)
  local self = setmetatable(vim.deepcopy(o), WorkflowPreset)
  for k, v in pairs(_WorkflowPresetDefaults) do
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

--- Creates a new WorkflowPreset instance from a decoded JSON table.
---@param json table The JSON table representing the preset.
---@return cmakeseer.cmake.preset.WorkflowPreset? obj, string? error_msg The new instance, if one was successfully created.
function WorkflowPreset.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "preset JSON must be an object"
  end

  local name = json["name"]
  if name == nil then
    return nil, "Could not find name in preset"
  end
  if type(name) ~= "string" then
    return nil, "name must be a string"
  end

  local steps = json["steps"]
  if steps == nil then
    return nil, "Could not find steps in workflow preset"
  end
  if type(steps) ~= "table" or vim.tbl_isempty(steps) then
    return nil, "steps must be a non-empty list"
  end

  for i, step in ipairs(steps) do
    if type(step) ~= "table" then
      return nil, ("step at index %d must be an object"):format(i)
    end
    if step.type == nil or type(step.type) ~= "string" then
      return nil, ("step at index %d requires a type string"):format(i)
    end
    if step.name == nil or type(step.name) ~= "string" then
      return nil, ("step at index %d requires a name string"):format(i)
    end
    if i == 1 and step.type ~= "configure" then
      return nil, "The first step in a workflow preset must be configure"
    end
    if step.type ~= "configure" and step.type ~= "build" and step.type ~= "test" and step.type ~= "package" then
      return nil, ("step type '%s' at index %d is invalid"):format(step.type, i)
    end
  end

  local vendor = json["vendor"]
  if vendor ~= nil and type(vendor) ~= "table" then
    return nil, "vendor must be an object"
  end

  local display_name = json["displayName"]
  if display_name ~= nil and type(display_name) ~= "string" then
    return nil, "displayName must be a string"
  end

  local description = json["description"]
  if description ~= nil and type(description) ~= "string" then
    return nil, "description must be a string"
  end

  return WorkflowPreset.new({
    name = name,
    steps = steps,
    vendor = vendor,
    display_name = display_name,
    description = description,
  })
end

return WorkflowPreset
