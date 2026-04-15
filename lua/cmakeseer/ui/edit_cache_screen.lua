local function pairsByKeys(t, f)
  local a = {}
  for n in pairs(t) do
    table.insert(a, n)
  end
  table.sort(a, f)
  local i = 0
  return function()
    i = i + 1
    if a[i] == nil then
      return nil
    else
      return a[i], t[a[i]]
    end
  end
end

local M = {}
function M.edit_cache_screen()
  local cmakeseer = require("cmakeseer")
  if not cmakeseer.project_is_configured() then
    vim.notify("Project is not configured; cannot edit cache", vim.log.levels.ERROR)
    return
  end

  local cache_path = vim.fs.joinpath(cmakeseer.get_build_directory(), "CMakeCache.txt")
  if vim.uv.fs_stat(cache_path) == nil then
    vim.notify("Cannot find cache at " .. cache_path, vim.log.levels.ERROR)
    return
  end

  local cs_cache = require("cmakeseer.cmake.cache")
  local maybe_cache = cs_cache.parse_cache_file(cache_path)
  if type(maybe_cache) == "string" then
    vim.notify(string.format("Unable to read cache at %s: %s", cache_path, maybe_cache), vim.log.levels.ERROR)
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ns = vim.api.nvim_create_namespace("cmakeseer")

  -- TODO: Might be better to do this all at once
  local values = {}
  local names = {}
  local max_name_length = 0
  vim
    .iter(pairsByKeys(maybe_cache))
    :filter(function(_, var)
      ---@cast var cmakeseer.cmake.cache.Variable
      return var.type ~= "STATIC" and var.type ~= "INTERNAL"
    end)
    :each(function(_, var)
      table.insert(values, var.value)
      table.insert(names, var.name)
      max_name_length = math.max(max_name_length, #var.name)
    end)

  vim.api.nvim_buf_set_lines(bufnr, 0, #values - 1, false, values)
  vim.iter(names):enumerate():each(function(i, name)
    local padded_name = string.format("%-" .. max_name_length .. "s", name)
    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
      virt_text = { { padded_name, "Comment" }, { " | ", "Comment" } },
      virt_text_pos = "inline",
      right_gravity = false,
    })
  end)
end

return M
