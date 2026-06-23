# AGENTS.md — bases.nvim

Compact guidance for AI agents working in this repo. See `README.md`,
`docs/devel/architecture.md`, and `docs/devel/testing.md` for full detail.

## What this is

A Neovim plugin that renders [Obsidian Bases](https://obsidian.md/blog/introducing-bases/)
(`.base` files) as interactive tables. Native engine, no LuaRocks/curl deps.

## Layout (where things actually live)

- `plugin/bases.lua` — autocmds (`BufReadCmd` on `*.base`, `:BasesDashboard`, `VimLeavePre`, `BufWritePost`).
- `lua/bases/init.lua` — public API: `setup`, `open`, `refresh`, `refresh_all_buffers`, etc.
- `lua/bases/engine/` — pure data layer: YAML, note index, base parser, query engine, expression evaluator. Loads on first use (lazy).
- `lua/bases/{buffer,render,navigation,edit,source_edit,views,debug,health,api,display}.lua` — UI layer.
- `lua/bases/inline/`, `lua/bases/dashboard/` — `![[name.base]]` embeds and multi-base dashboards.
- `tests/` — `unit/` (no buffers/windows) and `integration/` (creates buffers). `tests/fixtures/vault/` is a sample vault.
- `docs/` — user + developer docs (architecture, API reference, testing guide, contributing).

There is no `bases.nvim/` subdirectory. The repo root IS the plugin; lazy.nvim
spec is `miller3616/bases.nvim` (see `README.md` quick start).

## Build, test, lint

**Only the Makefile exists.** No linter, formatter, or typechecker is configured
(no stylua/selene/luacheck/luals configs). No CI workflow under `.github/`.

```bash
make deps              # one-time: clones mini.nvim into deps/
make test              # full suite (mini.test, headless)
make test-unit         # tests/unit/ only
make test-integration  # tests/integration/ only
make clean             # rm -rf deps
```

Single test file directly via nvim:
```bash
nvim --headless -u NONE \
  -c "lua vim.opt.runtimepath:prepend('.')" \
  -c "lua vim.opt.runtimepath:prepend('deps/mini.nvim')" \
  -c "lua require('mini.test').run_file('tests/unit/test_lexer.lua')"
```

Requires **Neovim 0.11+** (uses `vim.uv` and `vim.mpack`; see `lua/bases/health.lua`).
Run `:checkhealth bases` after loading the plugin.

## Code conventions (don't violate these)

- **LuaCATS annotations** on every public function (`---@param`, `---@return`,
  `---@class`). Existing `---@class BasesConfig` etc. are the source of truth.
- **Buffer-local state, never module-level.** All per-buffer state lives in
  `vim.b[buf].<key>`: `bases_path`, `bases_view_index`, `bases_links`,
  `bases_cells`, `bases_headers`, `bases_dashboard_name`,
  `bases_dashboard_sections`, `bases_inline_embeds`. See `lua/bases/init.lua:296-409`.
- **Callback-based async.** Engine uses `engine.on_ready(cb)` and
  `engine.query(path, view, cb)`. Callbacks fire inside `vim.schedule`.
- **Lazy engine init.** `setup()` stores config but does NOT index the vault.
  The engine initializes on first `.base` open via `engine.on_ready()`. Adding
  eager init will hurt cold-start time.
- **Display layer is unified.** All contexts (standalone, dashboard, inline)
  pass through `lua/bases/display.lua` for sort/limit before rendering.
- **No external runtime deps.** YAML parsing and expression evaluation are
  custom (`lua/bases/engine/yaml.lua`, `lua/bases/engine/expr/`). Do not add
  luarocks or curl dependencies.
- **`lua/bases/api.lua` is dead code** (HTTP client replaced by native engine).
  It is not required anywhere. Don't extend it.

## Test conventions (the easy-to-miss parts)

- Files must match `**/test_*.lua` to be discovered — glob is set in
  `tests/init.lua:13` and `tests/run_subset.lua:14`.
- Integration tests create real buffers/windows; clean up in `post_case` hooks
  (`vim.api.nvim_buf_delete(buf, { force = true })`).
- Modules call `require('bases')` (or read the `bases` global) inside functions
  to read config. **To unit-test such a module, you MUST mock it BEFORE
  requiring the module under test:**
  ```lua
  package.loaded['bases'] = { get_config = function() return { date_format = '%Y-%m-%d' } end }
  local mod = require('bases.views')  -- safe to require now
  ```
  Same pattern for `package.loaded['bases.engine']`. See
  `docs/devel/testing.md:264-301` and `tests/unit/test_query_engine.lua`-style
  tests for examples.
- Use `tests/helpers.lua` factories: `make_note_data`, `make_note_index`,
  `make_serialized_entry`, `fixture_path`, `read_fixture`.
- The fixture vault at `tests/fixtures/vault/` has `projects/`, `people/`,
  `daily/`, and `tasks.base`.

## Where to make common changes

| Task | File |
|---|---|
| Add a global expression function | `lua/bases/engine/expr/functions.lua` |
| Add a type method | `lua/bases/engine/expr/methods.lua` |
| Change table rendering | `lua/bases/render.lua` |
| Change sort/limit logic | `lua/bases/display.lua` |
| Change buffer setup/keymaps | `lua/bases/init.lua` (setup_keymaps), `lua/bases/buffer.lua` |
| Add a new autocmd/command | `plugin/bases.lua` |
| Add a new default keymap | `lua/bases/init.lua` (config.keymaps defaults + setup_keymaps) |

## Debugging

- In any bases buffer, `?` shows debug info (base path, view, link/cell
  positions). Implementation: `lua/bases/debug.lua`.
- `:checkhealth bases` reports vault status, engine init state, and cache.
- The note cache is at `<vault>/.obsidian/plugins/bases/note-cache.mpack`
  (msgpack via `vim.mpack`). Delete it to force a full re-index.
