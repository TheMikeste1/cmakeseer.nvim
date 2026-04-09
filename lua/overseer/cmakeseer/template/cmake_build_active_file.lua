---@module "overseer"

local function get_active_file()
  -- TODO: This should be the absolute with the project root trimmed off
  return vim.fn.expand("%:.")
end

---@private
local potential_targets = nil
local function find_active_targets()
  local targets = require("cmakeseer").state.get_targets()
  local active_file = get_active_file()

  -- TODO: Look into caching. Note that is will need to be refreshed whenever the project is reconfigured.
  ---@type cmakeseer.cmake.api.codemodel.Target[]
  return vim
    .iter(targets)
    :filter(
      ---@param t cmakeseer.cmake.api.codemodel.Target
      ---@return boolean
      function(t)
        ---@param s cmakeseer.cmake.api.codemodel.Source
        ---@return boolean
        return vim.iter(t.sources):any(function(s)
          return s.path == active_file
        end)
      end
    )
    :totable()
end

--- @param params table The parameters to the builder.
--- @return overseer.TaskDefinition
local function builder(params)
  assert(potential_targets ~= nil, "Got into builder without checking if the active_file")

  if #potential_targets == 0 then
    return {
      name = "CMake Build Active File",
      cmd = "echo",
      args = {
        "Unable to build active file. It does not belong to a target.",
      },
    }
  end
  -- TODO: Change this into a picker
  if #potential_targets > 1 then
    local potential_str = table.concat(
      vim
        .iter(potential_targets)
        :map(function(t)
          return t.name
        end)
        :totable(),
      ", "
    )
    return {
      name = "CMake Build Active File",
      cmd = "echo",
      args = {
        string.format("Unable to build active file. Too many potential targets: %s.", potential_str),
      },
    }
  end

  local target = potential_targets[1]
  local config = require("overseer.cmakeseer.template.cmake_build").builder(params)
  config.name = string.format("CMake Build %s", target.name)
  table.insert(config.args, "--target")
  table.insert(config.args, target.name)
  return config
end

--- @type overseer.TemplateFileDefinition
return {
  name = "CMake Build Active File",
  desc = "Builds the current file's target",
  builder = builder,
  condition = {
    callback = function()
      if not require("cmakeseer").project_is_configured() then
        return false
      end

      potential_targets = find_active_targets()
      return #potential_targets == 1
    end,
  },
}
