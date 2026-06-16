-- Dashboard module for bases.nvim
-- Displays multiple base files in a single view
local M = {}

---Get or create a buffer for a dashboard
---@param name string Dashboard name
---@return number bufnr
local function get_or_create_buffer(name)
    local buf_name = 'dashboard://' .. name

    -- Check if buffer already exists
    local existing = vim.fn.bufnr(buf_name)
    if existing ~= -1 then
        return existing
    end

    -- Create new buffer
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, buf_name)

    -- Set buffer options
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false
    vim.bo[buf].modifiable = false
    -- Note: filetype is set in render_to_buffer based on render_markdown config

    return buf
end

---Set buffer content (handles modifiable state)
---@param buf number Buffer handle
---@param lines string[] Lines to set
local function set_lines(buf, lines)
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
end

---Show loading state in buffer
---@param buf number Buffer handle
---@param name string Dashboard name being loaded
local function set_loading(buf, name)
    set_lines(buf, { '', '  Loading dashboard: ' .. name .. '...' })
end

---Show error state in buffer
---@param buf number Buffer handle
---@param message string Error message
local function set_error(buf, message)
    local lines = {
        '',
        '  Error loading dashboard:',
        '',
        '  ' .. message,
        '',
        '  Press R to retry',
    }
    set_lines(buf, lines)
end

---Setup keymaps for dashboard buffer
---@param buf number Buffer handle
local function setup_keymaps(buf)
    local nav = require('bases.dashboard.navigation')
    local bases = require('bases')
    local config = bases.get_config()

    local keymaps = config.keymaps or {}
    local map_opts = { buffer = buf, silent = true }

    -- Follow link under cursor / sort column
    if keymaps.follow_link then
        vim.keymap.set('n', keymaps.follow_link, function()
            nav.follow_link(buf)
        end, map_opts)
    end

    -- Navigate between links
    if keymaps.next_link then
        vim.keymap.set('n', keymaps.next_link, function()
            nav.next_link(buf)
        end, map_opts)
    end

    if keymaps.prev_link then
        vim.keymap.set('n', keymaps.prev_link, function()
            nav.prev_link(buf)
        end, map_opts)
    end

    -- Refresh
    if keymaps.refresh then
        vim.keymap.set('n', keymaps.refresh, function()
            M.refresh(buf)
        end, map_opts)
    end

    -- Edit cell under cursor
    if keymaps.edit_cell then
        vim.keymap.set('n', keymaps.edit_cell, function()
            M.edit_cell(buf)
        end, map_opts)
    end

    -- Section navigation (always enabled for dashboards)
    vim.keymap.set('n', ']]', function()
        nav.next_section(buf)
    end, vim.tbl_extend('force', map_opts, { desc = 'Next section' }))

    vim.keymap.set('n', '[[', function()
        nav.prev_section(buf)
    end, vim.tbl_extend('force', map_opts, { desc = 'Previous section' }))
end

---Fetch all sections in parallel (deduplicating requests for same base)
---@param config table Plugin configuration
---@param dashboard_config table Dashboard configuration
---@param callback fun(err: string|nil, section_data: table[]|nil)
local function fetch_sections(config, dashboard_config, callback)
    local engine = require('bases.engine')
    local render = require('bases.render')
    local sections = dashboard_config.sections or {}

    if #sections == 0 then
        callback('No sections configured', nil)
        return
    end

    -- Group sections by base name to deduplicate API calls
    local bases_to_fetch = {}  -- base_name -> {section_indices}
    for i, section in ipairs(sections) do
        local base = section.base
        if not bases_to_fetch[base] then
            bases_to_fetch[base] = {}
        end
        table.insert(bases_to_fetch[base], i)
    end

    -- Count unique bases to fetch
    local unique_bases = {}
    for base, _ in pairs(bases_to_fetch) do
        table.insert(unique_bases, base)
    end

    local results = {}
    local api_data_cache = {}  -- base_name -> api_data
    local completed = 0
    local has_error = false
    local total_to_fetch = #unique_bases

    -- Determine if we should use markdown rendering
    local use_markdown = config.render_markdown or false

    -- Helper to render a section from cached API data
    local function render_section(section_index, data)
        local display = require('bases.display')
        local display_data = display.prepare(data, {})
        local valid, err = display.validate(display_data)

        local lines, links, cells, headers, has_summaries
        if valid then
            local format = use_markdown and "markdown" or "unicode"
            lines, links, cells, headers, has_summaries = render.render_table(display_data, format)
        else
            lines = { '  ' .. err }
            links = {}
            cells = {}
            headers = {}
            has_summaries = false
        end

        return {
            lines = lines,
            links = links,
            cells = cells,
            headers = headers,
            has_summaries = has_summaries or false,
            base_name = sections[section_index].base,
            api_data = data,
        }
    end

    -- Fetch each unique base once
    for _, base in ipairs(unique_bases) do
        -- Resolve base file path
        local base_file
        local vault = engine.get_vault_path()
        if vault then
            base_file = vault .. '/' .. base .. '.base'
        else
            has_error = true
            callback('Engine not initialized', nil)
            return
        end

        engine.query(base_file, 0, function(err, data)
            if has_error then
                return
            end

            if err then
                has_error = true
                callback('Error loading ' .. base .. ': ' .. err, nil)
                return
            end

            -- Cache the API data
            api_data_cache[base] = data

            -- Render for all sections using this base
            for _, section_index in ipairs(bases_to_fetch[base]) do
                results[section_index] = render_section(section_index, data)
            end

            completed = completed + 1
            if completed == total_to_fetch then
                callback(nil, results)
            end
        end)
    end
end

---Render fetched section data to buffer
---@param buf number Buffer handle
---@param dashboard_config table Dashboard configuration
---@param section_data table[] Fetched section data
---@param use_markdown boolean Whether to use markdown rendering
local function render_to_buffer(buf, dashboard_config, section_data, use_markdown)
    local dashboard_render = require('bases.dashboard.render')
    local base_render = require('bases.render')
    local display = require('bases.display')

    -- Check for section-specific sort states
    local sort_states = vim.b[buf].bases_dashboard_sort_states or {}

    -- Re-render sections with sort states using display.prepare
    for i, data in ipairs(section_data) do
        -- Buffer variables can turn empty tables into vim.NIL (userdata), so check type
        local sort_state = sort_states[i]
        if type(sort_state) == 'table' and sort_state.property and data.api_data then
            local display_data = display.prepare(data.api_data, { sort = sort_state })
            local valid = display.validate(display_data)
            if valid then
                local format = use_markdown and "markdown" or "unicode"
                local lines, links, cells, headers, has_summaries = base_render.render_table(display_data, format)
                data.lines = lines
                data.links = links
                data.cells = cells
                data.headers = headers
                data.has_summaries = has_summaries or false
            end
        end
    end

    -- Compose the dashboard
    local result = dashboard_render.render_dashboard(dashboard_config, section_data, use_markdown)

    -- Set buffer content
    set_lines(buf, result.lines)

    -- Set appropriate filetype
    local filetype = use_markdown and 'markdown' or 'obsidian_dashboard'
    vim.bo[buf].filetype = filetype

    -- Store navigation data
    vim.b[buf].bases_links = result.links
    vim.b[buf].bases_cells = result.cells
    vim.b[buf].bases_headers = result.headers
    vim.b[buf].bases_dashboard_section_starts = result.section_starts
    vim.b[buf].bases_dashboard_section_data = section_data
    vim.b[buf].bases_dashboard_use_markdown = use_markdown

    -- Apply highlights
    dashboard_render.apply_highlights(buf, dashboard_config, result.section_starts)

    -- Apply link highlights only in unicode mode
    -- (render-markdown.nvim handles highlighting in markdown mode)
    if not use_markdown then
        base_render.highlight_links(buf, result.links)
    end

    -- Apply sorted header highlights for each section
    for i, data in ipairs(section_data) do
        local sort_state = sort_states[i]
        if type(sort_state) == 'table' and sort_state.property then
            -- Find headers for this section and highlight the sorted one
            for _, header in ipairs(result.headers) do
                if header.section_index == i and header.property == sort_state.property then
                    local ns = vim.api.nvim_create_namespace('bases_sorted_header')
                    local row0 = header.row - 1
                    local line = vim.api.nvim_buf_get_lines(buf, row0, row0 + 1, false)[1] or ''
                    local col_start = base_render.display_to_byte(line, header.col_start)
                    local col_end = base_render.display_to_byte(line, header.col_end)
                    vim.api.nvim_buf_add_highlight(buf, ns, 'BasesSortedHeader', row0, col_start, col_end)
                end
            end
        end
    end
end

---Open a dashboard by name
---@param name string Dashboard name from config
function M.open(name)
    local bases = require('bases')
    local plugin_config = bases.get_config()

    local dashboards = plugin_config.dashboards or {}
    local dashboard_config = dashboards[name]

    if not dashboard_config then
        vim.notify('Dashboard not found: ' .. name, vim.log.levels.ERROR)
        return
    end

    local buf = get_or_create_buffer(name)

    -- Store dashboard name and config
    vim.b[buf].bases_dashboard_name = name
    vim.b[buf].bases_dashboard_config = dashboard_config

    -- Switch to the buffer
    vim.api.nvim_set_current_buf(buf)

    -- Setup keymaps
    setup_keymaps(buf)

    -- Show loading state
    set_loading(buf, name)

    -- Defer data fetch until engine is ready
    local engine = require('bases.engine')
    engine.on_ready(function(init_err)
        if init_err then
            set_error(buf, init_err)
            return
        end

        local use_markdown = plugin_config.render_markdown or false
        fetch_sections(plugin_config, dashboard_config, function(err, section_data)
            if err then
                set_error(buf, err)
                return
            end

            render_to_buffer(buf, dashboard_config, section_data, use_markdown)
        end)
    end)
end

---Refresh the current dashboard buffer
---@param buf number|nil Buffer handle (default: current buffer)
---@param opts table|nil Options: { silent = boolean }
function M.refresh(buf, opts)
    buf = buf or vim.api.nvim_get_current_buf()
    opts = opts or {}

    local name = vim.b[buf].bases_dashboard_name
    local dashboard_config = vim.b[buf].bases_dashboard_config

    if not name or not dashboard_config then
        if not opts.silent then
            vim.notify('Not a dashboard buffer', vim.log.levels.WARN)
        end
        return
    end

    local bases = require('bases')
    local config = bases.get_config()

    if not opts.silent then
        vim.notify('Refreshing dashboard...', vim.log.levels.INFO)
    end

    -- Fetch all sections
    local use_markdown = config.render_markdown or false
    fetch_sections(config, dashboard_config, function(err, section_data)
        if err then
            set_error(buf, err)
            return
        end

        render_to_buffer(buf, dashboard_config, section_data, use_markdown)
        if not opts.silent then
            vim.notify('Dashboard refreshed', vim.log.levels.INFO)
        end
    end)
end

---Re-render dashboard with cached data (no API fetch)
---@param buf number Buffer handle
function M.refresh_display(buf)
    local dashboard_config = vim.b[buf].bases_dashboard_config
    local section_data = vim.b[buf].bases_dashboard_section_data
    if not dashboard_config or not section_data then
        return
    end
    local use_markdown = vim.b[buf].bases_dashboard_use_markdown or false
    render_to_buffer(buf, dashboard_config, section_data, use_markdown)
end

---Edit cell under cursor in dashboard
---@param buf number Buffer handle
function M.edit_cell(buf)
    local nav = require('bases.dashboard.navigation')
    local cell = nav.get_cell_at_cursor(buf)

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

    -- Get the section index and base name
    local section_index = cell.section_index
    if not section_index then
        vim.notify('Cannot determine section for edit', vim.log.levels.ERROR)
        return
    end

    local dashboard_config = vim.b[buf].bases_dashboard_config
    if not dashboard_config or not dashboard_config.sections[section_index] then
        vim.notify('Cannot find section configuration', vim.log.levels.ERROR)
        return
    end

    -- Use the edit module's create_edit_window but with custom submit

    -- Get raw value for editing
    local current_value = ''
    local raw = cell.raw_value
    if raw then
        if raw.type == 'null' then
            current_value = ''
        elseif raw.type == 'link' then
            local text = raw.value or ''
            current_value = text:match('%[%[([^%]]+)%]%]') or text
        elseif raw.type == 'primitive' then
            local v = raw.value
            if v ~= nil then
                if type(v) == 'boolean' then
                    current_value = v and 'true' or 'false'
                else
                    current_value = tostring(v)
                end
            end
        elseif raw.type == 'list' then
            local items = {}
            for _, item in ipairs(raw.value or {}) do
                if item.type == 'primitive' then
                    table.insert(items, tostring(item.value))
                elseif item.type == 'link' then
                    local text = item.value or ''
                    table.insert(items, text:match('%[%[([^%]]+)%]%]') or text)
                end
            end
            current_value = table.concat(items, ', ')
        else
            current_value = cell.display_text or ''
        end
    end

    local prop_name = cell.property:match('%.([^%.]+)$') or cell.property

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

        -- Convert empty string to nil for deletion
        local value = new_value
        if value == '' then
            value = nil
        end

        -- Resolve absolute file path
        local engine = require('bases.engine')
        local frontmatter_editor = require('bases.engine.frontmatter_editor')
        local vault = engine.get_vault_path()
        if not vault then
            vim.notify('Edit failed: engine not initialized', vim.log.levels.ERROR)
            return
        end
        local abs_path = vault .. '/' .. cell.file_path

        -- Extract bare field name
        local field_name = cell.property:match('%.([^%.]+)$') or cell.property

        -- Update frontmatter directly
        local success, err = frontmatter_editor.update_field(abs_path, field_name, value)
        if not success then
            vim.notify('Edit failed: ' .. (err or 'Unknown error'), vim.log.levels.ERROR)
            return
        end

        vim.notify('Updated ' .. prop_name, vim.log.levels.INFO)

        -- Re-index the modified file
        engine.update_file(cell.file_path, function(index_err)
            if index_err then
                vim.notify('Warning: re-index failed: ' .. index_err, vim.log.levels.WARN)
            end
            M.refresh(buf)
        end)
    end

    -- Cancel handler
    local function cancel()
        close_window()
    end

    -- Keymaps
    local opts = { buffer = edit_buf, silent = true, nowait = true }

    vim.keymap.set('n', '<CR>', save, opts)
    vim.keymap.set('i', '<CR>', function()
        vim.cmd('stopinsert')
        save()
    end, opts)

    vim.keymap.set('n', '<Esc>', cancel, opts)
    vim.keymap.set('n', 'q', cancel, opts)
    vim.keymap.set('i', '<Esc>', function()
        vim.cmd('stopinsert')
        cancel()
    end, opts)

    -- Start in insert mode
    vim.cmd('startinsert!')
end

---List available dashboard names
---@return string[] Dashboard names
function M.list_dashboards()
    local bases = require('bases')
    local config = bases.get_config()
    local dashboards = config.dashboards or {}

    local names = {}
    for name, _ in pairs(dashboards) do
        table.insert(names, name)
    end
    table.sort(names)

    return names
end

return M
