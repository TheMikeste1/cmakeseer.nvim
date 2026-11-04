local M = {}

---@async
--- Runs a command asynchronously, yielding the current coroutine until it completes.
---
--- When called outside a coroutine, this falls back to `:wait()`.
---@param cmd string[] The command and its arguments.
---@param opts? table Options passed to `vim.system`.
---@param timeout? integer Maximum milliseconds to wait for the process.
---@return vim.SystemCompleted? result The completed process result, or nil on failure.
---@return string? err An error message if the command could not be spawned.
function M.system(cmd, opts, timeout)
  local co = coroutine.running()
  local result = {}
  local done = false

  local sys_obj = vim.system(cmd, opts or {}, function(out)
    result = out
    done = true
    if co ~= nil and coroutine.status(co) == "suspended" then
      coroutine.resume(co, out)
    end
  end)

  if co == nil then
    -- Not in a coroutine: block as before.
    return sys_obj:wait(timeout), nil
  end

  -- The process may have already exited before we reached the yield; avoid yielding forever.
  if done then
    return result, nil
  end

  coroutine.yield()
  return result, nil
end

return M
