local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases config for date formatting
package.loaded['bases'] = {
  get_config = function()
    return { date_format = '%Y-%m-%d', date_format_relative = false }
  end,
}

local render = require('bases.render')

local T = new_set()

-- =======================
-- display_to_byte
-- =======================

T['display_to_byte'] = new_set()

T['display_to_byte']['returns 0 for column <= 1'] = function()
  expect.equality(render.display_to_byte('hello', 0), 0)
  expect.equality(render.display_to_byte('hello', 1), 0)
end

T['display_to_byte']['maps 1-indexed display column to 0-indexed byte'] = function()
  local line = 'hello'
  expect.equality(render.display_to_byte(line, 2), 1)
  expect.equality(render.display_to_byte(line, 6), 5)
end

T['display_to_byte']['returns byte index of first byte of multi-byte char'] = function()
  -- 'é' is 2 bytes in UTF-8 (0xC3 0xA9)
  local line = 'café'
  -- columns: c=1, a=2, f=3, é=4, 5
  -- display col 1 -> byte 0 (start of 'c')
  expect.equality(render.display_to_byte(line, 1), 0)
  expect.equality(render.display_to_byte(line, 2), 1)
  expect.equality(render.display_to_byte(line, 3), 2)
  -- display col 4 is inside 'é' (which spans bytes 3-4) -> return 3
  expect.equality(render.display_to_byte(line, 4), 3)
end

T['display_to_byte']['handles 2-cell-wide CJK characters'] = function()
  -- '你' is 3 bytes in UTF-8, but 2 display cells wide
  local line = 'a你b'
  -- columns: a=1, 你=2-3, b=4
  expect.equality(render.display_to_byte(line, 1), 0)
  -- col 2 is inside '你' (which starts at byte 1)
  expect.equality(render.display_to_byte(line, 2), 1)
  expect.equality(render.display_to_byte(line, 3), 1)
  -- col 4 is 'b' at byte 4
  expect.equality(render.display_to_byte(line, 4), 4)
end

T['display_to_byte']['handles unicode borders'] = function()
  -- '│' is 3 bytes in UTF-8 but only 1 display cell wide
  local line = '│ Name │'
  -- line is 8 display cells, 12 bytes
  -- column 1 -> byte 0 (left border)
  expect.equality(render.display_to_byte(line, 1), 0)
  -- column 2 is the space after the border (border is 1 cell wide, so col 2 is the next char)
  expect.equality(render.display_to_byte(line, 2), 3)
  -- column 3 -> byte 4 ('N')
  expect.equality(render.display_to_byte(line, 3), 4)
  -- column 8 -> byte 9 (last char of the line, right border '│' which is 1 cell but 3 bytes)
  expect.equality(render.display_to_byte(line, 8), 9)
  -- column past end of line returns #line (12)
  expect.equality(render.display_to_byte(line, 100), #line)
end

T['display_to_byte']['past end of line returns byte length'] = function()
  local line = 'hello'
  expect.equality(render.display_to_byte(line, 100), #line)
end

-- =======================
-- byte_to_display
-- =======================

T['byte_to_display'] = new_set()

T['byte_to_display']['returns 1 for byte 0'] = function()
  expect.equality(render.byte_to_display('hello', 0), 1)
end

T['byte_to_display']['maps 0-indexed byte to 1-indexed display column'] = function()
  local line = 'hello'
  expect.equality(render.byte_to_display(line, 0), 1)
  expect.equality(render.byte_to_display(line, 1), 2)
  expect.equality(render.byte_to_display(line, 5), 6)
end

T['byte_to_display']['clamps negative byte to 0'] = function()
  local line = 'hello'
  expect.equality(render.byte_to_display(line, -1), 1)
end

T['byte_to_display']['inside multi-byte char returns that char display column'] = function()
  -- 'é' is 2 bytes in UTF-8 (bytes 3-4 of "café")
  local line = 'café'
  -- byte 0 -> 'c' at display col 1
  expect.equality(render.byte_to_display(line, 0), 1)
  -- byte 3 -> inside 'é' at display col 4
  expect.equality(render.byte_to_display(line, 3), 4)
  -- byte 4 -> inside 'é' at display col 4 (last byte of the char)
  expect.equality(render.byte_to_display(line, 4), 4)
end

T['byte_to_display']['handles 2-cell-wide CJK characters'] = function()
  local line = 'a你b'
  -- byte 0 -> 'a' at col 1
  expect.equality(render.byte_to_display(line, 0), 1)
  -- byte 1 -> inside '你' at col 2
  expect.equality(render.byte_to_display(line, 1), 2)
  -- byte 4 -> 'b' at col 4
  expect.equality(render.byte_to_display(line, 4), 4)
end

T['byte_to_display']['handles unicode borders'] = function()
  -- '│' is 3 bytes in UTF-8
  local line = '│ Name │'
  expect.equality(render.byte_to_display(line, 0), 1)
  -- byte 3 -> space at display col 2
  expect.equality(render.byte_to_display(line, 3), 2)
  -- byte 4 -> 'N' at display col 3
  expect.equality(render.byte_to_display(line, 4), 3)
end

-- =======================
-- Round trip
-- =======================

T['round trip'] = new_set()

T['round trip']['display_to_byte then byte_to_display is identity for ASCII'] = function()
  for col = 1, 5 do
    local byte = render.display_to_byte('hello', col)
    local back = render.byte_to_display('hello', byte)
    expect.equality(back, col)
  end
end

T['round trip']['display_to_byte then byte_to_display is identity for multi-byte'] = function()
  local line = 'café'
  for col = 1, 5 do
    local byte = render.display_to_byte(line, col)
    local back = render.byte_to_display(line, byte)
    expect.equality(back, col)
  end
end

-- =======================
-- Header col_start/col_end alignment
-- =======================
-- These tests verify that header positions reported by render match the
-- actual text in the rendered line. With off-by-one errors the cursor or
-- highlight would land on the wrong character (often the leading space).

-- Convert a byte offset within `line` to a Lua string containing the single
-- character starting at that byte. Uses charidx to handle multi-byte chars.
local function char_at_byte(line, byte)
  local char_idx = vim.fn.charidx(line, byte)
  return vim.fn.strcharpart(line, char_idx, 1)
end

T['render_unicode_table header positions'] = new_set()

T['render_unicode_table header positions']['col_start points at first text char, not the leading space'] = function()
  local properties = { 'file.name' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['file.name'] = { type = 'primitive', value = 'Alpha' } } },
  }
  local lines, _, _, headers = render.render_unicode_table(properties, entries, nil, nil, nil)

  expect.equality(headers[1].row, 2)
  expect.equality(headers[1].property, 'file.name')

  -- Get the actual header line
  local header_line = lines[2]

  -- col_start should be the byte position of 'N' in "Name", not the leading space
  local byte_at_col_start = render.display_to_byte(header_line, headers[1].col_start)
  expect.equality(char_at_byte(header_line, byte_at_col_start), 'N')
end

T['render_unicode_table header positions']['col_end is exclusive, not the trailing space'] = function()
  local properties = { 'file.name' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['file.name'] = { type = 'primitive', value = 'Alpha' } } },
  }
  local lines, _, _, headers = render.render_unicode_table(properties, entries, nil, nil, nil)

  local header_line = lines[2]

  -- col_end is exclusive (one past last char of text)
  -- Header text 'Name' is 4 chars; col_end should be col_start + 4
  expect.equality(headers[1].col_end, headers[1].col_start + 4)

  -- The character at (col_end - 1) is the last char of the text
  local col_end_inclusive = headers[1].col_end - 1
  local byte_at_end = render.display_to_byte(header_line, col_end_inclusive)
  expect.equality(char_at_byte(header_line, byte_at_end), 'e') -- last char of "Name"
end

T['render_unicode_table header positions']['headers for second column are after the first'] = function()
  local properties = { 'file.name', 'note.status' }
  local entries = {
    { file = { path = 'a.md' }, values = {
      ['file.name'] = { type = 'primitive', value = 'Alpha' },
      ['note.status'] = { type = 'primitive', value = 'Active' },
    } },
  }
  local lines, _, _, headers = render.render_unicode_table(properties, entries, nil, nil, nil)

  local header_line = lines[2]
  expect.equality(headers[2].row, 2)
  expect.equality(headers[2].col_start > headers[1].col_end, true)

  -- Verify header text character at col_start for second header
  local byte_at_col_start = render.display_to_byte(header_line, headers[2].col_start)
  expect.equality(char_at_byte(header_line, byte_at_col_start), 'S') -- first char of "Status"
end

T['render_unicode_table header positions']['works with sort icon'] = function()
  local properties = { 'note.priority' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['note.priority'] = { type = 'primitive', value = 1 } } },
  }
  local sort_state = { property = 'note.priority', direction = 'asc' }
  local lines, _, _, headers = render.render_unicode_table(properties, entries, sort_state, nil, nil)

  local header_line = lines[2]
  -- Header text is 'Priority ▲' which is 10 cells wide (8 for 'Priority' + 1 space + 1 for '▲')
  expect.equality(headers[1].col_end, headers[1].col_start + 10)

  -- The character at (col_end - 1) is the sort icon '▲'
  local col_end_inclusive = headers[1].col_end - 1
  local byte_at_end = render.display_to_byte(header_line, col_end_inclusive)
  expect.equality(char_at_byte(header_line, byte_at_end), '▲')
end

-- =======================
-- Data cell col_start/col_end alignment
-- =======================

T['render_unicode_table cell positions'] = new_set()

T['render_unicode_table cell positions']['cell col_start points at first text char, not the leading space'] = function()
  local properties = { 'note.related' }
  local entries = {
    {
      file = { path = 'a.md' },
      values = {
        ['note.related'] = { type = 'link', value = '[[alpha]]', path = 'a.md' },
      },
    },
  }
  local lines, links, cells = render.render_unicode_table(properties, entries, nil, nil, nil)

  -- Row 4 is the data row
  local data_line = lines[4]

  -- The link text is "alpha" (5 chars). col_start should be at 'a', not at the leading space.
  expect.equality(links[1].row, 4)
  expect.equality(links[1].text, 'alpha')
  local byte_at_link_start = render.display_to_byte(data_line, links[1].col_start)
  expect.equality(char_at_byte(data_line, byte_at_link_start), 'a')

  -- col_end is exclusive: col_start + 5 for "alpha"
  expect.equality(links[1].col_end, links[1].col_start + 5)
  expect.equality(cells[1].col_end, cells[1].col_start + 5)
end

T['render_unicode_table cell positions']['cell ranges do not overlap'] = function()
  local properties = { 'file.name', 'note.status' }
  local entries = {
    { file = { path = 'a.md' }, values = {
      ['file.name'] = { type = 'primitive', value = 'Alpha' },
      ['note.status'] = { type = 'primitive', value = 'Active' },
    } },
  }
  local lines, _, cells = render.render_unicode_table(properties, entries, nil, nil, nil)

  local data_line = lines[4]

  -- Get the first two cells (row 4)
  local cell1 = cells[1]
  local cell2 = cells[2]
  expect.equality(cell1.row, 4)
  expect.equality(cell2.row, 4)

  -- The text at cell1.col_start should be the first letter of "Alpha"
  local byte1 = render.display_to_byte(data_line, cell1.col_start)
  expect.equality(char_at_byte(data_line, byte1), 'A')

  -- The text at cell2.col_start should be the first letter of "Active"
  local byte2 = render.display_to_byte(data_line, cell2.col_start)
  expect.equality(char_at_byte(data_line, byte2), 'A')

  -- cell1.col_end must be <= cell2.col_start (no overlap, gap is the border+padding)
  expect.equality(cell1.col_end <= cell2.col_start, true)
end

-- =======================
-- Markdown table alignment
-- =======================

T['render_markdown_table positions'] = new_set()

T['render_markdown_table positions']['header col_start points at first text char, not the leading space'] = function()
  local properties = { 'file.name' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['file.name'] = { type = 'primitive', value = 'Alpha' } } },
  }
  local lines, _, _, headers = render.render_markdown_table(properties, entries, nil, nil, nil)

  local header_line = lines[1]
  expect.equality(headers[1].row, 1)

  -- col_start should point at 'N' of 'Name', not the leading space
  local byte_at_col_start = render.display_to_byte(header_line, headers[1].col_start)
  expect.equality(char_at_byte(header_line, byte_at_col_start), 'N')
end

T['render_markdown_table positions']['cell col_start points at first text char, not the leading space'] = function()
  local properties = { 'note.related' }
  local entries = {
    {
      file = { path = 'a.md' },
      values = {
        ['note.related'] = { type = 'link', value = '[[alpha]]', path = 'a.md' },
      },
    },
  }
  local lines, links = render.render_markdown_table(properties, entries, nil, nil, nil)

  -- In markdown mode, line 3 is the data row
  local data_line = lines[3]
  local byte_at_link_start = render.display_to_byte(data_line, links[1].col_start)
  -- Markdown mode now also strips [[...]], so link starts at 'a' of 'alpha'
  expect.equality(char_at_byte(data_line, byte_at_link_start), 'a')
end

return T
