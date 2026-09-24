# How to Contribute

Want to report a bug? Check the current issues to see if a report exists already.

Feel like programming? Check to see is there's an issue you're interested in.

Want a neat new feature? You're welcome to file an issue, but be aware not all
feature requests will be accepted. Mostly because I'm too lazy to build it all,
but sometimes because it doesn't go in the direction I want the plugin to go.

## Making a Contribution

> [!IMPORTANT]
> Before making a contribution, be aware I'm somewhat crazy and plan to squash
> the entire project down to a single commit once I feel it's ready for a "1.0"
> release. Your contributions will still exist, but the squashed commit won't
> have your name on it.
> I might keep the original branch as a legacy branch, I've not decided yet.

1. Fork the repository
2. Make your additions
3. Open a PR to merge back

### Linting, Formatting, and Testing

The project uses `make` targets for linting and testing.

### Prerequisites

Install these tools before running the targets below:

- **Neovim** - tests run in headless Neovim.
- **[LuaRocks](https://luarocks.org)** - package manager used for Lua tools.
- `luarocks install luacheck` - Lua linter.
- `luarocks install luacov` - coverage tracking (`luacov-multiple` enables the HTML report).
  - `busted` (the test runner) is installed automatically by `make test`.
- **[stylua](https://github.com/JohnnyMorganz/StyLua)** - formatter (via cargo, homebrew, or a release binary).
- **[lua-language-server](https://luals.github.io)** - provides `llscheck` for static type checking.

### Linting and Formatting

- `make llscheck` - static type checking with the Lua Language Server. First run downloads type definitions into `.dependencies/`.
- `make luacheck` - lint `lua`, `plugin`, `scripts`, and `spec`.
- `make check-stylua` - verify formatting matches `stylua.toml` without modifying files.
- `make stylua` - auto-format `lua`, `plugin`, `scripts`, and `spec`.

### Tests

- `make test` - run the full suite with `busted`. Tests run in headless Neovim and download any missing dependencies into `.dependencies/` on first run.
- `make test-profile` - run the suite under profile.nvim's instrumenting profiler; writes `profile.json`.
- `make test-jit` - run the suite under LuaJIT's sampling profiler; writes `luajit.p.report`.

### Coverage

- `make coverage` - run tests with coverage tracking.
- `make coverage-text` / `make coverage-summary` - view the report.
- `make coverage-html` - HTML report.
- `make clean-test` - remove coverage and profiling artifacts.

## AI Contributions

Coding harnesses and other AI tools are cool pieces of technology.
My master's degree was directly related to AI/ML, and while working on it I had
the opportunity to watch and grade as students began using LLMs.
They can be useful tools, but come with downsides.
I am happy to accept AI contributions, but with a few caveats:

- You own every design decision made
- You should be able to explain every line of code you submit, regardless of if it is AI generated or not
- You should assume the AI took the shortest path possible to accomplish what you asked it to do, and so its contributions may not be the optimal design
- AI-generated text tends to have certain "smells." They like to reference the conversation you had with it while developing, they'll add "structure" comments, etc. I prefer to not have those in my code: my work already smells enough. You'll need to "sanitize" the AI's contributions

I recommend trying to implement a couple of features by hand first to gain an understanding of the project.
While not required, this will give you a good feel for the nature of the plugin and help you see
where improvements can be made.
