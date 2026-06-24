local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases module so submit_edit can require it
package.loaded['bases'] = {
  get_config = function()
    return { date_format = '%Y-%m-%d', date_format_relative = false }
  end,
}

-- Stub nvim_list_uis for headless mode (returns empty by default)
-- The edit window code does vim.api.nvim_list_uis()[1] which would be nil
local original_list_uis = vim.api.nvim_list_uis
vim.api.nvim_list_uis = function()
  return { { height = 40, width = 120 } }
end

local edit = require('bases.edit')

-- Track buffers for cleanup
local test_bufs = {}

local T = new_set({
  hooks = {
    post_case = function()
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end
      -- Close any floating windows left open
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(win)
        if config.relative ~= '' then
          pcall(vim.api.nvim_win_close, win, true)
        end
      end
      test_bufs = {}
    end,
  },
})

-- =======================
-- edit_cell opens window with correct pre-fill
-- =======================

T['edit_cell link'] = new_set()

T['edit_cell link']['opens edit window with [[path|display]] pre-fill'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  -- Populate buffer with enough lines to position cursor on row 4
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', '', '', 'cell content' })
  vim.api.nvim_set_current_buf(buf)

  -- Set up a link cell at row 4, col 1-15
  vim.b[buf].bases_cells = {
    {
      row = 4,
      col_start = 1,
      col_end = 15,
      property = 'note.foo',
      file_path = 'note.md',
      editable = true,
      display_text = 'bar',
      raw_value = { type = 'link', value = '[[bar]]', path = 'foo' },
    },
  }

  -- Position cursor on the cell
  vim.api.nvim_win_set_cursor(0, { 4, 0 })

  -- Call edit_cell; this should open a floating window without error
  local ok, err = pcall(edit.edit_cell, buf)
  if not ok then print('err:', err) end
  expect.equality(ok, true)

  -- Find the floating window and check its buffer
  local edit_buf
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= '' then
      edit_buf = vim.api.nvim_win_get_buf(win)
      break
    end
  end
  expect.no_equality(edit_buf, nil)

  local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
  expect.equality(lines[1], '[[foo|bar]]')
end

T['edit_cell link']['opens edit window with [[inner]] when path == inner'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '', '', '', 'cell content' })
  vim.api.nvim_set_current_buf(buf)

  vim.b[buf].bases_cells = {
    {
      row = 4,
      col_start = 1,
      col_end = 10,
      property = 'note.foo',
      file_path = 'note.md',
      editable = true,
      display_text = 'foo',
      raw_value = { type = 'link', value = '[[foo]]', path = 'foo' },
    },
  }

  vim.api.nvim_win_set_cursor(0, { 4, 0 })

  local ok = pcall(edit.edit_cell, buf)
  expect.equality(ok, true)

  local edit_buf
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local config = vim.api.nvim_win_get_config(win)
    if config.relative ~= '' then
      edit_buf = vim.api.nvim_win_get_buf(win)
      break
    end
  end
  expect.no_equality(edit_buf, nil)

  local lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
  expect.equality(lines[1], '[[foo]]')
end

-- =======================
-- get_cell_at_cursor: byte vs display column handling
-- =======================

T['get_cell_at_cursor'] = new_set()

T['get_cell_at_cursor']['finds cell when cursor is on cell text in a row with multi-byte borders'] = function()
  -- Reproduces the "No Link JRR" issue: the cell text is at display
  -- cols 42-45, but `│` borders (3 bytes each) shift the byte column to
  -- 46-49. get_cell_at_cursor must use display columns, not byte columns,
  -- to find the cell.
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  -- Reproduce the actual line from the user's setup:
  -- "│ No Link JRR  ...  │ test           │"
  -- The "test" cell text starts at byte col 46 (display col 42).
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '│ No Link JRR                          │ test           │',
  })
  vim.api.nvim_set_current_buf(buf)

  vim.b[buf].bases_cells = {
    {
      row = 1,
      col_start = 42,  -- display column of 't' of "test"
      col_end = 46,    -- one past 't' (last char of "test")
      property = 'note.authors',
      file_path = 'No Link JRR.md',
      editable = true,
      display_text = 'test',
      raw_value = { type = 'link', value = '[[test]]', path = 'J.R.R. Tolkien' },
    },
  }

  -- Position cursor on 't' of "test" — byte col 46
  vim.api.nvim_win_set_cursor(0, { 1, 45 })  -- 0-indexed byte

  local cell = edit.get_cell_at_cursor(buf)
  expect.no_equality(cell, nil)
  if cell then
    expect.equality(cell.property, 'note.authors')
  end
end

T['get_cell_at_cursor']['finds cell on first char of cell text'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '│ test │',
  })
  vim.api.nvim_set_current_buf(buf)

  vim.b[buf].bases_cells = {
    {
      row = 1,
      col_start = 3,
      col_end = 7,
      property = 'note.foo',
      file_path = 'note.md',
      editable = true,
    },
  }

  -- Cursor on first 't' of "test" (byte col 5, 0-indexed 4).
  -- '│' takes bytes 1-3, ' ' is byte 4, 't' is byte 5.
  vim.api.nvim_win_set_cursor(0, { 1, 4 })

  local cell = edit.get_cell_at_cursor(buf)
  expect.no_equality(cell, nil)
end

T['get_cell_at_cursor']['finds cell on last char of cell text'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '│ test │',
  })
  vim.api.nvim_set_current_buf(buf)

  vim.b[buf].bases_cells = {
    {
      row = 1,
      col_start = 3,
      col_end = 7,
      property = 'note.foo',
      file_path = 'note.md',
      editable = true,
    },
  }

  -- Cursor on last 't' of "test" (byte col 8, 0-indexed 7).
  vim.api.nvim_win_set_cursor(0, { 1, 7 })

  local cell = edit.get_cell_at_cursor(buf)
  expect.no_equality(cell, nil)
end

T['get_cell_at_cursor']['returns nil for cursor between cells'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    '│ test │ other │',
  })
  vim.api.nvim_set_current_buf(buf)

  vim.b[buf].bases_cells = {
    { row = 1, col_start = 3, col_end = 7, property = 'note.a', file_path = 'n.md', editable = true },
    { row = 1, col_start = 10, col_end = 15, property = 'note.b', file_path = 'n.md', editable = true },
  }

  -- Cursor on first '│' border between cells (byte col 9, 0-indexed 8).
  -- '│ test ' is bytes 1-8, '│' starts at byte 9.
  vim.api.nvim_win_set_cursor(0, { 1, 8 })

  local cell = edit.get_cell_at_cursor(buf)
  expect.equality(cell, nil)
end

T['get_cell_at_cursor']['returns nil when no cells'] = function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  table.insert(test_bufs, buf)
  vim.b[buf].bases_cells = nil

  local cell = edit.get_cell_at_cursor(buf)
  expect.equality(cell, nil)
end

-- =======================
-- submit_edit: list preservation
-- =======================

T['submit_edit list'] = new_set()

-- Helper: create a vault, a note with given frontmatter, and a base that
-- queries a list field. Returns {vault, note_path, base_path, engine, render,
-- display} so tests can render and submit edits.
local function setup_list_vault()
  local engine = require('bases.engine')
  -- Reset engine state from any prior test so the new vault starts clean.
  engine.shutdown()

  local vault = vim.fn.tempname()
  vim.fn.mkdir(vault, 'p')

  local note_path = vault .. '/note.md'
  local f = io.open(note_path, 'w')
  f:write('---\n')
  f:write('authors:\n')
  f:write('  - "[[jrrt|J.R.R. Tolkien]]"\n')
  f:write('  - "[[cslewis|C.S. Lewis]]"\n')
  f:write('---\n')
  f:write('# Note\n')
  f:close()

  local base_path = vault .. '/test.base'
  local fb = io.open(base_path, 'w')
  fb:write('properties:\n')
  fb:write('  note.authors:\n')
  fb:write('    displayName: Authors\n')
  fb:write('  file.name:\n')
  fb:write('    displayName: Name\n')
  fb:write('views:\n')
  fb:write('  - type: table\n')
  fb:write('    name: Default\n')
  fb:write('filters: ""\n')
  fb:close()

  engine.set_vault_path(vault)
  return { vault = vault, note_path = note_path, base_path = base_path, engine = engine }
end

-- Read file content into a state cell that the vim.wait polls
local file_content = ''

T['submit_edit list']['preserves list structure when editing'] = function()
  local h = setup_list_vault()

  h.engine.on_ready(function(_)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    table.insert(test_bufs, buf)
    vim.api.nvim_set_current_buf(buf)
    vim.b[buf].bases_path = h.base_path

    local cell = {
      row = 1,
      col_start = 1,
      col_end = 50,
      property = 'note.authors',
      file_path = 'note.md',
      editable = true,
      display_text = 'J.R.R. Tolkien, C.S. Lewis',
      raw_value = {
        type = 'list',
        value = {
          { type = 'link', value = '[[J.R.R. Tolkien]]', path = 'jrrt' },
          { type = 'link', value = '[[C.S. Lewis]]', path = 'cslewis' },
        },
      },
    }

    -- Edit pre-fill format: comma-joined wikilink syntax
    local new_value = '[[jrrt|J.R.R. Tolkien]], [[cslewis|C.S. Lewis]]'

    edit.submit_edit(buf, cell, new_value, function(_) end)
  end)

  -- Wait until the file is rewritten as a list
  vim.wait(5000, function()
    local f = io.open(h.note_path, 'r')
    if not f then return false end
    file_content = f:read('*a') or ''
    f:close()
    return file_content:find('authors:\n', 1, true) ~= nil
      and file_content:find('  - "[[jrrt|J.R.R. Tolkien]]', 1, true) ~= nil
  end)

  -- Verify the file has list structure, not a string
  expect.no_equality(file_content:find('authors:\n', 1, true), nil)
  expect.no_equality(file_content:find('  - "[[jrrt|J.R.R. Tolkien]]', 1, true), nil)
  expect.no_equality(file_content:find('  - "[[cslewis|C.S. Lewis]]', 1, true), nil)
  -- Make sure it is NOT a string
  expect.equality(file_content:find('authors: "[[', 1, true), nil)
end

T['submit_edit list']['handles single-item list'] = function()
  local h = setup_list_vault()

  h.engine.on_ready(function(_)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    table.insert(test_bufs, buf)
    vim.api.nvim_set_current_buf(buf)
    vim.b[buf].bases_path = h.base_path

    local cell = {
      row = 1,
      col_start = 1,
      col_end = 50,
      property = 'note.authors',
      file_path = 'note.md',
      editable = true,
      display_text = 'J.R.R. Tolkien',
      raw_value = {
        type = 'list',
        value = {
          { type = 'link', value = '[[J.R.R. Tolkien]]', path = 'jrrt' },
        },
      },
    }

    -- Single item (no commas)
    local new_value = '[[jrrt|J.R.R. Tolkien]]'

    edit.submit_edit(buf, cell, new_value, function(_) end)
  end)

  local content = ''
  vim.wait(5000, function()
    local f = io.open(h.note_path, 'r')
    if not f then return false end
    content = f:read('*a') or ''
    f:close()
    return content:find('  - "[[jrrt|J.R.R. Tolkien]]', 1, true) ~= nil
  end)

  expect.no_equality(content:find('authors:\n', 1, true), nil)
  expect.no_equality(content:find('  - "[[jrrt|J.R.R. Tolkien]]', 1, true), nil)
end

T['submit_edit list']['preserves link as string for non-list fields'] = function()
  -- Regression test: link fields (not lists) should still save as a
  -- single string, not be parsed as a list.
  local h = setup_list_vault()

  h.engine.on_ready(function(_)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    table.insert(test_bufs, buf)
    vim.api.nvim_set_current_buf(buf)
    vim.b[buf].bases_path = h.base_path

    local cell = {
      row = 1,
      col_start = 1,
      col_end = 50,
      property = 'note.foo',
      file_path = 'note.md',
      editable = true,
      display_text = 'bar',
      raw_value = { type = 'link', value = '[[bar]]', path = 'foo' },
    }

    local new_value = '[[foo|newbar]]'

    edit.submit_edit(buf, cell, new_value, function(_) end)
  end)

  local content = ''
  vim.wait(5000, function()
    local f = io.open(h.note_path, 'r')
    if not f then return false end
    content = f:read('*a') or ''
    f:close()
    return content:find('foo:') ~= nil
  end)

  -- Should be a string, NOT a list
  expect.no_equality(content:find('foo: "%[%[foo|newbar%]%]"'), nil)
end

return T
