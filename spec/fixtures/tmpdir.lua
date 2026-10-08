local spec_utils = require("spec.utils")

return function()
  -- Get the caller's functions
  local env = getfenv(2)
  ---@type fun(block: fun()), fun(block: fun())
  local before_each, after_each = env.before_each, env.after_each
  if before_each == nil or after_each == nil then
    error("Must be called inside a `describe` block")
  end

  local state = {
    ---@type string
    path = nil,
  }

  before_each(function()
    state.path = spec_utils.make_tmp_dir()
  end)

  after_each(function()
    if state.path and not vim.env.KEEP_TEST_DIRS then
      spec_utils.delete_dir(state.path)
    end
    state.path = nil
  end)

  return state
end
