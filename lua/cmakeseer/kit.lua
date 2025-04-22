local FileUtils = require("cmakeseer.file_utils")
local Utils = require("cmakeseer.utils")

--- @class cmakeseer.Compilers
--- @field C string
--- @field CXX string|nil

--- @class cmakeseer.Kit
--- @field name string
--- @field compilers cmakeseer.Compilers

--- @param kit_file string Paths to file containing CMake kit definitions. These will not be expanded.
--- @return cmakeseer.Kit[] kits The kits
local function read_cmakekit_files(kit_file)
  if vim.fn.filereadable(kit_file) == 0 then
    vim.notify("Kit file `" .. kit_file .. "` is not readable. Does it exist?", vim.log.levels.ERROR)
    return {}
  end

  local file = io.open(kit_file, "r")
  if file == nil then
    vim.notify("Unable to read kit file `" .. kit_file .. "`", vim.log.levels.ERROR)
    return {}
  end

  local file_contents = file:read("a")
  file:close()

  local kits = vim.json.decode(file_contents)
  -- TODO: Validate the kits we read in and ensure they are actually kits
  return kits
end

--- Checks if a name is a GCC kit, e.g. "gcc" or "gcc-11."
---@param name string The name of the kit to check.
---@return boolean is_kit If the name is a GCC kit.
local function name_is_gcc_kit(name)
  if name:sub(1, 3) ~= "gcc" then
    return false
  end

  if name == "gcc" then
    return true
  end

  local sub = name:sub(4)
  if #sub < 2 or sub[1] ~= "-" then
    return false
  end

  local numbers = sub:sub(2)
  for char in numbers:gmatch(".") do
    if char:find("%D") then
      return false
    end
  end
  return true
end

--- Extracts a kit from a GCC filepath, if it is a kit.
---@param filepath string The filepath that may be a GCC kit, e.g. "/usr/bin/gcc-11." This should be the gcc compiler, not the g++.
---@return cmakeseer.Kit|nil maybe_kit The kit, if the path was a kit.
local function extract_kit_from_gcc(filepath)
  local name_parts = vim.split(filepath, "/", { trimempty = true })
  local name = name_parts[#name_parts]
  if not name_is_gcc_kit(name) then
    return nil
  end

  -- Reassemble the name into the g++ version
  ---@type string|nil
  local cxx = ""
  for i, part in ipairs(name_parts) do
    if i == #name_parts then
      break
    end
    cxx = cxx .. "/" .. part
  end

  cxx = cxx .. "/" .. name:gsub("gcc", "g++")
  if cxx and vim.fn.filereadable(cxx) == 0 then
    cxx = nil
  end

  -- TODO: Get version

  ---@type cmakeseer.Kit
  local kit = {
    name = name,
    compilers = {
      C = filepath,
      CXX = cxx,
    },
  }
  return kit
end

--- Checks if a name is a clang kit, e.g. "clang" or "clang-11."
---@param name string The name of the kit to check.
---@return boolean is_kit If the name is a clang kit.
local function name_is_clang_kit(name)
  if name:sub(1, 3) ~= "clang" then
    return false
  end

  if name == "clang" then
    return true
  end

  local sub = name:sub(4)
  if #sub < 2 or sub[1] ~= "-" then
    return false
  end

  local numbers = sub:sub(2)
  for char in numbers:gmatch(".") do
    if char:find("%D") then
      return false
    end
  end
  return true
end

--- Extracts a kit from a clang filepath, if it is a kit.
---@param filepath string The filepath that may be a clang kit.
---@return cmakeseer.Kit|nil maybe_kit The kit, if the path was a kit.
local function extract_kit_from_clang(filepath)
  local name_parts = vim.split(filepath, "/")
  local name = name_parts[#name_parts]
  if not name_is_clang_kit(name) then
    return nil
  end

  -- TODO: Get version

  ---@type cmakeseer.Kit
  local kit = {
    name = name,
    compilers = {
      C = filepath,
      CXX = filepath,
    },
  }
  return kit
end

local M = {}

--- Loads all kit information from kit paths.
---@param kit_paths string[] Paths to files containing kit information.
---@return cmakeseer.Kit[] kits The list of known kits.
function M.load_all_kits(kit_paths)
  if kit_paths == nil then
    vim.notify("List of kit files was nil", vim.log.levels.ERROR)
    return {}
  end

  --- @type cmakeseer.Kit[]
  local kits = {}
  for _, file_path in ipairs(kit_paths) do
    local kits_from_file = read_cmakekit_files(file_path)
    kits = Utils.merge_arrays(kits, kits_from_file)
  end
  return kits
end

--- Scans for kits in the provided directory.
---@param directory string The directory in which to scan.
function M.scan_for_kits(directory)
  if directory:sub(-1) ~= "/" then
    directory = directory .. "/"
  end

  ---@type cmakeseer.Kit[]
  local kits = {}

  ---@type string[]
  local maybe_gcc_kits = vim.split(vim.fn.glob(directory .. "gcc*"), "\n")
  if #maybe_gcc_kits > 0 and maybe_gcc_kits[1] ~= "" then
    for _, maybe_kit in ipairs(maybe_gcc_kits) do
      local kit = extract_kit_from_gcc(maybe_kit)
      if kit then
        table.insert(kits, kit)
      end
    end
  end

  ---@type string[]
  local maybe_clang_kits = vim.split(vim.fn.glob(directory .. "clang*"), "\n")
  if #maybe_clang_kits > 0 and maybe_clang_kits[1] ~= "" then
    for _, maybe_kit in ipairs(maybe_clang_kits) do
      local kit = extract_kit_from_clang(maybe_kit)
      if kit then
        table.insert(kits, kit)
      end
    end
  end

  return kits
end

--- Persists the given kits to disk, overwriting any contents that are already there.
---@param filepath string The path to which the kits should be persisted.
---@param kits cmakeseer.Kit[] The kits to persist.
function M.persist_kits(filepath, kits)
  filepath = vim.fn.expand(filepath)
  local parent_path = FileUtils.get_parent_path(filepath)
  if not FileUtils.is_directory(parent_path) then
    local success = vim.fn.mkdir(parent_path, "p") == 1
    if not success then
      vim.notify("Failed to create parent path for " .. filepath .. ". Cannot persist kits.", vim.log.levels.ERROR)
      return
    end
  end

  local file, maybe_err = io.open(filepath, "w")
  if file == nil then
    local err_msg = "Unable to open file `" .. filepath .. "` for saving kits: "
    if maybe_err ~= nil then
      err_msg = err_msg .. maybe_err
    else
      err_msg = err_msg .. "Unknown error"
    end

    vim.notify(err_msg, vim.log.levels.ERROR)
    return
  end

  local kits_as_json = vim.json.encode(kits)
  _, maybe_err = file:write(kits_as_json)
  file:close()
  if maybe_err then
    vim.notify("Unable to write to file `" .. filepath .. "`: " .. maybe_err, vim.log.levels.ERROR)
  end
end

---@param a cmakeseer.Kit The lhs kit.
---@param b cmakeseer.Kit the rhs kit.
---@return boolean equal If the two kits are considered equal.
function M.are_kits_equal(a, b)
  return a.compilers.C == b.compilers.C and a.compilers.CXX == b.compilers.CXX
end

--- Removes duplicate kits.
---@param kits cmakeseer.Kit[] The array of kits.
---@return cmakeseer.Kit[] kits The array of kits without duplicates.
function M.remove_duplicate_kits(kits)
  local kit_set = {}
  for _, kit in ipairs(kits) do
    if not M.kit_exists(kit_set, kit) then
      table.insert(kit_set, kit)
    end
  end
  return kits
end

---@param kits cmakeseer.Kit[] The array containing kits.
---@param kit cmakeseer.Kit The kit to check.
---@return boolean exists If the kit is already in the array.
function M.kit_exists(kits, kit)
  for _, value in ipairs(kits) do
    if M.are_kits_equal(value, kit) then
      return true
    end
  end
  return false
end

return M
