if jit then
  jit.off()
end
require("luacov")

--- Run `busted` unittests with `LuaCov` enabled.
--- If run correctly, this script will generate a `luacov.stats.out` file.
--- e.g. `nvim -u NONE -U NONE -N -i NONE --headless -c "luafile scripts/luacov.lua" -c "quit"`

local _CURRENT_DIRECTORY = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.expand("<sfile>:p")), ":h")

local _PREVIOUS_RUN = vim.fs.joinpath(_CURRENT_DIRECTORY, "luacov.stats.out")

if vim.fn.filereadable(_PREVIOUS_RUN) then
  os.remove(_PREVIOUS_RUN)
end

dofile("spec/minimal_init.lua")

-- NOTE: These arguments were just found from experimentation. They
-- may not be 100% right.
_G.arg = { "--ignore-lua", [0] = "spec/minimal_init.lua" }
require("busted.runner")({ standalone = false })
