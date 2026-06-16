local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases config
package.loaded['bases'] = {
  get_config = function()
    return {
      render_markdown = false,
      date_format = '%Y-%m-%d',
      date_format_relative = false,
    }
  end,
}

local render = require('bases.render')
local buffer = require('bases.buffer')

-- Track buffers for cleanup
local test_bufs = {}

local function make_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

local T = new_set({
  hooks = {
    post_case = function()
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      test_bufs = {}
    end,
  },
})

-- =======================
-- Link highlight byte ranges
-- =======================

T['link highlights'] = new_set()

T['link highlights']['covers exactly the link text bytes (ASCII)'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'file.name' },
    entries = {
      {
        file = { path = 'a.md' },
        values = {
          ['file.name'] = { type = 'link', value = '[[alpha]]', path = 'a.md' },
        },
      },
    },
  }

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_links')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  expect.equality(#marks, 1)

  local mark = marks[1]
  local row = mark[2]
  local col_start = mark[3]
  local col_end = mark[4].end_col -- exclusive

  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  -- The highlighted text should be exactly "alpha" (5 chars, 5 bytes)
  local highlighted = line:sub(col_start + 1, col_end)
  expect.equality(highlighted, 'alpha')
end

T['link highlights']['covers exactly the link text bytes (multi-byte)'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.title' },
    entries = {
      {
        file = { path = 'a.md' },
        values = {
          ['note.title'] = { type = 'link', value = '[[café]]', path = 'a.md' },
        },
      },
    },
  }

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_links')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  expect.equality(#marks, 1)

  local mark = marks[1]
  local row = mark[2]
  local col_start = mark[3]
  local col_end = mark[4].end_col

  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local highlighted = line:sub(col_start + 1, col_end)
  -- 'café' is 4 chars (c, a, f, é) / 5 bytes in UTF-8
  expect.equality(highlighted, 'café')
  expect.equality(vim.fn.strchars(highlighted), 4)
  expect.equality(#highlighted, 5)
end

T['link highlights']['does not include the cell border or padding'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'file.name' },
    entries = {
      {
        file = { path = 'a.md' },
        values = {
          ['file.name'] = { type = 'link', value = '[[alpha]]', path = 'a.md' },
        },
      },
    },
  }

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_links')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  expect.equality(#marks, 1)
  local mark = marks[1]
  local col_start = mark[3]
  local col_end = mark[4].end_col

  local line = vim.api.nvim_buf_get_lines(buf, mark[2], mark[2] + 1, false)[1]
  -- Bytes immediately before col_start should be a space (padding), not '│'
  local before = line:sub(col_start, col_start)
  expect.equality(before, ' ')

  -- Bytes immediately at col_end should be a space (trailing padding), not '│'
  local after = line:sub(col_end + 1, col_end + 1)
  expect.equality(after, ' ')
end

-- =======================
-- Sorted header highlight
-- =======================

T['sorted header highlight'] = new_set()

T['sorted header highlight']['covers the header text bytes including the sort icon'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.status' },
    entries = {
      { file = { path = 'a.md' }, values = { ['note.status'] = { type = 'primitive', value = 'Active' } } },
    },
  }
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'asc' }

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_sorted_header')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  expect.equality(#marks, 1)

  local mark = marks[1]
  local row = mark[2]
  local col_start = mark[3]
  local col_end = mark[4].end_col

  local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
  local highlighted = line:sub(col_start + 1, col_end)

  -- Should contain both the header text and the sort icon ▲
  expect.no_equality(highlighted:find('Status', 1, true), nil)
  expect.no_equality(highlighted:find('▲', 1, true), nil)

  -- Should NOT include the cell border or padding
  local before = line:sub(col_start, col_start)
  expect.equality(before, ' ')
  local after = line:sub(col_end + 1, col_end + 1)
  expect.equality(after, ' ')
end

T['sorted header highlight']['only one header is highlighted'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'file.name', 'note.status' },
    entries = {
      {
        file = { path = 'a.md' },
        values = {
          ['file.name'] = { type = 'primitive', value = 'Alpha' },
          ['note.status'] = { type = 'primitive', value = 'Active' },
        },
      },
    },
  }
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'desc' }

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_sorted_header')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
  expect.equality(#marks, 1)
end

return T
