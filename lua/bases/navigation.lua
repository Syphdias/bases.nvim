-- Link navigation for Obsidian Bases
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

---Get header cell at cursor position
---@param buf number Buffer handle
---@return table|nil HeaderCellInfo if cursor is on a header
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

---Toggle sort state for a property
---@param buf number Buffer handle
---@param property string Property name to sort by
function M.toggle_sort(buf, property)
    local current = vim.b[buf].bases_sort or {}
    local new_state

    if current.property ~= property then
        new_state = { property = property, direction = 'asc' }
    elseif current.direction == 'asc' then
        new_state = { property = property, direction = 'desc' }
    else
        new_state = nil -- Clear user sort (restores default)
    end

    vim.b[buf].bases_sort = new_state

    -- Re-render with stored data
    local render = require('bases.render')
    local bases = require('bases')
    local config = bases.get_config()
    local data = vim.b[buf].bases_data
    if data then
        render.render(buf, data, config.render_markdown)
    end
end

---Get link at cursor position
---@param buf number Buffer handle
---@return table|nil Link data if cursor is on a link
local function get_link_at_cursor(buf)
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

---Follow link under cursor or toggle sort on header
---@param buf number Buffer handle
function M.follow_link(buf)
    -- Check header first
    local header = M.get_header_at_cursor(buf)
    if header then
        M.toggle_sort(buf, header.property)
        return
    end

    local link = get_link_at_cursor(buf)
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

---Find the next/previous link from current position
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
        vim.notify('No links in this base', vim.log.levels.INFO)
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
        vim.notify('No links in this base', vim.log.levels.INFO)
    end
end

return M
