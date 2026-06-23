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
-- display_name
-- =======================

T['display_name'] = new_set()

T['display_name']['with custom label'] = function()
  local labels = { ['note.status'] = 'Status' }
  local result = render.display_name('note.status', labels)
  expect.equality(result, 'Status')
end

T['display_name']['without label extracts after last dot'] = function()
  local result = render.display_name('file.name', nil)
  expect.equality(result, 'Name')
end

T['display_name']['note.status without label'] = function()
  local result = render.display_name('note.status', nil)
  expect.equality(result, 'Status')
end

T['display_name']['formula.total without label'] = function()
  local result = render.display_name('formula.total', nil)
  expect.equality(result, 'Total')
end

T['display_name']['no dots capitalizes first letter'] = function()
  local result = render.display_name('priority', nil)
  expect.equality(result, 'Priority')
end

T['display_name']['single letter property'] = function()
  local result = render.display_name('x', nil)
  expect.equality(result, 'X')
end

T['display_name']['multiple dots uses last segment'] = function()
  local result = render.display_name('deeply.nested.property', nil)
  expect.equality(result, 'Property')
end

T['display_name']['custom label overrides extraction'] = function()
  local labels = { ['file.name'] = 'Custom Name' }
  local result = render.display_name('file.name', labels)
  expect.equality(result, 'Custom Name')
end

-- =======================
-- value_text
-- =======================

T['value_text'] = new_set()

T['value_text']['nil value'] = function()
  local text, links = render.value_text(nil)
  expect.equality(text, '')
  expect.equality(#links, 0)
end

T['value_text']['null type'] = function()
  local text, links = render.value_text({ type = 'null' })
  expect.equality(text, '')
  expect.equality(#links, 0)
end

T['value_text']['primitive string'] = function()
  local text, links = render.value_text({ type = 'primitive', value = 'active' })
  expect.equality(text, 'active')
  expect.equality(#links, 0)
end

T['value_text']['primitive number'] = function()
  local text, links = render.value_text({ type = 'primitive', value = 42 })
  expect.equality(text, '42')
  expect.equality(#links, 0)
end

T['value_text']['primitive number decimal'] = function()
  local text, links = render.value_text({ type = 'primitive', value = 3.14 })
  expect.equality(text, '3.14')
  expect.equality(#links, 0)
end

T['value_text']['primitive boolean true'] = function()
  local text, links = render.value_text({ type = 'primitive', value = true })
  expect.equality(text, 'Yes')
  expect.equality(#links, 0)
end

T['value_text']['primitive boolean false'] = function()
  local text, links = render.value_text({ type = 'primitive', value = false })
  expect.equality(text, 'No')
  expect.equality(#links, 0)
end

T['value_text']['primitive nil value'] = function()
  local text, links = render.value_text({ type = 'primitive', value = nil })
  expect.equality(text, '')
  expect.equality(#links, 0)
end

T['value_text']['link shows inner text with embedded link'] = function()
  local text, links = render.value_text({ type = 'link', value = '[[alpha]]', path = 'projects/alpha.md' })
  expect.equality(text, 'alpha')
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'projects/alpha.md')
  expect.equality(links[1].offset, 1)
  expect.equality(links[1].length, #('alpha'))
end

T['value_text']['link keep_brackets is now no-op'] = function()
  local text_default, links_default = render.value_text({ type = 'link', value = '[[alpha]]', path = 'projects/alpha.md' })
  local text_keep, links_keep = render.value_text({ type = 'link', value = '[[alpha]]', path = 'projects/alpha.md' }, true)
  expect.equality(text_default, text_keep)
  expect.equality(text_default, 'alpha')
  expect.equality(#links_default, 1)
  expect.equality(#links_keep, 1)
  expect.equality(links_default[1].path, links_keep[1].path)
end

T['value_text']['link with display text shows only display portion'] = function()
  -- Engine strips path|Display into val.path + [[Display]] before serialization.
  -- The renderer just extracts the inner content of [[...]].
  local text, links = render.value_text({ type = 'link', value = '[[Alpha Project]]', path = 'projects/alpha.md' })
  expect.equality(text, 'Alpha Project')
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'projects/alpha.md')
  expect.equality(links[1].offset, 1)
  expect.equality(links[1].length, #('Alpha Project'))
end

T['value_text']['link keep_brackets with display text is also no-op'] = function()
  local text, links = render.value_text({ type = 'link', value = '[[Alpha Project]]', path = 'projects/alpha.md' }, true)
  expect.equality(text, 'Alpha Project')
  expect.equality(#links, 1)
end

T['value_text']['link with no brackets fallback'] = function()
  local text, links = render.value_text({ type = 'link', value = 'plain text', path = 'note.md' })
  expect.equality(text, 'plain text')
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'note.md')
  expect.equality(links[1].offset, 1)
  expect.equality(links[1].length, #('plain text'))
end

T['value_text']['date returns formatted string'] = function()
  -- 2025-01-15 00:00:00 UTC
  local timestamp_ms = 1736899200000
  local text, links = render.value_text({ type = 'date', value = timestamp_ms, iso = '2025-01-15' })
  expect.equality(type(text), 'string')
  expect.no_equality(text, '')
  expect.equality(#links, 0)
end

T['value_text']['date uses config format'] = function()
  local timestamp_ms = 1736899200000
  local text, links = render.value_text({ type = 'date', value = timestamp_ms, iso = '2025-01-15' })
  -- With date_format = '%Y-%m-%d', should produce something like 2025-01-15
  expect.no_equality(text:find('2025', 1, true), nil)
  expect.equality(#links, 0)
end

T['value_text']['list empty'] = function()
  local text, links = render.value_text({ type = 'list', value = {} })
  expect.equality(text, '')
  expect.equality(#links, 0)
end

T['value_text']['list with primitives'] = function()
  local list_val = {
    type = 'list',
    value = {
      { type = 'primitive', value = 'one' },
      { type = 'primitive', value = 'two' },
      { type = 'primitive', value = 'three' },
    },
  }
  local text, links = render.value_text(list_val)
  expect.equality(text, 'one, two, three')
  expect.equality(#links, 0)
end

T['value_text']['list with links tracks each embedded link'] = function()
  local list_val = {
    type = 'list',
    value = {
      { type = 'link', value = '[[alpha]]', path = 'alpha.md' },
      { type = 'link', value = '[[beta]]', path = 'beta.md' },
    },
  }
  local text, links = render.value_text(list_val)
  expect.equality(text, 'alpha, beta')
  expect.equality(#links, 2)
  expect.equality(links[1].path, 'alpha.md')
  expect.equality(links[1].offset, 1)
  expect.equality(links[1].length, #('alpha'))
  expect.equality(links[2].path, 'beta.md')
  -- Second link starts after "alpha, " (5 + 2 = 7)
  expect.equality(links[2].offset, 1 + #('alpha, '))
  expect.equality(links[2].length, #('beta'))
end

T['value_text']['list keep_brackets is also no-op'] = function()
  local list_val = {
    type = 'list',
    value = {
      { type = 'link', value = '[[alpha]]', path = 'alpha.md' },
      { type = 'link', value = '[[beta]]', path = 'beta.md' },
    },
  }
  local text, links = render.value_text(list_val, true)
  expect.equality(text, 'alpha, beta')
  expect.equality(#links, 2)
end

T['value_text']['list with link and plain tracks only the link'] = function()
  local list_val = {
    type = 'list',
    value = {
      { type = 'link', value = '[[qux]]', path = 'qux.md' },
      { type = 'primitive', value = 'quux' },
    },
  }
  local text, links = render.value_text(list_val)
  expect.equality(text, 'qux, quux')
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'qux.md')
  expect.equality(links[1].offset, 1)
  expect.equality(links[1].length, #('qux'))
  -- 'quux' is plain text, no link entry
end

T['value_text']['list with plain then link offsets correctly'] = function()
  local list_val = {
    type = 'list',
    value = {
      { type = 'primitive', value = 'foo' },
      { type = 'link', value = '[[bar]]', path = 'bar.md' },
    },
  }
  local text, links = render.value_text(list_val)
  expect.equality(text, 'foo, bar')
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'bar.md')
  -- bar starts after "foo, " (3 + 2 = 5)
  expect.equality(links[1].offset, 1 + #('foo, '))
  expect.equality(links[1].length, #('bar'))
end

T['value_text']['list with mixed types joins primitives only'] = function()
  local list_val = {
    type = 'list',
    value = {
      { type = 'primitive', value = 42 },
      { type = 'primitive', value = 'text' },
      { type = 'primitive', value = true },
    },
  }
  local text, links = render.value_text(list_val)
  expect.equality(text, '42, text, Yes')
  expect.equality(#links, 0)
end

T['value_text']['image'] = function()
  local text, links = render.value_text({ type = 'image', value = 'img.png' })
  expect.equality(text, 'img.png')
  expect.equality(#links, 0)
end

-- =======================
-- horizontal_line
-- =======================

T['horizontal_line'] = new_set()

T['horizontal_line']['builds border with widths'] = function()
  local result = render.horizontal_line({ 5, 3 }, '╭', '┬', '╮')
  expect.equality(result, '╭─────┬───╮')
end

T['horizontal_line']['single column'] = function()
  local result = render.horizontal_line({ 10 }, '╭', '┬', '╮')
  expect.equality(result, '╭──────────╮')
end

T['horizontal_line']['three columns'] = function()
  local result = render.horizontal_line({ 4, 6, 5 }, '├', '┼', '┤')
  expect.equality(result, '├────┼──────┼─────┤')
end

T['horizontal_line']['varying widths'] = function()
  local result = render.horizontal_line({ 2, 10, 3, 7 }, '╰', '┴', '╯')
  expect.equality(result, '╰──┴──────────┴───┴───────╯')
end

-- =======================
-- row
-- =======================

T['row'] = new_set()

T['row']['builds data row with padding'] = function()
  local result = render.row({ 'abc', 'de' }, { 5, 4 })
  expect.equality(result, '│ abc │ de │')
end

T['row']['single cell'] = function()
  local result = render.row({ 'test' }, { 8 })
  expect.equality(result, '│ test   │')
end

T['row']['multiple cells'] = function()
  local result = render.row({ 'A', 'B', 'C' }, { 3, 3, 3 })
  expect.equality(result, '│ A │ B │ C │')
end

T['row']['empty string cells'] = function()
  local result = render.row({ '', 'text', '' }, { 4, 6, 4 })
  expect.equality(result, '│    │ text │    │')
end

T['row']['text at exact width'] = function()
  -- Width 6 with 2-char padding = 4 chars for content
  local result = render.row({ 'abcd' }, { 6 })
  expect.equality(result, '│ abcd │')
end

-- =======================
-- sort_entries
-- =======================

T['sort_entries'] = new_set()

T['sort_entries']['ascending by number'] = function()
  local entries = {
    { values = { priority = { type = 'primitive', value = 3 } } },
    { values = { priority = { type = 'primitive', value = 1 } } },
    { values = { priority = { type = 'primitive', value = 2 } } },
  }
  local sorted = render.sort_entries(entries, 'priority', 'asc')
  expect.equality(sorted[1].values.priority.value, 1)
  expect.equality(sorted[2].values.priority.value, 2)
  expect.equality(sorted[3].values.priority.value, 3)
end

T['sort_entries']['descending by number'] = function()
  local entries = {
    { values = { priority = { type = 'primitive', value = 1 } } },
    { values = { priority = { type = 'primitive', value = 3 } } },
    { values = { priority = { type = 'primitive', value = 2 } } },
  }
  local sorted = render.sort_entries(entries, 'priority', 'desc')
  expect.equality(sorted[1].values.priority.value, 3)
  expect.equality(sorted[2].values.priority.value, 2)
  expect.equality(sorted[3].values.priority.value, 1)
end

T['sort_entries']['ascending by string'] = function()
  local entries = {
    { values = { name = { type = 'primitive', value = 'Charlie' } } },
    { values = { name = { type = 'primitive', value = 'Alice' } } },
    { values = { name = { type = 'primitive', value = 'Bob' } } },
  }
  local sorted = render.sort_entries(entries, 'name', 'asc')
  expect.equality(sorted[1].values.name.value, 'Alice')
  expect.equality(sorted[2].values.name.value, 'Bob')
  expect.equality(sorted[3].values.name.value, 'Charlie')
end

T['sort_entries']['descending by string'] = function()
  local entries = {
    { values = { name = { type = 'primitive', value = 'Alice' } } },
    { values = { name = { type = 'primitive', value = 'Charlie' } } },
    { values = { name = { type = 'primitive', value = 'Bob' } } },
  }
  local sorted = render.sort_entries(entries, 'name', 'desc')
  expect.equality(sorted[1].values.name.value, 'Charlie')
  expect.equality(sorted[2].values.name.value, 'Bob')
  expect.equality(sorted[3].values.name.value, 'Alice')
end

T['sort_entries']['null values sort to end ascending'] = function()
  local entries = {
    { values = { priority = { type = 'primitive', value = 2 } } },
    { values = { priority = { type = 'null' } } },
    { values = { priority = { type = 'primitive', value = 1 } } },
  }
  local sorted = render.sort_entries(entries, 'priority', 'asc')
  expect.equality(sorted[1].values.priority.value, 1)
  expect.equality(sorted[2].values.priority.value, 2)
  expect.equality(sorted[3].values.priority.type, 'null')
end

T['sort_entries']['null values sort to end descending'] = function()
  local entries = {
    { values = { priority = { type = 'primitive', value = 1 } } },
    { values = { priority = { type = 'null' } } },
    { values = { priority = { type = 'primitive', value = 3 } } },
  }
  local sorted = render.sort_entries(entries, 'priority', 'desc')
  expect.equality(sorted[1].values.priority.value, 3)
  expect.equality(sorted[2].values.priority.value, 1)
  expect.equality(sorted[3].values.priority.type, 'null')
end

T['sort_entries']['missing values treated as null'] = function()
  local entries = {
    { values = { priority = { type = 'primitive', value = 2 } } },
    { values = {} },
    { values = { priority = { type = 'primitive', value = 1 } } },
  }
  local sorted = render.sort_entries(entries, 'priority', 'asc')
  expect.equality(sorted[1].values.priority.value, 1)
  expect.equality(sorted[2].values.priority.value, 2)
  expect.equality(sorted[3].values.priority, nil)
end

T['sort_entries']['mixed types ascending numbers before strings'] = function()
  local entries = {
    { values = { val = { type = 'primitive', value = 'text' } } },
    { values = { val = { type = 'primitive', value = 42 } } },
    { values = { val = { type = 'primitive', value = 10 } } },
  }
  local sorted = render.sort_entries(entries, 'val', 'asc')
  expect.equality(sorted[1].values.val.value, 10)
  expect.equality(sorted[2].values.val.value, 42)
  expect.equality(sorted[3].values.val.value, 'text')
end

T['sort_entries']['mixed types descending strings before numbers'] = function()
  local entries = {
    { values = { val = { type = 'primitive', value = 42 } } },
    { values = { val = { type = 'primitive', value = 'text' } } },
    { values = { val = { type = 'primitive', value = 10 } } },
  }
  local sorted = render.sort_entries(entries, 'val', 'desc')
  expect.equality(sorted[1].values.val.value, 'text')
  expect.equality(sorted[2].values.val.value, 42)
  expect.equality(sorted[3].values.val.value, 10)
end

T['sort_entries']['mixed types numbers before strings before booleans ascending'] = function()
  local entries = {
    { values = { val = { type = 'primitive', value = true } } },
    { values = { val = { type = 'primitive', value = 'text' } } },
    { values = { val = { type = 'primitive', value = 42 } } },
  }
  local sorted = render.sort_entries(entries, 'val', 'asc')
  expect.equality(sorted[1].values.val.value, 42)
  expect.equality(sorted[2].values.val.value, 'text')
  expect.equality(sorted[3].values.val.value, true)
end

T['sort_entries']['does not modify original'] = function()
  local entries = {
    { values = { priority = { type = 'primitive', value = 3 } } },
    { values = { priority = { type = 'primitive', value = 1 } } },
    { values = { priority = { type = 'primitive', value = 2 } } },
  }
  local original_first = entries[1].values.priority.value
  local sorted = render.sort_entries(entries, 'priority', 'asc')
  expect.equality(entries[1].values.priority.value, original_first)
  expect.equality(sorted[1].values.priority.value, 1)
end

T['sort_entries']['boolean false before true ascending'] = function()
  local entries = {
    { values = { flag = { type = 'primitive', value = true } } },
    { values = { flag = { type = 'primitive', value = false } } },
  }
  local sorted = render.sort_entries(entries, 'flag', 'asc')
  expect.equality(sorted[1].values.flag.value, false)
  expect.equality(sorted[2].values.flag.value, true)
end

T['sort_entries']['boolean true before false descending'] = function()
  local entries = {
    { values = { flag = { type = 'primitive', value = false } } },
    { values = { flag = { type = 'primitive', value = true } } },
  }
  local sorted = render.sort_entries(entries, 'flag', 'desc')
  expect.equality(sorted[1].values.flag.value, true)
  expect.equality(sorted[2].values.flag.value, false)
end

T['sort_entries']['date by timestamp'] = function()
  local entries = {
    { values = { date = { type = 'date', value = 1736899200000 } } },
    { values = { date = { type = 'date', value = 1704067200000 } } },
    { values = { date = { type = 'date', value = 1720224000000 } } },
  }
  local sorted = render.sort_entries(entries, 'date', 'asc')
  expect.equality(sorted[1].values.date.value, 1704067200000)
  expect.equality(sorted[2].values.date.value, 1720224000000)
  expect.equality(sorted[3].values.date.value, 1736899200000)
end

T['sort_entries']['link by display text'] = function()
  local entries = {
    { values = { note = { type = 'link', value = '[[charlie]]', path = 'charlie.md' } } },
    { values = { note = { type = 'link', value = '[[alice]]', path = 'alice.md' } } },
    { values = { note = { type = 'link', value = '[[bob]]', path = 'bob.md' } } },
  }
  local sorted = render.sort_entries(entries, 'note', 'asc')
  expect.equality(sorted[1].values.note.value, '[[alice]]')
  expect.equality(sorted[2].values.note.value, '[[bob]]')
  expect.equality(sorted[3].values.note.value, '[[charlie]]')
end

T['sort_entries']['list by first item'] = function()
  local entries = {
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'zebra' } } } } },
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'apple' } } } } },
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'mango' } } } } },
  }
  local sorted = render.sort_entries(entries, 'tags', 'asc')
  expect.equality(sorted[1].values.tags.value[1].value, 'apple')
  expect.equality(sorted[2].values.tags.value[1].value, 'mango')
  expect.equality(sorted[3].values.tags.value[1].value, 'zebra')
end

T['sort_entries']['empty list sorts as null'] = function()
  local entries = {
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'beta' } } } } },
    { values = { tags = { type = 'list', value = {} } } },
    { values = { tags = { type = 'list', value = { { type = 'primitive', value = 'alpha' } } } } },
  }
  local sorted = render.sort_entries(entries, 'tags', 'asc')
  expect.equality(sorted[1].values.tags.value[1].value, 'alpha')
  expect.equality(sorted[2].values.tags.value[1].value, 'beta')
  expect.equality(#sorted[3].values.tags.value, 0)
end

-- =======================
-- render_unicode_table
-- =======================

T['render_unicode_table'] = new_set()

T['render_unicode_table']['basic table structure'] = function()
  local properties = { 'file.name', 'note.status' }
  local entries = {
    {
      file = { path = 'note1.md' },
      values = {
        ['file.name'] = { type = 'primitive', value = 'Note 1' },
        ['note.status'] = { type = 'primitive', value = 'Active' },
      },
    },
  }
  local lines, links, cells, headers, has_summaries = render.render_unicode_table(properties, entries, nil, nil, nil)

  -- Check line count: top border + header + separator + 1 data row + bottom border = 5
  expect.equality(#lines, 5)

  -- Check first line is top border
  expect.no_equality(lines[1]:find('╭', 1, true), nil)
  expect.no_equality(lines[1]:find('╮', 1, true), nil)

  -- Check last line is bottom border
  expect.no_equality(lines[5]:find('╰', 1, true), nil)
  expect.no_equality(lines[5]:find('╯', 1, true), nil)

  -- Check headers
  expect.equality(#headers, 2)
  expect.equality(headers[1].property, 'file.name')
  expect.equality(headers[2].property, 'note.status')
  expect.equality(headers[1].row, 2)

  -- Check cells
  expect.equality(#cells, 2)

  -- Check no summaries
  expect.equality(has_summaries, false)
end

T['render_unicode_table']['multiple entries'] = function()
  local properties = { 'file.name' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['file.name'] = { type = 'primitive', value = 'A' } } },
    { file = { path = 'b.md' }, values = { ['file.name'] = { type = 'primitive', value = 'B' } } },
    { file = { path = 'c.md' }, values = { ['file.name'] = { type = 'primitive', value = 'C' } } },
  }
  local lines = render.render_unicode_table(properties, entries, nil, nil, nil)

  -- top + header + sep + 3 data rows + bottom = 7
  expect.equality(#lines, 7)
end

T['render_unicode_table']['tracks links'] = function()
  local properties = { 'note.related' }
  local entries = {
    {
      file = { path = 'note1.md' },
      values = {
        ['note.related'] = { type = 'link', value = '[[other]]', path = 'other.md' },
      },
    },
  }
  local lines, links = render.render_unicode_table(properties, entries, nil, nil, nil)

  expect.equality(#links, 1)
  expect.equality(links[1].path, 'other.md')
  expect.equality(links[1].text, 'other')
  expect.equality(links[1].row, 4)  -- top + header + sep + data row
end

T['render_unicode_table']['tracks cells with editability'] = function()
  local properties = { 'file.name', 'note.status' }
  local entries = {
    {
      file = { path = 'note1.md' },
      values = {
        ['file.name'] = { type = 'primitive', value = 'Note 1' },
        ['note.status'] = { type = 'primitive', value = 'Active' },
      },
    },
  }
  local lines, links, cells = render.render_unicode_table(properties, entries, nil, nil, nil)

  expect.equality(#cells, 2)

  -- file.name is not editable
  expect.equality(cells[1].property, 'file.name')
  expect.equality(cells[1].editable, false)
  expect.equality(cells[1].file_path, 'note1.md')

  -- note.status is editable
  expect.equality(cells[2].property, 'note.status')
  expect.equality(cells[2].editable, true)
  expect.equality(cells[2].file_path, 'note1.md')
end

T['render_unicode_table']['with custom labels'] = function()
  local properties = { 'note.status' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['note.status'] = { type = 'primitive', value = 'Done' } } },
  }
  local labels = { ['note.status'] = 'Custom Status' }
  local lines = render.render_unicode_table(properties, entries, nil, labels, nil)

  -- Header should contain custom label
  expect.no_equality(lines[2]:find('Custom Status', 1, true), nil)
end

T['render_unicode_table']['with sort state shows icon'] = function()
  local properties = { 'note.priority' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['note.priority'] = { type = 'primitive', value = 1 } } },
  }
  local sort_state = { property = 'note.priority', direction = 'asc' }
  local lines = render.render_unicode_table(properties, entries, sort_state, nil, nil)

  -- Header should contain sort icon (▲)
  expect.no_equality(lines[2]:find('▲', 1, true), nil)
end

T['render_unicode_table']['with summaries'] = function()
  local properties = { 'note.value' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['note.value'] = { type = 'primitive', value = 10 } } },
  }
  local summaries = {
    ['note.value'] = {
      label = 'Total',
      value = { type = 'primitive', value = 10 },
    },
  }
  local lines, links, cells, headers, has_summaries = render.render_unicode_table(properties, entries, nil, nil, summaries)

  expect.equality(has_summaries, true)
  -- top + header + sep + 1 data + bottom + summary = 6
  expect.equality(#lines, 6)
  -- Summary line should contain label
  expect.no_equality(lines[6]:find('Total', 1, true), nil)
  expect.no_equality(lines[6]:find('10', 1, true), nil)
end

T['render_unicode_table']['empty entries'] = function()
  local properties = { 'file.name' }
  local entries = {}
  local lines = render.render_unicode_table(properties, entries, nil, nil, nil)

  -- top + header + sep + bottom = 4
  expect.equality(#lines, 4)
end

-- =======================
-- render_markdown_table
-- =======================

T['render_markdown_table'] = new_set()

T['render_markdown_table']['basic table structure'] = function()
  local properties = { 'file.name', 'note.status' }
  local entries = {
    {
      file = { path = 'note1.md' },
      values = {
        ['file.name'] = { type = 'primitive', value = 'Note 1' },
        ['note.status'] = { type = 'primitive', value = 'Active' },
      },
    },
  }
  local lines, links, cells, headers, has_summaries = render.render_markdown_table(properties, entries, nil, nil, nil)

  -- header + separator + 1 data row = 3
  expect.equality(#lines, 3)

  -- Check first line is header with pipes
  expect.no_equality(lines[1]:find('|', 1, true), nil)

  -- Check second line is separator with dashes
  expect.no_equality(lines[2]:find('-', 1, true), nil)

  -- Check headers (row 1 in markdown mode)
  expect.equality(#headers, 2)
  expect.equality(headers[1].row, 1)

  -- Check no summaries
  expect.equality(has_summaries, false)
end

T['render_markdown_table']['strips link brackets like unicode mode'] = function()
  local properties = { 'note.related' }
  local entries = {
    {
      file = { path = 'note1.md' },
      values = {
        ['note.related'] = { type = 'link', value = '[[other]]', path = 'other.md' },
      },
    },
  }
  local lines, links = render.render_markdown_table(properties, entries, nil, nil, nil)

  -- Markdown mode also strips brackets (consistency with unicode mode).
  -- render-markdown.nvim handles wikilink syntax via markdown's link rendering.
  expect.no_equality(lines[3]:find('| other ', 1, true), nil)
  expect.equality(lines[3]:find('[[', 1, true), nil)

  -- Links still tracked
  expect.equality(#links, 1)
  expect.equality(links[1].path, 'other.md')
end

T['render_markdown_table']['multiple entries'] = function()
  local properties = { 'file.name' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['file.name'] = { type = 'primitive', value = 'A' } } },
    { file = { path = 'b.md' }, values = { ['file.name'] = { type = 'primitive', value = 'B' } } },
  }
  local lines = render.render_markdown_table(properties, entries, nil, nil, nil)

  -- header + sep + 2 data rows = 4
  expect.equality(#lines, 4)
end

T['render_markdown_table']['with summaries'] = function()
  local properties = { 'note.value' }
  local entries = {
    { file = { path = 'a.md' }, values = { ['note.value'] = { type = 'primitive', value = 5 } } },
  }
  local summaries = {
    ['note.value'] = {
      label = 'Sum',
      value = { type = 'primitive', value = 5 },
    },
  }
  local lines, links, cells, headers, has_summaries = render.render_markdown_table(properties, entries, nil, nil, summaries)

  expect.equality(has_summaries, true)
  -- header + sep + 1 data + summary = 4
  expect.equality(#lines, 4)
  expect.no_equality(lines[4]:find('Sum', 1, true), nil)
end

T['render_markdown_table']['list with links strips brackets'] = function()
  local properties = { 'note.tags' }
  local list_val = {
    type = 'list',
    value = {
      { type = 'link', value = '[[tag1]]', path = 'tag1.md' },
      { type = 'link', value = '[[tag2]]', path = 'tag2.md' },
    },
  }
  local entries = {
    { file = { path = 'a.md' }, values = { ['note.tags'] = list_val } },
  }
  local lines, links = render.render_markdown_table(properties, entries, nil, nil, nil)

  expect.no_equality(lines[3]:find('| tag1, tag2 ', 1, true), nil)
  expect.equality(lines[3]:find('[[', 1, true), nil)

  -- Both links tracked
  expect.equality(#links, 2)
  expect.equality(links[1].path, 'tag1.md')
  expect.equality(links[2].path, 'tag2.md')
end

return T
