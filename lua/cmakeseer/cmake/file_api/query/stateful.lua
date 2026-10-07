---@class (exact) cmakeseer.cmake.file_api.query.Version A CMake version object.
---@field major number The major version number.
---@field minor number? The optional minor version number.

---@alias cmakeseer.cmake.file_api.query.ObjectKind.Version number|number[]|cmakeseer.cmake.file_api.query.Version

---@class (exact) cmakeseer.cmake.file_api.query.ObjectKind An query for an object kind.
---@field kind cmakeseer.cmake.file_api.object_kind.ObjectKindType The object kind to query for.
---@field version cmakeseer.cmake.file_api.query.ObjectKind.Version The version of the object kind. Note the CMake will use the first version it recognizes, so list them in preferred order.
---@field client table? Optional values to be copied into the reply, but not used by CMake itself.

--- A stateful query.
---@class cmakeseer.cmake.file_api.query.Stateful
---@field requests cmakeseer.cmake.file_api.query.ObjectKind[] The requests to make. Note that for each object kind CMake will choose the first version it recognizes, so versions should be listed in order of preference.
---@field client table? Optional values to be copied into the reply, but not used by CMake itself.
local Stateful = {}
Stateful.__index = Stateful

---@type cmakeseer.cmake.file_api.query.Stateful
local _StatefulDefaults = {
  requests = {},
}

--- Creates a new Stateful instance.
---@param o cmakeseer.cmake.file_api.query.Stateful? Initial values.
---@return cmakeseer.cmake.file_api.query.Stateful obj The new instance.
function Stateful.new(o)
  o = o or {}
  local self = setmetatable(vim.deepcopy(o), Stateful)
  for k, v in pairs(_StatefulDefaults) do
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

--- Creates a new Stateful instance using default values.
---@return cmakeseer.cmake.file_api.query.Stateful obj The new instance.
function Stateful.default()
  local self = setmetatable(vim.deepcopy(_StatefulDefaults), Stateful)
  return self
end

--- Converts the query to a file.
---@param path string
---@return string? err
function Stateful:to_file(path)
  local json = vim.json.encode(self)
  local f, err = io.open(path, "w")
  if f == nil then
    return err
  end

  f:write(json)
  f:close()
end

--- Reads a Stateful query from a file.
---@param path string The path to the file.
---@return cmakeseer.cmake.file_api.query.Stateful?,string?
function Stateful.from_file(path)
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

  json = vim.trim(json)

  ---@type boolean, cmakeseer.cmake.file_api.query.Stateful|string
  local success, full_query_or_err = pcall(vim.json.decode, json, { luanil = { object = true } })
  if not success then
    ---@cast full_query_or_err string
    return nil, "vim.json.decode: " .. full_query_or_err
  end

  if type(full_query_or_err) ~= "table" or json:sub(1, 1) ~= "{" or (full_query_or_err.requests ~= nil and not vim.islist(full_query_or_err.requests)) then
    return nil, "Invalid query at " .. path
  end

  ---@cast full_query_or_err cmakeseer.cmake.file_api.query.Stateful
  full_query_or_err.requests = full_query_or_err.requests or {}
  return Stateful.new(full_query_or_err), nil
end

return Stateful
