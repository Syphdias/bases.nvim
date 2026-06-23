local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local yaml = require('bases.engine.yaml')

local T = new_set()

-- =======================
-- parse_value: Empty/Blank
-- =======================

T['parse_value'] = new_set()

T['parse_value']['nil for empty string'] = function()
  expect.equality(yaml.parse_value(''), nil)
end

T['parse_value']['nil for blank string'] = function()
  expect.equality(yaml.parse_value('   '), nil)
end

T['parse_value']['nil for whitespace with tabs'] = function()
  expect.equality(yaml.parse_value('\t\t'), nil)
end

-- =======================
-- parse_value: Quoted Strings
-- =======================

T['parse_value']['double quoted string'] = function()
  expect.equality(yaml.parse_value('"hello"'), 'hello')
end

T['parse_value']['single quoted string'] = function()
  expect.equality(yaml.parse_value("'hello'"), 'hello')
end

T['parse_value']['empty double quoted string'] = function()
  expect.equality(yaml.parse_value('""'), '')
end

T['parse_value']['empty single quoted string'] = function()
  expect.equality(yaml.parse_value("''"), '')
end

T['parse_value']['double quoted with spaces'] = function()
  expect.equality(yaml.parse_value('"hello world"'), 'hello world')
end

T['parse_value']['single quoted with spaces'] = function()
  expect.equality(yaml.parse_value("'hello world'"), 'hello world')
end

T['parse_value']['double quoted with surrounding whitespace'] = function()
  expect.equality(yaml.parse_value('  "hello"  '), 'hello')
end

-- =======================
-- parse_value: Double-Quoted Escapes
-- =======================

T['parse_value']['escape newline'] = function()
  expect.equality(yaml.parse_value('"line1\\nline2"'), 'line1\nline2')
end

T['parse_value']['escape carriage return'] = function()
  expect.equality(yaml.parse_value('"text\\rmore"'), 'text\rmore')
end

T['parse_value']['escape tab'] = function()
  expect.equality(yaml.parse_value('"text\\ttab"'), 'text\ttab')
end

T['parse_value']['escape backslash'] = function()
  expect.equality(yaml.parse_value('"path\\\\file"'), 'path\\file')
end

T['parse_value']['escape double quote'] = function()
  expect.equality(yaml.parse_value('"say \\"hello\\""'), 'say "hello"')
end

T['parse_value']['escape single quote in double quoted'] = function()
  expect.equality(yaml.parse_value('"it\\\'s"'), "it's")
end

T['parse_value']['multiple escapes'] = function()
  expect.equality(yaml.parse_value('"\\n\\t\\r\\\\"'), '\n\t\r\\')
end

-- =======================
-- parse_value: Single-Quoted Escapes
-- =======================

T['parse_value']['single quoted double apostrophe becomes single'] = function()
  expect.equality(yaml.parse_value("'it''s'"), "it's")
end

T['parse_value']['single quoted multiple double apostrophes'] = function()
  expect.equality(yaml.parse_value("'don''t can''t'"), "don't can't")
end

T['parse_value']['single quoted no escape sequences'] = function()
  expect.equality(yaml.parse_value("'\\n\\t'"), '\\n\\t')
end

-- =======================
-- parse_value: Null Values
-- =======================

T['parse_value']['null keyword'] = function()
  expect.equality(yaml.parse_value('null'), nil)
end

T['parse_value']['tilde null'] = function()
  expect.equality(yaml.parse_value('~'), nil)
end

T['parse_value']['null with whitespace'] = function()
  expect.equality(yaml.parse_value('  null  '), nil)
end

T['parse_value']['tilde with whitespace'] = function()
  expect.equality(yaml.parse_value('  ~  '), nil)
end

-- =======================
-- parse_value: Booleans
-- =======================

T['parse_value']['boolean true'] = function()
  expect.equality(yaml.parse_value('true'), true)
end

T['parse_value']['boolean false'] = function()
  expect.equality(yaml.parse_value('false'), false)
end

T['parse_value']['boolean yes'] = function()
  expect.equality(yaml.parse_value('yes'), true)
end

T['parse_value']['boolean no'] = function()
  expect.equality(yaml.parse_value('no'), false)
end

T['parse_value']['boolean on'] = function()
  expect.equality(yaml.parse_value('on'), true)
end

T['parse_value']['boolean off'] = function()
  expect.equality(yaml.parse_value('off'), false)
end

T['parse_value']['boolean TRUE case insensitive'] = function()
  expect.equality(yaml.parse_value('TRUE'), true)
end

T['parse_value']['boolean False case insensitive'] = function()
  expect.equality(yaml.parse_value('False'), false)
end

T['parse_value']['boolean YES case insensitive'] = function()
  expect.equality(yaml.parse_value('YES'), true)
end

T['parse_value']['boolean No case insensitive'] = function()
  expect.equality(yaml.parse_value('No'), false)
end

T['parse_value']['boolean ON case insensitive'] = function()
  expect.equality(yaml.parse_value('ON'), true)
end

T['parse_value']['boolean Off case insensitive'] = function()
  expect.equality(yaml.parse_value('Off'), false)
end

-- =======================
-- parse_value: Numbers
-- =======================

T['parse_value']['integer'] = function()
  expect.equality(yaml.parse_value('42'), 42)
end

T['parse_value']['negative integer'] = function()
  expect.equality(yaml.parse_value('-42'), -42)
end

T['parse_value']['zero'] = function()
  expect.equality(yaml.parse_value('0'), 0)
end

T['parse_value']['decimal'] = function()
  expect.equality(yaml.parse_value('3.14'), 3.14)
end

T['parse_value']['negative decimal'] = function()
  expect.equality(yaml.parse_value('-3.14'), -3.14)
end

T['parse_value']['decimal with leading zero'] = function()
  expect.equality(yaml.parse_value('0.5'), 0.5)
end

T['parse_value']['number with whitespace'] = function()
  expect.equality(yaml.parse_value('  42  '), 42)
end

-- =======================
-- parse_value: Bare Strings
-- =======================

T['parse_value']['bare string'] = function()
  expect.equality(yaml.parse_value('hello'), 'hello')
end

T['parse_value']['bare string with hyphens'] = function()
  expect.equality(yaml.parse_value('my-value'), 'my-value')
end

T['parse_value']['bare string with underscores'] = function()
  expect.equality(yaml.parse_value('my_value'), 'my_value')
end

T['parse_value']['bare string alphanumeric'] = function()
  expect.equality(yaml.parse_value('value123'), 'value123')
end

T['parse_value']['bare string trimmed'] = function()
  expect.equality(yaml.parse_value('  bare  '), 'bare')
end

-- =======================
-- parse: Empty/Nil
-- =======================

T['parse'] = new_set()

T['parse']['nil input'] = function()
  expect.equality(vim.tbl_count(yaml.parse(nil)), 0)
end

T['parse']['empty string'] = function()
  expect.equality(vim.tbl_count(yaml.parse('')), 0)
end

T['parse']['blank lines only'] = function()
  expect.equality(vim.tbl_count(yaml.parse('\n\n\n')), 0)
end

-- =======================
-- parse: Simple Key-Value
-- =======================

T['parse']['single key value'] = function()
  local result = yaml.parse('name: John')
  expect.equality(result.name, 'John')
end

T['parse']['multiple key values'] = function()
  local result = yaml.parse('name: John\nage: 30')
  expect.equality(result.name, 'John')
  expect.equality(result.age, 30)
end

T['parse']['key with spaces around colon'] = function()
  local result = yaml.parse('name  :  John')
  expect.equality(result.name, 'John')
end

T['parse']['key with empty value'] = function()
  local result = yaml.parse('name:')
  expect.equality(result.name, nil)
end

T['parse']['key with whitespace-only value'] = function()
  local result = yaml.parse('name:   ')
  expect.equality(result.name, nil)
end

-- =======================
-- parse: Type Coercion
-- =======================

T['parse']['coerce boolean values'] = function()
  local result = yaml.parse('active: true\ninactive: false')
  expect.equality(result.active, true)
  expect.equality(result.inactive, false)
end

T['parse']['coerce number values'] = function()
  local result = yaml.parse('count: 42\nprice: 19.99')
  expect.equality(result.count, 42)
  expect.equality(result.price, 19.99)
end

T['parse']['coerce null values'] = function()
  local result = yaml.parse('empty: null\ntilde: ~')
  expect.equality(result.empty, nil)
  expect.equality(result.tilde, nil)
end

T['parse']['preserve quoted strings'] = function()
  local result = yaml.parse('text: "hello"\nnum: "42"')
  expect.equality(result.text, 'hello')
  expect.equality(result.num, '42')
end

T['parse']['bare string values'] = function()
  local result = yaml.parse('status: pending\ntype: urgent-task')
  expect.equality(result.status, 'pending')
  expect.equality(result.type, 'urgent-task')
end

-- =======================
-- parse: Nested Maps
-- =======================

T['parse']['nested map'] = function()
  local result = yaml.parse('person:\n  name: John\n  age: 30')
  expect.equality(result.person.name, 'John')
  expect.equality(result.person.age, 30)
end

T['parse']['deeply nested maps'] = function()
  local yaml_str = [[
level1:
  level2:
    level3:
      value: deep
]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.level1.level2.level3.value, 'deep')
end

T['parse']['multiple nested maps'] = function()
  local yaml_str = [[
person:
  name: John
  age: 30
address:
  city: NYC
  zip: 10001
]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.person.name, 'John')
  expect.equality(result.address.city, 'NYC')
  expect.equality(result.address.zip, 10001)
end

T['parse']['nested map with empty parent value'] = function()
  local yaml_str = [[
parent:
  child: value
]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.parent.child, 'value')
end

-- =======================
-- parse: Block Lists
-- =======================

T['parse']['simple list'] = function()
  local result = yaml.parse('items:\n  - apple\n  - banana\n  - cherry')
  expect.equality(#result.items, 3)
  expect.equality(result.items[1], 'apple')
  expect.equality(result.items[2], 'banana')
  expect.equality(result.items[3], 'cherry')
end

T['parse']['list with numbers'] = function()
  local result = yaml.parse('numbers:\n  - 1\n  - 2\n  - 3')
  expect.equality(#result.numbers, 3)
  expect.equality(result.numbers[1], 1)
  expect.equality(result.numbers[2], 2)
  expect.equality(result.numbers[3], 3)
end

T['parse']['list with booleans'] = function()
  local result = yaml.parse('flags:\n  - true\n  - false\n  - yes')
  expect.equality(#result.flags, 3)
  expect.equality(result.flags[1], true)
  expect.equality(result.flags[2], false)
  expect.equality(result.flags[3], true)
end

T['parse']['list with quoted strings'] = function()
  local result = yaml.parse('items:\n  - "quoted"\n  - \'single\'')
  expect.equality(#result.items, 2)
  expect.equality(result.items[1], 'quoted')
  expect.equality(result.items[2], 'single')
end

T['parse']['list with mixed types'] = function()
  local result = yaml.parse('mixed:\n  - text\n  - 42\n  - true')
  expect.equality(#result.mixed, 3)
  expect.equality(result.mixed[1], 'text')
  expect.equality(result.mixed[2], 42)
  expect.equality(result.mixed[3], true)
end

-- =======================
-- parse: Flow Sequences
-- =======================

T['parse']['empty flow sequence'] = function()
  local result = yaml.parse('items: []')
  expect.equality(#result.items, 0)
end

T['parse']['flow sequence with one item'] = function()
  local result = yaml.parse('items: [apple]')
  expect.equality(#result.items, 1)
  expect.equality(result.items[1], 'apple')
end

T['parse']['flow sequence with multiple items'] = function()
  local result = yaml.parse('items: [apple, banana, cherry]')
  expect.equality(#result.items, 3)
  expect.equality(result.items[1], 'apple')
  expect.equality(result.items[2], 'banana')
  expect.equality(result.items[3], 'cherry')
end

T['parse']['flow sequence with numbers'] = function()
  local result = yaml.parse('numbers: [1, 2, 3]')
  expect.equality(#result.numbers, 3)
  expect.equality(result.numbers[1], 1)
  expect.equality(result.numbers[2], 2)
  expect.equality(result.numbers[3], 3)
end

T['parse']['flow sequence with booleans'] = function()
  local result = yaml.parse('flags: [true, false, yes]')
  expect.equality(#result.flags, 3)
  expect.equality(result.flags[1], true)
  expect.equality(result.flags[2], false)
  expect.equality(result.flags[3], true)
end

T['parse']['flow sequence with spaces'] = function()
  local result = yaml.parse('items: [ apple , banana , cherry ]')
  expect.equality(#result.items, 3)
  expect.equality(result.items[1], 'apple')
end

T['parse']['flow sequence with quoted strings'] = function()
  local result = yaml.parse('items: ["hello", \'world\']')
  expect.equality(#result.items, 2)
  expect.equality(result.items[1], 'hello')
  expect.equality(result.items[2], 'world')
end

-- =======================
-- parse: Flow Mappings
-- =======================

T['parse']['empty flow mapping'] = function()
  local result = yaml.parse('obj: {}')
  expect.equality(vim.tbl_count(result.obj), 0)
end

T['parse']['flow mapping with one entry'] = function()
  local result = yaml.parse('obj: {name: John}')
  expect.equality(result.obj.name, 'John')
end

T['parse']['flow mapping with multiple entries'] = function()
  local result = yaml.parse('obj: {name: John, age: 30}')
  expect.equality(result.obj.name, 'John')
  expect.equality(result.obj.age, 30)
end

T['parse']['flow mapping with spaces'] = function()
  local result = yaml.parse('obj: { name : John , age : 30 }')
  expect.equality(result.obj.name, 'John')
  expect.equality(result.obj.age, 30)
end

T['parse']['flow mapping with quoted values'] = function()
  local result = yaml.parse('obj: {text: "hello", num: "42"}')
  expect.equality(result.obj.text, 'hello')
  expect.equality(result.obj.num, '42')
end

T['parse']['flow mapping with boolean and number'] = function()
  local result = yaml.parse('obj: {active: true, count: 5}')
  expect.equality(result.obj.active, true)
  expect.equality(result.obj.count, 5)
end

-- =======================
-- parse: Literal Block Scalar
-- =======================

T['parse']['literal block scalar'] = function()
  local yaml_str = [[description: |
    Line 1
    Line 2
    Line 3
next: value]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.description, '  Line 1\n  Line 2\n  Line 3')
end

T['parse']['literal block scalar with empty lines'] = function()
  local yaml_str = [[text: |
    First

    Second
next: value]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.text, '  First\n\n  Second')
end

T['parse']['literal block scalar preserves indentation'] = function()
  local yaml_str = [[code: |
    def hello():
      print("hi")
next: value]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.code, '  def hello():\n    print("hi")')
end

-- =======================
-- parse: Folded Block Scalar
-- =======================

T['parse']['folded block scalar'] = function()
  local yaml_str = [[text: >
    This is
    a long
    paragraph
next: value]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.text, 'This is a long paragraph')
end

T['parse']['folded block scalar with multiple words'] = function()
  local yaml_str = [[description: >
    Lorem ipsum
    dolor sit
    amet
next: value]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.description, 'Lorem ipsum dolor sit amet')
end

-- =======================
-- parse: Frontmatter Delimiters
-- =======================

T['parse']['frontmatter with opening delimiter'] = function()
  local result = yaml.parse('---\nname: John\nage: 30')
  expect.equality(result.name, 'John')
  expect.equality(result.age, 30)
end

T['parse']['frontmatter with closing delimiter'] = function()
  local result = yaml.parse('---\nname: John\n---')
  expect.equality(result.name, 'John')
end

T['parse']['frontmatter with ellipsis closing'] = function()
  local result = yaml.parse('---\nname: John\n...')
  expect.equality(result.name, 'John')
end

T['parse']['frontmatter ignores content after closing'] = function()
  local result = yaml.parse('---\nname: John\n---\nignored: true')
  expect.equality(result.name, 'John')
  expect.equality(result.ignored, nil)
end

T['parse']['frontmatter with both delimiters'] = function()
  local result = yaml.parse('---\nname: John\nage: 30\n---\nmore content')
  expect.equality(result.name, 'John')
  expect.equality(result.age, 30)
end

T['parse']['only opening delimiter'] = function()
  local result = yaml.parse('---')
  expect.equality(vim.tbl_count(result), 0)
end

-- =======================
-- parse: Inline Comments
-- =======================

T['parse']['comment after value'] = function()
  local result = yaml.parse('name: John # this is a comment')
  expect.equality(result.name, 'John')
end

T['parse']['full line comment'] = function()
  local result = yaml.parse('# comment line\nname: John')
  expect.equality(result.name, 'John')
end

T['parse']['multiple comments'] = function()
  local result = yaml.parse('# header\nname: John # name\nage: 30 # age')
  expect.equality(result.name, 'John')
  expect.equality(result.age, 30)
end

T['parse']['hash in quoted string not treated as comment'] = function()
  local result = yaml.parse('text: "hello # world"')
  expect.equality(result.text, 'hello # world')
end

T['parse']['hash in single quoted string'] = function()
  local result = yaml.parse("text: 'hello # world'")
  expect.equality(result.text, 'hello # world')
end

-- =======================
-- parse: List Items with Inline Key-Value
-- =======================

T['parse']['list with inline key-value'] = function()
  local yaml_str = [[
items:
  - type: table
  - type: chart
]]
  local result = yaml.parse(yaml_str)
  expect.equality(#result.items, 2)
  expect.equality(result.items[1].type, 'table')
  expect.equality(result.items[2].type, 'chart')
end

T['parse']['list with inline key-value and continuation'] = function()
  local yaml_str = [[
items:
  - type: table
    name: Main
  - type: chart
    name: Graph
]]
  local result = yaml.parse(yaml_str)
  expect.equality(#result.items, 2)
  expect.equality(result.items[1].type, 'table')
  expect.equality(result.items[1].name, 'Main')
  expect.equality(result.items[2].type, 'chart')
  expect.equality(result.items[2].name, 'Graph')
end

-- =======================
-- parse: List Items with Flow Mappings
-- =======================

T['parse']['list with flow mapping items'] = function()
  local yaml_str = [[
items:
  - {name: John, age: 30}
  - {name: Jane, age: 25}
]]
  local result = yaml.parse(yaml_str)
  expect.equality(#result.items, 2)
  expect.equality(result.items[1].name, 'John')
  expect.equality(result.items[1].age, 30)
  expect.equality(result.items[2].name, 'Jane')
  expect.equality(result.items[2].age, 25)
end

T['parse']['list with flow sequence items'] = function()
  local yaml_str = [[
matrix:
  - [1, 2, 3]
  - [4, 5, 6]
]]
  local result = yaml.parse(yaml_str)
  expect.equality(#result.matrix, 2)
  expect.equality(#result.matrix[1], 3)
  expect.equality(result.matrix[1][1], 1)
  expect.equality(result.matrix[2][3], 6)
end

-- =======================
-- parse: Nested Structures in Lists
-- =======================

T['parse']['list with nested maps'] = function()
  local yaml_str = [[
people:
  - name: John
    address:
      city: NYC
      zip: 10001
  - name: Jane
    address:
      city: LA
      zip: 90001
]]
  local result = yaml.parse(yaml_str)
  expect.equality(#result.people, 2)
  expect.equality(result.people[1].name, 'John')
  expect.equality(result.people[1].address.city, 'NYC')
  expect.equality(result.people[2].address.zip, 90001)
end

-- =======================
-- parse: Complex Real-World Examples
-- =======================

T['parse']['obsidian frontmatter example'] = function()
  local yaml_str = [[
---
title: My Note
tags: [project, important]
created: 2025-01-01
status: active
metadata:
  author: John
  version: 1.0
---
]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.title, 'My Note')
  expect.equality(#result.tags, 2)
  expect.equality(result.tags[1], 'project')
  expect.equality(result.status, 'active')
  expect.equality(result.metadata.author, 'John')
  expect.equality(result.metadata.version, 1.0)
end

T['parse']['base file example'] = function()
  local yaml_str = [[
type: table
columns:
  - name: Name
    type: text
  - name: Status
    type: select
rows:
  - {name: Project A, status: active}
  - {name: Project B, status: done}
]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.type, 'table')
  expect.equality(#result.columns, 2)
  expect.equality(result.columns[1].name, 'Name')
  expect.equality(result.columns[1].type, 'text')
  expect.equality(#result.rows, 2)
  expect.equality(result.rows[1].name, 'Project A')
  expect.equality(result.rows[2].status, 'done')
end

T['parse']['mixed nesting'] = function()
  local yaml_str = [[
config:
  name: Test
  options: [fast, secure]
  nested:
    level: 2
    items:
      - one
      - two
]]
  local result = yaml.parse(yaml_str)
  expect.equality(result.config.name, 'Test')
  expect.equality(#result.config.options, 2)
  expect.equality(result.config.nested.level, 2)
  expect.equality(#result.config.nested.items, 2)
  expect.equality(result.config.nested.items[1], 'one')
end

T['parse']['block sequence at parent indent'] = function()
  -- YAML spec allows a block sequence to start at the same indent as its key.
  local yaml_str = [[
authors:
- "C.S. Lewis"
year: 1950
]]
  local result = yaml.parse(yaml_str)
  expect.equality(type(result.authors), 'table')
  expect.equality(#result.authors, 1)
  expect.equality(result.authors[1], 'C.S. Lewis')
  expect.equality(result.year, 1950)
end

T['parse']['multiple block sequence items at parent indent'] = function()
  local yaml_str = [[
tags:
- book
- chronicles-of-narnia
genre: Fantasy
]]
  local result = yaml.parse(yaml_str)
  expect.equality(type(result.tags), 'table')
  expect.equality(#result.tags, 2)
  expect.equality(result.tags[1], 'book')
  expect.equality(result.tags[2], 'chronicles-of-narnia')
  expect.equality(result.genre, 'Fantasy')
end

T['parse']['block sequence at parent indent with wikilinks'] = function()
  local yaml_str = [==[
authors:
- "[[J.R.R. Tolkien]]"
year: 1937
]==]
  local result = yaml.parse(yaml_str)
  expect.equality(type(result.authors), 'table')
  expect.equality(#result.authors, 1)
  expect.equality(result.authors[1], '[[J.R.R. Tolkien]]')
  expect.equality(result.year, 1937)
end

return T
