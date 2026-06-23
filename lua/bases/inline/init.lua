-- Inline base rendering for markdown files
-- Renders ![[name.base]] embeds as virtual lines below the embed syntax
local M = {}

---Check if a file is within the configured vault
---@param file_path string Absolute file path
---@return boolean
local function is_in_vault(file_path)
    local vault_path = require('bases.engine').get_vault_path()
    if not vault_path then
        return false
    end

    return vim.startswith(file_path, vault_path)
end

---Setup buffer-local keymaps for inline navigation
---@param buf number Buffer handle
local function setup_keymaps(buf)
    local bases = require('bases')
    local config = bases.get_config()
    local nav = require('bases.inline.navigation')

    local keymaps = config.inline and config.inline.keymaps or {}
    local map_opts = { buffer = buf, silent = true }

    -- Follow link (falls through if not in embed)
    if keymaps.follow_link then
        vim.keymap.set('n', keymaps.follow_link, function()
            if not nav.follow_link(buf) then
                -- Fall through to default Enter behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<CR>', true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Follow link in inline base' }))
    end

    -- Next link
    if keymaps.next_link then
        vim.keymap.set('n', keymaps.next_link, function()
            if not nav.next_link(buf) then
                -- Fall through to default Tab behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<Tab>', true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Next link in inline base' }))
    end

    -- Previous link
    if keymaps.prev_link then
        vim.keymap.set('n', keymaps.prev_link, function()
            if not nav.prev_link(buf) then
                -- Fall through to default S-Tab behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes('<S-Tab>', true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Previous link in inline base' }))
    end

    -- Edit cell
    if keymaps.edit_cell then
        vim.keymap.set('n', keymaps.edit_cell, function()
            if not nav.edit_cell(buf) then
                -- Fall through to default 'c' behavior
                vim.api.nvim_feedkeys('c', 'n', false)
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Edit cell in inline base' }))
    end

    -- Edit source (for code block embeds)
    if keymaps.edit_source then
        vim.keymap.set('n', keymaps.edit_source, function()
            local embed = nav.get_embed_context(buf)
            if embed and embed.type == 'codeblock' then
                require('bases.inline.source_edit').edit_codeblock(buf, embed)
            else
                -- Fall through to default key behavior
                vim.api.nvim_feedkeys(
                    vim.api.nvim_replace_termcodes(keymaps.edit_source, true, false, true),
                    'n',
                    false
                )
            end
        end, vim.tbl_extend('force', map_opts, { desc = 'Edit inline base source' }))
    end

    -- Refresh
    if keymaps.refresh then
        vim.keymap.set('n', keymaps.refresh, function()
            M.refresh_buffer(buf)
        end, vim.tbl_extend('force', map_opts, { desc = 'Refresh inline bases' }))
    end
end

---Reset the embed's transient state to a clean baseline (used on error paths)
---@param embed table
local function reset_embed_state(embed)
    embed.data = nil
    embed.links = {}
    embed.cells = {}
    embed.headers = nil
    embed.api_data = nil
end

---Render a single file embed (![[name.base]] or ![[name.base#View]])
---@param buf number Buffer handle
---@param embed table Embed info
---@param callback fun(embed: table) Called when rendering is complete
local function render_single_embed(buf, embed, callback)
    local engine = require('bases.engine')
    local detect = require('bases.inline.detect')
    local render = require('bases.inline.render')
    local base_parser = require('bases.engine.base_parser')

    -- Capture the current render generation so callbacks from a stale
    -- (e.g. superseded or invalidated) render are discarded and do not
    -- touch the embed or buffer. Bump `bases_inline_render_gen` whenever
    -- `render_buffer` is called to invalidate any in-flight callbacks.
    local render_gen = vim.b[buf].bases_inline_render_gen or 0

    -- Split the embed source into its base name and optional view selector.
    -- parse_source returns nil for both values if the source is malformed,
    -- which can happen for hand-edited buffers.
    local base_name, view_name = detect.parse_source(embed.source)
    if not base_name then
        embed.extmark_id = render.apply_error(buf, embed, "Invalid embed source: " .. tostring(embed.source))
        reset_embed_state(embed)
        callback(embed)
        return
    end

    -- Show loading state
    embed.extmark_id = render.apply_loading(buf, embed, base_name)

    -- Resolve base file path within vault
    local vault = engine.get_vault_path()
    if not vault then
        embed.extmark_id = render.apply_error(buf, embed, 'Engine not initialized')
        reset_embed_state(embed)
        callback(embed)
        return
    end
    local base_file = vault .. '/' .. base_name .. '.base'

    -- Compute vault-relative path of the current buffer for `this` context
    local this_file_path = nil
    local buf_name = vim.api.nvim_buf_get_name(buf)
    if buf_name ~= '' and vim.startswith(buf_name, vault .. '/') then
        this_file_path = buf_name:sub(#vault + 2)
    end

    -- If the embed names a view (e.g. ![[Content.base#Author]]), resolve the
    -- view name to an index. We do this BEFORE issuing the query so an
    -- unknown view name is reported as an error in the embed, not silently
    -- substituted with the default view.
    local function run_query(view_index)
        -- Defer the query until the engine has finished its initial vault
        -- index build. The first BufEnter on a markdown file typically
        -- fires before `setup()` has triggered init (which is async), so
        -- without this guard the query would fail with "Query engine not
        -- initialized". When the engine is already ready, `on_ready`
        -- schedules the callback immediately on the next tick.
        engine.on_ready(function(init_err)
            -- Discard callbacks from stale renders.
            if vim.b[buf].bases_inline_render_gen ~= render_gen then
                return
            end

            if init_err then
                embed.extmark_id = render.apply_error(buf, embed, init_err)
                reset_embed_state(embed)
                callback(embed)
                return
            end

            engine.query(base_file, view_index, function(err, data)
                -- Discard callbacks from stale renders (e.g. a previous
                -- `render_buffer` call that has since been superseded, or
                -- a test buffer that has been recreated with the same ID).
                if vim.b[buf].bases_inline_render_gen ~= render_gen then
                    return
                end

                if err then
                    embed.extmark_id = render.apply_error(buf, embed, err)
                    reset_embed_state(embed)
                    callback(embed)
                    return
                end

                -- Render the table (pass view_state for future inline sorting support)
                local result = render.render_embed(data, embed.view or {})
                if result then
                    embed.extmark_id = render.apply_virtual_lines(buf, embed, result)
                    embed.data = result
                    embed.links = result.links
                    embed.cells = result.cells
                    embed.headers = result.headers
                    embed.api_data = data  -- Store full API response for re-rendering
                else
                    embed.extmark_id = render.apply_error(buf, embed, 'Failed to render')
                    reset_embed_state(embed)
                end

                callback(embed)
            end, this_file_path)
        end)
    end

    if not view_name then
        run_query(0)
        return
    end

    -- View selector present: parse the base file to look up the view index.
    -- base_parser.parse is synchronous; errors here are reported in the embed.
    local query_config, parse_err = base_parser.parse(base_file)
    if not query_config then
        embed.extmark_id = render.apply_error(buf, embed,
            "Could not resolve view '" .. view_name .. "': " .. tostring(parse_err))
        reset_embed_state(embed)
        callback(embed)
        return
    end

    local view_index, find_err = base_parser.find_view_index(query_config, view_name)
    if not view_index then
        embed.extmark_id = render.apply_error(buf, embed,
            "In " .. base_name .. ".base: " .. tostring(find_err))
        reset_embed_state(embed)
        callback(embed)
        return
    end

    run_query(view_index)
end

---Render a single code block embed (```base ... ```)
---@param buf number Buffer handle
---@param embed table Embed info with type='codeblock'
---@param callback fun(embed: table) Called when rendering is complete
local function render_single_codeblock(buf, embed, callback)
    local engine = require('bases.engine')
    local render = require('bases.inline.render')

    -- Capture the current render generation; see render_single_embed.
    local render_gen = vim.b[buf].bases_inline_render_gen or 0

    -- Conceal the source code block first
    render.conceal_codeblock(buf, embed)

    -- Show loading state
    embed.extmark_id = render.apply_codeblock_loading(buf, embed)

    -- Compute vault-relative path for this_file
    local this_file_path = nil
    local vault = engine.get_vault_path()
    if vault then
        local buf_name = vim.api.nvim_buf_get_name(buf)
        if vim.startswith(buf_name, vault .. '/') then
            this_file_path = buf_name:sub(#vault + 2)
        end
    end

    -- Query using the YAML string. Defer until the engine is ready so a
    -- first BufEnter before init completes doesn't fail with
    -- "Query engine not initialized".
    engine.on_ready(function(init_err)
        -- Discard stale callbacks; see render_single_embed.
        if vim.b[buf].bases_inline_render_gen ~= render_gen then
            return
        end

        if init_err then
            embed.extmark_id = render.apply_codeblock_error(buf, embed, init_err)
            reset_embed_state(embed)
            callback(embed)
            return
        end

        engine.query_string(embed.source, this_file_path, 0, function(err, data)
            -- Discard stale callbacks; see render_single_embed.
            if vim.b[buf].bases_inline_render_gen ~= render_gen then
                return
            end

            if err then
                embed.extmark_id = render.apply_codeblock_error(buf, embed, err)
                reset_embed_state(embed)
                callback(embed)
                return
            end

            local result = render.render_embed(data, embed.view or {})
            if result then
                embed.extmark_id = render.apply_codeblock_virtual_lines(buf, embed, result)
                embed.data = result
                embed.links = result.links
                embed.cells = result.cells
                embed.headers = result.headers
                embed.api_data = data
            else
                embed.extmark_id = render.apply_codeblock_error(buf, embed, 'Failed to render')
                reset_embed_state(embed)
            end

            callback(embed)
        end)
    end)
end

---Render all embeds in a buffer
---@param buf number Buffer handle
function M.render_buffer(buf)
    buf = buf or vim.api.nvim_get_current_buf()

    -- Get file path
    local file_path = vim.api.nvim_buf_get_name(buf)
    if file_path == '' then
        return
    end

    -- Check if file is in vault
    if not is_in_vault(file_path) then
        return
    end

    -- Check if inline rendering is enabled
    local bases = require('bases')
    local config = bases.get_config()
    if not config.inline or not config.inline.enabled then
        return
    end

    local detect = require('bases.inline.detect')
    local render = require('bases.inline.render')

    -- Bump the render generation so any in-flight callbacks from a previous
    -- render_buffer call are discarded when they eventually fire.
    vim.b[buf].bases_inline_render_gen = (vim.b[buf].bases_inline_render_gen or 0) + 1

    -- Clear existing embeds
    render.clear_all(buf)

    -- Scan for all embeds (file + codeblock)
    local embeds = detect.scan_all(buf)
    if #embeds == 0 then
        vim.b[buf].bases_inline_embeds = nil
        return
    end

    -- Store embeds in buffer variable
    vim.b[buf].bases_inline_embeds = embeds

    -- Setup keymaps
    setup_keymaps(buf)

    -- Render each embed by type
    for _, embed in ipairs(embeds) do
        local render_fn = embed.type == 'codeblock' and render_single_codeblock or render_single_embed
        render_fn(buf, embed, function(_)
            -- Update stored embeds
            vim.b[buf].bases_inline_embeds = embeds
        end)
    end
end

---Refresh all embeds in a buffer
---
---Always re-scans the buffer for embeds (delegating to `render_buffer`).
---This is what `plugin/bases.lua`'s BufWritePost handler calls after a
---file is saved, and the buffer text may have changed (e.g. a new
---`![[base.base#view]]` line was added), so we cannot reuse the cached
---embed list — we have to re-detect.
---
---For the `refresh` keymap (`<leader>br`) this is a no-op cost: if the
---embed list hasn't changed, `render_buffer` re-uses the same extmark
---ids and the visible output is identical.
---@param buf number Buffer handle
---@param opts table|nil Options: { silent = boolean }
function M.refresh_buffer(buf, opts)
    buf = buf or vim.api.nvim_get_current_buf()
    opts = opts or {}

    if not opts.silent then
        vim.notify('Refreshing inline bases...', vim.log.levels.INFO)
    end

    M.render_buffer(buf)
end

---Get embed at cursor position
---@param buf number Buffer handle
---@return table|nil Embed info if cursor is on an embed line
function M.get_embed_at_cursor(buf)
    local nav = require('bases.inline.navigation')
    return nav.get_embed_context(buf)
end

---Setup autocmds for markdown files
function M.setup()
    local bases = require('bases')
    local config = bases.get_config()

    if not config.inline or not config.inline.enabled then
        return
    end

    local group = vim.api.nvim_create_augroup('BasesInline', { clear = true })

    -- Auto-render on buffer enter (if enabled)
    if config.inline.auto_render then
        vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
            group = group,
            pattern = { '*.md', '*.markdown' },
            callback = function(args)
                -- Small delay to let buffer fully load
                -- Debounce check is inside defer_fn to handle BufEnter+BufWinEnter race
                vim.defer_fn(function()
                    if not vim.api.nvim_buf_is_valid(args.buf) then
                        return
                    end
                    -- Debounce: don't re-render if we already have embeds
                    local embeds = vim.b[args.buf].bases_inline_embeds
                    if embeds then
                        return
                    end
                    M.render_buffer(args.buf)
                end, 50)
            end,
            desc = 'Render inline bases in markdown files',
        })
    end

    -- NOTE: we deliberately do NOT register a `BufWritePost` here. The
    -- global handler in `plugin/bases.lua` already fires on every save
    -- and calls `bases.refresh_all_buffers()`, which iterates over every
    -- loaded buffer and calls `refresh_inline()` for buffers that have
    -- inline embeds. `refresh_buffer()` re-scans the buffer text via
    -- `detect.scan_all`, so newly added or removed embeds are picked up
    -- automatically. Registering our own handler here would cause each
    -- inline embed to render twice on `:w`.
end

return M
