# Architecture

## System Overview

bases.nvim is a native Neovim plugin that renders Obsidian Bases as interactive tables. The architecture consists of a native query engine that reads vault files directly, a data transformation pipeline, and rendering layers for standalone bases, inline embeds, and multi-base dashboards.

```
┌──────────────────────────────────────────────────────────────────────┐
│                               NEOVIM                                 │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                          bases.nvim                            │  │
│  │                                                                │  │
│  │  ┌─────────────────────────────────────────────────────────┐   │  │
│  │  │                    Native Engine                        │   │  │
│  │  │                                                         │   │  │
│  │  │  ┌───────────┐  ┌───────────┐  ┌────────────────────┐  │   │  │
│  │  │  │ yaml.lua  │  │note_index │  │   expr/ engine     │  │   │  │
│  │  │  │ (parser)  │  │  .lua     │  │ (lexer, parser,    │  │   │  │
│  │  │  └─────┬─────┘  └─────┬─────┘  │  evaluator, types, │  │   │  │
│  │  │        │              │         │  functions, methods)│  │   │  │
│  │  │        │              │         └─────────┬──────────┘  │   │  │
│  │  │  ┌─────▼─────┐  ┌────▼─────┐  ┌──────────▼──────────┐  │   │  │
│  │  │  │base_parser│  │  query   │  │  frontmatter_editor │  │   │  │
│  │  │  │   .lua    │  │ engine   │  │       .lua          │  │   │  │
│  │  │  └───────────┘  │  .lua    │  └─────────────────────┘  │   │  │
│  │  │                 └──────────┘                            │   │  │
│  │  │  ┌───────────┐  ┌──────────┐                           │   │  │
│  │  │  │  init.lua │  │  file    │                           │   │  │
│  │  │  │(public API│  │ watcher  │                           │   │  │
│  │  │  └───────────┘  │  .lua    │                           │   │  │
│  │  │                 └──────────┘                            │   │  │
│  │  └─────────────────────────────────────────────────────────┘   │  │
│  │                              │                                  │  │
│  │  ┌───────────┐ ┌───────────┐│┌───────────┐ ┌───────────────┐  │  │
│  │  │display.lua│ │render.lua │││buffer.lua │ │navigation.lua │  │  │
│  │  │(transform)│ │ (table)   │││ (state)   │ │   (links)     │  │  │
│  │  └───────────┘ └───────────┘│└───────────┘ └───────────────┘  │  │
│  │                              │                                  │  │
│  │  ┌──────────────────────────▼───────────────────────────────┐  │  │
│  │  │ inline/     dashboard/     edit.lua    views.lua         │  │  │
│  │  │ (embeds)    (multi-base)   (editing)   (view selection)  │  │  │
│  │  └─────────────────────────────────────────────────────────┘  │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │                  obsidian.nvim (optional)                      │  │
│  │                (vault path auto-detection)                     │  │
│  └────────────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                  ┌───────────────────────┐
                  │   Vault Filesystem    │
                  │  .md + .base files    │
                  └───────────────────────┘
```

## Engine Modules

The native engine replaces the HTTP-based API with direct filesystem access. All modules live under `engine/`.

| Module | Responsibility |
|--------|----------------|
| `engine/yaml.lua` | Custom YAML parser (no external dependencies) |
| `engine/note_index.lua` | In-memory vault index with secondary indices by tag, folder, link |
| `engine/base_parser.lua` | Parse `.base` YAML files into QueryConfig structures |
| `engine/expr/lexer.lua` | Expression tokenizer supporting 26 token types |
| `engine/expr/parser.lua` | Recursive descent parser generating AST nodes |
| `engine/expr/evaluator.lua` | AST walker with namespace resolution (file/note/formula/this) |
| `engine/expr/types.lua` | Runtime type system with coercion (null, string, number, boolean, date, link, list, image) |
| `engine/expr/functions.lua` | Global functions (today, now, date, if, contains, etc.) |
| `engine/expr/methods.lua` | Type method dispatch (e.g., string.lower(), date.year(), list.length()) |
| `engine/query_engine.lua` | Filter/sort/limit execution producing SerializedResult |
| `engine/summaries.lua` | Column aggregation (sum, avg, count, min, max) |
| `engine/init.lua` | Public API: init(), query(), query_string(), on_ready(), update_file(), shutdown() |
| `engine/file_watcher.lua` | vim.uv filesystem watcher with 300ms debounce for incremental index updates |
| `engine/frontmatter_editor.lua` | Line-level YAML frontmatter editing without full re-parse |

## Rendering Pipeline

The rendering pipeline transforms SerializedResult data into buffer content with link/cell tracking for navigation and editing.

| Module | Responsibility |
|--------|----------------|
| `display.lua` | Data transformation: sort entries, apply limits, validate constraints |
| `render.lua` | Unicode/markdown table generation, cell tracking, column width calculation |
| `buffer.lua` | Buffer creation, modifiable state management, loading/error states |
| `navigation.lua` | Link detection, cursor movement (Tab/Shift-Tab), header sorting (Enter) |
| `edit.lua` | Cell editing UI (floating window), frontmatter submission, refresh on save |
| `views.lua` | View selection picker, view switching, sort state clearing |
| `source_edit.lua` | Edit `.base` source files in split window |
| `debug.lua` | Debug overlay showing raw API data, links, cells, sort state |
| `inline/detect.lua` | Scan buffers for `![[base.base]]`, `![[base.base#View]]`, and ` ```base ` embeds |
| `inline/render.lua` | Render embeds as virtual lines using extmarks |
| `inline/navigation.lua` | Link/cell navigation within virtual line embeds |
| `inline/source_edit.lua` | Edit inline code block source |
| `dashboard/render.lua` | Compose multiple base tables with section headers |
| `dashboard/navigation.lua` | Section navigation (]]/ [[), per-section link/cell tracking |

## Data Flow

### Opening a Base

The flow from `:edit mybase.base` to rendered table:

1. `BufReadCmd` autocmd triggers `bases.open(base_path, buf)`
2. `bases.open()` configures buffer, shows loading state, calls `engine.on_ready()`
3. `engine.on_ready()` defers initialization, ensures `vault_path` is set, starts index build
4. `note_index:build()` scans vault recursively, loads msgpack cache, batches file parsing (50 per vim.schedule)
5. `engine.query()` parses `.base` file, executes filter/sort/limit, returns `SerializedResult`
6. `display.prepare()` applies client-side sort override (if set), applies limit after sort
7. `render.render()` generates unicode/markdown table, stores links/cells/headers in `vim.b[buf]`
8. `buffer.set_content()` writes lines to buffer, applies highlights

### NoteIndex Build

The asynchronous index build minimizes UI blocking:

1. `note_index:build(callback)` loads existing msgpack cache from `.obsidian/plugins/bases/note-cache.mpack`
2. `scan_directory_async()` recursively scans vault, yielding every 20 directories via `vim.schedule()`
3. Skip directories: `.obsidian`, `.git`, `.trash`, any starting with `.`
4. Classify files by mtime/size: restore cached entries if unchanged, else parse fresh
5. Batch processing: 100 files per stat batch, 50 files per parse batch, each yielding to event loop
6. Build secondary indices: `by_tag[tag_lowercase]`, `by_folder[folder_path]`, `by_outgoing_link[target]`
7. Save cache on shutdown via `note_index:save_cache()`
8. Start file watcher for incremental updates (create/modify/delete events)

### Editing a Property

The property edit flow uses direct frontmatter editing without HTTP:

1. User presses `c` on editable cell (note.* properties only)
2. `edit.edit_cell()` creates floating window with current value
3. User modifies value, presses Enter
4. `edit.submit_edit()` calls `frontmatter_editor.update_field(abs_path, field_name, value)`
5. `frontmatter_editor` parses frontmatter, updates field, writes back to file
6. `engine.update_file()` re-indexes modified file, updates secondary indices
7. `bases.refresh()` re-queries base, re-renders table with updated value

### Following a Link

Link navigation uses the engine vault path:

1. User presses Enter on link cell
2. `navigation.follow_link()` gets link at cursor from `vim.b[buf].bases_links`
3. Resolve link path: `engine.get_vault_path() .. '/' .. link.path .. '.md'`
4. `vim.cmd('edit ' .. full_path)` opens target file

## Data Transformation Layer

The `display.lua` module centralizes sort-before-limit ordering to ensure consistency across standalone bases, inline embeds, and dashboards.

### display.prepare(raw_data, view_state)

```lua
{
  properties = { "file.name", "note.status", "note.priority" },
  entries = { /* sorted and limited SerializedEntry[] */ },
  sort_state = { property = "note.priority", direction = "desc" },
  property_labels = { ["note.status"] = "Status" },
  summaries = { ["note.budget"] = { type = "primitive", value = 3000, label = "Total" } },
}
```

Processing steps:

1. Compute effective sort: `view_state.sort` (user override) OR `raw_data.defaultSort` (view config)
2. Sort entries by property if sort exists
3. Apply limit after sorting (e.g., limit 25 means "top 25 after sort")
4. Return DisplayData with transformed entries

## Data Serialization

### SerializedResult

The query engine produces this structure:

```lua
{
  properties = { "file.name", "note.status" },  -- Column names
  entries = { SerializedEntry, ... },           -- Row data
  limit = 25,                                    -- View limit
  defaultSort = { property = "note.status", direction = "ASC" },
  propertyLabels = { ["note.status"] = "Status" },  -- Custom column labels
  views = { count = 2, current = 0, names = { "All", "Active" } },
  summaries = { ["note.budget"] = SummaryEntry },
}
```

### SerializedEntry

Each row contains file metadata and column values:

```lua
{
  file = { path = "projects/alpha.md", name = "alpha.md", basename = "alpha" },
  values = {
    ["file.name"] = { type = "link", value = "[[alpha]]", path = "projects/alpha.md" },
    ["note.status"] = { type = "primitive", value = "active" },
  },
}
```

### SerializedValue types

The type system supports:

- `primitive`: `{ type = "primitive", value = "active" }`
- `link`: `{ type = "link", value = "[[John]]", path = "people/john.md" }`
- `date`: `{ type = "date", value = 1706054400000, iso = "2024-01-24" }`
- `list`: `{ type = "list", value = { SerializedValue, ... } }`
- `null`: `{ type = "null" }`
- `image`: `{ type = "image", value = "path/to/image.png" }`

## Expression Engine Pipeline

The expression engine transforms filter/formula strings into evaluated results:

```
Source string → Lexer → Tokens → Parser → AST → Evaluator → TypedValue
```

### Key Features

**Operators**: `+`, `-`, `*`, `/`, `%`, `==`, `!=`, `<`, `>`, `<=`, `>=`, `&&`, `||`, `!`

**Namespaces**:
- `file.*`: File properties (name, path, folder, ext, size, ctime, mtime, tags, links)
- `note.*`: Frontmatter properties (custom fields from YAML)
- `formula.*`: Computed fields defined in base config
- `this.*`: Context-aware reference to current file (for inline embeds)

**Index Optimization**: The query engine detects simple patterns and uses secondary indices:
- `file.hasTag("project")` → uses `by_tag["project"]` index
- `file.inFolder("projects")` → uses `by_folder["projects"]` index
- Complex filters fall back to full scan

**Type Coercion**: The type system handles mixed types gracefully:
- Nulls always sort to end
- Type precedence for mixed columns: numbers < strings < booleans
- String comparisons are case-insensitive

## Lua Implementation Notes

### Parser Architecture

```
YAML Parser → Expression Lexer → Expression Parser → AST Builder → Evaluator
```

All parsing is pure Lua with no external dependencies. The YAML parser supports the subset needed for Obsidian frontmatter (scalars, lists, maps, null, booleans, numbers, strings with quotes/literals).

### Key Considerations

**Number precision**: Lua 5.3+ uses 64-bit integers for date milliseconds (`os.time() * 1000`)

**Pattern matching**: Lua patterns differ from JavaScript regex. Examples:
- `%[%[([^%]]+)%]%]` matches `[[wikilink]]`
- `^file%.hasTag%("([^"]+)"%)`  matches `file.hasTag("tag")`

**Method chaining**: Lua metatables with `__index` enable `note.tags.contains("active")`:
```lua
{ __index = function(t, k) return function(...) return method_dispatch(t, k, ...) end end }
```

**Null handling**: Lua `nil` maps to missing properties. The type system uses `{ type = "null" }` to distinguish "property exists with no value" from "property doesn't exist".

### AST Node Types

```lua
local NodeType = {
  LITERAL = "literal",       -- Raw values: 123, "text", true
  IDENTIFIER = "identifier", -- Variable names: file, note, formula
  BINARY_OP = "binary_op",   -- Infix operators: a + b, x > 5
  UNARY_OP = "unary_op",     -- Prefix operators: !active, -10
  CALL = "call",             -- Function calls: date("2024-01-01")
  MEMBER = "member",         -- Dot access: file.name
  INDEX = "index",           -- Bracket access: tags[0]
  ARRAY = "array",           -- Array literals: [1, 2, 3]
  OBJECT = "object"          -- Object literals: {a: 1, b: 2}
}
```

## NoteData Structure

Each indexed note stores:

```lua
{
  path = "people/john.md",           -- Vault-relative path
  name = "john.md",                  -- File name with extension
  basename = "john",                 -- File name without extension
  folder = "people",                 -- Parent folder path
  ext = "md",                        -- File extension
  ctime = 1706054400000,             -- Creation time (milliseconds)
  mtime = 1706140800000,             -- Modification time (milliseconds)
  size = 1234,                       -- File size (bytes)
  frontmatter = { Person = "John", status = "active" },  -- Parsed YAML frontmatter
  tags = { "project", "active" },    -- Expanded tags from frontmatter
  tag_set = { project = true, active = true },  -- O(1) tag lookup (lowercase)
  links = { "other-note", "folder/ref" },  -- Outgoing wikilinks
  outgoing_link_set = { ["other-note"] = true },  -- O(1) link lookup
}
```

## Plugin Integration

### obsidian.nvim (optional)

bases.nvim uses obsidian.nvim for one purpose:

1. **Vault path auto-detection**: Read from `Obsidian.dir` global if `vault_path` is not configured

Link resolution is handled internally by the engine using `engine.get_vault_path()`. obsidian.nvim is not required — users can set `vault_path` explicitly in `setup()`.

## Deferred Initialization

The engine uses a lazy-load pattern to minimize startup overhead:

1. `setup()` stores `vault_path` but does NOT start indexing
2. `engine.on_ready(callback)` queues callbacks and triggers `init()` on first use
3. Query modules (`base_parser`, `query_engine`) are loaded lazily on first query
4. NoteIndex cache uses msgpack serialization for fast startup (cache restored before fresh parse)
5. File watcher starts after initial index build completes

This pattern allows the plugin to load instantly while deferring expensive operations (filesystem scan, YAML parsing) until the user opens a base.

## File Watcher

The file watcher provides incremental index updates without full rescans:

- Uses `vim.uv.fs_event` for recursive vault watching
- Debounces events with 300ms timer to batch rapid changes
- Filters by extension (`.md`, `.base`) and skips hidden directories
- Determines event type (create/modify/delete) by stat check
- Calls `note_index:update_file()` or `note_index:remove_file()`
- Updates secondary indices automatically
- Refreshes all open base-related buffers on file changes

## Cache Strategy

The NoteIndex persists to disk for fast startup:

- Cache path: `.obsidian/plugins/bases/note-cache.mpack`
- Cache version: 2 (bump on schema changes)
- Serialization: msgpack (faster than JSON, binary format)
- Validation: checks vault path and cache version
- Optimization: restored notes skip full YAML parse if mtime/size unchanged
- Save trigger: `engine.shutdown()` or manual `note_index:save_cache()`

## Buffer State Management

Each buffer type stores metadata in `vim.b[buf]` variables:

### Standalone Base Buffer

```lua
vim.b[buf].bases_path           -- Relative path to .base file
vim.b[buf].bases_data           -- Full SerializedResult from API
vim.b[buf].bases_links          -- Array of { row, col_start, col_end, path, text }
vim.b[buf].bases_cells          -- Array of CellInfo for editing
vim.b[buf].bases_headers        -- Array of HeaderCellInfo for sorting
vim.b[buf].bases_sort           -- Client-side sort override { property, direction }
vim.b[buf].bases_view_index     -- 0-based view index
```

### Dashboard Buffer

```lua
vim.b[buf].bases_dashboard_name          -- Dashboard name from config
vim.b[buf].bases_dashboard_config        -- Dashboard configuration
vim.b[buf].bases_dashboard_section_data  -- Cached section data
vim.b[buf].bases_dashboard_section_starts  -- Line numbers where sections begin
vim.b[buf].bases_dashboard_sort_states   -- Per-section sort overrides
vim.b[buf].bases_dashboard_use_markdown  -- Rendering mode
vim.b[buf].bases_links                   -- Global link array
vim.b[buf].bases_cells                   -- Global cell array
vim.b[buf].bases_headers                 -- Global header array
```

### Inline Embed Buffer

```lua
vim.b[buf].bases_inline_embeds  -- Array of embed info with extmark IDs, links, cells
```

## Highlight Groups

The plugin defines these highlight groups:

- `BasesLink`: Link text (default: Underlined)
- `BasesHeader`: Table headers (default: Title)
- `BasesBorder`: Table borders (default: Comment)
- `BasesEditable`: Editable cells (default: String)
- `BasesSortedHeader`: Currently sorted column header (default: Special)
- `BasesDashboardTitle`: Dashboard main title (default: Title)
- `BasesDashboardSectionTitle`: Section titles (default: Label)
- `BasesSummary`: Summary line text (default: Comment)

## Performance Characteristics

**Index Build**: O(n) where n = number of markdown files. Batched to avoid blocking UI.

**Query Execution**:
- With index hint (hasTag/inFolder): O(m) where m = matching files
- Without hint: O(n) full scan
- Per-file evaluation: O(p) where p = number of properties

**Sorting**: O(m log m) where m = result size before limit

**Rendering**: O(r * c) where r = displayed rows, c = columns

**Cache Load**: O(1) file read, O(n) deserialization

**File Watch**: O(1) per event after debounce

## Extension Points

The architecture supports extension via:

1. **Custom Functions**: Add to `engine/expr/functions.lua`
2. **Custom Methods**: Add to `engine/expr/methods.lua`
3. **New Data Types**: Extend `engine/expr/types.lua` and `SerializedValue` types
4. **Alternative Renderers**: Implement new modules similar to `inline/` or `dashboard/`
5. **Pre/Post Query Hooks**: Modify `engine/query_engine.lua` execute function

## Testing

The project has a comprehensive test suite using mini.test. See [Testing](testing.md) for the full guide.

Tests cover the expression engine (lexer, parser, evaluator, types, functions, methods), YAML and base parser, query engine, display and render pipeline, summaries, frontmatter editor, buffer management, and navigation. Unit tests verify pure logic; integration tests verify Neovim buffer interactions and multi-module workflows.

## Known Limitations

1. **Large Vaults**: Initial index build can take 10+ seconds for 10,000+ notes
2. **Complex Formulas**: Deep formula dependencies may cause evaluation cycles
3. **Date Parsing**: Only ISO-8601 format (`YYYY-MM-DD`) supported
4. **Link Resolution**: Assumes `.md` extension if not specified
5. **Frontmatter Schema**: No validation of frontmatter structure
6. **Concurrent Edits**: No conflict detection for simultaneous edits to same file
7. **Memory Usage**: Full vault index kept in memory (typically 1-5MB for 1000 notes)
