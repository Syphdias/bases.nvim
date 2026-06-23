local MiniTest = require('mini.test')
local new_set = MiniTest.new_set
local expect = MiniTest.expect

local methods = require('bases.engine.expr.methods')
local types = require('bases.engine.expr.types')

local T = new_set()

-- =======================
-- Null receiver
-- =======================

T['dispatch'] = new_set()
T['dispatch']['null receiver'] = new_set()

T['dispatch']['null receiver']['isEmpty returns true'] = function()
  local result = methods.dispatch(types.null(), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['null receiver']['contains returns null'] = function()
  local result = methods.dispatch(types.null(), 'contains', { types.string('x') }, nil, nil)
  expect.equality(result.type, 'null')
end

T['dispatch']['null receiver']['startsWith returns null'] = function()
  local result = methods.dispatch(types.null(), 'startsWith', { types.string('a') }, nil, nil)
  expect.equality(result.type, 'null')
end

T['dispatch']['null receiver']['unknown method returns null'] = function()
  local result = methods.dispatch(types.null(), 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- String methods
-- =======================

T['dispatch']['string'] = new_set()

T['dispatch']['string']['contains with match'] = function()
  local result = methods.dispatch(types.string('hello world'), 'contains', { types.string('world') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['contains without match'] = function()
  local result = methods.dispatch(types.string('hello world'), 'contains', { types.string('foo') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['contains no args'] = function()
  local result = methods.dispatch(types.string('hello'), 'contains', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['contains case sensitive'] = function()
  local result = methods.dispatch(types.string('Hello'), 'contains', { types.string('hello') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['containsAll with list all present'] = function()
  local list = types.list({ types.string('he'), types.string('lo') })
  local result = methods.dispatch(types.string('hello'), 'containsAll', { list }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['containsAll with list some missing'] = function()
  local list = types.list({ types.string('he'), types.string('world') })
  local result = methods.dispatch(types.string('hello'), 'containsAll', { list }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['containsAll with empty list'] = function()
  local result = methods.dispatch(types.string('hello'), 'containsAll', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['containsAll with non-list arg'] = function()
  local result = methods.dispatch(types.string('hello'), 'containsAll', { types.string('he') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['containsAny with list one present'] = function()
  local list = types.list({ types.string('foo'), types.string('lo') })
  local result = methods.dispatch(types.string('hello'), 'containsAny', { list }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['containsAny with list none present'] = function()
  local list = types.list({ types.string('foo'), types.string('bar') })
  local result = methods.dispatch(types.string('hello'), 'containsAny', { list }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['startsWith match'] = function()
  local result = methods.dispatch(types.string('hello world'), 'startsWith', { types.string('hello') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['startsWith no match'] = function()
  local result = methods.dispatch(types.string('hello world'), 'startsWith', { types.string('world') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['startsWith no args'] = function()
  local result = methods.dispatch(types.string('hello'), 'startsWith', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['endsWith match'] = function()
  local result = methods.dispatch(types.string('hello world'), 'endsWith', { types.string('world') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['endsWith no match'] = function()
  local result = methods.dispatch(types.string('hello world'), 'endsWith', { types.string('hello') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['isEmpty true for empty string'] = function()
  local result = methods.dispatch(types.string(''), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['string']['isEmpty false for non-empty string'] = function()
  local result = methods.dispatch(types.string('hello'), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['string']['lower'] = function()
  local result = methods.dispatch(types.string('HELLO World'), 'lower', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello world')
end

T['dispatch']['string']['title single word'] = function()
  local result = methods.dispatch(types.string('hello'), 'title', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'Hello')
end

T['dispatch']['string']['title multiple words'] = function()
  local result = methods.dispatch(types.string('hello world'), 'title', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'Hello World')
end

T['dispatch']['string']['title mixed case'] = function()
  local result = methods.dispatch(types.string('hELLO wORLD'), 'title', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'Hello World')
end

T['dispatch']['string']['trim whitespace'] = function()
  local result = methods.dispatch(types.string('  hello  '), 'trim', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['dispatch']['string']['trim tabs and newlines'] = function()
  local result = methods.dispatch(types.string('\t\nhello\n\t'), 'trim', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['dispatch']['string']['reverse'] = function()
  local result = methods.dispatch(types.string('hello'), 'reverse', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'olleh')
end

T['dispatch']['string']['slice from start'] = function()
  local result = methods.dispatch(types.string('hello'), 'slice', { types.number(1) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'ello')
end

T['dispatch']['string']['slice with end'] = function()
  local result = methods.dispatch(types.string('hello'), 'slice', { types.number(1), types.number(4) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'ell')
end

T['dispatch']['string']['slice negative start'] = function()
  local result = methods.dispatch(types.string('hello'), 'slice', { types.number(-2) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'lo')
end

T['dispatch']['string']['slice negative end'] = function()
  local result = methods.dispatch(types.string('hello'), 'slice', { types.number(0), types.number(-1) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hell')
end

T['dispatch']['string']['slice no args'] = function()
  local result = methods.dispatch(types.string('hello'), 'slice', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['dispatch']['string']['slice start greater than end'] = function()
  local result = methods.dispatch(types.string('hello'), 'slice', { types.number(3), types.number(1) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '')
end

T['dispatch']['string']['split by space'] = function()
  local result = methods.dispatch(types.string('hello world'), 'split', { types.string(' ') }, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 'hello')
  expect.equality(result.value[2].value, 'world')
end

T['dispatch']['string']['split by comma'] = function()
  local result = methods.dispatch(types.string('a,b,c'), 'split', { types.string(',') }, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
  expect.equality(result.value[3].value, 'c')
end

T['dispatch']['string']['split empty separator'] = function()
  local result = methods.dispatch(types.string('abc'), 'split', { types.string('') }, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
  expect.equality(result.value[3].value, 'c')
end

T['dispatch']['string']['split no args'] = function()
  local result = methods.dispatch(types.string('hello'), 'split', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 1)
  expect.equality(result.value[1].value, 'hello')
end

T['dispatch']['string']['replace simple'] = function()
  local result =
    methods.dispatch(types.string('hello world'), 'replace', { types.string('world'), types.string('there') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello there')
end

T['dispatch']['string']['replace multiple occurrences'] = function()
  local result =
    methods.dispatch(types.string('foo bar foo'), 'replace', { types.string('foo'), types.string('baz') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'baz bar baz')
end

T['dispatch']['string']['replace no match'] = function()
  local result = methods.dispatch(types.string('hello'), 'replace', { types.string('x'), types.string('y') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['dispatch']['string']['replace insufficient args'] = function()
  local result = methods.dispatch(types.string('hello'), 'replace', { types.string('h') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['dispatch']['string']['replace special characters escaped'] = function()
  local result =
    methods.dispatch(types.string('a.b'), 'replace', { types.string('.'), types.string('_') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'a_b')
end

T['dispatch']['string']['toString returns same value'] = function()
  local receiver = types.string('hello')
  local result = methods.dispatch(receiver, 'toString', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'hello')
end

T['dispatch']['string']['icon returns same value'] = function()
  local receiver = types.string('icon')
  local result = methods.dispatch(receiver, 'icon', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'icon')
end

T['dispatch']['string']['unknown method returns null'] = function()
  local result = methods.dispatch(types.string('hello'), 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- String fields
-- =======================

T['get_field'] = new_set()
T['get_field']['string'] = new_set()

T['get_field']['string']['length'] = function()
  local result = methods.get_field(types.string('hello'), 'length')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['get_field']['string']['length empty'] = function()
  local result = methods.get_field(types.string(''), 'length')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

T['get_field']['string']['unknown field'] = function()
  local result = methods.get_field(types.string('hello'), 'unknown')
  expect.equality(result, nil)
end

-- =======================
-- Number methods
-- =======================

T['dispatch']['number'] = new_set()

T['dispatch']['number']['abs positive'] = function()
  local result = methods.dispatch(types.number(5), 'abs', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['dispatch']['number']['abs negative'] = function()
  local result = methods.dispatch(types.number(-5), 'abs', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 5)
end

T['dispatch']['number']['abs zero'] = function()
  local result = methods.dispatch(types.number(0), 'abs', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

T['dispatch']['number']['ceil'] = function()
  local result = methods.dispatch(types.number(3.14), 'ceil', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 4)
end

T['dispatch']['number']['ceil negative'] = function()
  local result = methods.dispatch(types.number(-3.14), 'ceil', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, -3)
end

T['dispatch']['number']['floor'] = function()
  local result = methods.dispatch(types.number(3.14), 'floor', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 3)
end

T['dispatch']['number']['floor negative'] = function()
  local result = methods.dispatch(types.number(-3.14), 'floor', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, -4)
end

T['dispatch']['number']['round up'] = function()
  local result = methods.dispatch(types.number(3.6), 'round', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 4)
end

T['dispatch']['number']['round down'] = function()
  local result = methods.dispatch(types.number(3.4), 'round', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 3)
end

T['dispatch']['number']['round half'] = function()
  local result = methods.dispatch(types.number(3.5), 'round', {}, nil, nil)
  expect.equality(result.type, 'number')
  expect.equality(result.value, 4)
end

T['dispatch']['number']['toFixed no args'] = function()
  local result = methods.dispatch(types.number(3.14159), 'toFixed', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '3.14159')
end

T['dispatch']['number']['toFixed precision 2'] = function()
  local result = methods.dispatch(types.number(3.14159), 'toFixed', { types.number(2) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '3.14')
end

T['dispatch']['number']['toFixed precision 0'] = function()
  local result = methods.dispatch(types.number(3.14159), 'toFixed', { types.number(0) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '3')
end

T['dispatch']['number']['toFixed precision 4'] = function()
  local result = methods.dispatch(types.number(3.14159), 'toFixed', { types.number(4) }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '3.1416')
end

T['dispatch']['number']['isEmpty always false'] = function()
  local result = methods.dispatch(types.number(0), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['number']['toString'] = function()
  local result = methods.dispatch(types.number(42), 'toString', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '42')
end

T['dispatch']['number']['toString decimal'] = function()
  local result = methods.dispatch(types.number(3.14), 'toString', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '3.14')
end

T['dispatch']['number']['unknown method returns null'] = function()
  local result = methods.dispatch(types.number(42), 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- Date methods and fields
-- =======================

T['dispatch']['date'] = new_set()

-- Use a known timestamp: 2025-01-15 10:30:45
local test_timestamp = os.time({ year = 2025, month = 1, day = 15, hour = 10, min = 30, sec = 45 }) * 1000

T['dispatch']['date']['date strips time'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'date', {}, nil, nil)
  expect.equality(result.type, 'date')
  -- Result should be midnight on the same day
  local t = os.date('*t', math.floor(result.value / 1000))
  expect.equality(t.hour, 0)
  expect.equality(t.min, 0)
  expect.equality(t.sec, 0)
  expect.equality(t.year, 2025)
  expect.equality(t.month, 1)
  expect.equality(t.day, 15)
end

T['dispatch']['date']['time returns formatted string'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'time', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '10:30:45')
end

T['dispatch']['date']['format no args returns ISO'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'format', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(#result.value, 19)
  expect.no_equality(result.value:find('2025%-01%-15T10:30:45'), nil)
end

T['dispatch']['date']['format with pattern'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'format', { types.string('%Y-%m-%d') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '2025-01-15')
end

T['dispatch']['date']['format with custom pattern'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'format', { types.string('%B %d, %Y') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.no_equality(result.value:find('January 15, 2025'), nil)
end

T['dispatch']['date']['isEmpty always false'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['date']['unknown method returns null'] = function()
  local result = methods.dispatch(types.date(test_timestamp), 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

T['get_field']['date'] = new_set()

T['get_field']['date']['year'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'year')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 2025)
end

T['get_field']['date']['month'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'month')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 1)
end

T['get_field']['date']['day'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'day')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 15)
end

T['get_field']['date']['hour'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'hour')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 10)
end

T['get_field']['date']['minute'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'minute')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 30)
end

T['get_field']['date']['second'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'second')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 45)
end

T['get_field']['date']['millisecond'] = function()
  local ts_with_ms = test_timestamp + 123
  local result = methods.get_field(types.date(ts_with_ms), 'millisecond')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 123)
end

T['get_field']['date']['millisecond zero'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'millisecond')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

T['get_field']['date']['unknown field'] = function()
  local result = methods.get_field(types.date(test_timestamp), 'unknown')
  expect.equality(result, nil)
end

-- =======================
-- List methods
-- =======================

T['dispatch']['list'] = new_set()

T['dispatch']['list']['contains true'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'contains', { types.string('b') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['list']['contains false'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'contains', { types.string('x') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['list']['contains no args'] = function()
  local list = types.list({ types.string('a') })
  local result = methods.dispatch(list, 'contains', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['list']['contains number'] = function()
  local list = types.list({ types.number(1), types.number(2), types.number(3) })
  local result = methods.dispatch(list, 'contains', { types.number(2) }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['list']['containsAll with all present'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local search = types.list({ types.string('a'), types.string('c') })
  local result = methods.dispatch(list, 'containsAll', { search }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['list']['containsAll with some missing'] = function()
  local list = types.list({ types.string('a'), types.string('b') })
  local search = types.list({ types.string('a'), types.string('c') })
  local result = methods.dispatch(list, 'containsAll', { search }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['list']['containsAll empty search'] = function()
  local list = types.list({ types.string('a') })
  local result = methods.dispatch(list, 'containsAll', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['list']['containsAny with one present'] = function()
  local list = types.list({ types.string('a'), types.string('b') })
  local search = types.list({ types.string('b'), types.string('x') })
  local result = methods.dispatch(list, 'containsAny', { search }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['list']['containsAny with none present'] = function()
  local list = types.list({ types.string('a'), types.string('b') })
  local search = types.list({ types.string('x'), types.string('y') })
  local result = methods.dispatch(list, 'containsAny', { search }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['list']['isEmpty true'] = function()
  local result = methods.dispatch(types.list({}), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['list']['isEmpty false'] = function()
  local result = methods.dispatch(types.list({ types.string('a') }), 'isEmpty', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['list']['join default separator'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'join', {}, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'a,b,c')
end

T['dispatch']['list']['join custom separator'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'join', { types.string(' - ') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, 'a - b - c')
end

T['dispatch']['list']['join empty list'] = function()
  local result = methods.dispatch(types.list({}), 'join', { types.string(',') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '')
end

T['dispatch']['list']['join mixed types'] = function()
  local list = types.list({ types.number(1), types.string('a'), types.boolean(true) })
  local result = methods.dispatch(list, 'join', { types.string(',') }, nil, nil)
  expect.equality(result.type, 'string')
  expect.equality(result.value, '1,a,true')
end

T['dispatch']['list']['reverse'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'reverse', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 'c')
  expect.equality(result.value[2].value, 'b')
  expect.equality(result.value[3].value, 'a')
end

T['dispatch']['list']['reverse empty'] = function()
  local result = methods.dispatch(types.list({}), 'reverse', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 0)
end

T['dispatch']['list']['sort numbers'] = function()
  local list = types.list({ types.number(3), types.number(1), types.number(2) })
  local result = methods.dispatch(list, 'sort', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 1)
  expect.equality(result.value[2].value, 2)
  expect.equality(result.value[3].value, 3)
end

T['dispatch']['list']['sort strings'] = function()
  local list = types.list({ types.string('c'), types.string('a'), types.string('b') })
  local result = methods.dispatch(list, 'sort', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
  expect.equality(result.value[3].value, 'c')
end

T['dispatch']['list']['sort mixed types'] = function()
  local list = types.list({ types.string('b'), types.number(1), types.string('a'), types.number(2) })
  local result = methods.dispatch(list, 'sort', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 4)
  -- Numbers first (sorted), then strings (sorted)
  expect.equality(result.value[1].value, 1)
  expect.equality(result.value[2].value, 2)
  expect.equality(result.value[3].value, 'a')
  expect.equality(result.value[4].value, 'b')
end

T['dispatch']['list']['flat simple'] = function()
  local inner1 = types.list({ types.string('a'), types.string('b') })
  local inner2 = types.list({ types.string('c') })
  local list = types.list({ inner1, types.string('x'), inner2 })
  local result = methods.dispatch(list, 'flat', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 4)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
  expect.equality(result.value[3].value, 'x')
  expect.equality(result.value[4].value, 'c')
end

T['dispatch']['list']['flat nested'] = function()
  local inner2 = types.list({ types.string('c') })
  local inner1 = types.list({ types.string('a'), inner2 })
  local list = types.list({ inner1, types.string('b') })
  local result = methods.dispatch(list, 'flat', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'c')
  expect.equality(result.value[3].value, 'b')
end

T['dispatch']['list']['flat already flat'] = function()
  local list = types.list({ types.string('a'), types.string('b') })
  local result = methods.dispatch(list, 'flat', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
end

T['dispatch']['list']['unique removes duplicates'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('a'), types.string('c') })
  local result = methods.dispatch(list, 'unique', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 3)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
  expect.equality(result.value[3].value, 'c')
end

T['dispatch']['list']['unique by value and type'] = function()
  local list = types.list({ types.string('1'), types.number(1), types.string('1') })
  local result = methods.dispatch(list, 'unique', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].type, 'string')
  expect.equality(result.value[1].value, '1')
  expect.equality(result.value[2].type, 'number')
  expect.equality(result.value[2].value, 1)
end

T['dispatch']['list']['slice from start'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'slice', { types.number(1) }, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 'b')
  expect.equality(result.value[2].value, 'c')
end

T['dispatch']['list']['slice with end'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'slice', { types.number(0), types.number(2) }, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 'a')
  expect.equality(result.value[2].value, 'b')
end

T['dispatch']['list']['slice negative indices'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.dispatch(list, 'slice', { types.number(-2) }, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
  expect.equality(result.value[1].value, 'b')
  expect.equality(result.value[2].value, 'c')
end

T['dispatch']['list']['slice no args'] = function()
  local list = types.list({ types.string('a'), types.string('b') })
  local result = methods.dispatch(list, 'slice', {}, nil, nil)
  expect.equality(result.type, 'list')
  expect.equality(#result.value, 2)
end

T['dispatch']['list']['unknown method returns null'] = function()
  local result = methods.dispatch(types.list({}), 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

T['get_field']['list'] = new_set()

T['get_field']['list']['length'] = function()
  local list = types.list({ types.string('a'), types.string('b'), types.string('c') })
  local result = methods.get_field(list, 'length')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 3)
end

T['get_field']['list']['length empty'] = function()
  local result = methods.get_field(types.list({}), 'length')
  expect.equality(result.type, 'number')
  expect.equality(result.value, 0)
end

-- =======================
-- File methods
-- =======================

T['dispatch']['file'] = new_set()

T['dispatch']['file']['hasTag exact match'] = function()
  local note_data = { tag_set = { project = true, active = true } }
  local result = methods.dispatch(types.file(note_data), 'hasTag', { types.string('project') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasTag hierarchy match'] = function()
  local note_data = { tag_set = { ['project/active'] = true } }
  local result = methods.dispatch(types.file(note_data), 'hasTag', { types.string('project') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasTag no match'] = function()
  local note_data = { tag_set = { project = true } }
  local result = methods.dispatch(types.file(note_data), 'hasTag', { types.string('archive') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['hasTag case insensitive'] = function()
  local note_data = { tag_set = { Project = true } }
  local result = methods.dispatch(types.file(note_data), 'hasTag', { types.string('project') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasTag multiple tags all present'] = function()
  local note_data = { tag_set = { project = true, active = true } }
  local result =
    methods.dispatch(types.file(note_data), 'hasTag', { types.string('project'), types.string('active') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasTag multiple tags some missing'] = function()
  local note_data = { tag_set = { project = true } }
  local result =
    methods.dispatch(types.file(note_data), 'hasTag', { types.string('project'), types.string('active') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['hasTag no args'] = function()
  local note_data = { tag_set = { project = true } }
  local result = methods.dispatch(types.file(note_data), 'hasTag', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasTag no tag_set'] = function()
  local note_data = {}
  local result = methods.dispatch(types.file(note_data), 'hasTag', { types.string('project') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['hasLink exact match'] = function()
  local note_data = { outgoing_link_set = { ['notes/project'] = true } }
  local result = methods.dispatch(types.file(note_data), 'hasLink', { types.string('notes/project') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasLink case insensitive'] = function()
  local note_data = { outgoing_link_set = { ['notes/Project'] = true } }
  local result = methods.dispatch(types.file(note_data), 'hasLink', { types.string('notes/project') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['hasLink no match'] = function()
  local note_data = { outgoing_link_set = { ['notes/project'] = true } }
  local result = methods.dispatch(types.file(note_data), 'hasLink', { types.string('notes/other') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['hasLink no args'] = function()
  local note_data = { outgoing_link_set = { ['notes/project'] = true } }
  local result = methods.dispatch(types.file(note_data), 'hasLink', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['hasLink no outgoing_link_set'] = function()
  local note_data = {}
  local result = methods.dispatch(types.file(note_data), 'hasLink', { types.string('note') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['inFolder exact match'] = function()
  local note_data = { folder = 'projects' }
  local result = methods.dispatch(types.file(note_data), 'inFolder', { types.string('projects') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['inFolder prefix match'] = function()
  local note_data = { folder = 'projects/active' }
  local result = methods.dispatch(types.file(note_data), 'inFolder', { types.string('projects') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['file']['inFolder no match'] = function()
  local note_data = { folder = 'archive' }
  local result = methods.dispatch(types.file(note_data), 'inFolder', { types.string('projects') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['inFolder no folder field'] = function()
  local note_data = {}
  local result = methods.dispatch(types.file(note_data), 'inFolder', { types.string('projects') }, nil, nil)
  expect.equality(result.type, 'boolean')
  -- Empty string doesn't start with 'projects', so this is false
  expect.equality(result.value, false)
end

T['dispatch']['file']['inFolder no args'] = function()
  local note_data = { folder = 'projects' }
  local result = methods.dispatch(types.file(note_data), 'inFolder', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['file']['asLink default display'] = function()
  local note_data = { path = 'notes/project.md', basename = 'project' }
  local result = methods.dispatch(types.file(note_data), 'asLink', {}, nil, nil)
  expect.equality(result.type, 'link')
  expect.equality(result.path, 'notes/project.md')
  expect.equality(result.value, 'project')
end

T['dispatch']['file']['asLink custom display'] = function()
  local note_data = { path = 'notes/project.md', basename = 'project' }
  local result = methods.dispatch(types.file(note_data), 'asLink', { types.string('My Project') }, nil, nil)
  expect.equality(result.type, 'link')
  expect.equality(result.path, 'notes/project.md')
  expect.equality(result.value, 'My Project')
end

T['dispatch']['file']['unknown method returns null'] = function()
  local result = methods.dispatch(types.file({}), 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- Link methods
-- =======================

T['dispatch']['link'] = new_set()

T['dispatch']['link']['linksTo file match'] = function()
  -- Link implementation expects receiver.value.path, so value must be a table
  local link_typed = { type = 'link', value = { path = 'notes/project.md' } }
  local target = types.file({ path = 'notes/project.md' })
  local result = methods.dispatch(link_typed, 'linksTo', { target }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['link']['linksTo file no match'] = function()
  local link_typed = { type = 'link', value = { path = 'notes/project.md' } }
  local target = types.file({ path = 'notes/other.md' })
  local result = methods.dispatch(link_typed, 'linksTo', { target }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['link']['linksTo string match'] = function()
  local link_typed = { type = 'link', value = { path = 'notes/project.md' } }
  local result = methods.dispatch(link_typed, 'linksTo', { types.string('notes/project.md') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['link']['linksTo string no match'] = function()
  local link_typed = { type = 'link', value = { path = 'notes/project.md' } }
  local result = methods.dispatch(link_typed, 'linksTo', { types.string('notes/other.md') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['link']['linksTo no args'] = function()
  local link_typed = { type = 'link', value = { path = 'notes/project.md' } }
  local result = methods.dispatch(link_typed, 'linksTo', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['link']['linksTo other type'] = function()
  local link_typed = { type = 'link', value = { path = 'notes/project.md' } }
  local result = methods.dispatch(link_typed, 'linksTo', { types.number(42) }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['link']['unknown method returns null'] = function()
  local link_typed = { type = 'link', value = { path = 'note' } }
  local result = methods.dispatch(link_typed, 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- Regex methods
-- =======================

T['dispatch']['regex'] = new_set()

T['dispatch']['regex']['matches simple pattern'] = function()
  -- Regex implementation expects receiver.value.pattern, so value must be a table
  local regex = { type = 'regex', value = { pattern = 'h.l+o', flags = '' } }
  local result = methods.dispatch(regex, 'matches', { types.string('hello') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, true)
end

T['dispatch']['regex']['matches no match'] = function()
  local regex = { type = 'regex', value = { pattern = 'xyz', flags = '' } }
  local result = methods.dispatch(regex, 'matches', { types.string('hello') }, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['regex']['matches no args'] = function()
  local regex = { type = 'regex', value = { pattern = 'pattern', flags = '' } }
  local result = methods.dispatch(regex, 'matches', {}, nil, nil)
  expect.equality(result.type, 'boolean')
  expect.equality(result.value, false)
end

T['dispatch']['regex']['unknown method returns null'] = function()
  local regex = { type = 'regex', value = { pattern = 'pattern', flags = '' } }
  local result = methods.dispatch(regex, 'unknownMethod', {}, nil, nil)
  expect.equality(result.type, 'null')
end

-- =======================
-- values_equal helper
-- =======================

T['values_equal'] = new_set()

T['values_equal']['both null'] = function()
  local result = methods.values_equal(types.null(), types.null())
  expect.equality(result, true)
end

T['values_equal']['one null'] = function()
  local result = methods.values_equal(types.null(), types.string('a'))
  expect.equality(result, false)
end

T['values_equal']['same type and value'] = function()
  local result = methods.values_equal(types.string('hello'), types.string('hello'))
  expect.equality(result, true)
end

T['values_equal']['same type different value'] = function()
  local result = methods.values_equal(types.string('hello'), types.string('world'))
  expect.equality(result, false)
end

T['values_equal']['numeric conversion'] = function()
  local result = methods.values_equal(types.string('42'), types.number(42))
  expect.equality(result, true)
end

T['values_equal']['different types non-numeric'] = function()
  local result = methods.values_equal(types.string('hello'), types.boolean(true))
  expect.equality(result, false)
end

T['values_equal']['string with wiki-link brackets equals plain string'] = function()
  -- "[[J.R.R. Tolkien]]" should compare equal to "J.R.R. Tolkien" so
  -- that frontmatter values with wikilinks match plain string values
  -- used in `this` context.
  local result = methods.values_equal(types.string('[[J.R.R. Tolkien]]'), types.string('J.R.R. Tolkien'))
  expect.equality(result, true)
end

T['values_equal']['string with display-text wiki-link uses the link target'] = function()
  -- "[[link|display]]" should match "link" (the target), not "display".
  local result = methods.values_equal(types.string('[[J.R.R. Tolkien|Tolkien]]'), types.string('J.R.R. Tolkien'))
  expect.equality(result, true)
end

T['values_equal']['string matches link value or path'] = function()
  -- A link's value is the display name, path is the underlying target.
  -- A plain string should match either.
  local link = types.link('people/J.R.R. Tolkien.md', 'J.R.R. Tolkien')
  local str = types.string('J.R.R. Tolkien')
  expect.equality(methods.values_equal(str, link), true)
end

T['values_equal']['string with wiki-link brackets matches link path'] = function()
  -- "[[some/path]]" should match a link whose path ends in "some/path".
  local link = types.link('folder/some/path', 'some/path')
  local str = types.string('[[some/path]]')
  expect.equality(methods.values_equal(str, link), true)
end

return T
