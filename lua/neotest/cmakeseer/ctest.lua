-- TODO: Rework
local M = {}

--- Sets up the adapter.
---@param opts table
---@return neotest.Adapter adapter The adapter.
function M.setup(opts)
  M.opts = vim.tbl_extend("keep", opts or {}, M.opts)
  vim.notify("CMakeSeer CTest is undergoing rework! It will not currently work.", vim.log.levels.WARN)
  return M
end

return M
