local M = {}

---Creates a temporary directory for the test.
---@param name? string An optional directory prefix to use. Defaults to nvim_test.
---@return string tmp_dir
function M.make_tmp_dir(name)
  name = name or "nvim_test"
  local tmp_base = vim.uv.os_tmpdir() or "/tmp"
  local template = vim.fs.joinpath(tmp_base, ("%s_XXXXXX"):format(name))
  local tmp_dir = assert(vim.uv.fs_mkdtemp(template))
  return tmp_dir
end

---Recursively deletes a directory.
---@param dir string
function M.delete_dir(dir)
  if dir == "/" then
    return
  end
  vim.fn.delete(dir, "rf")
end

---Writes a file with contents.
---@param path string The path to the file.
---@param contents string The exact bytes to write.
function M.write_file(path, contents)
  vim.fs.mkdir(vim.fs.dirname(path), { parents = true })
  local f = assert(io.open(path, "w"))
  f:write(contents)
  f:close()
end

---@param path string The path to the file.
---@return string contents
function M.read_file(path)
  local f = assert(io.open(path, "r"))
  local contents = f:read("*a")
  f:close()
  return contents
end

return M
