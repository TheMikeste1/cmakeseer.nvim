local M = {}

--- Checks if some object is an object.
---@param obj any The object to check.
---@return boolean obj_is_object If the object is an object or empty.
---@sa https://stackoverflow.com/a/52697380
function M.is_object(obj)
  return type(obj) == "table" and not vim.isarray(obj)
end

---@generic T
---@param array T[] The array from which to remove duplicates.
---@return T[] array The array without duplicates.
function M.remove_duplicates(array)
  local merged_set = {}
  for _, v in ipairs(array) do
    if not M.exists(merged_set, v) then
      table.insert(merged_set, v)
    end
  end
  return merged_set
end

--- Merges two sets into one.
---@generic T
---@param a T[] The first set.
---@param b T[] The second set.
---@return T[] merged_set The merged set.
function M.merge_sets(a, b)
  local merged_set = {}

  if a ~= nil then
    for _, v in ipairs(a) do
      if not M.exists(merged_set, v) then
        table.insert(merged_set, v)
      end
    end
  end

  if b ~= nil then
    for _, v in ipairs(b) do
      if not M.exists(merged_set, v) then
        table.insert(merged_set, v)
      end
    end
  end

  return merged_set
end

---@generic T
---@param array T[] The array to check.
---@param element T The element to check.
---@return boolean exists If the element exists in the array.
function M.exists(array, element)
  for _, x in ipairs(array) do
    if x == element then
      return true
    end
  end
  return false
end

return M
