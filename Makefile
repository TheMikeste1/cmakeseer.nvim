LUAROCKS_TREE  := $(CURDIR)/.luarocks
# Neovim runs LuaJIT (Lua 5.1 compatible), so we target 5.1.
LUAROCKS_VER   := 5.1
LUAROCKS_FLAGS := --lua-version=$(LUAROCKS_VER) --tree=$(LUAROCKS_TREE)

export PATH := $(LUAROCKS_TREE)/bin:$(PATH)
export LUA_PATH := $(LUAROCKS_TREE)/share/lua/$(LUAROCKS_VER)/?.lua;$(LUAROCKS_TREE)/share/lua/$(LUAROCKS_VER)/?/init.lua;;
export LUA_CPATH := $(LUAROCKS_TREE)/lib/lua/$(LUAROCKS_VER)/?.so;$(LUAROCKS_TREE)/lib64/lua/$(LUAROCKS_VER)/?.so;;

.PHONY: download-types install-lua-tools install-busted install-luacheck check-lua-51 check-llscheck check-stylua-bin llscheck-all llscheck llscheck-spec check-stylua luacheck stylua test test-profile test-jit coverage coverage-text coverage-html coverage-summary clean-test clean all doc doc-panvimdoc doc-mini profile-start profile-stop jit-start jit-stop

ifeq ($(OS),Windows_NT)
    IGNORE_EXISTING =
else
    IGNORE_EXISTING = 2> /dev/null || true
endif

CONFIGURATION = .luarc.json
SPEC_CONFIGURATION = .luarc_spec.json

# Lua tooling installed into the project-local tree above.
# busted and luacheck are LuaRocks rocks. llscheck and stylua are NOT
# LuaRocks packages -- llscheck ships with the lua-language-server binary
# release and stylua is a Rust binary -- so they must be installed separately.
LUA_TOOLS := busted luacheck

install-lua-tools: check-lua-51 install-busted install-luacheck

# Verify a Lua 5.1 interpreter (lua5.1, luajit, or lua 5.1) is available.
# Neovim runs LuaJIT (Lua 5.1 compatible), so LuaRocks needs Lua 5.1 to
# install rocks targeting 5.1. This is a warning only -- it does not abort.
check-lua-51:
	@LUA51=""; \
	for interp in lua5.1 luajit lua; do \
		if command -v $$interp > /dev/null 2>&1; then \
			LUA51=$$interp; \
			break; \
		fi; \
	done; \
	if [ -z "$$LUA51" ]; then \
		echo ""; \
		echo "WARNING: No Lua 5.1 interpreter found on PATH."; \
		echo "         Neovim uses LuaJIT (Lua 5.1 compatible), so LuaRocks"; \
		echo "         needs Lua 5.1 to install busted/luacheck into .luarocks/."; \
		echo ""; \
		echo "         Install Lua 5.1 or LuaJIT, e.g.:"; \
		echo "           Debian/Ubuntu: sudo apt-get install lua5.1"; \
		echo "           macOS:         brew install lua@5.1  (or luajit)"; \
		echo "           Arch:          sudo pacman -S lua51 luajit"; \
		echo "           LuaJIT:        https://luajit.org/install.html"; \
		echo ""; \
	else \
		case $$LUA51 in \
			luajit) ;; \
			*) \
				VER=$$($$LUA51 -v 2>&1); \
				if ! echo "$$VER" | grep -q "5.1"; then \
					echo ""; \
					echo "WARNING: Found '$$LUA51' but it is not Lua 5.1: $$VER"; \
					echo "         Neovim uses LuaJIT (Lua 5.1 compatible)."; \
					echo ""; \
				fi ;; \
		esac; \
	fi

check-llscheck:
	@if ! command -v llscheck > /dev/null 2>&1; then \
		echo ""; \
		echo "WARNING: llscheck not found on PATH."; \
		echo "         llscheck ships with the lua-language-server binary release."; \
		echo ""; \
		echo "         Install lua-language-server, e.g.:"; \
		echo "           https://github.com/LuaLS/lua-language-server/releases"; \
		echo ""; \
	fi

check-stylua-bin:
	@if ! command -v stylua > /dev/null 2>&1; then \
		echo ""; \
		echo "WARNING: stylua not found on PATH."; \
		echo ""; \
		echo "         Install stylua, e.g.:"; \
		echo "           cargo install stylua"; \
		echo "           https://github.com/JohnnyMorganz/StyLua/releases"; \
		echo ""; \
	fi

install-busted:
	@which busted > /dev/null 2>&1 || luarocks $(LUAROCKS_FLAGS) install busted

install-luacheck:
	@which luacheck > /dev/null 2>&1 || luarocks $(LUAROCKS_FLAGS) install luacheck

download-types:
	@echo "Downloading types. . ."
	@git clone git@github.com:Bilal2453/luvit-meta.git   .dependencies/luvit-meta    $(IGNORE_EXISTING)
	@git clone git@github.com:LuaCATS/busted.git         .dependencies/busted        $(IGNORE_EXISTING)
	@git clone git@github.com:LuaCATS/luassert.git       .dependencies/luassert      $(IGNORE_EXISTING)
	@git clone git@github.com:folke/neoconf.nvim.git     .dependencies/neoconf.nvim  $(IGNORE_EXISTING)
	@git clone git@github.com:nvim-neotest/neotest.git   .dependencies/neotest       $(IGNORE_EXISTING)
	@git clone git@github.com:stevearc/overseer.nvim.git .dependencies/overseer.nvim $(IGNORE_EXISTING)
	@git clone git@github.com:MunifTanjim/nui.nvim.git   .dependencies/nui.nvim      $(IGNORE_EXISTING)

llscheck-spec: download-types check-llscheck
	@echo "Running llscheck-spec. . ."
	@VIMRUNTIME="`nvim --clean --headless --cmd 'lua io.write(os.getenv("VIMRUNTIME"))' --cmd 'quit'`" llscheck --configpath $(SPEC_CONFIGURATION) .

llscheck: download-types check-llscheck
	@echo "Running llscheck. . ."
	@VIMRUNTIME="`nvim --clean --headless --cmd 'lua io.write(os.getenv("VIMRUNTIME"))' --cmd 'quit'`" llscheck --configpath $(CONFIGURATION) .

llscheck-all: llscheck-spec llscheck

luacheck: install-lua-tools
	@echo "Running luacheck. . ."
	@luacheck lua plugin scripts spec

check-stylua: check-stylua-bin
	@echo "Running check-stylua. . ."
	@stylua lua plugin scripts spec --color always --check

stylua: check-stylua-bin
	@echo "Running stylua. . ."
	@stylua lua plugin scripts spec

TEST ?= .

test: install-lua-tools download-deps
	@echo "Running tests. . ."
	@if [ "$(TEST)" = "." ]; then \
	  busted --helper ./spec/minimal_init.lua spec/unit & \
	  busted --helper ./spec/minimal_init.lua spec/integration & \
	  wait; \
	else \
	  busted $(TEST); \
	fi

download-deps:
	@mkdir -p .dependencies
	@echo "Downloading test dependencies. . ."
	@git clone https://github.com/nvim-neotest/neotest.git    .dependencies/neotest     2> /dev/null || true
	@git clone https://github.com/nvim-lua/plenary.nvim.git   .dependencies/plenary.nvim 2> /dev/null || true
	@git clone https://github.com/nvim-neotest/nvim-nio.git   .dependencies/nvim-nio     2> /dev/null || true
	@git clone https://github.com/folke/neoconf.nvim.git      .dependencies/neoconf.nvim 2> /dev/null || true
	@git clone https://github.com/stevearc/overseer.nvim.git  .dependencies/overseer.nvim 2> /dev/null || true
	@git clone https://github.com/MunifTanjim/nui.nvim.git    .dependencies/nui.nvim     2> /dev/null || true
	@git clone https://github.com/Bilal2453/luvit-meta.git    .dependencies/luvit-meta   2> /dev/null || true
	@git clone https://github.com/LuaCATS/luassert.git        .dependencies/luassert     2> /dev/null || true
	@git clone https://github.com/nvim-lua/nvim-lspconfig.git .dependencies/nvim-lspconfig 2> /dev/null || true

# Run tests under instrumenting profiler (profile.nvim)
# Best for: Finding logic-based bottlenecks and redundant calls.
# Output: profile.json
test-profile:
	@echo "Starting tests with instrumenting profiler. . ."
	TEST_PROFILE=1 busted --helper spec/minimal_init.lua $(TEST)
	@echo "Tests finished. Trace saved to profile.json"

# Run tests under sampling profiler (jit.p)
# Best for: Identifying 'hot' code and JIT-compilation aborts.
# Output: luajit.p.report
test-jit:
	@echo "Starting tests with sampling profiler. . ."
	TEST_JIT=1 busted --helper spec/minimal_init.lua $(TEST)
	@echo "Tests finished. Results in luajit.p.report"

# luarocks install luacov
coverage:
	nvim -u NONE -U NONE -N -i NONE --headless -c "luafile scripts/luacov.lua" -c "quit"
	luacov

# luarocks install luacov-multiple
coverage-html: coverage
	luacov --reporter multiple.html

coverage-text: coverage
	cat luacov.report.out

coverage-summary: coverage
	@awk '/^File/,/^Total/' luacov.report.out

# Documentation generation (requires panvimdoc)
doc-panvimdoc:
	@echo "Generating vimdoc with panvimdoc. . ."
	@mkdir -p doc
	@docker run --rm -v $(PWD):/data kdheepak/panvimdoc -f README.md -p cmakeseer -t cmakeseer
	@echo "Documentation generated at doc/cmakeseer.txt"

# Documentation generation (mini.doc)
doc-mini:
	@echo "Generating documentation with mini.doc. . ."
	@nvim --headless -c "lua require('mini.doc').generate()" -c "quit"

doc: doc-panvimdoc

# Profiling targets (instrumenting via profile.nvim)
profile-start:
	@echo "Starting profile.nvim (instrumenting). . ."
	@nvim --cmd "lua require('cmakeseer.dev').profile_start()"

profile-stop:
	@echo "Stopping profile.nvim and saving trace. . ."
	@nvim --cmd "lua require('cmakeseer.dev').profile_stop()"

# Profiling targets (sampling via jit.p)
jit-start:
	@echo "Starting LuaJIT sampling profiler. . ."
	@nvim --cmd "lua require('cmakeseer.dev').jit_start()"

jit-stop:
	@echo "Stopping LuaJIT sampling profiler. . ."
	@nvim --cmd "lua require('cmakeseer.dev').jit_stop()"

clean-test:
	rm -rf luacov.stats.out luacov.report.out luacov_html/ profile.json luajit.p.report luajit.p.out

clean: clean-test
	rm -rf .dependencies

all: test llscheck-all luacheck check-stylua
