.PHONY: download-types llscheck check-stylua luacheck stylua test test-profile test-jit coverage coverage-text coverage-html coverage-summary clean-test clean all doc doc-panvimdoc doc-mini profile-start profile-stop jit-start jit-stop neoclippy

ifeq ($(OS),Windows_NT)
    IGNORE_EXISTING =
else
    IGNORE_EXISTING = 2> /dev/null || true
endif

CONFIGURATION = .luarc.json

download-types:
	@echo "Downloading types. . ."
	@git clone git@github.com:Bilal2453/luvit-meta.git   .dependencies/luvit-meta    $(IGNORE_EXISTING)
	@git clone git@github.com:LuaCATS/busted.git         .dependencies/busted        $(IGNORE_EXISTING)
	@git clone git@github.com:LuaCATS/luassert.git       .dependencies/luassert      $(IGNORE_EXISTING)
	@git clone git@github.com:folke/neoconf.nvim.git     .dependencies/neoconf.nvim  $(IGNORE_EXISTING)
	@git clone git@github.com:nvim-neotest/neotest.git   .dependencies/neotest       $(IGNORE_EXISTING)
	@git clone git@github.com:stevearc/overseer.nvim.git .dependencies/overseer.nvim $(IGNORE_EXISTING)
	@git clone git@github.com:MunifTanjim/nui.nvim.git   .dependencies/nui.nvim      $(IGNORE_EXISTING)


llscheck: download-types
	VIMRUNTIME="`nvim --clean --headless --cmd 'lua io.write(os.getenv("VIMRUNTIME"))' --cmd 'quit'`" llscheck --configpath $(CONFIGURATION) .

luacheck:
	luacheck lua plugin scripts spec

check-stylua:
	stylua lua plugin scripts spec --color always --check

stylua:
	stylua lua plugin scripts spec

neoclippy:
	python3 neoclippy.py lua/

# standard test
test:
	busted .

# Run tests under instrumenting profiler (profile.nvim)
# Best for: Finding logic-based bottlenecks and redundant calls.
# Output: profile.json
test-profile:
	@echo "Starting tests with instrumenting profiler. . ."
	TEST_PROFILE=1 busted --helper spec/minimal_init.lua .
	@echo "Tests finished. Trace saved to profile.json"

# Run tests under sampling profiler (jit.p)
# Best for: Identifying 'hot' code and JIT-compilation aborts.
# Output: luajit.p.report
test-jit:
	@echo "Starting tests with sampling profiler. . ."
	TEST_JIT=1 busted --helper spec/minimal_init.lua .
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

all: test llscheck luacheck check-stylua neoclippy
