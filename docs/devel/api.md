# API Reference

This is the Neovim Lua API reference for bases.nvim developers. For user-facing documentation, see the [User Guide](../users/user-guide.md).

## Configuration

### Type Definitions

```lua
---@class BasesKeymaps
---@field follow_link string|false  -- Follow link or toggle sort (default: '<CR>')
---@field next_link string|false    -- Jump to next link (default: '<Tab>')
---@field prev_link string|false    -- Jump to previous link (default: '<S-Tab>')
---@field refresh string|false      -- Refresh base data (default: 'R')
---@field edit_cell string|false    -- Edit cell under cursor (default: 'c')
---@field edit_source string|false  -- Edit base source file (default: 'E')
---@field select_view string|false  -- Select view (default: 'v')
---@field debug string|false        -- Show debug info (default: '?')

---@class BasesInlineKeymaps
---@field follow_link string|false  -- Follow link in inline base (default: '<CR>')
---@field next_link string|false    -- Jump to next link (default: '<Tab>')
---@field prev_link string|false    -- Jump to previous link (default: '<S-Tab>')
---@field refresh string|false      -- Refresh inline bases (default: '<leader>br')
---@field edit_cell string|false    -- Edit cell in inline base (default: 'c')
---@field edit_source string|false  -- Edit inline base source (default: 'E')

---@class BasesInlineConfig
---@field enabled boolean            -- Enable inline rendering (default: true)
---@field auto_render boolean        -- Auto-render on BufEnter (default: true)
---@field keymaps BasesInlineKeymaps -- Keymap configuration for inline bases

---@class BasesDashboardSection
---@field base string        -- Base name (without .base extension)
---@field title string|nil   -- Section title (defaults to base name)
---@field max_rows number|nil -- Maximum data rows to display

---@class BasesDashboardConfig
---@field title string|nil              -- Main dashboard title
---@field sections BasesDashboardSection[] -- Sections to display
---@field spacing number|nil             -- Lines between sections (default: 1)

---@class BasesConfig
---@field vault_path string|nil         -- Vault path (auto-detected from obsidian.nvim if available)
---@field render_markdown boolean       -- Use markdown tables for render-markdown.nvim (default: false)
---@field date_format string            -- Date format string (default: '%Y-%m-%d')
---@field date_format_relative boolean  -- Use relative dates (default: false)
---@field keymaps BasesKeymaps           -- Keymap configuration
---@field inline BasesInlineConfig      -- Inline base rendering configuration
---@field dashboards table<string, BasesDashboardConfig>|nil -- Named dashboard configurations
```

### Default Configuration

```lua
{
    vault_path = nil,              -- Set explicitly or auto-detected from obsidian.nvim
    render_markdown = false,       -- Use unicode tables by default
    date_format = '%Y-%m-%d',
    date_format_relative = false,
    keymaps = {
        follow_link = '<CR>',
        next_link = '<Tab>',
        prev_link = '<S-Tab>',
        refresh = 'R',
        edit_cell = 'c',
        edit_source = 'E',
        select_view = 'v',
        debug = '?',
    },
    inline = {
        enabled = true,
        auto_render = true,
        keymaps = {
            follow_link = '<CR>',
            next_link = '<Tab>',
            prev_link = '<S-Tab>',
            refresh = '<leader>br',
            edit_cell = 'c',
            edit_source = 'E',
        },
    },
    dashboards = nil,
}
```

## Plugin API

Source: `lua/bases/init.lua`

### bases.setup(opts)

Initialize the plugin with user configuration. Must be called during Neovim initialization.

**Parameters:**
- `opts` (BasesConfig|nil) - User configuration overrides

**Example:**
```lua
require('bases').setup({
    vault_path = '/path/to/vault',
    date_format_relative = true,
    keymaps = {
        refresh = '<leader>br',  -- Custom keymap
        debug = false,           -- Disable debug keymap
    },
})
```

**Behavior:**
- Merges user config with defaults
- Creates highlight groups
- Sets up inline rendering if enabled
- Resolves vault path (from config or obsidian.nvim)
- Defers engine initialization until first use

---

### bases.open(base_path, existing_buf?)

Open a base file and render it as a table.

**Parameters:**
- `base_path` (string) - Path to .base file (absolute or vault-relative)
- `existing_buf` (number|nil) - Pre-existing buffer from BufReadCmd

**Example:**
```lua
require('bases').open('projects.base')
```

**Behavior:**
- Creates or reuses buffer
- Sets up buffer-local keymaps
- Shows loading state
- Queues query until engine is ready
- Renders table when data arrives

---

### bases.refresh(buf?, opts?)

Refresh the current base buffer by re-querying the engine.

**Parameters:**
- `buf` (number|nil) - Buffer handle (default: current buffer)
- `opts` (table|nil) - Options:
  - `silent` (boolean) - Suppress notifications (default: false)

**Example:**
```lua
-- Refresh current buffer
require('bases').refresh()

-- Refresh specific buffer silently
require('bases').refresh(bufnr, { silent = true })
```

**Returns:** Nothing

---

### bases.get_config()

Returns a deep copy of the current configuration.

**Returns:** (BasesConfig) - Current configuration

**Example:**
```lua
local config = require('bases').get_config()
print(config.date_format)
```

---

### bases.enable_inline()

Enable inline rendering if it was disabled during setup.

**Example:**
```lua
require('bases').enable_inline()
```

---

### bases.render_inline(buf?)

Render inline `![[*.base]]` embeds in a buffer.

**Parameters:**
- `buf` (number|nil) - Buffer handle (default: current buffer)

**Example:**
```lua
-- Render inline embeds in current buffer
require('bases').render_inline()
```

---

### bases.refresh_inline(buf?, opts?)

Refresh all inline bases in a buffer.

**Parameters:**
- `buf` (number|nil) - Buffer handle (default: current buffer)
- `opts` (table|nil) - Options:
  - `silent` (boolean) - Suppress notifications

**Example:**
```lua
require('bases').refresh_inline(nil, { silent = true })
```

---

### bases.open_dashboard(name)

Open a named dashboard from configuration.

**Parameters:**
- `name` (string) - Dashboard name from `setup({ dashboards = { [name] = {...} } })`

**Example:**
```lua
require('bases').open_dashboard('daily')
```

**Errors:**
- Notifies if dashboard name not found in config

---

### bases.refresh_dashboard(buf?, opts?)

Refresh all sections in the current dashboard buffer.

**Parameters:**
- `buf` (number|nil) - Buffer handle (default: current buffer)
- `opts` (table|nil) - Options:
  - `silent` (boolean) - Suppress notifications

**Example:**
```lua
require('bases').refresh_dashboard()
```

---

### bases.refresh_all_buffers(opts?)

Refresh all open base-related buffers (standalone bases, dashboards, and inline embeds).

**Parameters:**
- `opts` (table|nil) - Options forwarded to each refresh call (default: `{ silent = true }`)

**Example:**
```lua
-- Silent refresh of all base buffers
require('bases').refresh_all_buffers()

-- Verbose refresh
require('bases').refresh_all_buffers({ silent = false })
```

**Behavior:**
- Only refreshes if engine is ready
- Iterates all loaded buffers
- Detects buffer type via buffer-local variables

---

### bases.list_dashboards()

Returns a sorted list of configured dashboard names.

**Returns:** (string[]) - Dashboard names

**Example:**
```lua
local dashboards = require('bases').list_dashboards()
for _, name in ipairs(dashboards) do
    print(name)
end
```

## Engine API

Source: `lua/bases/engine/init.lua`

The engine is the core query system that indexes vault files and executes base queries.

### engine.set_vault_path(path)

Store the vault path without triggering initialization. Called by `bases.setup()`.

**Parameters:**
- `path` (string) - Absolute path to the vault directory

**Example:**
```lua
local engine = require('bases.engine')
engine.set_vault_path('/Users/me/vault')
```

---

### engine.init(path, callback?)

Initialize the engine and build the vault index. This is an expensive operation (scans all .md files).

**Parameters:**
- `path` (string) - Absolute path to the vault directory
- `callback` (function|nil) - Called when indexing completes: `callback(err)`

**Example:**
```lua
local engine = require('bases.engine')
engine.init('/Users/me/vault', function(err)
    if err then
        print('Init failed:', err)
    else
        print('Engine ready')
    end
end)
```

**Behavior:**
- Creates NoteIndex instance
- Scans vault for all .md files
- Parses frontmatter and metadata
- Starts file watcher for incremental updates
- Callbacks are scheduled via `vim.schedule()`

---

### engine.query(base_path, view_index, callback, this_file_path?)

Execute a query against a .base file.

**Parameters:**
- `base_path` (string) - Path to .base file (absolute or vault-relative)
- `view_index` (number) - 0-based view index
- `callback` (function) - `callback(err, result)` where:
  - `err` (string|nil) - Error message or nil on success
  - `result` (SerializedResult|nil) - Query result data
- `this_file_path` (string|nil, optional) - Vault-relative path of the
  embedding file. Resolved to a `NoteData` and made available to filter
  and formula expressions via the `this` namespace (e.g. `this.file.name`).
  Pass `nil` if the embed has no containing file (e.g. standalone .base
  buffers).

**Example:**
```lua
local engine = require('bases.engine')
engine.query('projects.base', 0, function(err, result)
    if err then
        print('Query failed:', err)
    else
        print('Found', #result.entries, 'entries')
    end
end)
```

**Errors:**
- "Query engine not initialized" if engine not ready
- Parse errors from .base file
- Expression evaluation errors

---

### engine.query_string(yaml_string, this_file_path?, view_index, callback)

Execute a query from a YAML string. Used for inline code block embeds.

**Parameters:**
- `yaml_string` (string) - YAML content of the base definition
- `this_file_path` (string|nil) - Vault-relative path of the containing file (for `this.` context)
- `view_index` (number) - 0-based view index
- `callback` (function) - `callback(err, result)`

**Example:**
```lua
local yaml = [[
properties:
  - file.name
  - note.status
where: note.status = "active"
]]

local engine = require('bases.engine')
engine.query_string(yaml, 'daily/2024-01-15.md', 0, function(err, result)
    -- ...
end)
```

---

### engine.is_ready()

Check if the engine has finished indexing and is ready to process queries.

**Returns:** (boolean) - true if ready, false otherwise

**Example:**
```lua
local engine = require('bases.engine')
if engine.is_ready() then
    -- Execute queries
end
```

---

### engine.on_ready(callback)

Queue a callback to fire once the engine is ready.

**Parameters:**
- `callback` (function) - `callback(err)` where err is nil on success

**Behavior:**
- If already initialized: fires immediately via `vim.schedule()`
- If initialization failed: fires with error
- Otherwise: queues callback and triggers lazy init if not started

**Example:**
```lua
local engine = require('bases.engine')
engine.on_ready(function(err)
    if not err then
        -- Engine is ready
    end
end)
```

---

### engine.get_index()

Returns the underlying NoteIndex instance.

**Returns:** (NoteIndex|nil) - Index instance or nil if not initialized

**Example:**
```lua
local engine = require('bases.engine')
local index = engine.get_index()
if index then
    local note = index:get('projects/alpha.md')
end
```

---

### engine.get_vault_path()

Returns the current vault path.

**Returns:** (string|nil) - Vault path or nil

---

### engine.update_file(file_path, callback?)

Re-index a specific file (vault-relative or absolute path).

**Parameters:**
- `file_path` (string) - Path to the file
- `callback` (function|nil) - `callback(err)`

**Example:**
```lua
local engine = require('bases.engine')
engine.update_file('projects/alpha.md', function(err)
    if not err then
        print('File updated')
    end
end)
```

**Errors:**
- "Query engine not initialized" if not ready

---

### engine.remove_file(file_path, callback?)

Remove a file from the index.

**Parameters:**
- `file_path` (string) - Path to the file
- `callback` (function|nil) - `callback(err)`

---

### engine.rebuild_index(callback?)

Perform a full rebuild of the index from scratch. Stops the file watcher, recreates the index, and restarts the watcher.

**Parameters:**
- `callback` (function|nil) - `callback(err)`

**Example:**
```lua
local engine = require('bases.engine')
engine.rebuild_index(function(err)
    if not err then
        print('Index rebuilt')
    end
end)
```

---

### engine.shutdown()

Stop the file watcher, save the cache, and clean up engine state.

**Example:**
```lua
local engine = require('bases.engine')
engine.shutdown()
```

**Behavior:**
- Stops file watcher
- Saves NoteIndex cache to disk
- Resets initialization state

---

## Base Parser API

Source: `lua/bases/engine/base_parser.lua`

The base parser module exposes helpers for working with parsed `.base`
QueryConfig structures, in addition to the `parse` / `parse_string` functions
used by the engine.

### base_parser.find_view_index(query_config, view_name)

Look up a view by name in a parsed QueryConfig and return its 0-based
index. The match is exact and case-sensitive. Used by the inline embed
renderer to resolve `![[name.base#View Name]]` style embeds.

**Parameters:**
- `query_config` (QueryConfig) - Parsed base config (e.g. from `parse`)
- `view_name` (string) - Name of the view to look up (matches `view.name`)

**Returns:**
- On success: `(index, nil)` where `index` is a 0-based integer
- On failure: `(nil, error_message)` where `error_message` describes the
  reason (e.g. `"View 'Foo' not found"`, `"View name is nil"`,
  `"Query config must be a table, got string"`)

**Example:**
```lua
local base_parser = require('bases.engine.base_parser')
local config, err = base_parser.parse('/path/to/projects.base')
if not config then
    error(err)
end

local idx, err = base_parser.find_view_index(config, 'Active Projects')
if not idx then
    error('Unknown view: ' .. err)
end
print('View index:', idx)
```

## Buffer-Local Data

These buffer-local variables are used to track state for navigation, editing, and rendering.

### Standalone Base Buffers

```lua
-- Path to the .base file
vim.b[buf].bases_path = "projects.base"

-- Currently selected view index (0-based)
vim.b[buf].bases_view_index = 0

-- Raw API response data (SerializedResult)
vim.b[buf].bases_data = { properties = {...}, entries = {...}, ... }

-- User sort state (overrides default sort)
vim.b[buf].bases_sort = { property = "note.status", direction = "asc" }

-- Link positions for navigation
vim.b[buf].bases_links = {
    { row = 4, col_start = 5, col_end = 15, path = "people/john.md", text = "john" },
    -- ...
}

-- Cell positions for editing
vim.b[buf].bases_cells = {
    {
        row = 4,
        col_start = 5,
        col_end = 15,
        property = "note.status",
        file_path = "projects/alpha.md",
        editable = true,
        display_text = "active",
        raw_value = { type = "primitive", value = "active" }
    },
    -- ...
}

-- Header cell positions for sorting
vim.b[buf].bases_headers = {
    { row = 2, col_start = 2, col_end = 10, property = "file.name" },
    { row = 2, col_start = 14, col_end = 20, property = "note.status" },
    -- ...
}
```

### Dashboard Buffers

```lua
-- Dashboard name from config
vim.b[buf].bases_dashboard_name = "daily"

-- Dashboard configuration
vim.b[buf].bases_dashboard_config = {
    title = "Daily Overview",
    sections = { ... },
    spacing = 1,
}

-- Line numbers where each section starts
vim.b[buf].bases_dashboard_section_starts = { 1, 15, 28 }

-- Section data (for refresh)
vim.b[buf].bases_dashboard_section_data = {
    { base = "tasks.base", title = "Tasks", ... },
    -- ...
}

-- Per-section sort states
vim.b[buf].bases_dashboard_sort_states = {
    [1] = { property = "note.status", direction = "asc" },
    [2] = nil,  -- No custom sort for section 2
}
```

### Inline Embed Buffers

```lua
-- Inline embed metadata
vim.b[buf].bases_inline_embeds = {
    {
        type = 'file',           -- or 'codeblock'
        source = 'projects.base', -- File path or nil for codeblock
        line_start = 5,          -- 1-indexed line number
        line_end = 5,            -- End of embed marker
        extmark_id = 123,        -- Extmark ID for rendered content
        selected_link = 1,       -- Currently selected link index
        links = { ... },         -- Link positions (relative to embed)
        cells = { ... },         -- Cell positions (relative to embed)
        data = { ... },          -- SerializedResult
    },
    -- ...
}
```

## Data Types

### SerializedResult

The result of a query execution. Returned by `engine.query()` and `engine.query_string()`.

```lua
{
    properties = { "file.name", "note.status", "note.priority" },
    entries = {
        -- Array of SerializedEntry
        { file = {...}, values = {...} },
    },
    limit = 25,  -- Row limit from .base file or nil
    defaultSort = {
        property = "note.status",
        direction = "ASC",  -- or "DESC"
    },
    propertyLabels = {
        ["note.status"] = "Status",
        ["note.priority"] = "Priority",
    },
    views = {
        count = 2,
        current = 0,  -- 0-based
        names = { "All", "Active" },
    },
    summaries = {
        ["note.priority"] = {
            label = "average",
            value = { type = "primitive", value = 2.5 },
        },
    },
}
```

### SerializedEntry

Represents a single row in the query result.

```lua
{
    file = {
        path = "projects/alpha.md",  -- Vault-relative path
        name = "alpha.md",
        basename = "alpha",
    },
    values = {
        ["file.name"] = { type = "primitive", value = "alpha" },
        ["note.status"] = { type = "primitive", value = "active" },
        ["note.due"] = { type = "date", value = 1704067200000, iso = "2024-01-01" },
        -- ...
    },
}
```

### SerializedValue (union type)

Values are tagged unions representing different data types.

**Primitive:**
```lua
{ type = "primitive", value = "hello" }   -- string
{ type = "primitive", value = 42 }        -- number
{ type = "primitive", value = true }      -- boolean
```

**Link:**
```lua
{ type = "link", value = "[[john]]", path = "people/john.md" }
```

**Date:**
```lua
{ type = "date", value = 1704067200000, iso = "2024-01-01T00:00:00Z" }
```

**List:**
```lua
{
    type = "list",
    value = {
        { type = "primitive", value = "tag1" },
        { type = "primitive", value = "tag2" },
    }
}
```

**Null:**
```lua
{ type = "null" }
```

**Image:**
```lua
{ type = "image", value = "attachments/photo.jpg" }
```

## See Also

- [User Guide](../users/user-guide.md) - User-facing keymaps and workflows
- [Architecture](architecture.md) - System design and data flow
