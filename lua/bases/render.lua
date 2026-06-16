-- Unicode table rendering for Obsidian Bases
local M = {}

local SORT_ICONS = { asc = ' ▲', desc = ' ▼' }

-- Convert a 1-indexed display column to a 0-indexed byte offset within a line.
function M.display_to_byte(line, display_col_1indexed)
    if display_col_1indexed <= 1 then
        return 0
    end
    local width = 0
    for i = 0, vim.fn.strchars(line) - 1 do
        local char = vim.fn.strcharpart(line, i, 1)
        width = width + vim.fn.strdisplaywidth(char)
        if width >= display_col_1indexed then
            return vim.fn.byteidx(line, i)
        end
    end
    return #line
end

-- Convert a 0-indexed byte offset within a line to a 1-indexed display column.
-- Follows the `nvim_win_get_cursor` convention: the returned column is the
-- position of the character under the cursor (i.e., the cursor sits *before*
-- the character at `byte_0indexed`, so the column is the display column of
-- that character). When the byte falls inside a multi-byte character, the
-- column reported is that of the character containing the byte.
function M.byte_to_display(line, byte_0indexed)
    local target = math.max(0, byte_0indexed)
    local width = 0
    for i = 0, vim.fn.strchars(line) - 1 do
        local char = vim.fn.strcharpart(line, i, 1)
        local char_byte = vim.fn.byteidx(line, i)
        local char_end = char_byte + #char
        if char_byte <= target and target < char_end then
            -- Cursor is inside this character
            return width + 1
        end
        if char_byte > target then
            -- Cursor is past this character (only possible if the previous
            -- iteration was inside an earlier char with same byte_start, but
            -- that's not possible for valid UTF-8; defensive)
            return width + 1
        end
        width = width + vim.fn.strdisplaywidth(char)
    end
    return width + 1
end

---@class HeaderCellInfo
---@field row number 1-indexed line number (2 for unicode, 1 for markdown)
---@field col_start number 1-indexed column of first char of text (inclusive)
---@field col_end number 1-indexed column one past last char of text (exclusive)
---@field property string Property name (e.g., "file.name")

---@class CellInfo
---@field row number 1-indexed line number
---@field col_start number 1-indexed column of first char of text (inclusive)
---@field col_end number 1-indexed column one past last char of text (exclusive)
---@field property string Property name (e.g., "note.Person")
---@field file_path string Path to source note
---@field editable boolean true for note.* properties
---@field display_text string Text displayed in the cell
---@field raw_value any Original SerializedValue

-- Border characters (rounded corners)
local BORDER = {
    top_left = '╭',
    top_right = '╮',
    bottom_left = '╰',
    bottom_right = '╯',
    horizontal = '─',
    vertical = '│',
    cross = '┼',
    top_mid = '┬',
    bottom_mid = '┴',
    left_mid = '├',
    right_mid = '┤',
}

---Format a timestamp as relative date ("2 days ago", "in 3 hours", etc.)
---@param timestamp_ms number Timestamp in milliseconds
---@return string Formatted relative date
local function format_relative_date(timestamp_ms)
    local now = os.time() * 1000
    local diff_ms = now - timestamp_ms
    local diff_sec = math.floor(diff_ms / 1000)
    local is_past = diff_sec >= 0

    if not is_past then
        diff_sec = -diff_sec
    end

    local value, unit
    if diff_sec < 60 then
        value, unit = diff_sec, 'second'
    elseif diff_sec < 3600 then
        value, unit = math.floor(diff_sec / 60), 'minute'
    elseif diff_sec < 86400 then
        value, unit = math.floor(diff_sec / 3600), 'hour'
    elseif diff_sec < 2592000 then
        value, unit = math.floor(diff_sec / 86400), 'day'
    elseif diff_sec < 31536000 then
        value, unit = math.floor(diff_sec / 2592000), 'month'
    else
        value, unit = math.floor(diff_sec / 31536000), 'year'
    end

    if value ~= 1 then
        unit = unit .. 's'
    end

    if is_past then
        return string.format('%d %s ago', value, unit)
    else
        return string.format('in %d %s', value, unit)
    end
end

---Format a date timestamp according to config
---@param timestamp_ms number Timestamp in milliseconds
---@param iso string|nil ISO date string (fallback)
---@return string Formatted date
local function format_date(timestamp_ms, iso)
    local bases_config = require('bases').get_config()
    if bases_config.date_format_relative then
        return format_relative_date(timestamp_ms)
    end
    local seconds = math.floor(timestamp_ms / 1000)
    return os.date(bases_config.date_format, seconds)
end

---Convert property name to display name
---@param prop string Property name like "file.name" or "note.status"
---@param labels table|nil Optional map of property names to custom labels
---@return string Display name like "Name" or "Status"
function M.display_name(prop, labels)
    -- Check for custom label from API first
    if labels and labels[prop] then
        return labels[prop]
    end
    -- Fallback: get the part after the last dot and capitalize
    local name = prop:match('%.([^%.]+)$') or prop
    return name:sub(1, 1):upper() .. name:sub(2)
end

---Extract display text from a SerializedValue
---@param val table|nil SerializedValue object
---@param keep_brackets boolean|nil Keep [[...]] brackets for links (for markdown mode)
---@return string text Display text
---@return string|nil path File path for links
function M.value_text(val, keep_brackets)
    if not val then
        return '', nil
    end

    if val.type == 'date' then
        return format_date(val.value, val.iso), nil
    elseif val.type == 'link' then
        local text = val.value or ''
        if keep_brackets then
            -- Keep the [[...]] format for render-markdown.nvim
            return text, val.path
        else
            -- Extract link text from [[...]] format
            local link_text = text:match('%[%[([^%]]+)%]%]') or text
            return link_text, val.path
        end
    elseif val.type == 'list' then
        -- Join list items
        local items = {}
        for _, item in ipairs(val.value or {}) do
            local item_text = M.value_text(item, keep_brackets)
            table.insert(items, item_text)
        end
        return table.concat(items, ', '), nil
    else
        -- Primitive values
        local v = val.value
        if v == nil then
            return '', nil
        elseif type(v) == 'boolean' then
            return v and 'Yes' or 'No', nil
        else
            return tostring(v), nil
        end
    end
end

---Get sort icon for a property if it's currently sorted
---@param property string Property name
---@param sort_state table|nil Current sort state {property: string, direction: 'asc'|'desc'}
---@return string Icon string or empty string
function M.get_sort_icon(property, sort_state)
    if not sort_state or sort_state.property ~= property then
        return ''
    end
    return SORT_ICONS[sort_state.direction] or ''
end

---Extract sortable value from a SerializedValue
---@param val table|nil SerializedValue object
---@return any Sortable value
---@return string type_name Type for mixed-type comparison
local function extract_sort_value(val)
    if not val or val.value == nil then
        return nil, 'null'
    end

    if val.type == 'date' then
        -- Sort by timestamp (numeric)
        return val.value, 'number'
    elseif val.type == 'link' then
        -- Extract display text from [[...]] format
        local text = val.value or ''
        local link_text = text:match('%[%[([^%]]+)%]%]') or text
        return link_text:lower(), 'string'
    elseif val.type == 'list' then
        -- Sort by first item
        if val.value and #val.value > 0 then
            return extract_sort_value(val.value[1])
        end
        return nil, 'null'
    else
        -- Primitive values
        local v = val.value
        if type(v) == 'number' then
            return v, 'number'
        elseif type(v) == 'boolean' then
            return v, 'boolean'
        elseif type(v) == 'string' then
            return v:lower(), 'string'
        else
            return tostring(v):lower(), 'string'
        end
    end
end

---Compare two values for sorting
---@param a any First value
---@param b any Second value
---@param direction string 'asc' or 'desc'
---@return boolean true if a should come before b
local function compare_values(a, b, direction)
    local val_a, type_a = extract_sort_value(a)
    local val_b, type_b = extract_sort_value(b)

    -- Nulls always sort to end regardless of direction
    if type_a == 'null' and type_b == 'null' then
        return false
    elseif type_a == 'null' then
        return false
    elseif type_b == 'null' then
        return true
    end

    -- Mixed types: numbers < strings < booleans
    local type_order = { number = 1, string = 2, boolean = 3 }
    if type_a ~= type_b then
        local order_a = type_order[type_a] or 4
        local order_b = type_order[type_b] or 4
        if direction == 'desc' then
            return order_a > order_b
        end
        return order_a < order_b
    end

    -- Same type comparison
    if type_a == 'boolean' then
        -- false < true in ascending, true < false in descending
        if val_a == val_b then
            return false
        end
        if direction == 'desc' then
            return val_a and not val_b
        else
            return not val_a and val_b
        end
    else
        if val_a == val_b then
            return false
        end
        if direction == 'desc' then
            return val_a > val_b
        else
            return val_a < val_b
        end
    end
end

---Sort entries by a property
---@param entries table[] Entry data
---@param property string Property to sort by
---@param direction string 'asc' or 'desc'
---@return table[] Sorted entries (new table, original unchanged)
function M.sort_entries(entries, property, direction)
    local sorted = vim.deepcopy(entries)
    table.sort(sorted, function(a, b)
        local val_a = a.values and a.values[property]
        local val_b = b.values and b.values[property]
        return compare_values(val_a, val_b, direction)
    end)
    return sorted
end

---Calculate display width of a string (accounting for multi-byte characters)
---@param str string
---@return number
local function display_width(str)
    return vim.fn.strdisplaywidth(str)
end

---Pad string to width
---@param str string
---@param width number
---@return string
local function pad(str, width)
    local current = display_width(str)
    if current >= width then
        return str
    end
    return str .. string.rep(' ', width - current)
end

---Calculate column widths from data
---@param properties string[] Property names
---@param entries table[] Entry data
---@param keep_brackets boolean|nil Keep [[...]] brackets for links
---@param sort_state table|nil Current sort state
---@param labels table|nil Custom property labels
---@return number[] Column widths
function M.calc_widths(properties, entries, keep_brackets, sort_state, labels)
    local widths = {}

    -- Start with header widths (including sort icon if applicable)
    for i, prop in ipairs(properties) do
        local header_text = M.display_name(prop, labels) .. M.get_sort_icon(prop, sort_state)
        widths[i] = display_width(header_text)
    end

    -- Expand for data widths
    for _, entry in ipairs(entries) do
        for i, prop in ipairs(properties) do
            local val = entry.values and entry.values[prop]
            local text = M.value_text(val, keep_brackets)
            local w = display_width(text)
            if w > widths[i] then
                widths[i] = w
            end
        end
    end

    -- Add padding
    for i = 1, #widths do
        widths[i] = widths[i] + 2  -- 1 space on each side
    end

    return widths
end

---Build a horizontal border line
---@param widths number[] Column widths
---@param left string Left corner character
---@param mid string Middle junction character
---@param right string Right corner character
---@return string
function M.horizontal_line(widths, left, mid, right)
    local parts = { left }
    for i, w in ipairs(widths) do
        table.insert(parts, string.rep(BORDER.horizontal, w))
        if i < #widths then
            table.insert(parts, mid)
        end
    end
    table.insert(parts, right)
    return table.concat(parts)
end

---Build a data row
---@param items string[] Cell contents
---@param widths number[] Column widths
---@return string
function M.row(items, widths)
    local parts = { BORDER.vertical }
    for i, item in ipairs(items) do
        local padded = ' ' .. pad(item, widths[i] - 2) .. ' '
        table.insert(parts, padded)
        table.insert(parts, BORDER.vertical)
    end
    return table.concat(parts)
end

-- Markdown table helpers

---Build a markdown header row
---@param items string[] Cell contents
---@param widths number[] Column widths
---@return string
function M.markdown_header(items, widths)
    local parts = { '|' }
    for i, item in ipairs(items) do
        local padded = ' ' .. pad(item, widths[i] - 2) .. ' '
        table.insert(parts, padded)
        table.insert(parts, '|')
    end
    return table.concat(parts)
end

---Build a markdown separator line
---@param widths number[] Column widths
---@return string
function M.markdown_separator(widths)
    local parts = { '|' }
    for _, w in ipairs(widths) do
        table.insert(parts, string.rep('-', w))
        table.insert(parts, '|')
    end
    return table.concat(parts)
end

---Build a markdown data row
---@param items string[] Cell contents
---@param widths number[] Column widths
---@return string
function M.markdown_row(items, widths)
    local parts = { '|' }
    for i, item in ipairs(items) do
        local padded = ' ' .. pad(item, widths[i] - 2) .. ' '
        table.insert(parts, padded)
        table.insert(parts, '|')
    end
    return table.concat(parts)
end

---Render unicode table (default mode)
---@param properties string[] Property names
---@param entries table[] Entry data
---@param sort_state table|nil Current sort state
---@param labels table|nil Custom property labels
---@param summaries table<string, SummaryEntry>|nil Summary entries
---@return string[] lines Rendered lines
---@return table[] links Link positions for navigation
---@return CellInfo[] cells All cell positions for editing
---@return HeaderCellInfo[] headers Header cell positions for sorting
---@return boolean has_summaries Whether a summary row was rendered
function M.render_unicode_table(properties, entries, sort_state, labels, summaries)
    local widths = M.calc_widths(properties, entries, false, sort_state, labels)
    local lines = {}
    local links = {}
    local cells = {}
    local header_cells = {}
    local has_summaries = summaries ~= nil and not vim.tbl_isempty(summaries)

    -- Top border
    table.insert(lines, M.horizontal_line(widths, BORDER.top_left, BORDER.top_mid, BORDER.top_right))

    -- Header row (line 2)
    local headers = {}
    local header_row = 2  -- Headers are on line 2 in unicode mode
    local col = 1  -- Start after first border character
    for i, prop in ipairs(properties) do
        local header_text = M.display_name(prop, labels) .. M.get_sort_icon(prop, sort_state)
        table.insert(headers, header_text)

        local cell_start = col + 2  -- Skip left border + left padding space
        table.insert(header_cells, {
            row = header_row,
            col_start = cell_start,
            col_end = cell_start + display_width(header_text),
            property = prop,
        })
        col = col + widths[i] + 1
    end
    table.insert(lines, M.row(headers, widths))

    -- Header separator
    table.insert(lines, M.horizontal_line(widths, BORDER.left_mid, BORDER.cross, BORDER.right_mid))

    -- Data rows (entries are pre-sorted by display.prepare)
    for _, entry in ipairs(entries) do
        local cell_texts = {}
        local row_num = #lines + 1  -- 1-indexed line number

        -- Calculate column positions for link tracking
        col = 1  -- Start after first border character

        -- Get file path from entry (entry.file.path from serialized data)
        local file_path = entry.file and entry.file.path or ''

        for i, prop in ipairs(properties) do
            local val = entry.values and entry.values[prop]
            local text, path = M.value_text(val, false)
            table.insert(cell_texts, text)

            local cell_start = col + 2  -- Skip left border + left padding space

            -- Track cell for editing
            table.insert(cells, {
                row = row_num,
                col_start = cell_start,
                col_end = cell_start + display_width(text),
                property = prop,
                file_path = file_path,
                editable = prop:match('^note%.') ~= nil,
                display_text = text,
                raw_value = val,
            })

            -- Track link position (for navigation)
            if path then
                table.insert(links, {
                    row = row_num,
                    col_start = cell_start,
                    col_end = cell_start + display_width(text),
                    path = path,
                    text = text,
                })
            end

            -- Move column position (cell width + border)
            col = col + widths[i] + 1
        end

        table.insert(lines, M.row(cell_texts, widths))
    end

    -- Bottom border
    table.insert(lines, M.horizontal_line(widths, BORDER.bottom_left, BORDER.bottom_mid, BORDER.bottom_right))

    -- Summary line (outside table)
    if has_summaries then
        local parts = {}
        for _, prop in ipairs(properties) do
            local entry = summaries[prop]
            if entry then
                local col_name = M.display_name(prop, labels)
                local val_text = M.value_text(entry.value, false)
                table.insert(parts, col_name .. ': ' .. entry.label .. ' ' .. val_text)
            end
        end
        if #parts > 0 then
            table.insert(lines, table.concat(parts, ' · '))
        end
    end

    return lines, links, cells, header_cells, has_summaries
end

---Render markdown table (for render-markdown.nvim)
---@param properties string[] Property names
---@param entries table[] Entry data
---@param sort_state table|nil Current sort state
---@param labels table|nil Custom property labels
---@param summaries table<string, SummaryEntry>|nil Summary entries
---@return string[] lines Rendered lines
---@return table[] links Link positions for navigation
---@return CellInfo[] cells All cell positions for editing
---@return HeaderCellInfo[] headers Header cell positions for sorting
---@return boolean has_summaries Whether a summary row was rendered
function M.render_markdown_table(properties, entries, sort_state, labels, summaries)
    local widths = M.calc_widths(properties, entries, true, sort_state, labels)
    local lines = {}
    local links = {}
    local cells = {}
    local header_cells = {}
    local has_summaries = summaries ~= nil and not vim.tbl_isempty(summaries)

    -- Header row (line 1 in markdown mode)
    local headers = {}
    local header_row = 1
    local col = 1  -- Start after first pipe character
    for i, prop in ipairs(properties) do
        local header_text = M.display_name(prop, labels) .. M.get_sort_icon(prop, sort_state)
        table.insert(headers, header_text)

        local cell_start = col + 2  -- Skip left pipe + left padding space
        table.insert(header_cells, {
            row = header_row,
            col_start = cell_start,
            col_end = cell_start + display_width(header_text),
            property = prop,
        })
        col = col + widths[i] + 1
    end
    table.insert(lines, M.markdown_header(headers, widths))

    -- Separator
    table.insert(lines, M.markdown_separator(widths))

    -- Data rows (entries are pre-sorted by display.prepare)
    for _, entry in ipairs(entries) do
        local cell_texts = {}
        local row_num = #lines + 1  -- 1-indexed line number

        -- Calculate column positions for link tracking
        col = 1  -- Start after first pipe character

        -- Get file path from entry (entry.file.path from serialized data)
        local file_path = entry.file and entry.file.path or ''

        for i, prop in ipairs(properties) do
            local val = entry.values and entry.values[prop]
            local text, path = M.value_text(val, true)
            table.insert(cell_texts, text)

            local cell_start = col + 2  -- Skip left pipe + left padding space

            -- Track cell for editing
            table.insert(cells, {
                row = row_num,
                col_start = cell_start,
                col_end = cell_start + display_width(text),
                property = prop,
                file_path = file_path,
                editable = prop:match('^note%.') ~= nil,
                display_text = text,
                raw_value = val,
            })

            -- Track link position (for Tab/Shift-Tab navigation)
            if path then
                table.insert(links, {
                    row = row_num,
                    col_start = cell_start,
                    col_end = cell_start + display_width(text),
                    path = path,
                    text = text,
                })
            end

            -- Move column position (cell width + pipe)
            col = col + widths[i] + 1
        end

        table.insert(lines, M.markdown_row(cell_texts, widths))
    end

    -- Summary line (outside table)
    if has_summaries then
        local parts = {}
        for _, prop in ipairs(properties) do
            local entry = summaries[prop]
            if entry then
                local col_name = M.display_name(prop, labels)
                local val_text = M.value_text(entry.value, true)
                table.insert(parts, col_name .. ': ' .. entry.label .. ' ' .. val_text)
            end
        end
        if #parts > 0 then
            table.insert(lines, table.concat(parts, ' · '))
        end
    end

    return lines, links, cells, header_cells, has_summaries
end

---Render display data to table format
---@param display_data table DisplayData from display.prepare()
---@param format string|nil "unicode" or "markdown" (default: "unicode")
---@return string[] lines Rendered lines
---@return table[] links Link positions
---@return CellInfo[] cells Cell positions
---@return HeaderCellInfo[] headers Header positions
---@return boolean has_summaries Whether a summary row was rendered
function M.render_table(display_data, format)
    format = format or "unicode"
    local labels = display_data.property_labels
    local summaries = display_data.summaries
    if format == "markdown" then
        return M.render_markdown_table(display_data.properties, display_data.entries, display_data.sort_state, labels, summaries)
    else
        return M.render_unicode_table(display_data.properties, display_data.entries, display_data.sort_state, labels, summaries)
    end
end

---Render base data to buffer
---@param buf number Buffer handle
---@param data table API response data
---@param use_markdown boolean|nil Use markdown tables (default: false)
function M.render(buf, data, use_markdown)
    local buffer = require('bases.buffer')
    local display = require('bases.display')

    -- Prepare display data with sort and limit applied
    -- display.prepare will use user sort (bases_sort) if set, otherwise falls back to data.defaultSort
    local view_state = { sort = vim.b[buf].bases_sort }
    local display_data = display.prepare(data, view_state)

    -- Validate
    local valid, err = display.validate(display_data)
    if not valid then
        buffer.set_content(buf, { '', '  ' .. err })
        return
    end

    -- Render table
    local format = use_markdown and "markdown" or "unicode"
    local lines, links, cells, headers, has_summaries = M.render_table(display_data, format)

    -- Store links for navigation
    vim.b[buf].bases_links = links

    -- Store cells for editing
    vim.b[buf].bases_cells = cells

    -- Store headers for sorting
    vim.b[buf].bases_headers = headers

    -- Store full API response for reference
    vim.b[buf].bases_data = data

    -- Set content with appropriate filetype
    local filetype = use_markdown and 'markdown' or 'obsidian_base'
    buffer.set_content(buf, lines, filetype)

    -- Apply manual highlights only for unicode mode
    -- (render-markdown.nvim handles highlighting in markdown mode)
    if not use_markdown then
        M.highlight_links(buf, links)
        M.highlight_sorted_header(buf, headers, display_data.sort_state)
        if has_summaries then
            M.highlight_summary_row(buf, lines)
        end
    end
end

---Apply highlights to links
---@param buf number Buffer handle
---@param links table[] Link positions
function M.highlight_links(buf, links)
    local ns = vim.api.nvim_create_namespace('bases_links')
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    for _, link in ipairs(links) do
        local row0 = link.row - 1
        local line = vim.api.nvim_buf_get_lines(buf, row0, row0 + 1, false)[1] or ''
        local col_start = M.display_to_byte(line, link.col_start)
        local col_end = M.display_to_byte(line, link.col_end)
        vim.api.nvim_buf_add_highlight(buf, ns, 'BasesLink', row0, col_start, col_end)
    end
end

---Apply highlight to summary line (last line, outside table)
---@param buf number Buffer handle
---@param lines string[] All rendered lines
function M.highlight_summary_row(buf, lines)
    local ns = vim.api.nvim_create_namespace('bases_summary')
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    -- Summary line is the last line (after bottom border)
    local summary_line = #lines
    if summary_line >= 1 then
        vim.api.nvim_buf_add_highlight(buf, ns, 'BasesSummary', summary_line - 1, 0, -1)
    end
end

---Apply highlight to sorted column header
---@param buf number Buffer handle
---@param headers HeaderCellInfo[] Header positions
---@param sort_state table|nil Current sort state
function M.highlight_sorted_header(buf, headers, sort_state)
    local ns = vim.api.nvim_create_namespace('bases_sorted_header')
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

    if not sort_state or not sort_state.property then
        return
    end

    for _, header in ipairs(headers) do
        if header.property == sort_state.property then
            local row0 = header.row - 1
            local line = vim.api.nvim_buf_get_lines(buf, row0, row0 + 1, false)[1] or ''
            local col_start = M.display_to_byte(line, header.col_start)
            local col_end = M.display_to_byte(line, header.col_end)
            vim.api.nvim_buf_add_highlight(buf, ns, 'BasesSortedHeader', row0, col_start, col_end)
            break
        end
    end
end

return M
