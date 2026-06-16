-- Dashboard navigation - section jumping and merged link/cell navigation
local M = {}

---Get the current cursor position as a 1-indexed (row, display_col) pair.
---@return number row 1-indexed line number
---@return number col 1-indexed display column
local function get_cursor_display_pos()
    local render = require('bases.render')
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] -- 1-indexed
    local line = vim.api.nvim_get_current_line()
    local col = render.byte_to_display(line, cursor[2])
    return row, col
end

---Get section starts from buffer
---@param buf number Buffer handle
---@return number[]|nil Section start lines (1-indexed)
local function get_section_starts(buf)
    return vim.b[buf].bases_dashboard_section_starts
end

---Get current section index based on cursor position
---@param buf number Buffer handle
---@return number|nil Current section index (1-indexed)
function M.get_current_section(buf)
    local section_starts = get_section_starts(buf)
    if not section_starts or #section_starts == 0 then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1] -- 1-indexed

    -- Find which section contains the cursor
    local current_section = 1
    for i, start_line in ipairs(section_starts) do
        if row >= start_line then
            current_section = i
        else
            break
        end
    end

    return current_section
end

---Jump to next section
---@param buf number Buffer handle
function M.next_section(buf)
    local section_starts = get_section_starts(buf)
    if not section_starts or #section_starts == 0 then
        vim.notify('No sections in this dashboard', vim.log.levels.INFO)
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]

    -- Find next section
    for _, start_line in ipairs(section_starts) do
        if start_line > row then
            vim.api.nvim_win_set_cursor(0, { start_line, 0 })
            return
        end
    end

    -- Wrap to first section
    vim.api.nvim_win_set_cursor(0, { section_starts[1], 0 })
end

---Jump to previous section
---@param buf number Buffer handle
function M.prev_section(buf)
    local section_starts = get_section_starts(buf)
    if not section_starts or #section_starts == 0 then
        vim.notify('No sections in this dashboard', vim.log.levels.INFO)
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]

    -- Find previous section
    for i = #section_starts, 1, -1 do
        if section_starts[i] < row then
            vim.api.nvim_win_set_cursor(0, { section_starts[i], 0 })
            return
        end
    end

    -- Wrap to last section
    vim.api.nvim_win_set_cursor(0, { section_starts[#section_starts], 0 })
end

---Get link at cursor position (merged across all sections)
---@param buf number Buffer handle
---@return table|nil Link data if cursor is on a link
function M.get_link_at_cursor(buf)
    local links = vim.b[buf].bases_links
    if not links or #links == 0 then
        return nil
    end

    local row, col = get_cursor_display_pos()

    for _, link in ipairs(links) do
        if link.row == row and col >= link.col_start and col < link.col_end then
            return link
        end
    end

    return nil
end

---Get cell at cursor position (merged across all sections)
---@param buf number Buffer handle
---@return table|nil Cell data if cursor is on a cell
function M.get_cell_at_cursor(buf)
    local cells = vim.b[buf].bases_cells
    if not cells or #cells == 0 then
        return nil
    end

    local row, col = get_cursor_display_pos()

    for _, cell in ipairs(cells) do
        if cell.row == row and col >= cell.col_start and col < cell.col_end then
            return cell
        end
    end

    return nil
end

---Get header cell at cursor position (merged across all sections)
---@param buf number Buffer handle
---@return table|nil Header data if cursor is on a header
function M.get_header_at_cursor(buf)
    local headers = vim.b[buf].bases_headers
    if not headers or #headers == 0 then
        return nil
    end

    local row, col = get_cursor_display_pos()

    for _, header in ipairs(headers) do
        if header.row == row and col >= header.col_start and col < header.col_end then
            return header
        end
    end

    return nil
end

---Find the next/previous link from current position (across all sections)
---@param buf number Buffer handle
---@param direction number 1 for next, -1 for previous
---@return table|nil Link data
local function find_adjacent_link(buf, direction)
    local links = vim.b[buf].bases_links
    if not links or #links == 0 then
        return nil
    end

    local row, col = get_cursor_display_pos()

    -- Sort links by position
    local sorted = vim.deepcopy(links)
    table.sort(sorted, function(a, b)
        if a.row ~= b.row then
            return a.row < b.row
        end
        return a.col_start < b.col_start
    end)

    if direction > 0 then
        -- Find next link
        for _, link in ipairs(sorted) do
            if link.row > row or (link.row == row and link.col_start > col) then
                return link
            end
        end
        -- Wrap to first link
        return sorted[1]
    else
        -- Find previous link
        for i = #sorted, 1, -1 do
            local link = sorted[i]
            if link.row < row or (link.row == row and link.col_end <= col) then
                return link
            end
        end
        -- Wrap to last link
        return sorted[#sorted]
    end
end

---Jump to next link
---@param buf number Buffer handle
function M.next_link(buf)
    local link = find_adjacent_link(buf, 1)
    if link then
        local line = vim.api.nvim_buf_get_lines(0, link.row - 1, link.row, false)[1] or ''
        local byte = require('bases.render').display_to_byte(line, link.col_start)
        vim.api.nvim_win_set_cursor(0, { link.row, byte })
    else
        vim.notify('No links in this dashboard', vim.log.levels.INFO)
    end
end

---Jump to previous link
---@param buf number Buffer handle
function M.prev_link(buf)
    local link = find_adjacent_link(buf, -1)
    if link then
        local line = vim.api.nvim_buf_get_lines(0, link.row - 1, link.row, false)[1] or ''
        local byte = require('bases.render').display_to_byte(line, link.col_start)
        vim.api.nvim_win_set_cursor(0, { link.row, byte })
    else
        vim.notify('No links in this dashboard', vim.log.levels.INFO)
    end
end

---Follow link under cursor or toggle sort on header
---@param buf number Buffer handle
function M.follow_link(buf)
    -- Check header first
    local header = M.get_header_at_cursor(buf)
    if header then
        M.toggle_sort(buf, header)
        return
    end

    local link = M.get_link_at_cursor(buf)
    if not link then
        vim.notify('No link under cursor', vim.log.levels.WARN)
        return
    end

    local engine = require('bases.engine')
    local vault_path = engine.get_vault_path()
    if not vault_path then
        vim.notify('vault_path not configured', vim.log.levels.ERROR)
        return
    end

    local full_path = vault_path .. '/' .. link.path

    -- Add .md extension if not present
    if not full_path:match('%.md$') then
        full_path = full_path .. '.md'
    end

    if vim.fn.filereadable(full_path) == 1 then
        vim.cmd('edit ' .. vim.fn.fnameescape(full_path))
    else
        vim.notify('Could not resolve: ' .. link.path, vim.log.levels.WARN)
    end
end

---Toggle sort state for a header (section-specific sorting)
---@param buf number Buffer handle
---@param header table Header info with property and section_index
function M.toggle_sort(buf, header)
    local section_index = header.section_index
    if not section_index then
        vim.notify('Cannot determine section for sorting', vim.log.levels.WARN)
        return
    end

    -- Get or create section sort states
    local sort_states = vim.b[buf].bases_dashboard_sort_states or {}

    -- Buffer variables can turn empty tables into vim.NIL (userdata), so check type
    local current = sort_states[section_index]
    if type(current) ~= 'table' then
        current = {}
    end
    local new_state

    if current.property ~= header.property then
        new_state = { property = header.property, direction = 'asc' }
    elseif current.direction == 'asc' then
        new_state = { property = header.property, direction = 'desc' }
    else
        new_state = {} -- Clear sort
    end

    sort_states[section_index] = new_state
    vim.b[buf].bases_dashboard_sort_states = sort_states

    -- Re-render the dashboard with cached data (no API fetch)
    local dashboard = require('bases.dashboard')
    dashboard.refresh_display(buf)
end

return M
