--- Install information for a target.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install.Destination
---@field path string The install destination path.
---@field backtrace? number Optional index into the backtrace graph.

--- Install information for a target.
---@class cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install
---@field prefix string The installation prefix.
---@field destinations cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install.Destination[] Install destination paths.
local Install = {}

--- Parses an array of destinations.
---@param json any The JSON array.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install.Destination[]? destinations, string? err
local function parse_destinations(json)
  if json == nil then
    return nil, "destinations is missing"
  end
  if type(json) ~= "table" or not vim.islist(json) then
    return nil, "destinations is wrong type: " .. type(json)
  end
  local destinations = {}
  for i, dest_json in ipairs(json) do
    if type(dest_json) ~= "table" then
      return nil, ("destinations[%d] is wrong type: %s"):format(i, type(dest_json))
    end
    local path = dest_json.path
    if type(path) ~= "string" then
      return nil, ("destinations[%d].path is wrong type: %s"):format(i, type(path))
    end
    local backtrace = dest_json.backtrace
    if backtrace ~= nil and type(backtrace) ~= "number" then
      return nil, ("destinations[%d].backtrace is wrong type: %s"):format(i, type(backtrace))
    end
    table.insert(destinations, { path = path, backtrace = backtrace })
  end
  return destinations, nil
end

--- Creates a new Install instance from JSON.
---@param json any The json object from which values should be extracted.
---@return cmakeseer.cmake.file_api.object_kind.Codemodel.Target.Install? obj, string? err The new instance if successful. Otherwise an error.
function Install.try_from_json(json)
  if type(json) ~= "table" then
    return nil, "json is wrong type: " .. type(json)
  end

  local prefix_json = json.prefix
  if type(prefix_json) ~= "table" then
    return nil, "prefix is wrong type: " .. type(prefix_json)
  end
  local prefix_path = prefix_json.path
  if type(prefix_path) ~= "string" then
    return nil, "prefix.path is wrong type: " .. type(prefix_path)
  end

  local destinations, err = parse_destinations(json.destinations)
  if destinations == nil then
    return nil, err
  end

  return {
    prefix = prefix_path,
    destinations = destinations,
  }
end

return Install
