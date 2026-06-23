local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local detect = require('bases.inline.detect')

local T = new_set()

-- =======================
-- parse_source
-- =======================

T['parse_source'] = new_set()

T['parse_source']['without view selector returns base name and nil'] = function()
  local base_name, view_name = detect.parse_source('Content.base')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, nil)
end

T['parse_source']['with view selector returns base name and view name'] = function()
  local base_name, view_name = detect.parse_source('Content.base#Author')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, 'Author')
end

T['parse_source']['view name with spaces is preserved'] = function()
  local base_name, view_name = detect.parse_source('Content.base#Active Projects')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, 'Active Projects')
end

T['parse_source']['splits on the first hash only'] = function()
  -- A second `#` in the source belongs to the view name itself
  local base_name, view_name = detect.parse_source('Content.base#A#B')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, 'A#B')
end

T['parse_source']['empty view after hash is treated as no view'] = function()
  local base_name, view_name = detect.parse_source('Content.base#')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, nil)
end

T['parse_source']['hash only with empty base is invalid'] = function()
  local base_name, view_name = detect.parse_source('#view')
  expect.equality(base_name, nil)
  expect.equality(view_name, nil)
end

T['parse_source']['hash only with no content is invalid'] = function()
  local base_name, view_name = detect.parse_source('#')
  expect.equality(base_name, nil)
  expect.equality(view_name, nil)
end

T['parse_source']['empty source is invalid'] = function()
  local base_name, view_name = detect.parse_source('')
  expect.equality(base_name, nil)
  expect.equality(view_name, nil)
end

T['parse_source']['missing .base extension is invalid'] = function()
  local base_name, view_name = detect.parse_source('Content')
  expect.equality(base_name, nil)
  expect.equality(view_name, nil)
end

T['parse_source']['missing .base extension with view is invalid'] = function()
  local base_name, view_name = detect.parse_source('Content#View')
  expect.equality(base_name, nil)
  expect.equality(view_name, nil)
end

T['parse_source']['base name with internal dots is preserved'] = function()
  local base_name, view_name = detect.parse_source('my.content.base#View')
  expect.equality(base_name, 'my.content')
  expect.equality(view_name, 'View')
end

T['parse_source']['strips only the trailing .base suffix'] = function()
  local base_name, view_name = detect.parse_source('foo.base.base')
  expect.equality(base_name, 'foo.base')
  expect.equality(view_name, nil)
end

T['parse_source']['strips trailing .base when view selector is present'] = function()
  local base_name, view_name = detect.parse_source('foo.base.base#View')
  expect.equality(base_name, 'foo.base')
  expect.equality(view_name, 'View')
end

T['parse_source']['base name with folders is preserved'] = function()
  local base_name, view_name = detect.parse_source('subdir/Content.base#View')
  expect.equality(base_name, 'subdir/Content')
  expect.equality(view_name, 'View')
end

T['parse_source']['view name matching view index number is preserved as a string'] = function()
  local base_name, view_name = detect.parse_source('Content.base#1')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, '1')
end

T['parse_source']['leading and trailing whitespace in view name is trimmed'] = function()
  -- A stray space (e.g. `![[Content.base# Author]]`) should not cause a
  -- spurious "view not found" error.
  local base_name, view_name = detect.parse_source('Content.base# Author ')
  expect.equality(base_name, 'Content')
  expect.equality(view_name, 'Author')
end

-- =======================
-- scan_buffer
-- =======================

T['scan_buffer'] = new_set()

---Helper to create a fresh scratch buffer with the given lines and return its handle
local function scratch_with_lines(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  return buf
end

T['scan_buffer']['finds plain embed without view selector'] = function()
  local buf = scratch_with_lines({
    'Some text',
    '![[Content.base]]',
    'More text',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 1)
  expect.equality(embeds[1].type, 'file')
  expect.equality(embeds[1].source, 'Content.base')
  expect.equality(embeds[1].line_start, 2)
  expect.equality(embeds[1].line_end, 2)
  -- No `view` field, or view is nil — either way it means "use default"
  expect.equality(embeds[1].view, nil)
end

T['scan_buffer']['finds embed with view selector and exposes view name'] = function()
  local buf = scratch_with_lines({
    '![[Content.base#Author]]',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 1)
  expect.equality(embeds[1].source, 'Content.base#Author')
  expect.equality(embeds[1].view, 'Author')
  expect.equality(embeds[1].line_start, 1)
  expect.equality(embeds[1].line_end, 1)
end

T['scan_buffer']['finds embed with view name containing spaces'] = function()
  local buf = scratch_with_lines({
    '![[Content.base#Active Projects]]',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 1)
  expect.equality(embeds[1].view, 'Active Projects')
end

T['scan_buffer']['finds multiple embeds with mixed view selectors'] = function()
  local buf = scratch_with_lines({
    '![[A.base]]',
    '![[B.base#Foo]]',
    '![[C.base#Bar Baz]]',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 3)
  expect.equality(embeds[1].source, 'A.base')
  expect.equality(embeds[1].view, nil)
  expect.equality(embeds[2].source, 'B.base#Foo')
  expect.equality(embeds[2].view, 'Foo')
  expect.equality(embeds[3].source, 'C.base#Bar Baz')
  expect.equality(embeds[3].view, 'Bar Baz')
end

T['scan_buffer']['tolerates leading and trailing whitespace'] = function()
  local buf = scratch_with_lines({
    '   ![[Content.base#View]]   ',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 1)
  expect.equality(embeds[1].view, 'View')
end

T['scan_buffer']['ignores embed without .base extension'] = function()
  local buf = scratch_with_lines({
    '![[note.md]]',
    '![[Content#View]]',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 0)
end

T['scan_buffer']['ignores hash-only embed'] = function()
  local buf = scratch_with_lines({
    '![[#View]]',
    '![[#]]',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 0)
end

T['scan_buffer']['returns empty list for empty buffer'] = function()
  local buf = scratch_with_lines({})
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 0)
end

T['scan_buffer']['returns empty list when no embeds present'] = function()
  local buf = scratch_with_lines({
    '# Heading',
    'Just some text.',
    'And a [link](http://example.com).',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 0)
end

T['scan_buffer']['does not match line containing embed mid-line'] = function()
  -- Embed syntax is a line on its own (matches the existing codeblock behavior)
  local buf = scratch_with_lines({
    'Some text ![[Content.base]] more text',
  })
  local embeds = detect.scan_buffer(buf)
  expect.equality(#embeds, 0)
end

-- =======================
-- base_name (back-compat wrapper)
-- =======================

T['base_name'] = new_set()

T['base_name']['strips trailing .base from plain source'] = function()
  expect.equality(detect.base_name('Content.base'), 'Content')
end

T['base_name']['strips trailing .base and ignores view selector'] = function()
  -- The old wrapper returns just the base name; view is ignored
  expect.equality(detect.base_name('Content.base#Author'), 'Content')
end

T['base_name']['returns input unchanged when no .base suffix'] = function()
  expect.equality(detect.base_name('Content'), 'Content')
end

return T
