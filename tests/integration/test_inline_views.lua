-- Integration tests for the inline view selector: ![[name.base#View Name]]
--
-- These tests verify the end-to-end wiring:
--   1. inline.render_buffer() detects the #view suffix
--   2. base_parser.find_view_index() resolves the view name
--   3. engine.query() is called with the resolved view_index
--   4. engine.query() is also called with the correct this_file_path
--   5. Unknown view names are reported as errors in the embed
--   6. Backward-compat: ![[name.base]] (no #) still uses view 0
--
-- The real engine is replaced with a stub that records calls and
-- returns canned SerializedResult data, so the test does not depend
-- on async filesystem indexing.

local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- =======================
-- Test infrastructure
-- =======================

-- Track every buffer created in a test for cleanup
local test_bufs = {}

local function new_scratch_buf(name, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  if lines then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  end
  table.insert(test_bufs, buf)
  return buf
end

-- Build a SerializedResult that the fake engine will hand back to the
-- inline renderer. Includes view metadata so we can verify the inline
-- module forwards the right view_index.
local function make_result(view_index, view_count)
  view_count = view_count or 2
  local names = {}
  for i = 1, view_count do
    names[i] = 'View ' .. i
  end
  return {
    properties = { 'file.name' },
    entries = {
      {
        file = { path = 'people/alice.md', name = 'alice.md', basename = 'alice' },
        values = { ['file.name'] = { type = 'primitive', value = 'alice' } },
      },
    },
    limit = nil,
    defaultSort = nil,
    propertyLabels = {},
    views = { count = view_count, current = view_index, names = names },
    summaries = nil,
  }
end

-- Install a fake `bases.engine` module that:
--   * reports the given vault_path
--   * on_ready fires the callback synchronously with no error
--   * query() records the (base_file, view_index, this_file_path) tuple and
--     invokes its callback with a canned result
--   * base_parser.parse() returns a fake QueryConfig; base_parser.find_view_index()
--     delegates to `view_for_view_name` so each test can control the
--     view-name → view-index resolution (or trigger a "not found" error).
local function install_fake_engine(opts)
  opts = opts or {}
  local vault = opts.vault_path or '/fake/vault'
  local result_for_view = opts.result_for_view or function(view_index)
    return make_result(view_index, 2)
  end
  local view_for_view_name = opts.view_for_view_name
    or function(_) return 1 end
  local query_err_for_view = opts.query_err_for_view
  local query_calls = {}

  local fake_engine = {
    get_vault_path = function()
      return vault
    end,
    is_ready = function()
      return true
    end,
    on_ready = function(callback)
      callback(nil)
    end,
    query = function(base_file, view_index, callback, this_file_path)
      table.insert(query_calls, {
        base_file = base_file,
        view_index = view_index,
        this_file_path = this_file_path,
      })
      if query_err_for_view then
        local err = query_err_for_view(view_index)
        if err then
          vim.schedule(function() callback(err, nil) end)
          return
        end
      end
      local data = result_for_view(view_index)
      vim.schedule(function() callback(nil, data) end)
    end,
    -- query_string is required by the codeblock render path even when
    -- we only test file embeds; provide a harmless stub.
    query_string = function(_, _, _, callback)
      if callback then vim.schedule(function() callback('not used', nil) end) end
    end,
  }

  -- Stub `bases.engine.base_parser` so view-name resolution doesn't try to
  -- read `/fake/vault/*.base` from disk. The fake parse() returns a
  -- QueryConfig with two named views; find_view_index() delegates to the
  -- test-supplied `view_for_view_name` callback, which can return
  -- (index, nil) for success or (nil, err_msg) for an unknown view.
  local real_bp = package.loaded['bases.engine.base_parser']
  local view_names = { 'First View', 'Second View' }
  local fake_bp = setmetatable({
    parse = function(_)
      return { views = { { name = view_names[1], type = 'table' }, { name = view_names[2], type = 'table' } } }, nil
    end,
    parse_string = real_bp and real_bp.parse_string or function() return nil, 'not stubbed' end,
    find_view_index = function(_, view_name)
      return view_for_view_name(view_name)
    end,
  }, { __index = real_bp })
  package.loaded['bases.engine.base_parser'] = fake_bp

  -- Save the real engine if it was loaded, then replace
  local real_engine = package.loaded['bases.engine']
  package.loaded['bases.engine'] = fake_engine

  return fake_engine, query_calls, function()
    package.loaded['bases.engine'] = real_engine
    package.loaded['bases.engine.base_parser'] = real_bp
  end
end

-- =======================
-- Setup / teardown
-- =======================

-- Install a stub for `bases` with a fully-populated `inline` config so
-- the inline renderer's `config.inline.enabled` check passes.
--
-- Why a pre_case hook: the other integration test files each install their
-- own `package.loaded['bases']` stub at module load (alphabetical order:
-- test_buffer, test_frontmatter_editor, test_highlight_ranges, ...,
-- test_query_engine, test_render_to_buffer). Whichever file is sourced
-- LAST wins, so a module-level stub would be clobbered by one of them.
-- The pre_case hook runs immediately before each of our test cases, which
-- is the only reliable way to ensure our stub is in place when our code
-- executes.
local function install_bases_stub()
  package.loaded['bases'] = {
    get_config = function()
      return {
        date_format = '%Y-%m-%d',
        date_format_relative = false,
        inline = {
          enabled = true,
          auto_render = false,
          keymaps = {
            follow_link = false,
            next_link = false,
            prev_link = false,
            edit_cell = false,
            edit_source = false,
            refresh = false,
          },
        },
      }
    end,
  }
end

local T = new_set({
  hooks = {
    pre_case = function()
      install_bases_stub()
    end,
    post_case = function()
      for _, buf in ipairs(test_bufs) do
        if vim.api.nvim_buf_is_valid(buf) then
          pcall(vim.api.nvim_buf_delete, buf, { force = true })
        end
      end
      test_bufs = {}
    end,
  },
})

-- =======================
-- Helpers
-- =======================

-- Wait for the inline renderer to finish. The renderer places a "loading"
-- extmark first, then schedules an async `engine.query` whose callback
-- places the real data extmark. We poll until the engine.query callback
-- has actually run by checking that `vim.b[buf].bases_inline_embeds[1]`
-- has `api_data` set (only set on the success path of the query callback).
-- A pure extmark-count check would race the loading extmark and report
-- success before the data is available.
local function wait_for_embeds(buf, expected_count, timeout_ms)
  timeout_ms = timeout_ms or 5000
  local ns = vim.api.nvim_create_namespace('bases_inline')
  local start = vim.loop.now()
  while vim.loop.now() - start < timeout_ms do
    local embeds = vim.b[buf] and vim.b[buf].bases_inline_embeds
    if embeds and #embeds >= 1 and embeds[1].api_data then
      local marks = vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, {})
      if #marks >= expected_count then
        return true
      end
    end
    vim.wait(20, function() return false end)
  end
  return false
end

-- =======================
-- view selector is forwarded to engine.query
-- =======================

T['view selector'] = new_set()

T['view selector']['plain embed calls engine.query with view 0'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    'Some prose',
    '![[Content.base]]',
    'Trailing text',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  expect.equality(#query_calls, 1)
  expect.equality(query_calls[1].base_file, '/fake/vault/Content.base')
  expect.equality(query_calls[1].view_index, 0)
  expect.equality(query_calls[1].this_file_path, 'notes/page.md')

  restore()
end

T['view selector']['embed with #View calls engine.query with resolved view_index'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[Content.base#Author]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  expect.equality(#query_calls, 1)
  expect.equality(query_calls[1].base_file, '/fake/vault/Content.base')
  expect.equality(query_calls[1].view_index, 1)
  expect.equality(query_calls[1].this_file_path, 'notes/page.md')

  restore()
end

T['view selector']['embed with #View name containing spaces is forwarded'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[Content.base#Active Projects]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  expect.equality(#query_calls, 1)
  expect.equality(query_calls[1].view_index, 1)

  restore()
end

T['view selector']['this_file_path is vault-relative to the buffer'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/sub/dir/page.md', {
    '![[Content.base#Author]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  expect.equality(#query_calls, 1)
  expect.equality(query_calls[1].this_file_path, 'sub/dir/page.md')

  restore()
end

T['view selector']['resolves view selector for a base in a subdirectory'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/page.md', {
    '![[projects/notes.base#Important]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  expect.equality(#query_calls, 1)
  expect.equality(query_calls[1].base_file, '/fake/vault/projects/notes.base')
  expect.equality(query_calls[1].view_index, 1)

  restore()
end

T['view selector']['this_file_path is nil when buffer is not in vault'] = function()
  -- Buffer is outside the configured vault, so render_buffer early-returns
  -- and engine.query is never called.
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/elsewhere/page.md', {
    '![[Content.base#Author]]',
  })

  inline.render_buffer(buf)

  -- No embeds are expected, and no query was issued
  expect.equality(#query_calls, 0)

  restore()
end

T['view selector']['this_file_path is nil when buffer has no name'] = function()
  -- When the buffer has no name, `is_in_vault` returns false (no path to
  -- compare against the vault root) and the renderer skips the buffer
  -- entirely. The interesting question for `this_file_path` is what
  -- happens for a buffer INSIDE the vault; that's covered by the
  -- `this_file_path is vault-relative to the buffer` test above. We assert
  -- here that the early-return is silent (no extmarks, no query).
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf(nil, {
    '![[Content.base#Author]]',
  })

  inline.render_buffer(buf)
  -- Give the (non-existent) callback a chance to run
  vim.wait(50, function() return false end)

  expect.equality(#query_calls, 0)
  expect.equality(vim.b[buf].bases_inline_embeds, nil)

  restore()
end

-- =======================
-- resolved view is reflected in the embed data
-- =======================

T['embed data'] = new_set()

T['embed data']['embed.api_data.views.current matches resolved index'] = function()
  local _, _, restore = install_fake_engine({
    vault_path = '/fake/vault',
    result_for_view = function(view_index) return make_result(view_index, 3) end,
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[Content.base#Author]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  local embeds = vim.b[buf].bases_inline_embeds
  expect.no_equality(embeds, nil)
  expect.equality(#embeds, 1)
  expect.equality(embeds[1].view, 'Author')
  expect.no_equality(embeds[1].api_data, nil)
  expect.equality(embeds[1].api_data.views.current, 1)

  restore()
end

T['embed data']['plain embed (no #) reports current = 0'] = function()
  local _, _, restore = install_fake_engine({
    vault_path = '/fake/vault',
    result_for_view = function(view_index) return make_result(view_index, 2) end,
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[Content.base]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)

  local embeds = vim.b[buf].bases_inline_embeds
  expect.no_equality(embeds, nil)
  expect.equality(embeds[1].view, nil)
  expect.equality(embeds[1].api_data.views.current, 0)

  restore()
end

-- =======================
-- unknown view name: error is rendered in the embed
-- =======================

T['unknown view'] = new_set()

T['unknown view']['view name not in base file shows an error in the embed'] = function()
  -- Configure the fake base_parser to report any view name as not found
  local _, _, restore = install_fake_engine({
    vault_path = '/fake/vault',
    view_for_view_name = function(_)
      return nil, "View 'Author' not found in Content.base"
    end,
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[Content.base#Author]]',
  })

  inline.render_buffer(buf)
  -- Give the renderer a chance to apply the error extmark
  vim.wait(50, function() return false end)

  local embeds = vim.b[buf].bases_inline_embeds
  expect.no_equality(embeds, nil)
  expect.equality(#embeds, 1)
  -- Embed should have been marked as errored: data is nil, no api_data,
  -- and the extmark still exists for the error message.
  expect.equality(embeds[1].data, nil)
  expect.equality(embeds[1].api_data, nil)

  restore()
end

-- =======================
-- multiple embeds, each with their own view_index
-- =======================

T['multiple embeds'] = new_set()

T['multiple embeds']['each embed resolves its own view_index'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[A.base]]',
    'Mid paragraph',
    '![[B.base#Foo]]',
    '![[C.base#Bar]]',
  })

  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 3), true)

  expect.equality(#query_calls, 3)
  expect.equality(query_calls[1].base_file, '/fake/vault/A.base')
  expect.equality(query_calls[1].view_index, 0)
  expect.equality(query_calls[2].base_file, '/fake/vault/B.base')
  expect.equality(query_calls[2].view_index, 1)
  expect.equality(query_calls[3].base_file, '/fake/vault/C.base')
  expect.equality(query_calls[3].view_index, 1)

  restore()
end

-- =======================
-- regression: refresh_buffer re-scans the buffer
-- =======================
-- Earlier the inline refresh path reused the cached embeds list, which
-- meant embeds added to the buffer (e.g. via BufWritePost → plugin's
-- refresh_all_buffers → refresh_inline → refresh_buffer) were silently
-- dropped. refresh_buffer must always re-scan so newly-typed
-- `![[base.base#view]]` lines are picked up.

T['refresh_buffer'] = new_set()

T['refresh_buffer']['re-scans the buffer and picks up newly added embeds'] = function()
  local _, query_calls, restore = install_fake_engine({
    vault_path = '/fake/vault',
  })

  local inline = require('bases.inline')
  local buf = new_scratch_buf('/fake/vault/notes/page.md', {
    '![[Content.base]]',
  })

  -- Initial render
  inline.render_buffer(buf)
  expect.equality(wait_for_embeds(buf, 1), true)
  expect.equality(#query_calls, 1)

  -- Simulate the user adding a new embed to the buffer
  local last = vim.api.nvim_buf_line_count(buf)
  vim.api.nvim_buf_set_lines(buf, last, last, false, { '![[Meeting.base#Person]]' })

  -- Now refresh. This must re-scan the buffer and pick up the new embed.
  inline.refresh_buffer(buf)

  -- Wait for the new query to land
  local function wait_for_calls(n, timeout)
    timeout = timeout or 5000
    local start = vim.loop.now()
    while vim.loop.now() - start < timeout do
      if #query_calls >= n then return true end
      vim.wait(20, function() return false end)
    end
    return false
  end

  expect.equality(wait_for_calls(2), true)
  expect.equality(query_calls[#query_calls].base_file, '/fake/vault/Meeting.base')
  expect.equality(query_calls[#query_calls].view_index, 1)

  restore()
end

return T
