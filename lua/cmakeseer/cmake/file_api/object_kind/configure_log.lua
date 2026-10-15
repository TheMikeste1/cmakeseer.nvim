local object_kind = require("cmakeseer.cmake.file_api.object_kind")
local ObjectKindType = object_kind.ObjectKindType

---Type and version information for an event kind. See <https://cmake.org/cmake/help/latest/manual/cmake-configure-log.7.html#event-kinds>.
---@class cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind
---@field kind cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKindType The type of the event kind.
---@field version number

--- A `configureLog` object from the CMake file API.
--- Describes the location inside and events in a cmake-configure-log.
---@class cmakeseer.cmake.file_api.object_kind.ConfigureLog: cmakeseer.cmake.file_api.object_kind.ObjectKind
---@field kind "configureLog"
---@field path string The path to the configure log.
---@field event_kinds cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind[] The event kinds in the configure log.
local ConfigureLog = {
  ---@enum cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKindType
  EventKind = {
    Message = "message",
    TryCompile = "try_compile",
    TryRun = "try_run",
    Find = "find",
    FindPackage = "find_package",
  },
}
ConfigureLog.__index = ConfigureLog

--- Creates a new ConfigureLog instance.
---@param version cmakeseer.cmake.file_api.object_kind.Version The version for the log.
---@param path string The path to the configure log.
---@param event_kinds cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind[] The event kinds in the configure log.
---@return cmakeseer.cmake.file_api.object_kind.ConfigureLog obj The new instance.
function ConfigureLog.new(version, path, event_kinds)
  local self = setmetatable({
    kind = ObjectKindType.ConfigureLog,
    version = vim.deepcopy(version),
    path = path,
    event_kinds = vim.deepcopy(event_kinds),
  }, ConfigureLog)
  return self
end

--- Tries to parse an EventKind from a string.
---@param val string The string.
---@return cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind? event_kind
local function try_event_kind_from_string(val)
  local name, version = val:match("^(.-)-v(%d+)$")
  version = tonumber(version)
  if name == nil or version == nil then
    return nil
  end

  for _, type_ in pairs(ConfigureLog.EventKind) do
    if name == type_ then
      return {
        kind = type_,
        version = version,
      }
    end
  end
  return nil
end

--- Creates a new ConfigureLog instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.ConfigureLog? obj, string? err The new instance if successful. Otherwise an error.
function ConfigureLog.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  if json.kind ~= ObjectKindType.ConfigureLog then
    return nil, "Incorrect kind: " .. vim.inspect(json.kind)
  end

  local version, err = object_kind.try_version_from_json(json.version)
  if version == nil then
    return nil, err
  end

  local path = json.path
  if type(path) ~= "string" then
    return nil, "path is wrong type: " .. type(path)
  end

  local event_kinds_as_strings = json.eventKindNames
  if not vim.islist(event_kinds_as_strings) then
    return nil, "eventKindNames is wrong type: " .. type(event_kinds_as_strings)
  end
  ---@cast event_kinds_as_strings string[]

  ---@type cmakeseer.cmake.file_api.object_kind.ConfigureLog.EventKind[]
  local event_kinds = {}
  for i, val in ipairs(event_kinds_as_strings) do
    if type(val) == "string" then
      local maybe_event_kind = try_event_kind_from_string(val)
      if maybe_event_kind == nil then
        return nil, ("Invalid event kind at index %d: %s"):format(i, val)
      end
      table.insert(event_kinds, maybe_event_kind)
    else
      return nil, ("Invalid event kind at index %d: %s"):format(i, vim.inspect(val))
    end
  end

  return ConfigureLog.new(version, path, event_kinds)
end

--- Creates a new ConfigureLog instance from a file.
---@param path string The path to the file to load.
---@return cmakeseer.cmake.file_api.object_kind.ConfigureLog? obj, string? err The new instance if successful. Otherwise an error.
function ConfigureLog.try_from_file(path)
  local f, err = io.open(path, "r")
  if f == nil then
    return nil, err
  end

  ---@type string?
  local json = f:read("*a")
  f:close()
  if json == nil then
    return nil, "Failed to read " .. path .. ": Is a directory"
  end

  ---@type boolean, table<string>|string
  local success, configure_log_or_err = pcall(vim.json.decode, json)
  if not success then
    ---@cast configure_log_or_err string
    return nil, "vim.json.decode: " .. configure_log_or_err
  end

  return ConfigureLog.try_from_json(configure_log_or_err)
end

return ConfigureLog
