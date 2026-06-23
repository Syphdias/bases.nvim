local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

-- Mock bases config
package.loaded['bases'] = {
  get_config = function()
    return { date_format = '%Y-%m-%d', date_format_relative = false }
  end,
}

local query_engine = require('bases.engine.query_engine')
local base_parser = require('bases.engine.base_parser')
local helpers = require('tests.helpers')

local T = new_set()

-- =======================
-- Helper Functions
-- =======================

-- Create test notes for various scenarios
local function create_project_notes()
  local alpha = helpers.make_note_data({
    path = 'projects/alpha.md',
    frontmatter = { status = 'active', priority = 1, budget = 5000 },
    tags = { 'project', 'project/active' },
  })
  local beta = helpers.make_note_data({
    path = 'projects/beta.md',
    frontmatter = { status = 'complete', priority = 3, budget = 2000 },
    tags = { 'project' },
  })
  local gamma = helpers.make_note_data({
    path = 'projects/gamma.md',
    frontmatter = { status = 'pending', priority = 2, budget = 3000 },
    tags = { 'project', 'project/active' },
  })
  local alice = helpers.make_note_data({
    path = 'people/alice.md',
    frontmatter = { role = 'engineer' },
    tags = { 'person' },
  })

  return { alpha, beta, gamma, alice }
end

-- =======================
-- Tests
-- =======================

T['execute'] = new_set()

T['execute']['filters by tag'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: All Projects
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should only include the 3 project notes, not alice
  expect.equality(#result.entries, 3)

  -- Verify the entries are project notes
  local paths = {}
  for _, entry in ipairs(result.entries) do
    table.insert(paths, entry.file.path)
  end
  table.sort(paths)

  expect.equality(paths[1], 'projects/alpha.md')
  expect.equality(paths[2], 'projects/beta.md')
  expect.equality(paths[3], 'projects/gamma.md')
end

T['execute']['filters by folder'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.inFolder(\"projects\")"
views:
  - type: table
    name: All Projects
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should only include the 3 project notes in projects folder
  expect.equality(#result.entries, 3)
end

T['execute']['applies view-specific filter'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: All Projects
  - type: table
    name: Active Projects
    filters: "note.status == \"active\""
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  -- First view (index 0) - all projects
  local result1 = query_engine.execute(config, index, 0, nil)
  expect.equality(#result1.entries, 3)

  -- Second view (index 1) - only active projects
  local result2 = query_engine.execute(config, index, 1, nil)
  expect.equality(#result2.entries, 1)
  expect.equality(result2.entries[1].file.basename, 'alpha')
end

T['execute']['evaluates formula columns'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
formulas:
  double_budget: "note.budget * 2"
  budget_priority: "note.budget / note.priority"
views:
  - type: table
    name: All
    order:
      - file.name
      - note.budget
      - formula.double_budget
      - formula.budget_priority
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Find alpha project entry
  local alpha_entry = nil
  for _, entry in ipairs(result.entries) do
    if entry.file.basename == 'alpha' then
      alpha_entry = entry
      break
    end
  end

  expect.no_equality(alpha_entry, nil)

  -- Verify formula values
  local double_budget = alpha_entry.values['formula.double_budget']
  expect.no_equality(double_budget, nil)
  expect.equality(double_budget.type, 'primitive')
  expect.equality(double_budget.value, 10000) -- 5000 * 2

  local budget_priority = alpha_entry.values['formula.budget_priority']
  expect.no_equality(budget_priority, nil)
  expect.equality(budget_priority.type, 'primitive')
  expect.equality(budget_priority.value, 5000) -- 5000 / 1
end

T['execute']['auto-discovers properties'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
formulas:
  double_budget: "note.budget * 2"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should auto-discover: file.name, note.status, note.priority, note.budget, formula.double_budget
  expect.no_equality(#result.properties, 0)

  -- file.name should always be first
  expect.equality(result.properties[1], 'file.name')

  -- Check that all expected properties are present
  local prop_set = {}
  for _, prop in ipairs(result.properties) do
    prop_set[prop] = true
  end

  expect.equality(prop_set['file.name'], true)
  expect.equality(prop_set['note.status'], true)
  expect.equality(prop_set['note.priority'], true)
  expect.equality(prop_set['note.budget'], true)
  expect.equality(prop_set['formula.double_budget'], true)
end

T['execute']['uses explicit property order'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: All
    order:
      - name
      - status
      - budget
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should have exactly the specified properties in that order
  expect.equality(#result.properties, 3)
  expect.equality(result.properties[1], 'file.name')
  expect.equality(result.properties[2], 'note.status')
  expect.equality(result.properties[3], 'note.budget')
end

T['execute']['respects sort configuration'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: By Priority
    sort:
      - column: priority
        direction: ASC
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should have defaultSort set
  expect.no_equality(result.defaultSort, nil)
  expect.equality(result.defaultSort.property, 'note.priority')
  expect.equality(result.defaultSort.direction, 'asc')
end

T['execute']['respects limit'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: Top 2
    limit: 2
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should have limit set in result metadata
  expect.equality(result.limit, 2)
end

T['execute']['computes summaries'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: All
    summaries:
      budget: "sum"
      priority: "average"
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should have summaries
  expect.no_equality(result.summaries, nil)

  -- Check budget sum (5000 + 2000 + 3000 = 10000)
  local budget_summary = result.summaries['note.budget']
  expect.no_equality(budget_summary, nil)
  expect.equality(budget_summary.value.type, 'primitive')
  expect.equality(budget_summary.value.value, 10000)

  -- Check priority average ((1 + 3 + 2) / 3 = 2)
  local priority_summary = result.summaries['note.priority']
  expect.no_equality(priority_summary, nil)
  expect.equality(priority_summary.value.type, 'primitive')
  expect.equality(priority_summary.value.value, 2)
end

T['execute']['selects correct view by index'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: First View
    filters: "note.status == \"active\""
  - type: table
    name: Second View
    filters: "note.status == \"complete\""
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  -- View 0 - active
  local result0 = query_engine.execute(config, index, 0, nil)
  expect.equality(#result0.entries, 1)
  expect.equality(result0.entries[1].file.basename, 'alpha')

  -- View 1 - complete
  local result1 = query_engine.execute(config, index, 1, nil)
  expect.equality(#result1.entries, 1)
  expect.equality(result1.entries[1].file.basename, 'beta')
end

T['execute']['populates views metadata'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: First View
  - type: table
    name: Second View
  - type: table
    name: Third View
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 1, nil)

  -- Check views metadata
  expect.equality(result.views.count, 3)
  expect.equality(result.views.current, 1) -- 0-based index
  expect.equality(#result.views.names, 3)
  expect.equality(result.views.names[1], 'First View')
  expect.equality(result.views.names[2], 'Second View')
  expect.equality(result.views.names[3], 'Third View')
end

T['execute']['uses property labels'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
properties:
  status:
    display_name: "Current Status"
  budget:
    display_name: "Total Budget"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Check property labels
  expect.no_equality(result.propertyLabels, nil)
  expect.equality(result.propertyLabels['note.status'], 'Current Status')
  expect.equality(result.propertyLabels['note.budget'], 'Total Budget')
end

T['execute']['handles complex AND filters'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters:
  and:
    - "file.hasTag(\"project\")"
    - "note.priority < 3"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should include alpha (priority 1) and gamma (priority 2), but not beta (priority 3)
  expect.equality(#result.entries, 2)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    table.insert(basenames, entry.file.basename)
  end
  table.sort(basenames)

  expect.equality(basenames[1], 'alpha')
  expect.equality(basenames[2], 'gamma')
end

T['execute']['handles OR filters'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters:
  or:
    - "note.status == \"active\""
    - "note.status == \"complete\""
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should include alpha (active), beta (complete), but not gamma (pending)
  -- Also should not include alice (no status field)
  expect.equality(#result.entries, 2)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    table.insert(basenames, entry.file.basename)
  end
  table.sort(basenames)

  expect.equality(basenames[1], 'alpha')
  expect.equality(basenames[2], 'beta')
end

T['execute']['handles NOT filters'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters:
  and:
    - "file.hasTag(\"project\")"
    - not: "note.status == \"complete\""
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should include alpha and gamma, but not beta (complete)
  expect.equality(#result.entries, 2)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    table.insert(basenames, entry.file.basename)
  end
  table.sort(basenames)

  expect.equality(basenames[1], 'alpha')
  expect.equality(basenames[2], 'gamma')
end

T['execute']['handles formula dependencies'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
formulas:
  base_value: "note.budget"
  doubled: "formula.base_value * 2"
  quadrupled: "formula.doubled * 2"
views:
  - type: table
    name: All
    order:
      - file.name
      - formula.quadrupled
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Find alpha project entry
  local alpha_entry = nil
  for _, entry in ipairs(result.entries) do
    if entry.file.basename == 'alpha' then
      alpha_entry = entry
      break
    end
  end

  expect.no_equality(alpha_entry, nil)

  -- Verify formula chain: 5000 * 2 * 2 = 20000
  local quadrupled = alpha_entry.values['formula.quadrupled']
  expect.no_equality(quadrupled, nil)
  expect.equality(quadrupled.type, 'primitive')
  expect.equality(quadrupled.value, 20000)
end

T['execute']['serializes file.name as link'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: All
    order:
      - name
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Check that file.name is serialized as a link
  local entry = result.entries[1]
  local name_value = entry.values['file.name']

  expect.equality(name_value.type, 'link')
  expect.no_equality(name_value.path, nil)
  expect.no_equality(name_value.value, nil)
  expect.equality(name_value.value:match('^%[%[.+%]%]$') ~= nil, true) -- Matches [[...]]
end

T['execute']['handles empty results'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"nonexistent\")"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should return empty entries
  expect.equality(#result.entries, 0)
  expect.no_equality(result.properties, nil)
  expect.no_equality(result.views, nil)
end

T['execute']['handles notes without frontmatter'] = function()
  local note_without_fm = helpers.make_note_data({
    path = 'notes/simple.md',
    frontmatter = {},
    tags = { 'note' },
  })

  local index = helpers.make_note_index({ note_without_fm })

  local yaml = [[
filters: "file.hasTag(\"note\")"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should still return the entry with file.name
  expect.equality(#result.entries, 1)
  expect.equality(result.entries[1].file.basename, 'simple')
end

T['execute']['uses index optimization for tag queries'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  -- This should use the by_tag index optimization
  local yaml = [[
filters: "file.hasTag(\"project/active\")"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should return alpha and gamma (both have project/active tag)
  expect.equality(#result.entries, 2)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    table.insert(basenames, entry.file.basename)
  end
  table.sort(basenames)

  expect.equality(basenames[1], 'alpha')
  expect.equality(basenames[2], 'gamma')
end

T['execute']['uses index optimization for folder queries'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  -- This should use the by_folder index optimization
  local yaml = [[
filters: "file.inFolder(\"people\")"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should return only alice
  expect.equality(#result.entries, 1)
  expect.equality(result.entries[1].file.basename, 'alice')
end

T['execute']['handles combined global and view filters'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: High Priority
    filters:
      and:
        - "note.priority <= 2"
        - "note.budget >= 3000"
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Should return alpha (priority 1, budget 5000) and gamma (priority 2, budget 3000)
  -- Beta is excluded by view filter (priority 3)
  expect.equality(#result.entries, 2)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    table.insert(basenames, entry.file.basename)
  end
  table.sort(basenames)

  expect.equality(basenames[1], 'alpha')
  expect.equality(basenames[2], 'gamma')
end

T['execute']['preserves entry file metadata'] = function()
  local notes = create_project_notes()
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "file.hasTag(\"project\")"
views:
  - type: table
    name: All
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local result = query_engine.execute(config, index, 0, nil)

  -- Check that each entry has complete file metadata
  for _, entry in ipairs(result.entries) do
    expect.no_equality(entry.file.path, nil)
    expect.no_equality(entry.file.name, nil)
    expect.no_equality(entry.file.basename, nil)

    -- Verify basename matches name without extension
    expect.equality(entry.file.name:match('^(.+)%.md$'), entry.file.basename)
  end
end

T['execute']['bare `this` resolves to the embedding file basename'] = function()
  -- When a filter references `this` without a property (e.g.
  -- `list(authors).contains(this)`), the engine should treat it as
  -- the embedding file's basename. Combined with the wiki-link
  -- stripping in `values_equal`, this lets frontmatter values like
  -- `[[J.R.R. Tolkien]]` be matched against a plain string
  -- `J.R.R. Tolkien` used as the `this` context for the embedding
  -- file. This is the convention used by the demo vault's
  -- Content.base#Author view.
  local notes = {
    helpers.make_note_data({
      path = 'books/fellowship.md',
      frontmatter = { authors = { '[[J.R.R. Tolkien]]' } },
    }),
    helpers.make_note_data({
      path = 'books/return.md',
      frontmatter = { authors = { '[[J.R.R. Tolkien]]' } },
    }),
    helpers.make_note_data({
      path = 'books/lion.md',
      frontmatter = { authors = { '[[C.S. Lewis]]' } },
    }),
    helpers.make_note_data({
      path = 'books/hobbit.md',
      frontmatter = { authors = {} },
    }),
  }
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "list(note.authors).contains(this)"
views:
  - type: table
    name: By Author
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  local this_file = helpers.make_note_data({
    path = 'books/J.R.R. Tolkien.md',
    basename = 'J.R.R. Tolkien',
  })

  local result = query_engine.execute(config, index, 0, this_file)

  expect.equality(#result.entries, 2)

  local basenames = {}
  for _, entry in ipairs(result.entries) do
    table.insert(basenames, entry.file.basename)
  end
  table.sort(basenames)

  expect.equality(basenames[1], 'fellowship')
  expect.equality(basenames[2], 'return')
end

T['execute']['bare `this` returns null when no this_file is set'] = function()
  local notes = {
    helpers.make_note_data({
      path = 'books/fellowship.md',
      frontmatter = { authors = { '[[J.R.R. Tolkien]]' } },
    }),
  }
  local index = helpers.make_note_index(notes)

  local yaml = [[
filters: "list(note.authors).contains(this)"
views:
  - type: table
    name: By Author
]]

  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  -- No this_file passed → `this` is null → no rows match
  local result = query_engine.execute(config, index, 0, nil)
  expect.equality(#result.entries, 0)
end

return T
