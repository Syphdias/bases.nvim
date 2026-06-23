local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases module to provide config
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

-- =======================
-- Helper Functions
-- =======================

local function make_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.api.nvim_set_current_buf(buf)
  return buf
end

-- Sample test data (raw SerializedResult format)
local function make_test_data()
  return {
    properties = { 'file.name', 'note.status', 'note.priority' },
    entries = {
      {
        file = { path = 'projects/alpha.md', name = 'alpha.md', basename = 'alpha' },
        values = {
          ['file.name'] = { type = 'link', value = '[[alpha]]', path = 'projects/alpha.md' },
          ['note.status'] = { type = 'primitive', value = 'active' },
          ['note.priority'] = { type = 'primitive', value = 1 },
        },
      },
      {
        file = { path = 'projects/beta.md', name = 'beta.md', basename = 'beta' },
        values = {
          ['file.name'] = { type = 'link', value = '[[beta]]', path = 'projects/beta.md' },
          ['note.status'] = { type = 'primitive', value = 'complete' },
          ['note.priority'] = { type = 'primitive', value = 3 },
        },
      },
    },
  }
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
    end,
  },
})

-- =======================
-- render: Unicode Table
-- =======================

T['render unicode'] = new_set()

T['render unicode']['renders unicode table to buffer'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines > 0, true)
  -- First line should have border characters
  expect.equality(#lines[1] > 0, true)
end

T['render unicode']['uses unicode borders'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Top and bottom borders should contain horizontal line characters
  expect.equality(#lines[1] > 10, true)
  local last_line = lines[#lines]
  expect.equality(#last_line > 10, true)
  -- Should have multiple lines (border, header, separator, data rows, border)
  expect.equality(#lines >= 6, true)
end

T['render unicode']['has header on line 2'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Line 2 should contain headers
  expect.equality(lines[2]:match('Name') ~= nil, true)
  expect.equality(lines[2]:match('Status') ~= nil, true)
  expect.equality(lines[2]:match('Priority') ~= nil, true)
end

T['render unicode']['has separator on line 3'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Line 3 should be separator (longer than headers due to borders)
  expect.equality(#lines[3] > 10, true)
end

T['render unicode']['renders data rows'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Line 4 should have first entry (alpha)
  expect.equality(lines[4]:match('alpha') ~= nil, true)
  expect.equality(lines[4]:match('active') ~= nil, true)
  expect.equality(lines[4]:match('1') ~= nil, true)
  -- Line 5 should have second entry (beta)
  expect.equality(lines[5]:match('beta') ~= nil, true)
  expect.equality(lines[5]:match('complete') ~= nil, true)
  expect.equality(lines[5]:match('3') ~= nil, true)
end

T['render unicode']['sets filetype to obsidian_base'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  expect.equality(vim.bo[buf].filetype, 'obsidian_base')
end

-- =======================
-- render: Markdown Table
-- =======================

T['render markdown'] = new_set()

T['render markdown']['renders markdown table to buffer'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines > 0, true)
  -- First line should start with pipe
  expect.equality(lines[1]:sub(1, 1), '|')
end

T['render markdown']['uses pipe delimiters'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- All lines should use pipe delimiters
  for i, line in ipairs(lines) do
    expect.equality(line:sub(1, 1), '|', 'Line ' .. i .. ' should start with |')
    expect.equality(line:sub(-1), '|', 'Line ' .. i .. ' should end with |')
  end
end

T['render markdown']['has header on line 1'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Line 1 should contain headers
  expect.equality(lines[1]:match('Name') ~= nil, true)
  expect.equality(lines[1]:match('Status') ~= nil, true)
  expect.equality(lines[1]:match('Priority') ~= nil, true)
end

T['render markdown']['has separator on line 2'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Line 2 should be all dashes between pipes
  local sep = lines[2]:gsub('|', ''):gsub('-', '')
  expect.equality(sep, '')
end

T['render markdown']['strips wiki-link brackets like unicode mode'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Data rows now also strip brackets (consistency with unicode mode).
  -- render-markdown.nvim handles wikilinks via markdown link syntax downstream.
  expect.no_equality(lines[3]:match(' alpha '), nil)
  expect.no_equality(lines[4]:match(' beta '), nil)
  expect.equality(lines[3]:match('%[%['), nil)
end

T['render markdown']['sets filetype to markdown'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  expect.equality(vim.bo[buf].filetype, 'markdown')
end

-- =======================
-- render: Buffer Variables
-- =======================

T['buffer variables'] = new_set()

T['buffer variables']['populates bases_links'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(type(links), 'table')
  expect.equality(#links, 2) -- Two file.name links
  expect.equality(links[1].path, 'projects/alpha.md')
  expect.equality(links[2].path, 'projects/beta.md')
end

T['buffer variables']['populates bases_cells'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  expect.equality(type(cells), 'table')
  -- Should have 6 cells: 3 properties × 2 entries
  expect.equality(#cells, 6)
end

T['buffer variables']['populates bases_headers'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local headers = vim.b[buf].bases_headers
  expect.equality(type(headers), 'table')
  expect.equality(#headers, 3) -- Three properties
  expect.equality(headers[1].property, 'file.name')
  expect.equality(headers[2].property, 'note.status')
  expect.equality(headers[3].property, 'note.priority')
end

T['buffer variables']['populates bases_data'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local stored_data = vim.b[buf].bases_data
  expect.equality(type(stored_data), 'table')
  expect.equality(stored_data.properties[1], 'file.name')
  expect.equality(#stored_data.entries, 2)
end

-- =======================
-- render: Link Tracking
-- =======================

T['link tracking'] = new_set()

T['link tracking']['tracks link positions'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(links[1].row > 0, true)
  expect.equality(links[1].col_start > 0, true)
  expect.equality(links[1].col_end > links[1].col_start, true)
end

T['link tracking']['tracks link text'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(links[1].text, 'alpha')
  expect.equality(links[2].text, 'beta')
end

T['link tracking']['tracks link inside list cell at correct offset'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.refs' },
    entries = {
      {
        file = { path = 'a.md', name = 'a.md', basename = 'a' },
        values = {
          ['note.refs'] = {
            type = 'list',
            value = {
              { type = 'link', value = '[[alpha]]', path = 'projects/alpha.md' },
              { type = 'primitive', value = 'plain' },
            },
          },
        },
      },
    },
  }

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'projects/alpha.md')

  -- Verify the link range covers 'alpha' and not ', plain'
  local line = vim.api.nvim_buf_get_lines(buf, links[1].row - 1, links[1].row, false)[1] or ''
  local sub_start = render.display_to_byte(line, links[1].col_start) + 1
  local sub_end = render.display_to_byte(line, links[1].col_end)
  expect.equality(line:sub(sub_start, sub_end), 'alpha')

  -- The full rendered text should be 'alpha, plain'
  expect.equality(line:find('alpha, plain', 1, true) ~= nil, true)
end

T['link tracking']['tracks multiple links in single list cell'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.refs' },
    entries = {
      {
        file = { path = 'a.md', name = 'a.md', basename = 'a' },
        values = {
          ['note.refs'] = {
            type = 'list',
            value = {
              { type = 'link', value = '[[alpha]]', path = 'projects/alpha.md' },
              { type = 'link', value = '[[beta]]', path = 'projects/beta.md' },
            },
          },
        },
      },
    },
  }

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(#links, 2)
  expect.equality(links[1].path, 'projects/alpha.md')
  expect.equality(links[2].path, 'projects/beta.md')

  -- Both links should be on the same row
  expect.equality(links[1].row, links[2].row)
  -- Second link should start after first link + ', '
  expect.equality(links[2].col_start > links[1].col_end, true)
end

T['link tracking']['no link entries for plain list items'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.tags' },
    entries = {
      {
        file = { path = 'a.md', name = 'a.md', basename = 'a' },
        values = {
          ['note.tags'] = {
            type = 'list',
            value = {
              { type = 'primitive', value = 'plain' },
              { type = 'primitive', value = 'also-plain' },
            },
          },
        },
      },
    },
  }

  render.render(buf, data, false)

  expect.equality(#vim.b[buf].bases_links, 0)
end

T['link tracking']['single link cell shows inner text only'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  -- Cell should display 'alpha' (no brackets), not '[[alpha]]'
  local links = vim.b[buf].bases_links
  local line = vim.api.nvim_buf_get_lines(buf, links[1].row - 1, links[1].row, false)[1] or ''
  local sub_start = render.display_to_byte(line, links[1].col_start) + 1
  local sub_end = render.display_to_byte(line, links[1].col_end)
  expect.equality(line:sub(sub_start, sub_end), 'alpha')
  -- Cell should NOT contain brackets
  expect.equality(line:find('[[', 1, true) ~= nil, false)
end

T['link tracking']['tracks link paths'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(links[1].path, 'projects/alpha.md')
  expect.equality(links[2].path, 'projects/beta.md')
end

T['link tracking']['only tracks link-type values'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.title', 'note.status' },
    entries = {
      {
        file = { path = 'test.md', name = 'test.md', basename = 'test' },
        values = {
          ['note.title'] = { type = 'primitive', value = 'Not a link' },
          ['note.status'] = { type = 'primitive', value = 'active' },
        },
      },
    },
  }

  render.render(buf, data, false)

  local links = vim.b[buf].bases_links
  expect.equality(#links, 0) -- No links in this data
end

-- =======================
-- render: Cell Tracking
-- =======================

T['cell tracking'] = new_set()

T['cell tracking']['tracks all cells'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  -- 3 properties × 2 entries = 6 cells
  expect.equality(#cells, 6)
end

T['cell tracking']['tracks cell positions'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  for _, cell in ipairs(cells) do
    expect.equality(cell.row > 0, true)
    expect.equality(cell.col_start > 0, true)
    expect.equality(cell.col_end >= cell.col_start, true)
  end
end

T['cell tracking']['tracks property names'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  -- Check that cells have property names
  local properties = {}
  for _, cell in ipairs(cells) do
    properties[cell.property] = true
  end
  expect.equality(properties['file.name'], true)
  expect.equality(properties['note.status'], true)
  expect.equality(properties['note.priority'], true)
end

T['cell tracking']['tracks file paths'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  -- First three cells (row 4) should have alpha.md path
  expect.equality(cells[1].file_path, 'projects/alpha.md')
  expect.equality(cells[2].file_path, 'projects/alpha.md')
  expect.equality(cells[3].file_path, 'projects/alpha.md')
  -- Next three cells (row 5) should have beta.md path
  expect.equality(cells[4].file_path, 'projects/beta.md')
  expect.equality(cells[5].file_path, 'projects/beta.md')
  expect.equality(cells[6].file_path, 'projects/beta.md')
end

T['cell tracking']['marks note properties as editable'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  for _, cell in ipairs(cells) do
    if cell.property:match('^note%.') then
      expect.equality(cell.editable, true)
    else
      expect.equality(cell.editable, false)
    end
  end
end

T['cell tracking']['stores display text'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  -- Find cell for note.status in first entry
  local status_cell = nil
  for _, cell in ipairs(cells) do
    if cell.property == 'note.status' and cell.file_path == 'projects/alpha.md' then
      status_cell = cell
      break
    end
  end
  expect.equality(status_cell.display_text, 'active')
end

T['cell tracking']['stores raw value'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local cells = vim.b[buf].bases_cells
  -- Find cell for note.priority in first entry
  local priority_cell = nil
  for _, cell in ipairs(cells) do
    if cell.property == 'note.priority' and cell.file_path == 'projects/alpha.md' then
      priority_cell = cell
      break
    end
  end
  expect.equality(priority_cell.raw_value.type, 'primitive')
  expect.equality(priority_cell.raw_value.value, 1)
end

-- =======================
-- render: Header Tracking
-- =======================

T['header tracking'] = new_set()

T['header tracking']['tracks all headers'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local headers = vim.b[buf].bases_headers
  expect.equality(#headers, 3)
end

T['header tracking']['header row is 2 for unicode'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local headers = vim.b[buf].bases_headers
  for _, header in ipairs(headers) do
    expect.equality(header.row, 2)
  end
end

T['header tracking']['header row is 1 for markdown'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local headers = vim.b[buf].bases_headers
  for _, header in ipairs(headers) do
    expect.equality(header.row, 1)
  end
end

T['header tracking']['tracks header positions'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local headers = vim.b[buf].bases_headers
  -- Headers should be in order left to right
  expect.equality(headers[1].col_start < headers[2].col_start, true)
  expect.equality(headers[2].col_start < headers[3].col_start, true)
end

T['header tracking']['tracks property names'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local headers = vim.b[buf].bases_headers
  expect.equality(headers[1].property, 'file.name')
  expect.equality(headers[2].property, 'note.status')
  expect.equality(headers[3].property, 'note.priority')
end

-- =======================
-- render: Sort Icons
-- =======================

T['sort icons'] = new_set()

T['sort icons']['shows ascending icon'] = function()
  local buf = make_buf()
  local data = make_test_data()
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'asc' }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Header line should have ascending icon
  expect.equality(lines[2]:match('▲') ~= nil, true)
end

T['sort icons']['shows descending icon'] = function()
  local buf = make_buf()
  local data = make_test_data()
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'desc' }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Header line should have descending icon
  expect.equality(lines[2]:match('▼') ~= nil, true)
end

T['sort icons']['shows no icon when not sorted'] = function()
  local buf = make_buf()
  local data = make_test_data()
  vim.b[buf].bases_sort = nil

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Header line should have no sort icons
  expect.equality(lines[2]:match('▲') == nil, true)
  expect.equality(lines[2]:match('▼') == nil, true)
end

T['sort icons']['shows icon only for sorted column'] = function()
  local buf = make_buf()
  local data = make_test_data()
  vim.b[buf].bases_sort = { property = 'note.priority', direction = 'asc' }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local header = lines[2]
  -- Count how many times the icon appears
  local _, count = header:gsub('▲', '')
  expect.equality(count, 1) -- Only one icon
end

-- =======================
-- render: Custom Labels
-- =======================

T['custom labels'] = new_set()

T['custom labels']['uses custom label from propertyLabels'] = function()
  local buf = make_buf()
  local data = make_test_data()
  data.propertyLabels = { ['note.status'] = 'Current Status' }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(lines[2]:match('Current Status') ~= nil, true)
end

T['custom labels']['falls back to default when no custom label'] = function()
  local buf = make_buf()
  local data = make_test_data()
  data.propertyLabels = {}

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- Should use default capitalized name
  expect.equality(lines[2]:match('Status') ~= nil, true)
end

T['custom labels']['supports multiple custom labels'] = function()
  local buf = make_buf()
  local data = make_test_data()
  data.propertyLabels = {
    ['note.status'] = 'State',
    ['note.priority'] = 'Importance',
  }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(lines[2]:match('State') ~= nil, true)
  expect.equality(lines[2]:match('Importance') ~= nil, true)
end

-- =======================
-- render: Highlights
-- =======================

T['highlights'] = new_set()

T['highlights']['applies link highlights in unicode mode'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_links')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  -- Should have highlights for links
  expect.equality(#marks > 0, true)
end

T['highlights']['does not apply manual highlights in markdown mode'] = function()
  local buf = make_buf()
  local data = make_test_data()

  render.render(buf, data, true)

  local ns = vim.api.nvim_create_namespace('bases_links')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  -- Should have no manual highlights in markdown mode
  expect.equality(#marks, 0)
end

T['highlights']['applies sorted header highlight when sorted'] = function()
  local buf = make_buf()
  local data = make_test_data()
  vim.b[buf].bases_sort = { property = 'note.status', direction = 'asc' }

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_sorted_header')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  -- Should have highlight for sorted header
  expect.equality(#marks > 0, true)
end

T['highlights']['does not highlight header when not sorted'] = function()
  local buf = make_buf()
  local data = make_test_data()
  vim.b[buf].bases_sort = nil

  render.render(buf, data, false)

  local ns = vim.api.nvim_create_namespace('bases_sorted_header')
  local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
  -- Should have no header highlights
  expect.equality(#marks, 0)
end

-- =======================
-- render: Invalid Data
-- =======================

T['invalid data'] = new_set()

T['invalid data']['shows error when no properties'] = function()
  local buf = make_buf()
  local data = {
    properties = {},
    entries = {},
  }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines, 2)
  expect.equality(lines[2]:match('No properties') ~= nil, true)
end

T['invalid data']['shows error when no entries'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'file.name' },
    entries = {},
  }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  expect.equality(#lines, 2)
  expect.equality(lines[2]:match('No entries') ~= nil, true)
end

T['invalid data']['does not populate buffer vars when invalid'] = function()
  local buf = make_buf()
  local data = {
    properties = {},
    entries = {},
  }

  render.render(buf, data, false)

  -- Buffer vars should not be set for invalid data
  expect.equality(vim.b[buf].bases_links, nil)
  expect.equality(vim.b[buf].bases_cells, nil)
  expect.equality(vim.b[buf].bases_headers, nil)
  expect.equality(vim.b[buf].bases_data, nil)
end

-- =======================
-- render: Sorting
-- =======================

T['sorting'] = new_set()

T['sorting']['applies sort from bases_sort buffer var'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.title', 'note.priority' },
    entries = {
      {
        file = { path = 'a.md', name = 'a.md', basename = 'a' },
        values = {
          ['note.title'] = { type = 'primitive', value = 'Zebra' },
          ['note.priority'] = { type = 'primitive', value = 3 },
        },
      },
      {
        file = { path = 'b.md', name = 'b.md', basename = 'b' },
        values = {
          ['note.title'] = { type = 'primitive', value = 'Apple' },
          ['note.priority'] = { type = 'primitive', value = 1 },
        },
      },
    },
  }
  vim.b[buf].bases_sort = { property = 'note.title', direction = 'asc' }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- First data row (line 4) should have Apple (sorted asc)
  expect.equality(lines[4]:match('Apple') ~= nil, true)
  -- Second data row (line 5) should have Zebra
  expect.equality(lines[5]:match('Zebra') ~= nil, true)
end

T['sorting']['applies descending sort'] = function()
  local buf = make_buf()
  local data = {
    properties = { 'note.priority' },
    entries = {
      {
        file = { path = 'a.md', name = 'a.md', basename = 'a' },
        values = { ['note.priority'] = { type = 'primitive', value = 1 } },
      },
      {
        file = { path = 'b.md', name = 'b.md', basename = 'b' },
        values = { ['note.priority'] = { type = 'primitive', value = 3 } },
      },
    },
  }
  vim.b[buf].bases_sort = { property = 'note.priority', direction = 'desc' }

  render.render(buf, data, false)

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  -- First data row should have higher priority (3)
  expect.equality(lines[4]:match('3') ~= nil, true)
  -- Second data row should have lower priority (1)
  expect.equality(lines[5]:match('1') ~= nil, true)
end

return T
