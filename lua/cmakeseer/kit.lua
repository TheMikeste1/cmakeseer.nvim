local Utils = require("cmakeseer.utils")

--- @class Compilers
--- @field C string
--- @field CXX string|nil

--- @class Kit
--- @field name string
--- @field compilers Compilers

--- @param kit_file string Paths to file containing CMake kit definitions. These will not be expanded.
--- @return Kit[] kits The kits
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
---@return Kit|nil maybe_kit The kit, if the path was a kit.
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

  ---@type Kit
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
---@return Kit|nil maybe_kit The kit, if the path was a kit.
local function extract_kit_from_clang(filepath)
  local name_parts = vim.split(filepath, "/")
  local name = name_parts[#name_parts]
  if not name_is_clang_kit(name) then
    return nil
  end

  ---@type Kit
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
---@return Kit[] kits The list of known kits.
function M.load_all_kits(kit_paths)
  if kit_paths == nil then
    vim.notify("List of kit files was nil", vim.log.levels.ERROR)
    return {}
  end

  --- @type Kit[]
  local kits = {}
  for _, file_path in ipairs(kit_paths) do
    local kits_from_file = read_cmakekit_files(file_path)
    kits = Utils.merge_tables(kits, kits_from_file)
  end
  return kits
end

--- Scans for kits in the provided directory.
---@param directory string The directory in which to scan.
function M.scan_for_kits(directory)
  if directory:sub(-1) ~= "/" then
    directory = directory .. "/"
  end

  ---@type Kit[]
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

return M
