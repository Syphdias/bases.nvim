-- Detection of ![[*.base]] embeds and ```base code blocks in markdown files
local M = {}

---Pattern to match ![[name.base]] embeds, with optional `#<view-name>` suffix.
---Requires the base portion to end in `.base`; the view portion (if any) is
---captured together as a second capture.
---
---Captures:
---   1: the base portion, ending in `.base` (e.g. "Content.base")
---   2: the view portion, including the leading `#` (e.g. "#Author"), or "" if absent
---
---Examples that match:
---   ![[Content.base]]
---   ![[Content.base#Author]]
---   ![[subdir/Content.base#Active Projects]]
---   ![[foo.bar.base#View With Spaces]]
---
---Examples that do NOT match (rejected by the regex):
---   ![[#View]]           (no base name)
---   ![[Content.md]]      (not a .base file)
---   ![[]]                (empty)
---   ![[Content#View]]    (no .base extension)
local EMBED_PATTERN = '^%s*!%[%[([^[%]]+%.base)(#?[^%]]*)%]%]%s*$'

---Patterns to match ```base fenced code blocks
local CODEBLOCK_OPEN_PATTERN = '^%s*```base%s*$'
local CODEBLOCK_CLOSE_PATTERN = '^%s*```%s*$'

---Scan a buffer for all ![[*.base]] embed patterns
---@param buf number Buffer handle
---@return table[] List of embed info {type='file', source='name.base[#View]', line_start, line_end, view=string|nil}
function M.scan_buffer(buf)
    local embeds = {}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for i, line in ipairs(lines) do
        local base_part, view_part = line:match(EMBED_PATTERN)
        if base_part then
            -- view_part either is empty (no `#`) or starts with `#`
            local view_name = nil
            if view_part and #view_part > 0 then
                -- Strip the leading `#` to get the view name itself
                view_name = view_part:sub(2)
                if view_name == '' then
                    -- `![[Content.base#]]` is "no view", not "empty view"
                    view_name = nil
                    view_part = nil
                end
            end

            table.insert(embeds, {
                type = 'file',
                -- Reconstruct the source string (base + optional view)
                source = base_part .. (view_part or ''),
                line_start = i,  -- 1-indexed
                line_end = i,    -- Single line embed
                view = view_name,
            })
        end
    end

    return embeds
end

---Scan a buffer for all ```base fenced code blocks
---@param buf number Buffer handle
---@return table[] List of embed info {type='codeblock', source=yaml_string, line_start, line_end, content_start, content_end}
function M.scan_codeblocks(buf)
    local embeds = {}
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local i = 1

    while i <= #lines do
        if lines[i]:match(CODEBLOCK_OPEN_PATTERN) then
            local open_line = i
            local j = i + 1
            local found_close = false

            while j <= #lines do
                if lines[j]:match(CODEBLOCK_CLOSE_PATTERN) then
                    -- Extract YAML content between fences
                    local content_lines = {}
                    for k = open_line + 1, j - 1 do
                        table.insert(content_lines, lines[k])
                    end
                    local yaml_string = table.concat(content_lines, '\n')

                    table.insert(embeds, {
                        type = 'codeblock',
                        source = yaml_string,
                        line_start = open_line,     -- 1-indexed
                        line_end = j,               -- 1-indexed
                        content_start = open_line + 1,  -- 1-indexed
                        content_end = j - 1,            -- 1-indexed
                    })

                    i = j + 1
                    found_close = true
                    break
                end
                j = j + 1
            end

            -- Skip unterminated fences
            if not found_close then
                i = i + 1
            end
        else
            i = i + 1
        end
    end

    return embeds
end

---Scan a buffer for all embeds (file embeds + code blocks), sorted by line_start
---@param buf number Buffer handle
---@return table[] Merged list of embeds sorted by line_start
function M.scan_all(buf)
    local file_embeds = M.scan_buffer(buf)
    local codeblock_embeds = M.scan_codeblocks(buf)

    -- Merge both lists
    local all = {}
    for _, e in ipairs(file_embeds) do
        table.insert(all, e)
    end
    for _, e in ipairs(codeblock_embeds) do
        table.insert(all, e)
    end

    -- Sort by line_start
    table.sort(all, function(a, b)
        return a.line_start < b.line_start
    end)

    return all
end

---Extract base name from a single source token (the part captured inside
---`![[...]]`). Strips the trailing `.base` extension AND any `#view` suffix.
---This is a thin back-compat wrapper; prefer `parse_source()` when you also
---need the view name.
---@param source string Source like "projects.base" or "projects.base#Author"
---@return string Base name like "projects", or the source unchanged if invalid
function M.base_name(source)
    local base_name = M.parse_source(source)
    if base_name then
        return base_name
    end
    -- For invalid sources, fall back to the legacy behavior of just stripping
    -- the trailing `.base` (or returning the input unchanged if there isn't
    -- one). This keeps the old function useful as a general "strip suffix" helper.
    return source:gsub('%.base$', '')
end

---Parse an embed source into its base name and optional view-name suffix.
---
---The source is the literal string captured from inside `![[...]]` by
---`scan_buffer()`, e.g. `"Content.base"` or `"Content.base#Author"`.
---
---A view name is the substring after the **first** `#`. This matches
---Obsidian's wikilink anchor syntax and is the most natural reading. An
---empty view (`"Content.base#"`) is treated as no view at all.
---
---The function is strict about the base portion ending in `.base`. Sources
---whose base portion doesn't end in `.base` (e.g. `"Content.md"`, `"#view"`,
---`"Content"`) are rejected as invalid, returning `(nil, nil)`.
---
---@param source string Source like "Content.base" or "Content.base#Author"
---@return string|nil base_name Base name (with `.base` stripped) or nil if invalid
---@return string|nil view_name View name (without leading `#`) or nil if absent
function M.parse_source(source)
    if type(source) ~= 'string' or source == '' then
        return nil, nil
    end

    -- Split on the FIRST `#`. A second `#` is treated as part of the view
    -- name (defensive — Obsidian view names don't contain `#` in practice).
    local first_hash = source:find('#', 1, true)

    local base_part, view_part
    if first_hash then
        base_part = source:sub(1, first_hash - 1)
        view_part = source:sub(first_hash + 1)
    else
        base_part = source
        view_part = nil
    end

    -- Reject sources whose base portion doesn't end in `.base`. This guards
    -- against things like "Content.md", "Content" or "#view" being treated
    -- as a valid base source.
    if base_part == '' or not base_part:match('%.base$') then
        return nil, nil
    end

    -- Strip the trailing `.base` from the base portion only
    local base_name = base_part:gsub('%.base$', '')

    -- An empty view (e.g. source = "Content.base#") is treated as no view.
    -- Leading/trailing whitespace in the view name is trimmed so a stray
    -- space (e.g. `![[Content.base# Author]]`) doesn't cause a spurious
    -- "View 'Author' not found" error.
    local view_name = nil
    if view_part and #view_part > 0 then
        view_name = view_part:match('^%s*(.-)%s*$')
    end

    return base_name, view_name
end

return M
