-- Cell editing for Obsidian Bases
local M = {}

---Get cell at cursor position
---@param buf number Buffer handle
---@return table|nil CellInfo if cursor is on a cell
function M.get_cell_at_cursor(buf)
    local cells = vim.b[buf].bases_cells
    if not cells or #cells == 0 then
        return nil
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]  -- 1-indexed
    local col = cursor[2] + 1  -- Convert to 1-indexed

    for _, cell in ipairs(cells) do
        if cell.row == row and col >= cell.col_start and col < cell.col_end then
            return cell
        end
    end

    return nil
end

---Get the raw value to edit from a cell
---@param cell table CellInfo
---@return string Text value to edit
local function get_edit_value(cell)
    local raw = cell.raw_value
    if not raw then
        return ''
    end

    if raw.type == 'null' then
        return ''
    elseif raw.type == 'link' then
        -- Return the full bracketed link text so users can edit the
        -- full wikilink syntax (including [[...]]).
        return raw.value or ''
    elseif raw.type == 'primitive' then
        local v = raw.value
        if v == nil then
            return ''
        elseif type(v) == 'boolean' then
            return v and 'true' or 'false'
        else
            return tostring(v)
        end
    elseif raw.type == 'list' then
        -- For lists, join with commas. Preserve [[...]] on link items
        -- so users see and can edit the full wikilink syntax.
        local items = {}
        for _, item in ipairs(raw.value or {}) do
            if item.type == 'primitive' then
                table.insert(items, tostring(item.value))
            elseif item.type == 'link' then
                table.insert(items, item.value or '')
            end
        end
        return table.concat(items, ', ')
    end

    return cell.display_text or ''
end

---Get property display name
---@param property string Property name like "note.Person"
---@return string Display name like "Person"
local function property_display_name(property)
    return property:match('%.([^%.]+)$') or property
end

---Create floating window for editing
---@param cell table CellInfo
---@param on_save fun(new_value: string) Callback when user saves
---@param on_cancel fun() Callback when user cancels
---@return number win Window handle
---@return number edit_buf Buffer handle
local function create_edit_window(cell, on_save, on_cancel)
    local current_value = get_edit_value(cell)
    local prop_name = property_display_name(cell.property)

    -- Calculate window size
    local width = math.max(30, #current_value + 4)
    local height = 1

    -- Create buffer
    local edit_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { current_value })

    -- Window position (centered)
    local ui = vim.api.nvim_list_uis()[1]
    local row = math.floor((ui.height - height) / 2) - 1
    local col = math.floor((ui.width - width) / 2)

    -- Create floating window
    local win = vim.api.nvim_open_win(edit_buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = row,
        col = col,
        style = 'minimal',
        border = 'rounded',
        title = ' Edit: ' .. prop_name .. ' ',
        title_pos = 'center',
    })

    -- Buffer options
    vim.bo[edit_buf].buftype = 'nofile'
    vim.bo[edit_buf].bufhidden = 'wipe'
    vim.bo[edit_buf].modifiable = true

    -- Window options
    vim.wo[win].cursorline = false
    vim.wo[win].number = false
    vim.wo[win].relativenumber = false

    -- Position cursor at end of text
    vim.api.nvim_win_set_cursor(win, { 1, #current_value })

    -- Close window helper
    local function close_window()
        if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
        end
    end

    -- Save handler
    local function save()
        local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
        local new_value = lines[1] or ''
        close_window()
        on_save(new_value)
    end

    -- Cancel handler
    local function cancel()
        close_window()
        on_cancel()
    end

    -- Keymaps
    local opts = { buffer = edit_buf, silent = true, nowait = true }

    -- Save on Enter
    vim.keymap.set('n', '<CR>', save, opts)
    vim.keymap.set('i', '<CR>', function()
        vim.cmd('stopinsert')
        save()
    end, opts)

    -- Cancel on Escape or q
    vim.keymap.set('n', '<Esc>', cancel, opts)
    vim.keymap.set('n', 'q', cancel, opts)
    vim.keymap.set('i', '<Esc>', function()
        vim.cmd('stopinsert')
        cancel()
    end, opts)

    -- Start in insert mode
    vim.cmd('startinsert!')

    return win, edit_buf
end

---Submit edit via direct frontmatter modification
---@param buf number Original buffer handle
---@param cell table CellInfo
---@param new_value string New value (empty string to delete)
---@param callback fun(err: string|nil) Callback with error or nil on success
function M.submit_edit(buf, cell, new_value, callback)
    local engine = require('bases.engine')
    local frontmatter_editor = require('bases.engine.frontmatter_editor')

    -- Get base name from buffer
    local base_path = vim.b[buf].bases_path
    if not base_path then
        callback('Not a bases buffer')
        return
    end

    -- Resolve absolute file path
    local vault = engine.get_vault_path()
    if not vault then
        callback('Engine not initialized')
        return
    end
    local abs_path = vault .. '/' .. cell.file_path

    -- Extract bare field name from qualified property name
    local field_name = cell.property:match('%.([^%.]+)$') or cell.property

    -- Convert empty string to nil for deletion
    local value = new_value
    if value == '' then
        value = nil
    end

    -- Update frontmatter directly
    local success, err = frontmatter_editor.update_field(abs_path, field_name, value)
    if not success then
        callback(err or 'Failed to update field')
        return
    end

    -- Re-index the modified file
    engine.update_file(cell.file_path, function(index_err)
        if index_err then
            -- Edit succeeded but re-index failed; still report success
            vim.notify('Warning: re-index failed: ' .. index_err, vim.log.levels.WARN)
        end
        callback(nil)
    end)
end

---Main edit function - edit cell at cursor
---@param buf number Buffer handle
function M.edit_cell(buf)
    local cell = M.get_cell_at_cursor(buf)

    if not cell then
        vim.notify('No cell under cursor', vim.log.levels.WARN)
        return
    end

    if not cell.editable then
        local prop_type = cell.property:match('^([^%.]+)%.') or 'unknown'
        vim.notify(
            string.format('%s properties are read-only', prop_type),
            vim.log.levels.WARN
        )
        return
    end

    if not cell.file_path or cell.file_path == '' then
        vim.notify('Cannot edit: file path unknown', vim.log.levels.ERROR)
        return
    end

    -- Open edit window
    create_edit_window(cell,
        -- on_save
        function(new_value)
            M.submit_edit(buf, cell, new_value, function(err)
                if err then
                    vim.notify('Edit failed: ' .. err, vim.log.levels.ERROR)
                else
                    vim.notify('Updated ' .. property_display_name(cell.property), vim.log.levels.INFO)
                    -- Refresh buffer
                    local bases = require('bases')
                    bases.refresh(buf)
                end
            end)
        end,
        -- on_cancel
        function()
            -- Nothing to do
        end
    )
end

return M
