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

-- Track buffers and windows for cleanup
local test_bufs = {}
local test_wins = {}

-- =======================
-- Helper Functions
-- =======================

local function track(buf)
  table.insert(test_bufs, buf)
  return buf
end

-- Create a test buffer with a window
local function make_test_buf(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  track(buf)
  vim.bo[buf].buftype = 'nofile'

  -- Set content - use longer lines to accommodate cursor positions
  local default_lines = {
    string.rep(' ', 80),
    string.rep(' ', 80),
    string.rep(' ', 80),
    string.rep(' ', 80),
    string.rep(' ', 80),
  }
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or default_lines)
  vim.bo[buf].modifiable = false

  -- Open in current window
  vim.api.nvim_set_current_buf(buf)

  return buf
end

-- =======================
-- Test Setup
-- =======================

local T = new_set({
  hooks = {
    post_case = function()
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      test_bufs = {}
      test_wins = {}
    end,
  },
})

-- =======================
-- get_header_at_cursor
-- =======================

T['get_header_at_cursor'] = new_set()

T['get_header_at_cursor']['returns nil when no headers'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = nil
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

T['get_header_at_cursor']['returns nil when headers empty'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {}
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

T['get_header_at_cursor']['returns header when cursor on header'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 2, col_end = 10, property = 'file.name' },
    { row = 2, col_start = 14, col_end = 20, property = 'note.status' },
  }

  -- Cursor on first header (row 2, col 5 = 1-indexed, so 0-indexed col 4)
  vim.api.nvim_win_set_cursor(0, { 2, 4 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result.property, 'file.name')
  expect.equality(result.row, 2)
  expect.equality(result.col_start, 2)
  expect.equality(result.col_end, 10)
end

T['get_header_at_cursor']['returns second header when cursor on it'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 2, col_end = 10, property = 'file.name' },
    { row = 2, col_start = 14, col_end = 20, property = 'note.status' },
  }

  -- Cursor on second header (row 2, col 16 = 1-indexed, so 0-indexed col 15)
  vim.api.nvim_win_set_cursor(0, { 2, 15 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result.property, 'note.status')
end

T['get_header_at_cursor']['returns nil when cursor on wrong row'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 2, col_end = 10, property = 'file.name' },
  }

  -- Cursor on row 3, not row 2
  vim.api.nvim_win_set_cursor(0, { 3, 4 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

T['get_header_at_cursor']['returns nil when cursor before header col_start'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 5, col_end = 10, property = 'file.name' },
  }

  -- Cursor at col 3 (1-indexed), which is 0-indexed col 2, before col_start 5
  vim.api.nvim_win_set_cursor(0, { 2, 2 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

T['get_header_at_cursor']['returns nil when cursor after header col_end'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 5, col_end = 10, property = 'file.name' },
  }

  -- Cursor at col 12 (1-indexed), which is 0-indexed col 11, after col_end 10
  vim.api.nvim_win_set_cursor(0, { 2, 11 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

T['get_header_at_cursor']['matches at exact col_start boundary'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 5, col_end = 10, property = 'file.name' },
  }

  -- Cursor at col 5 (1-indexed), which is 0-indexed col 4
  vim.api.nvim_win_set_cursor(0, { 2, 4 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result.property, 'file.name')
end

T['get_header_at_cursor']['matches at exact col_end boundary'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_headers = {
    { row = 2, col_start = 5, col_end = 10, property = 'file.name' },
  }

  -- col_end is exclusive: cursor at col 10 falls outside [5, 10) and should
  -- not be detected as the header.
  vim.api.nvim_win_set_cursor(0, { 2, 9 })

  local result = navigation.get_header_at_cursor(buf)
  expect.equality(result, nil)
end

-- =======================
-- toggle_sort
-- =======================

T['toggle_sort'] = new_set()

T['toggle_sort']['sets asc for new property'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_sort = nil
  vim.b[buf].bases_data = nil -- Prevent re-render

  navigation.toggle_sort(buf, 'note.status')

  local sort = vim.b[buf].bases_sort
  expect.equality(sort.property, 'note.status')
  expect.equality(sort.direction, 'asc')
end

T['toggle_sort']['changes asc to desc for same property'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'asc' }
  vim.b[buf].bases_data = nil -- Prevent re-render

  navigation.toggle_sort(buf, 'note.status')

  local sort = vim.b[buf].bases_sort
  expect.equality(sort.property, 'note.status')
  expect.equality(sort.direction, 'desc')
end

T['toggle_sort']['clears sort when toggling desc'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'desc' }
  vim.b[buf].bases_data = nil -- Prevent re-render

  navigation.toggle_sort(buf, 'note.status')

  local sort = vim.b[buf].bases_sort
  expect.equality(sort, nil)
end

T['toggle_sort']['resets to asc when changing property'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'desc' }
  vim.b[buf].bases_data = nil -- Prevent re-render

  navigation.toggle_sort(buf, 'note.priority')

  local sort = vim.b[buf].bases_sort
  expect.equality(sort.property, 'note.priority')
  expect.equality(sort.direction, 'asc')
end

T['toggle_sort']['cycles through full sequence'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_sort = nil
  vim.b[buf].bases_data = nil -- Prevent re-render

  -- First toggle: asc
  navigation.toggle_sort(buf, 'note.status')
  expect.equality(vim.b[buf].bases_sort.direction, 'asc')

  -- Second toggle: desc
  navigation.toggle_sort(buf, 'note.status')
  expect.equality(vim.b[buf].bases_sort.direction, 'desc')

  -- Third toggle: clear
  navigation.toggle_sort(buf, 'note.status')
  expect.equality(vim.b[buf].bases_sort, nil)
end

-- =======================
-- next_link
-- =======================

T['next_link'] = new_set()

T['next_link']['moves to next link'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 15, path = 'note1.md' },
    { row = 3, col_start = 10, col_end = 20, path = 'note2.md' },
    { row = 5, col_start = 3, col_end = 8, path = 'note3.md' },
  }

  -- Cursor at row 1, before any links
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 2)
  expect.equality(cursor[2], 4) -- col_start 5 - 1 = 4 (0-indexed)
end

T['next_link']['moves from first to second link'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 15, path = 'note1.md' },
    { row = 3, col_start = 10, col_end = 20, path = 'note2.md' },
    { row = 5, col_start = 3, col_end = 8, path = 'note3.md' },
  }

  -- Cursor on first link
  vim.api.nvim_win_set_cursor(0, { 2, 5 })

  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 3)
  expect.equality(cursor[2], 9) -- col_start 10 - 1 = 9
end

T['next_link']['wraps around to first link'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 15, path = 'note1.md' },
    { row = 3, col_start = 10, col_end = 20, path = 'note2.md' },
  }

  -- Cursor after last link
  vim.api.nvim_win_set_cursor(0, { 5, 0 })

  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 2)
  expect.equality(cursor[2], 4) -- First link
end

T['next_link']['handles multiple links on same row'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 10, path = 'note1.md' },
    { row = 2, col_start = 15, col_end = 20, path = 'note2.md' },
  }

  -- Cursor on first link
  vim.api.nvim_win_set_cursor(0, { 2, 5 })

  navigation.next_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 2)
  expect.equality(cursor[2], 14) -- Second link on same row
end

T['next_link']['notifies when no links'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = nil

  -- Capture vim.notify calls
  local notified = false
  local old_notify = vim.notify
  vim.notify = function(msg, level)
    notified = true
    expect.equality(msg, 'No links in this base')
    expect.equality(level, vim.log.levels.INFO)
  end

  navigation.next_link(buf)

  vim.notify = old_notify
  expect.equality(notified, true)
end

T['next_link']['notifies when links empty'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {}

  local notified = false
  local old_notify = vim.notify
  vim.notify = function(msg, level)
    notified = true
  end

  navigation.next_link(buf)

  vim.notify = old_notify
  expect.equality(notified, true)
end

-- =======================
-- prev_link
-- =======================

T['prev_link'] = new_set()

T['prev_link']['moves to previous link'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 15, path = 'note1.md' },
    { row = 3, col_start = 10, col_end = 20, path = 'note2.md' },
    { row = 5, col_start = 3, col_end = 8, path = 'note3.md' },
  }

  -- Cursor on third link
  vim.api.nvim_win_set_cursor(0, { 5, 3 })

  navigation.prev_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 3)
  expect.equality(cursor[2], 9) -- Second link
end

T['prev_link']['moves from second to first link'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 15, path = 'note1.md' },
    { row = 3, col_start = 10, col_end = 20, path = 'note2.md' },
  }

  -- Cursor on second link
  vim.api.nvim_win_set_cursor(0, { 3, 10 })

  navigation.prev_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 2)
  expect.equality(cursor[2], 4) -- First link
end

T['prev_link']['wraps around to last link'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 15, path = 'note1.md' },
    { row = 3, col_start = 10, col_end = 20, path = 'note2.md' },
  }

  -- Cursor before first link
  vim.api.nvim_win_set_cursor(0, { 1, 0 })

  navigation.prev_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 3)
  expect.equality(cursor[2], 9) -- Last link
end

T['prev_link']['handles multiple links on same row'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 10, path = 'note1.md' },
    { row = 2, col_start = 15, col_end = 20, path = 'note2.md' },
  }

  -- Cursor on second link
  vim.api.nvim_win_set_cursor(0, { 2, 15 })

  navigation.prev_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 2)
  expect.equality(cursor[2], 4) -- First link on same row
end

T['prev_link']['handles cursor between two links on same row'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {
    { row = 2, col_start = 5, col_end = 10, path = 'note1.md' },
    { row = 2, col_start = 15, col_end = 20, path = 'note2.md' },
  }

  -- Cursor between the two links (col 12)
  vim.api.nvim_win_set_cursor(0, { 2, 12 })

  navigation.prev_link(buf)

  local cursor = vim.api.nvim_win_get_cursor(0)
  expect.equality(cursor[1], 2)
  expect.equality(cursor[2], 4) -- First link
end

T['prev_link']['notifies when no links'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = nil

  local notified = false
  local old_notify = vim.notify
  vim.notify = function(msg, level)
    notified = true
    expect.equality(msg, 'No links in this base')
    expect.equality(level, vim.log.levels.INFO)
  end

  navigation.prev_link(buf)

  vim.notify = old_notify
  expect.equality(notified, true)
end

T['prev_link']['notifies when links empty'] = function()
  local buf = make_test_buf()
  vim.b[buf].bases_links = {}

  local notified = false
  local old_notify = vim.notify
  vim.notify = function(msg, level)
    notified = true
  end

  navigation.prev_link(buf)

  vim.notify = old_notify
  expect.equality(notified, true)
end

return T
