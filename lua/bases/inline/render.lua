-- Rendering of inline base embeds using extmarks with virtual lines
local M = {}

local NS_NAME = 'bases_inline'
local CONCEAL_NS_NAME = 'bases_inline_conceal'

---Convert display column position to byte position in a UTF-8 string
---@param str string The string to index into
---@param display_col number 1-indexed display column
---@return number byte_pos 1-indexed byte position
local function display_to_byte(str, display_col)
    if display_col <= 1 then
        return 1
    end
    local current_col = 1
    local num_chars = vim.fn.strchars(str)
    for i = 0, num_chars - 1 do
        if current_col >= display_col then
            return vim.fn.byteidx(str, i) + 1  -- +1 for 1-indexed
        end
        local char = vim.fn.strcharpart(str, i, 1)
        local char_width = vim.fn.strdisplaywidth(char)
        current_col = current_col + char_width
    end
    -- display_col is past end of string
    return #str + 1
end

---Get or create the namespace for inline base rendering
---@return number Namespace ID
local function get_namespace()
    return vim.api.nvim_create_namespace(NS_NAME)
end

---Get or create the namespace for concealment extmarks
---@return number Namespace ID
local function get_conceal_namespace()
    return vim.api.nvim_create_namespace(CONCEAL_NS_NAME)
end

---Build a virtual line with highlighting chunks
---@param text string The line text
---@param default_hl string Default highlight group
---@return table[] Chunk list for virt_lines
local function build_line_chunks(text, default_hl)
    return {{ text, default_hl }}
end

---Build virtual lines from rendered table lines with proper highlighting
---@param lines string[] Rendered table lines
---@param links table[] Link positions
---@param cells table[] Cell positions
---@return table[] virt_lines Array of chunk arrays for extmark virt_lines
local function build_virtual_lines(lines, links, cells)
    local virt_lines = {}

    for line_idx, line_text in ipairs(lines) do
        local chunks = {}

        -- Find all highlights for this line
        local highlights = {}

        -- Add link highlights
        for _, link in ipairs(links) do
            if link.row == line_idx then
                table.insert(highlights, {
                    col_start = link.col_start,
                    col_end = link.col_end,
                    hl = 'BasesLink',
                })
            end
        end

        -- Add editable cell highlights
        for _, cell in ipairs(cells) do
            if cell.row == line_idx and cell.editable then
                -- Only highlight if not already a link
                local is_link = false
                for _, link in ipairs(links) do
                    if link.row == line_idx and link.col_start == cell.col_start then
                        is_link = true
                        break
                    end
                end
                if not is_link then
                    table.insert(highlights, {
                        col_start = cell.col_start,
                        col_end = cell.col_end,
                        hl = 'BasesEditable',
                    })
                end
            end
        end

        -- Sort highlights by position
        table.sort(highlights, function(a, b)
            return a.col_start < b.col_start
        end)

        -- Build chunks with highlights (using display column positions)
        local display_pos = 1
        for _, hl in ipairs(highlights) do
            -- Add text before this highlight
            if hl.col_start > display_pos then
                local byte_start = display_to_byte(line_text, display_pos)
                local byte_end = display_to_byte(line_text, hl.col_start) - 1
                local before = line_text:sub(byte_start, byte_end)
                if #before > 0 then
                    table.insert(chunks, { before, 'BasesBorder' })
                end
            end
            -- Add highlighted text
            local hl_byte_start = display_to_byte(line_text, hl.col_start)
            local hl_byte_end = display_to_byte(line_text, hl.col_end) - 1
            local highlighted = line_text:sub(hl_byte_start, hl_byte_end)
            if #highlighted > 0 then
                table.insert(chunks, { highlighted, hl.hl })
            end
            display_pos = hl.col_end
        end

        -- Add remaining text after last highlight
        if #highlights > 0 then
            local remaining_byte_start = display_to_byte(line_text, display_pos)
            if remaining_byte_start <= #line_text then
                local remaining = line_text:sub(remaining_byte_start)
                if #remaining > 0 then
                    table.insert(chunks, { remaining, 'BasesBorder' })
                end
            end
        end

        -- If no highlights on this line, add the whole line as a single chunk
        if #chunks == 0 then
            table.insert(chunks, { line_text, 'BasesBorder' })
        end

        table.insert(virt_lines, chunks)
    end

    return virt_lines
end

---Render an embed and return virtual lines data
---@param data table API response data
---@param view_state table|nil View state with optional sort {property, direction}
---@return table|nil Result with lines, links, cells, headers or nil on error
function M.render_embed(data, view_state)
    local render = require('bases.render')
    local display = require('bases.display')

    -- Prepare display data with sort and limit applied
    local display_data = display.prepare(data, view_state or {})

    -- Validate
    local valid, err = display.validate(display_data)
    if not valid then
        return {
            lines = { '  ' .. err },
            links = {},
            cells = {},
            headers = {},
        }
    end

    -- Render table
    local lines, links, cells, headers = render.render_table(display_data, "unicode")

    return {
        lines = lines,
        links = links,
        cells = cells,
        headers = headers,
    }
end

---Apply virtual lines to buffer below an embed line
---@param buf number Buffer handle
---@param embed table Embed info with line_end, extmark_id
---@param render_result table Result from render_embed
---@return number extmark_id The created extmark ID
function M.apply_virtual_lines(buf, embed, render_result)
    local ns = get_namespace()

    -- Clear existing extmark if present
    if embed.extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, embed.extmark_id)
    end

    -- Build virtual lines with highlighting
    local virt_lines = build_virtual_lines(
        render_result.lines,
        render_result.links,
        render_result.cells
    )

    -- Create extmark with virtual lines below the embed line
    local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, embed.line_end - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
    })

    return extmark_id
end

---Apply loading state virtual lines
---@param buf number Buffer handle
---@param embed table Embed info
---@param base_name string Base name being loaded
---@return number extmark_id
function M.apply_loading(buf, embed, base_name)
    local ns = get_namespace()

    -- Clear existing extmark if present
    if embed.extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, embed.extmark_id)
    end

    local virt_lines = {
        {{ '  Loading ' .. base_name .. '...', 'Comment' }},
    }

    local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, embed.line_end - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
    })

    return extmark_id
end

---Apply error state virtual lines
---@param buf number Buffer handle
---@param embed table Embed info
---@param error_msg string Error message
---@return number extmark_id
function M.apply_error(buf, embed, error_msg)
    local ns = get_namespace()

    -- Clear existing extmark if present
    if embed.extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, embed.extmark_id)
    end

    local virt_lines = {
        {{ '  Error: ' .. error_msg, 'ErrorMsg' }},
    }

    local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, embed.line_end - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
    })

    return extmark_id
end

---Conceal a ```base code block: overlay the opening fence, hide content + closing fence
---@param buf number Buffer handle
---@param embed table Embed info with line_start, content_start, content_end, line_end (1-indexed)
function M.conceal_codeblock(buf, embed)
    local ns = get_conceal_namespace()

    -- Opening fence: overlay with "▶ base" label (NOT concealed — anchors virt_lines)
    vim.api.nvim_buf_set_extmark(buf, ns, embed.line_start - 1, 0, {
        virt_text = {{ '▶ base', 'Comment' }},
        virt_text_pos = 'overlay',
    })

    -- Content lines + closing fence: hide them
    for lnum = embed.content_start - 1, embed.line_end - 1 do
        vim.api.nvim_buf_set_extmark(buf, ns, lnum, 0, {
            conceal_lines = '',
        })
    end
end

---Apply virtual lines for a code block embed (anchored at opening fence)
---@param buf number Buffer handle
---@param embed table Embed info
---@param render_result table Result from render_embed
---@return number extmark_id The created extmark ID
function M.apply_codeblock_virtual_lines(buf, embed, render_result)
    local ns = get_namespace()

    -- Clear existing extmark if present
    if embed.extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, embed.extmark_id)
    end

    -- Build virtual lines with highlighting
    local virt_lines = build_virtual_lines(
        render_result.lines,
        render_result.links,
        render_result.cells
    )

    -- Anchor at opening fence line
    local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, embed.line_start - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
    })

    return extmark_id
end

---Apply loading state for a code block embed
---@param buf number Buffer handle
---@param embed table Embed info
---@return number extmark_id
function M.apply_codeblock_loading(buf, embed)
    local ns = get_namespace()

    if embed.extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, embed.extmark_id)
    end

    local virt_lines = {
        {{ '  Loading...', 'Comment' }},
    }

    local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, embed.line_start - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
    })

    return extmark_id
end

---Apply error state for a code block embed
---@param buf number Buffer handle
---@param embed table Embed info
---@param error_msg string Error message
---@return number extmark_id
function M.apply_codeblock_error(buf, embed, error_msg)
    local ns = get_namespace()

    if embed.extmark_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, ns, embed.extmark_id)
    end

    local virt_lines = {
        {{ '  Error: ' .. error_msg, 'ErrorMsg' }},
    }

    local extmark_id = vim.api.nvim_buf_set_extmark(buf, ns, embed.line_start - 1, 0, {
        virt_lines = virt_lines,
        virt_lines_above = false,
    })

    return extmark_id
end

---Clear all inline embeds from buffer
---@param buf number Buffer handle
function M.clear_all(buf)
    local ns = get_namespace()
    vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    local conceal_ns = get_conceal_namespace()
    vim.api.nvim_buf_clear_namespace(buf, conceal_ns, 0, -1)
end

return M
