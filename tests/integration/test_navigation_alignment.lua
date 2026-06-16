local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases module to avoid re-rendering side effects
package.loaded['bases'] = {
  get_config = function()
    return {
      render_markdown = false,
      date_format = '%Y-%m-%d',
      date_format_relative = false,
    }
  end,
}

local navigation = require('bases.navigation')
local render = require('bases.render')

-- Track buffers and windows for cleanup
local test_bufs = {}

-- Return the single character in `line` starting at the given byte offset
-- (0-indexed). Uses charidx to find the char index, then strcharpart to extract.
local function char_at_byte(line, byte)
  return vim.fn.strcharpart(line, vim.fn.charidx(line, byte), 1)
end

-- =======================
-- Helper Functions
-- =======================

local function track(buf)
  table.insert(test_bufs, buf)
  return buf
end

-- Create a test buffer that contains a real header line (e.g. "│ Name │ Status │")
-- so we can place the cursor at the actual bytes of the rendered table.
local function make_buf_with_line(line, row)
  local buf = vim.api.nvim_create_buf(false, true)
  track(buf)
  vim.bo[buf].buftype = 'nofile'

  local lines = { '' }
  -- Ensure buffer has at least `row` lines
  for _ = 1, row do
    table.insert(lines, '')
  end
  lines[row] = line

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

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
-- Header detection: cursor on the actual header text
-- =======================

T['get_header_at_cursor on real table'] = new_set()

T['get_header_at_cursor on real table']['detects header when cursor on first char of name'] = function()
  -- Rendered header line for 'file.name'/'note.status' table:
  --   '│ Name  │ Status │'
  --    ^ col 1 (border)
  --          ^ col 3 ('N' of Name)
  local line = '│ Name  │ Status │'
  local buf = make_buf_with_line(line, 2)

  -- Header info: col_start at 'N', col_end exclusive at last char of 'Name' + 1
  -- 'Name' is 4 wide, padding 1 each side, column width = 4 + 2 = 6.
  -- 'Name' starts at col 3, ends at col 6 (exclusive col 7).
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 3, col_end = 7, property = 'file.name' },
    { row = 2, col_start = 10, col_end = 16, property = 'note.status' },
  }

  -- Place cursor on 'N' (the first letter of Name)
  local byte = render.display_to_byte(line, 3)
  vim.api.nvim_win_set_cursor(0, { 2, byte })

  local result = navigation.get_header_at_cursor(buf)
  expect.no_equality(result, nil)
  expect.equality(result.property, 'file.name')
end

T['get_header_at_cursor on real table']['detects header when cursor on last char of name'] = function()
  local line = '│ Name  │ Status │'
  local buf = make_buf_with_line(line, 2)

  vim.b[buf].bases_headers = {
    { row = 2, col_start = 3, col_end = 7, property = 'file.name' },
    { row = 2, col_start = 10, col_end = 16, property = 'note.status' },
  }

  -- Place cursor on 'e' (last char of Name), which is at display col 6
  local byte = render.display_to_byte(line, 6)
  vim.api.nvim_win_set_cursor(0, { 2, byte })

  local result = navigation.get_header_at_cursor(buf)
  expect.no_equality(result, nil)
  expect.equality(result.property, 'file.name')
end

T['get_header_at_cursor on real table']['returns nil when cursor on leading space'] = function()
  local line = '│ Name  │ Status │'
  local buf = make_buf_with_line(line, 2)

  vim.b[buf].bases_headers = {
    { row = 2, col_start = 3, col_end = 7, property = 'file.name' },
  }

  -- Place cursor on the leading space at display col 2 (inside the cell padding)
  local byte = render.display_to_byte(line, 2)
  vim.api.nvim_win_set_cursor(0, { 2, byte })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

T['get_header_at_cursor on real table']['returns nil when cursor on trailing space'] = function()
  local line = '│ Name  │ Status │'
  local buf = make_buf_with_line(line, 2)

  vim.b[buf].bases_headers = {
    { row = 2, col_start = 3, col_end = 7, property = 'file.name' },
  }

  -- col 7 is the trailing space (right after 'Name').
  local byte = render.display_to_byte(line, 7)
  vim.api.nvim_win_set_cursor(0, { 2, byte })

  local result = navigation.get_header_at_cursor(buf)
  -- 'Name' occupies [3,7) in exclusive-end semantics; col 7 is the trailing
  -- space and should NOT be detected as the header.
  expect.equality(result, nil)
end

T['get_header_at_cursor on real table']['returns nil when cursor on left border'] = function()
  local line = '│ Name  │ Status │'
  local buf = make_buf_with_line(line, 2)

  vim.b[buf].bases_headers = {
    { row = 2, col_start = 3, col_end = 7, property = 'file.name' },
  }

  local byte = render.display_to_byte(line, 1)
  vim.api.nvim_win_set_cursor(0, { 2, byte })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

-- =======================
-- next_link/prev_link jump to the actual displayed byte of the link
-- =======================

T['next_link on real table'] = new_set()

T['next_link on real table']['lands cursor on the first char of the link text'] = function()
  -- Rendered data row: '│ alpha │ active │'
  -- link 'alpha' starts at col 3
  local line = '│ alpha │ active │'
  local buf = make_buf_with_line(line, 4)

  vim.b[buf].bases_links = {
    { row = 4, col_start = 3, col_end = 8, path = 'note1.md', text = 'alpha' },
  }

  -- Place cursor at row 1 before any links
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 4)
  -- Cursor should land on the first byte of 'a' in "alpha"
  local expected_byte = render.display_to_byte(line, 3)
  expect.equality(cursor[2], expected_byte)

  -- And the byte position should actually be on 'a'
  expect.equality(char_at_byte(line, cursor[2]), 'a')
end

T['next_link on real table']['works with multi-byte characters in link text'] = function()
  -- 'café' is the link text (4 chars, 5 bytes in UTF-8)
  local line = '│ café │ done │'
  local buf = make_buf_with_line(line, 4)

  vim.b[buf].bases_links = {
    { row = 4, col_start = 3, col_end = 7, path = 'note1.md', text = 'café' },
  }

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 4)
  -- The cursor should land on the first byte of 'c' in 'café'
  local expected_byte = render.display_to_byte(line, 3)
  expect.equality(cursor[2], expected_byte)

  -- And the char at that byte should be 'c'
  expect.equality(char_at_byte(line, cursor[2]), 'c')
end

T['next_link on real table']['works with wide CJK characters in link text'] = function()
  -- '你' is 2 display cells wide and 3 bytes in UTF-8
  -- '│ 你好 │ done │' (1 + space + 你好 + space + 1 + space + done + space + 1)
  local line = '│ 你好 │ done │'
  local buf = make_buf_with_line(line, 4)

  -- '你好' is 4 display cells (2 + 2), starts at col 3
  vim.b[buf].bases_links = {
    { row = 4, col_start = 3, col_end = 7, path = 'note1.md', text = '你好' },
  }

  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 4)
  local expected_byte = render.display_to_byte(line, 3)
  expect.equality(cursor[2], expected_byte)
end

-- =======================
-- Link detection at multi-byte cursor positions
-- =======================

T['get_link_at_cursor on real table'] = new_set()

-- Verify that get_link_at_cursor detects the link when the cursor lands on
-- the link text. We test this indirectly via next_link: with one link, calling
-- next_link while inside the link wraps to the same link, and the cursor
-- must be repositioned to byte 0 of the link text (display col_start).

T['get_link_at_cursor on real table']['detects link when cursor on the link text'] = function()
  local line = '│ alpha │ active │'
  local buf = make_buf_with_line(line, 4)

  vim.b[buf].bases_links = {
    { row = 4, col_start = 3, col_end = 8, path = 'note1.md', text = 'alpha' },
  }

  -- Place cursor on 'p' of alpha (display col 5)
  local byte = render.display_to_byte(line, 5)
  vim.api.nvim_win_set_cursor(0, { 4, byte })

  -- Calling next_link while inside the only link wraps to the same link, and
  -- repositions the cursor to byte of display col 3 (start of 'a').
  navigation.next_link(buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 4)
  local expected_byte = render.display_to_byte(line, 3)
  expect.equality(cursor[2], expected_byte)
  expect.equality(char_at_byte(line, cursor[2]), 'a')
end

return T
