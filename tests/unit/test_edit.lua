local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local edit = require('bases.edit')

local T = new_set()

-- =======================
-- get_edit_value: link cells
-- =======================

T['get_edit_value link'] = new_set()

T['get_edit_value link']['[[foo|bar]] reconstructs to [[foo|bar]]'] = function()
  -- Engine strips the path during serialization, so the cell stores
  -- val.value="[[bar]]" with val.path="foo". The pre-fill should
  -- reconstruct the original [[foo|bar]] so the user can edit both
  -- the path and the display.
  local cell = {
    property = 'note.foo',
    raw_value = { type = 'link', value = '[[bar]]', path = 'foo' },
  }
  expect.equality(edit.get_edit_value(cell), '[[foo|bar]]')
end

T['get_edit_value link']['[[foo]] (no display) keeps as [[foo]]'] = function()
  -- When path == inner text, the original had no display portion.
  -- The pre-fill should NOT add a redundant |foo.
  local cell = {
    property = 'note.foo',
    raw_value = { type = 'link', value = '[[foo]]', path = 'foo' },
  }
  expect.equality(edit.get_edit_value(cell), '[[foo]]')
end

T['get_edit_value link']['link without brackets keeps as is'] = function()
  -- Fallback: link value with no [[...]] wrapping (defensive).
  local cell = {
    property = 'note.foo',
    raw_value = { type = 'link', value = 'plain text', path = 'note.md' },
  }
  expect.equality(edit.get_edit_value(cell), 'plain text')
end

T['get_edit_value link']['missing path falls back to val.value'] = function()
  local cell = {
    property = 'note.foo',
    raw_value = { type = 'link', value = '[[bar]]', path = nil },
  }
  expect.equality(edit.get_edit_value(cell), '[[bar]]')
end

-- =======================
-- get_edit_value: list cells with link items
-- =======================

T['get_edit_value list'] = new_set()

T['get_edit_value list']['list with link items reconstructs each [[path|display]]'] = function()
  local cell = {
    property = 'note.authors',
    raw_value = {
      type = 'list',
      value = {
        { type = 'link', value = '[[J.R.R. Tolkien]]', path = 'jrrt' },
        { type = 'link', value = '[[C.S. Lewis]]', path = 'cslewis' },
      },
    },
  }
  expect.equality(edit.get_edit_value(cell), '[[jrrt|J.R.R. Tolkien]], [[cslewis|C.S. Lewis]]')
end

T['get_edit_value list']['mixed link and primitive items'] = function()
  -- Link item keeps [[...]] brackets so the user can edit the full syntax.
  local cell = {
    property = 'note.refs',
    raw_value = {
      type = 'list',
      value = {
        { type = 'link', value = '[[qux]]', path = 'qux' },
        { type = 'primitive', value = 'plain' },
      },
    },
  }
  expect.equality(edit.get_edit_value(cell), '[[qux]], plain')
end

T['get_edit_value list']['link item without path keeps [[inner]]'] = function()
  local cell = {
    property = 'note.refs',
    raw_value = {
      type = 'list',
      value = {
        { type = 'link', value = '[[qux]]', path = 'qux' },
      },
    },
  }
  expect.equality(edit.get_edit_value(cell), '[[qux]]')
end

-- =======================
-- get_edit_value: other types
-- =======================

T['get_edit_value other'] = new_set()

T['get_edit_value other']['nil raw returns empty string'] = function()
  local cell = { property = 'note.foo' }
  expect.equality(edit.get_edit_value(cell), '')
end

T['get_edit_value other']['null type returns empty string'] = function()
  local cell = { property = 'note.foo', raw_value = { type = 'null' } }
  expect.equality(edit.get_edit_value(cell), '')
end

T['get_edit_value other']['primitive string'] = function()
  local cell = { property = 'note.foo', raw_value = { type = 'primitive', value = 'hello' } }
  expect.equality(edit.get_edit_value(cell), 'hello')
end

T['get_edit_value other']['primitive number'] = function()
  local cell = { property = 'note.foo', raw_value = { type = 'primitive', value = 42 } }
  expect.equality(edit.get_edit_value(cell), '42')
end

T['get_edit_value other']['primitive boolean true'] = function()
  local cell = { property = 'note.foo', raw_value = { type = 'primitive', value = true } }
  expect.equality(edit.get_edit_value(cell), 'true')
end

T['get_edit_value other']['primitive boolean false'] = function()
  local cell = { property = 'note.foo', raw_value = { type = 'primitive', value = false } }
  expect.equality(edit.get_edit_value(cell), 'false')
end

T['get_edit_value other']['primitive nil value'] = function()
  local cell = { property = 'note.foo', raw_value = { type = 'primitive', value = nil } }
  expect.equality(edit.get_edit_value(cell), '')
end

return T
