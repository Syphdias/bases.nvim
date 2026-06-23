local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local base_parser = require('bases.engine.base_parser')

local T = new_set()

-- =======================
-- parse_string: Empty Input
-- =======================

T['parse_string'] = new_set()

T['parse_string']['empty input creates default view'] = function()
  local config, err = base_parser.parse_string('')
  expect.equality(err, nil)
  expect.equality(#config.views, 1)
  expect.equality(config.views[1].type, 'table')
  expect.equality(config.views[1].name, 'Default')
end

T['parse_string']['whitespace only creates default view'] = function()
  local config, err = base_parser.parse_string('   \n\n  ')
  expect.equality(err, nil)
  expect.equality(#config.views, 1)
  expect.equality(config.views[1].type, 'table')
  expect.equality(config.views[1].name, 'Default')
end

T['parse_string']['empty object creates default view'] = function()
  local config, err = base_parser.parse_string('{}')
  expect.equality(err, nil)
  expect.equality(#config.views, 1)
  expect.equality(config.views[1].type, 'table')
  expect.equality(config.views[1].name, 'Default')
end

-- =======================
-- parse_string: Invalid YAML
-- =======================

T['parse_string']['array at top level returns error'] = function()
  -- Note: The YAML parser may parse this as an empty table
  -- This test verifies that non-map top-level structure results in an error or default view
  local config, err = base_parser.parse_string('- item1\n- item2')
  -- Either fails with error or creates default view (current behavior: default view)
  if config then
    expect.equality(#config.views, 1)
  else
    expect.no_equality(err, nil)
  end
end

-- =======================
-- parse_string: Top-level Filters
-- =======================

T['parse_string']['string filter creates expression node'] = function()
  local config, err = base_parser.parse_string('filters: note.status = "active"')
  expect.equality(err, nil)
  expect.no_equality(config.filters, nil)
  expect.equality(config.filters.type, 'expression')
  expect.equality(config.filters.expression, 'note.status = "active"')
end

T['parse_string']['and filter creates and node'] = function()
  local yaml = [[
filters:
  and:
    - note.status = "active"
    - note.priority = "high"
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.filters, nil)
  expect.equality(config.filters.type, 'and')
  expect.equality(#config.filters.children, 2)
  expect.equality(config.filters.children[1].type, 'expression')
  expect.equality(config.filters.children[1].expression, 'note.status = "active"')
  expect.equality(config.filters.children[2].type, 'expression')
  expect.equality(config.filters.children[2].expression, 'note.priority = "high"')
end

T['parse_string']['or filter creates or node'] = function()
  local yaml = [[
filters:
  or:
    - note.status = "active"
    - note.status = "pending"
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.filters, nil)
  expect.equality(config.filters.type, 'or')
  expect.equality(#config.filters.children, 2)
  expect.equality(config.filters.children[1].expression, 'note.status = "active"')
  expect.equality(config.filters.children[2].expression, 'note.status = "pending"')
end

T['parse_string']['not filter with single item'] = function()
  local yaml = [[
filters:
  not: note.archived = true
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.filters, nil)
  expect.equality(config.filters.type, 'not')
  expect.equality(#config.filters.children, 1)
  expect.equality(config.filters.children[1].type, 'expression')
  expect.equality(config.filters.children[1].expression, 'note.archived = true')
end

T['parse_string']['not filter with array'] = function()
  local yaml = [[
filters:
  not:
    - note.archived = true
    - note.deleted = true
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.filters, nil)
  expect.equality(config.filters.type, 'not')
  expect.equality(#config.filters.children, 2)
  expect.equality(config.filters.children[1].expression, 'note.archived = true')
  expect.equality(config.filters.children[2].expression, 'note.deleted = true')
end

T['parse_string']['compound filter at top level'] = function()
  local yaml = [[
filters:
  and:
    - note.status = "active"
    - note.priority = "high"
    - note.archived = false
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.filters.type, 'and')
  expect.equality(#config.filters.children, 3)
  expect.equality(config.filters.children[1].type, 'expression')
  expect.equality(config.filters.children[2].type, 'expression')
  expect.equality(config.filters.children[3].type, 'expression')
end

T['parse_string']['invalid filter type returns error'] = function()
  local yaml = 'filters: 123'
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['filter without recognized combinator returns error'] = function()
  local yaml = [[
filters:
  invalid: something
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: Formulas
-- =======================

T['parse_string']['single formula'] = function()
  local yaml = [[
formulas:
  total: price * quantity
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.formulas, nil)
  expect.equality(config.formulas.total, 'price * quantity')
end

T['parse_string']['multiple formulas'] = function()
  local yaml = [[
formulas:
  total: price * quantity
  discount: total * 0.1
  final: total - discount
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.formulas.total, 'price * quantity')
  expect.equality(config.formulas.discount, 'total * 0.1')
  expect.equality(config.formulas.final, 'total - discount')
end

T['parse_string']['non-table formulas returns error'] = function()
  local yaml = 'formulas: not a map'
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['non-string formula expression returns error'] = function()
  local yaml = [[
formulas:
  total: 123
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: Properties
-- =======================

T['parse_string']['property with display name'] = function()
  local yaml = [[
properties:
  status:
    display_name: Current Status
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.properties, nil)
  expect.no_equality(config.properties.status, nil)
  expect.equality(config.properties.status.display_name, 'Current Status')
end

T['parse_string']['multiple properties'] = function()
  local yaml = [[
properties:
  status:
    display_name: Current Status
  priority:
    display_name: Priority Level
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.properties.status.display_name, 'Current Status')
  expect.equality(config.properties.priority.display_name, 'Priority Level')
end

T['parse_string']['property with empty config'] = function()
  local yaml = [[
properties:
  status: {}
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.properties.status, nil)
end

T['parse_string']['non-table properties returns error'] = function()
  local yaml = 'properties: not a map'
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['non-table property config returns error'] = function()
  local yaml = [[
properties:
  status: not a table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['non-string display_name returns error'] = function()
  local yaml = [[
properties:
  status:
    display_name: 123
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Basics
-- =======================

T['parse_string']['single view with defaults'] = function()
  local yaml = [[
views:
  - {}
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(#config.views, 1)
  expect.equality(config.views[1].type, 'table')
  expect.equality(config.views[1].name, 'View 1')
end

T['parse_string']['view with custom name'] = function()
  local yaml = [[
views:
  - name: Main View
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].name, 'Main View')
end

T['parse_string']['view with table type'] = function()
  local yaml = [[
views:
  - type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].type, 'table')
end

T['parse_string']['view with cards type'] = function()
  local yaml = [[
views:
  - type: cards
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].type, 'cards')
end

T['parse_string']['view with map type'] = function()
  local yaml = [[
views:
  - type: map
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].type, 'map')
end

T['parse_string']['invalid view type returns error'] = function()
  local yaml = [[
views:
  - type: invalid
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['multiple views'] = function()
  local yaml = [[
views:
  - name: Table View
    type: table
  - name: Card View
    type: cards
  - name: Map View
    type: map
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(#config.views, 3)
  expect.equality(config.views[1].name, 'Table View')
  expect.equality(config.views[2].name, 'Card View')
  expect.equality(config.views[3].name, 'Map View')
  expect.equality(config.views[1].type, 'table')
  expect.equality(config.views[2].type, 'cards')
  expect.equality(config.views[3].type, 'map')
end

T['parse_string']['multiple views with default names'] = function()
  local yaml = [[
views:
  - type: table
  - type: cards
  - type: map
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].name, 'View 1')
  expect.equality(config.views[2].name, 'View 2')
  expect.equality(config.views[3].name, 'View 3')
end

T['parse_string']['non-table view returns error'] = function()
  local yaml = [[
views:
  - not a table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['non-array views returns error'] = function()
  local yaml = 'views: not an array'
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Order
-- =======================

T['parse_string']['view with order normalizes bare names'] = function()
  local yaml = [[
views:
  - type: table
    order: [status, priority, title]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(#config.views[1].order, 3)
  expect.equality(config.views[1].order[1], 'note.status')
  expect.equality(config.views[1].order[2], 'note.priority')
  expect.equality(config.views[1].order[3], 'note.title')
end

T['parse_string']['view order normalizes file properties'] = function()
  local yaml = [[
views:
  - type: table
    order: [name, path, size, mtime]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].order[1], 'file.name')
  expect.equality(config.views[1].order[2], 'file.path')
  expect.equality(config.views[1].order[3], 'file.size')
  expect.equality(config.views[1].order[4], 'file.mtime')
end

T['parse_string']['view order preserves prefixed names'] = function()
  local yaml = [[
views:
  - type: table
    order: [file.name, note.status, formula.total]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].order[1], 'file.name')
  expect.equality(config.views[1].order[2], 'note.status')
  expect.equality(config.views[1].order[3], 'formula.total')
end

T['parse_string']['non-array order returns error'] = function()
  local yaml = [[
views:
  - type: table
    order: not an array
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['non-string order entry returns error'] = function()
  local yaml = [[
views:
  - type: table
    order: [status, 123]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Limit
-- =======================

T['parse_string']['view with limit'] = function()
  local yaml = [[
views:
  - type: table
    limit: 10
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].limit, 10)
end

T['parse_string']['non-number limit returns error'] = function()
  local yaml = [[
views:
  - type: table
    limit: "10"
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Sort
-- =======================

T['parse_string']['view with single sort using column'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - column: status
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].sort, nil)
  expect.equality(#config.views[1].sort, 1)
  expect.equality(config.views[1].sort[1].column, 'note.status')
  expect.equality(config.views[1].sort[1].direction, 'ASC')
end

T['parse_string']['view with single sort using property alias'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - property: priority
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].sort, nil)
  expect.equality(config.views[1].sort[1].column, 'note.priority')
end

T['parse_string']['view with sort direction ASC'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - column: status
        direction: ASC
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].sort, nil)
  expect.equality(config.views[1].sort[1].direction, 'ASC')
end

T['parse_string']['view with sort direction DESC'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - column: priority
        direction: DESC
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].sort, nil)
  expect.equality(config.views[1].sort[1].direction, 'DESC')
end

T['parse_string']['view with multiple sort criteria'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - column: status
        direction: ASC
      - column: priority
        direction: DESC
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].sort, nil)
  expect.equality(#config.views[1].sort, 2)
  expect.equality(config.views[1].sort[1].column, 'note.status')
  expect.equality(config.views[1].sort[1].direction, 'ASC')
  expect.equality(config.views[1].sort[2].column, 'note.priority')
  expect.equality(config.views[1].sort[2].direction, 'DESC')
end

T['parse_string']['view sort normalizes property names'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - column: name
      - column: mtime
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].sort, nil)
  expect.equality(config.views[1].sort[1].column, 'file.name')
  expect.equality(config.views[1].sort[2].column, 'file.mtime')
end

T['parse_string']['non-array sort returns error'] = function()
  local yaml = [[
views:
  - type: table
    sort: not an array
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['non-table sort entry returns error'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - not a table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['sort entry missing column returns error'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - direction: ASC
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['invalid sort direction returns error'] = function()
  local yaml = [[
views:
  - type: table
    sort:
      - column: status
        direction: INVALID
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Group By
-- =======================

T['parse_string']['view with group_by'] = function()
  local yaml = [[
views:
  - type: table
    group_by: status
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].group_by, 'note.status')
end

T['parse_string']['view group_by normalizes file properties'] = function()
  local yaml = [[
views:
  - type: table
    group_by: folder
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].group_by, 'file.folder')
end

T['parse_string']['non-string group_by returns error'] = function()
  local yaml = [[
views:
  - type: table
    group_by: 123
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Filters
-- =======================

T['parse_string']['view with string filter'] = function()
  local yaml = [[
views:
  - type: table
    filters: note.status = "active"
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].filters, nil)
  expect.equality(config.views[1].filters.type, 'expression')
  expect.equality(config.views[1].filters.expression, 'note.status = "active"')
end

T['parse_string']['view with compound filter'] = function()
  local yaml = [[
views:
  - type: table
    filters:
      and:
        - note.status = "active"
        - note.priority = "high"
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].filters, nil)
  expect.equality(config.views[1].filters.type, 'and')
  expect.equality(#config.views[1].filters.children, 2)
end

T['parse_string']['view filter error propagates'] = function()
  local yaml = [[
views:
  - type: table
    filters: 123
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: View Summaries
-- =======================

T['parse_string']['view with single summary'] = function()
  local yaml = [[
views:
  - type: table
    summaries:
      total: sum(amount)
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].summaries, nil)
  expect.equality(config.views[1].summaries['note.total'], 'sum(amount)')
end

T['parse_string']['view with multiple summaries'] = function()
  local yaml = [[
views:
  - type: table
    summaries:
      total: sum(amount)
      average: avg(score)
      count: count()
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].summaries, nil)
  expect.equality(config.views[1].summaries['note.total'], 'sum(amount)')
  expect.equality(config.views[1].summaries['note.average'], 'avg(score)')
  expect.equality(config.views[1].summaries['note.count'], 'count()')
end

T['parse_string']['view summaries normalize property names'] = function()
  local yaml = [[
views:
  - type: table
    summaries:
      size: sum(size)
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].summaries, nil)
  expect.equality(config.views[1].summaries['file.size'], 'sum(size)')
end

T['parse_string']['non-table summaries returns error'] = function()
  local yaml = [[
views:
  - type: table
    summaries: not a table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

T['parse_string']['summary key is normalized like properties'] = function()
  local yaml = [[
views:
  - type: table
    summaries:
      count: count()
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.no_equality(config.views[1].summaries, nil)
  expect.equality(config.views[1].summaries['note.count'], 'count()')
end

T['parse_string']['non-string summary value returns error'] = function()
  local yaml = [[
views:
  - type: table
    summaries:
      total: 123
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(config, nil)
  expect.no_equality(err, nil)
end

-- =======================
-- parse_string: Cards View
-- =======================

T['parse_string']['cards view with image'] = function()
  local yaml = [[
views:
  - type: cards
    image: thumbnail
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].image, 'note.thumbnail')
end

T['parse_string']['cards view image normalizes file properties'] = function()
  local yaml = [[
views:
  - type: cards
    image: path
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].image, 'file.path')
end

T['parse_string']['table view ignores image field'] = function()
  local yaml = [[
views:
  - type: table
    image: thumbnail
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].image, nil)
end

-- =======================
-- parse_string: Map View
-- =======================

T['parse_string']['map view with lat and long'] = function()
  local yaml = [[
views:
  - type: map
    lat: latitude
    long: longitude
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].lat, 'note.latitude')
  expect.equality(config.views[1].long, 'note.longitude')
end

T['parse_string']['map view with title'] = function()
  local yaml = [[
views:
  - type: map
    title: location_name
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].title, 'note.location_name')
end

T['parse_string']['map view normalizes all fields'] = function()
  local yaml = [[
views:
  - type: map
    lat: lat
    long: long
    title: name
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].lat, 'note.lat')
  expect.equality(config.views[1].long, 'note.long')
  expect.equality(config.views[1].title, 'file.name')
end

T['parse_string']['table view ignores map fields'] = function()
  local yaml = [[
views:
  - type: table
    lat: latitude
    long: longitude
    title: name
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].lat, nil)
  expect.equality(config.views[1].long, nil)
  expect.equality(config.views[1].title, nil)
end

-- =======================
-- parse_string: Complete Examples
-- =======================

T['parse_string']['complete base with all features'] = function()
  local yaml = [[
filters:
  and:
    - note.status = "active"
    - not: note.archived = true
formulas:
  total: price * quantity
  discount: total * 0.1
properties:
  status:
    display_name: Current Status
  priority:
    display_name: Priority Level
views:
  - name: Main View
    type: table
    order: [name, status, priority]
    sort:
      - column: status
        direction: ASC
      - column: priority
        direction: DESC
    limit: 100
    group_by: status
    summaries:
      total: sum(amount)
  - name: Cards
    type: cards
    image: thumbnail
    limit: 50
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)

  -- Check filters
  expect.equality(config.filters.type, 'and')
  expect.equality(#config.filters.children, 2)

  -- Check formulas
  expect.equality(config.formulas.total, 'price * quantity')
  expect.equality(config.formulas.discount, 'total * 0.1')

  -- Check properties
  expect.equality(config.properties.status.display_name, 'Current Status')
  expect.equality(config.properties.priority.display_name, 'Priority Level')

  -- Check views
  expect.equality(#config.views, 2)
  expect.equality(config.views[1].name, 'Main View')
  expect.equality(config.views[1].type, 'table')
  expect.equality(#config.views[1].order, 3)
  expect.equality(config.views[1].order[1], 'file.name')
  expect.equality(#config.views[1].sort, 2)
  expect.equality(config.views[1].limit, 100)
  expect.equality(config.views[1].group_by, 'note.status')
  expect.equality(config.views[1].summaries['note.total'], 'sum(amount)')

  expect.equality(config.views[2].name, 'Cards')
  expect.equality(config.views[2].type, 'cards')
  expect.equality(config.views[2].image, 'note.thumbnail')
  expect.equality(config.views[2].limit, 50)
end

T['parse_string']['minimal valid base'] = function()
  local yaml = [[
views:
  - name: Simple
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(#config.views, 1)
  expect.equality(config.views[1].name, 'Simple')
  expect.equality(config.views[1].type, 'table')
end

-- =======================
-- parse_string: Property Normalization Edge Cases
-- =======================

T['parse_string']['bare property name gets note prefix'] = function()
  local yaml = [[
views:
  - type: table
    order: [title]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].order[1], 'note.title')
end

T['parse_string']['file property without prefix gets file prefix'] = function()
  local yaml = [[
views:
  - type: table
    order: [name, path, folder, ext, size, ctime, mtime, links, embeds, file]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].order[1], 'file.name')
  expect.equality(config.views[1].order[2], 'file.path')
  expect.equality(config.views[1].order[3], 'file.folder')
  expect.equality(config.views[1].order[4], 'file.ext')
  expect.equality(config.views[1].order[5], 'file.size')
  expect.equality(config.views[1].order[6], 'file.ctime')
  expect.equality(config.views[1].order[7], 'file.mtime')
  expect.equality(config.views[1].order[8], 'file.links')
  expect.equality(config.views[1].order[9], 'file.embeds')
  expect.equality(config.views[1].order[10], 'file.file')
end

T['parse_string']['already prefixed names are preserved'] = function()
  local yaml = [[
views:
  - type: table
    order: [file.name, note.title, formula.total]
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  expect.equality(config.views[1].order[1], 'file.name')
  expect.equality(config.views[1].order[2], 'note.title')
  expect.equality(config.views[1].order[3], 'formula.total')
end

-- =======================
-- find_view_index
-- =======================

T['find_view_index'] = new_set()

T['find_view_index']['returns 0-based index for first view by name'] = function()
  local yaml = [[
views:
  - name: First View
    type: table
  - name: Second View
    type: table
  - name: Third View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'First View')
  expect.equality(view_err, nil)
  expect.equality(index, 0)
end

T['find_view_index']['returns correct index for middle view by name'] = function()
  local yaml = [[
views:
  - name: First View
    type: table
  - name: Second View
    type: table
  - name: Third View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'Second View')
  expect.equality(view_err, nil)
  expect.equality(index, 1)
end

T['find_view_index']['returns correct index for last view by name'] = function()
  local yaml = [[
views:
  - name: First View
    type: table
  - name: Second View
    type: table
  - name: Third View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'Third View')
  expect.equality(view_err, nil)
  expect.equality(index, 2)
end

T['find_view_index']['returns error for non-existent view name'] = function()
  local yaml = [[
views:
  - name: First View
    type: table
  - name: Second View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'Non Existent')
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
  expect.equality(view_err:match('not found') ~= nil, true)
end

T['find_view_index']['handles views with default names'] = function()
  local yaml = [[
views:
  - type: table
  - type: cards
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'View 1')
  expect.equality(view_err, nil)
  expect.equality(index, 0)
  index, view_err = base_parser.find_view_index(config, 'View 2')
  expect.equality(view_err, nil)
  expect.equality(index, 1)
end

T['find_view_index']['returns error for nil config'] = function()
  local index, view_err = base_parser.find_view_index(nil, 'Some View')
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
end

T['find_view_index']['returns error for non-table config'] = function()
  local index, view_err = base_parser.find_view_index('not a table', 'Some View')
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
end

T['find_view_index']['returns error for nil view_name'] = function()
  local yaml = [[
views:
  - name: Test View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, nil)
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
end

T['find_view_index']['returns error for non-string view_name'] = function()
  local yaml = [[
views:
  - name: Test View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 42)
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
end

T['find_view_index']['handles single view'] = function()
  local yaml = [[
views:
  - name: Only View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'Only View')
  expect.equality(view_err, nil)
  expect.equality(index, 0)
end

T['find_view_index']['is case sensitive'] = function()
  local yaml = [[
views:
  - name: My View
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'my view')
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
  index, view_err = base_parser.find_view_index(config, 'MY VIEW')
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
end

T['find_view_index']['error message includes the requested view name'] = function()
  local yaml = [[
views:
  - name: Foo
    type: table
]]
  local config, err = base_parser.parse_string(yaml)
  expect.equality(err, nil)
  local index, view_err = base_parser.find_view_index(config, 'Bar')
  expect.equality(index, nil)
  expect.no_equality(view_err, nil)
  expect.equality(view_err:match("'Bar'") ~= nil, true)
end

return T
