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
  vim.iter(maybe_cache):enumerate():each(function(i, _, var)
    vim.api.nvim_buf_set_lines(bufnr, i - 1, i - 1, false, { var.value })
    vim.api.nvim_buf_set_extmark(bufnr, ns, i - 1, 0, {
      virt_text = { { var.name .. " | ", "Comment" } },
      virt_text_pos = "inline",
    })
  end)
end

return M
