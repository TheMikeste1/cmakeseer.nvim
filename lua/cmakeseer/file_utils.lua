local M = {}

--- Gets the parent path of a path.
--- @param path string The path for which the parent should be got.
--- @return string path The parent parent.
function M.get_parent_path(path)
  return vim.fn.fnamemodify(path, ":h")
end

--- Check if a directory exists.
--- @return boolean is_directory If the path is a directory.
function M.is_directory(path)
  return vim.fn.isdirectory(path) == 1
end

return M
