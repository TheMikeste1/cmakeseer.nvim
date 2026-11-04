# Neovim runs LuaJIT (Lua 5.1 compatible), so we target 5.1.
LUAROCKS_VER := "5.1"
LUAROCKS_TREE := ".luarocks"
LUAROCKS_FLAGS := f"--lua-version={{LUAROCKS_VER}} --tree={{LUAROCKS_TREE}}"

export PATH := justfile_directory() + f"/{{LUAROCKS_TREE}}/bin" + (if os_family() == "windows" { ";" } else { ":" }) + env("PATH")
export LUA_PATH := f"{{LUAROCKS_TREE}}/share/lua/{{LUAROCKS_VER}}/?.lua;{{LUAROCKS_TREE}}/share/lua/{{LUAROCKS_VER}}/?/init.lua;;"
export LUA_CPATH := f"{{LUAROCKS_TREE}}/lib/lua/{{LUAROCKS_VER}}/?.so;{{LUAROCKS_TREE}}/lib64/lua/{{LUAROCKS_VER}}/?.so;;"

[default]
all: test llscheck-all luacheck check-stylua

clean: clean-test
    rm -rf .dependencies

clean-test:
    rm -rf luacov.stats.out luacov.report.out luacov_html/ profile.json luajit.p.report luajit.p.out

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

[private]
download-dep owner repo:
    @mkdir -p .dependencies
    @git clone "git@github.com:{{ owner }}/{{ repo }}.git" ".dependencies/{{ repo }}" 2> /dev/null || true

download-deps:
    @echo "Downloading dependencies. . ."
    @just download-dep Bilal2453 luvit-meta
    @just download-dep LuaCATS busted
    @just download-dep LuaCATS luassert
    @just download-dep MunifTanjim nui.nvim
    @just download-dep folke neoconf.nvim
    @just download-dep nvim-lua nvim-lspconfig
    @just download-dep nvim-lua plenary.nvim
    @just download-dep nvim-neotest neotest
    @just download-dep nvim-neotest nvim-nio
    @just download-dep stevearc overseer.nvim

[private]
luarocks-install package:
    #!/usr/bin/env bash
    if [[ ! -f "{{ LUAROCKS_TREE }}/bin/{{ package }}" ]]; then
      echo luarocks {{ LUAROCKS_FLAGS }} install {{ package }}
      luarocks {{ LUAROCKS_FLAGS }} install {{ package }}
    fi

[group("install-tools")]
install-busted: (luarocks-install "busted")
[group("install-tools")]
install-llscheck: (luarocks-install "llscheck")
[group("install-tools")]
install-luacheck: (luarocks-install "luacheck")
[group("install-tools")]
install-stylua:
    @cargo install stylua

[parallel]
[private]
run-llscheck config: download-deps install-llscheck
    @echo llscheck --configpath {{ config }} .
    @VIMRUNTIME="`nvim --clean --headless --cmd 'lua io.write(os.getenv("VIMRUNTIME"))' --cmd 'quit'`" llscheck --configpath {{ config }} .

llscheck-spec: (run-llscheck "./.luarc_spec.json")

llscheck: (run-llscheck "./.luarc.json")

llscheck-all: llscheck-spec llscheck

luacheck:
    luacheck lua plugin scripts spec

check-stylua:
    stylua lua plugin scripts spec --color always --check

stylua:
    stylua lua plugin scripts spec

run-test args:
    busted --helper ./spec/minimal_init.lua {{ args }}

unit-test: (run-test "spec/unit")
integration-test: (run-test "spec/integration")

[parallel]
test: download-deps install-busted
    just unit-test & just integration-test & wait
