local M = {
  __api_directory = ".cmake/api/v1",
}

---@return string api_directory The subpath to the API directory where queries and responses are made.
function M.api_directory()
  return M.__api_directory
end

return M
