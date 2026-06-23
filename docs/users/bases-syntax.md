# Bases Syntax Reference

This document describes the YAML-based query language used in Obsidian Bases to create database-like views of vault notes.

## Base File Structure

A `.base` file is a YAML document with four optional top-level sections that are processed in this order:

1. **filters** - Define which notes appear in the base
2. **formulas** - Compute derived values from note properties
3. **properties** - Configure property metadata and display settings
4. **views** - Define how the data is displayed (tables, cards, maps)

```ebnf
BaseFile ::= YAMLDocument
YAMLDocument ::= FiltersSection? FormulasSection? PropertiesSection? ViewsSection?
```

### Minimal Example

```yaml
filters:
  file.hasTag("project")

views:
  - type: table
    order: [file.name, status, priority]
```

This creates a table view showing all notes tagged with `#project`, displaying their name, status, and priority properties.

### Complete Example

```yaml
filters:
  and:
    - file.hasTag("task")
    - not:
        - note.status == "complete"

formulas:
  days_remaining: "note.due - today()"
  is_overdue: "days_remaining < 0"

properties:
  priority:
    type: select
    options: [high, medium, low]

views:
  - type: table
    name: "Active Tasks"
    order: [file.name, priority, due, formula.days_remaining]
    sort:
      - column: priority
        direction: DESC
      - column: due
        direction: ASC
```

## Embedding Syntax

There are two ways to embed a base into a note:

### File Embed

Use wikilink syntax to embed an entire base file:

```markdown
![[projects.base]]
```

To display a specific view by name, append `#<view-name>` to the embed:

```markdown
![[projects.base#Active Projects]]
```

The view name must match the `name:` field of one of the views in the
`views:` list of the base file. Matching is case-sensitive. If the named
view is not found in the base, the embed is rendered as an inline error
(`Error: View 'Foo' not found in projects.base`) instead of a table.

If the embed has no `#view` suffix, the first view in the `views:` list is
used.

### Code Block Embed

Define an inline base using a code block:

````markdown
```base
filters:
  file.hasTag("book")
views:
  - type: table
    order: [file.name, author, rating]
```
````

Code block embeds support `this.*` references to access properties from the containing note. See [The `this` Context](#the-this-context) for details.

## Filters

Filters determine which notes appear in your base. They use recursive boolean logic to combine conditions.

### Boolean Operators

- **and** - ALL conditions must be true
- **or** - ANY condition must be true
- **not** - NONE of the conditions can be true

### Filter Structure

```yaml
filters:
  or:
    - file.hasTag("project")
    - and:
        - file.hasTag("book")
        - file.hasLink("Textbook")
    - not:
        - file.inFolder("Archive")
```

This matches notes that are either:
- Tagged with `#project`, OR
- Tagged with `#book` AND link to the "Textbook" note, OR
- NOT in the "Archive" folder

### Nesting

Filters can be nested to unlimited depth. Each level can use `and`, `or`, or `not`:

```yaml
filters:
  and:
    - or:
        - file.hasTag("work")
        - file.hasTag("personal")
    - not:
        - or:
            - note.status == "archived"
            - note.status == "deleted"
```

### Global vs View-Specific Filters

Filters defined at the top level apply to all views. Each view can also define its own filters:

```yaml
filters:
  file.hasTag("project")  # Global filter

views:
  - type: table
    name: "High Priority"
    filters:
      note.priority == "high"  # View-specific filter
```

The effective filter for the "High Priority" view is the global filter AND the view filter, equivalent to:

```yaml
and:
  - file.hasTag("project")
  - note.priority == "high"
```

## Expression Grammar

Bases expressions follow a C-like syntax with operator precedence and associativity rules.

### EBNF Grammar

```ebnf
Expression         ::= LogicalOrExpr
LogicalOrExpr      ::= LogicalAndExpr ('||' LogicalAndExpr)*
LogicalAndExpr     ::= EqualityExpr ('&&' EqualityExpr)*
EqualityExpr       ::= RelationalExpr (('==' | '!=') RelationalExpr)*
RelationalExpr     ::= AdditiveExpr (('<' | '>' | '<=' | '>=') AdditiveExpr)*
AdditiveExpr       ::= MultiplicativeExpr (('+' | '-') MultiplicativeExpr)*
MultiplicativeExpr ::= UnaryExpr (('*' | '/' | '%') UnaryExpr)*
UnaryExpr          ::= '!' UnaryExpr | PostfixExpr
PostfixExpr        ::= PrimaryExpr ('.' Identifier ArgumentList? | '[' Expression ']' | ArgumentList)*
PrimaryExpr        ::= Literal | Identifier | '(' Expression ')' | ArrayLiteral | ObjectLiteral
ArgumentList       ::= '(' (Expression (',' Expression)*)? ')'
ArrayLiteral       ::= '[' (Expression (',' Expression)*)? ']'
ObjectLiteral      ::= '{' (Identifier ':' Expression (',' Identifier ':' Expression)*)? '}'
Literal            ::= String | Number | Boolean | Null
Identifier         ::= [a-zA-Z_][a-zA-Z0-9_]*
String             ::= '"' StringChar* '"' | "'" StringChar* "'"
Number             ::= '-'? Digit+ ('.' Digit+)?
Boolean            ::= 'true' | 'false'
Null               ::= 'null'
```

### Operator Precedence

Operators are evaluated in the following order (highest to lowest precedence):

| Level | Operators        | Associativity | Description              |
|-------|------------------|---------------|--------------------------|
| 1     | `()` `[]` `.`    | Left          | Grouping, indexing, access |
| 2     | `!`              | Right         | Logical NOT              |
| 3     | `*` `/` `%`      | Left          | Multiplication, division, modulo |
| 4     | `+` `-`          | Left          | Addition, subtraction    |
| 5     | `<` `>` `<=` `>=`| Left          | Relational comparison    |
| 6     | `==` `!=`        | Left          | Equality comparison      |
| 7     | `&&`             | Left          | Logical AND              |
| 8     | `||`             | Left          | Logical OR               |

### Important: Arithmetic Spacing

**Arithmetic operators (`+`, `-`, `*`, `/`, `%`) MUST be surrounded by whitespace.**

```yaml
# VALID
formula: "price * quantity"
formula: "total - discount"
formula: "count + 1"

# INVALID - Will cause parse errors
formula: "price*quantity"
formula: "total-discount"
formula: "count+1"
```

This requirement prevents ambiguity with property names and negative numbers.

## Data Types

### String

Text values enclosed in single or double quotes.

**Literals:**
```yaml
formula: "'hello world'"
formula: '"double quotes"'
```

**Escape Sequences:**
- `\\` - Backslash
- `\"` - Double quote
- `\'` - Single quote
- `\n` - Newline
- `\r` - Carriage return
- `\t` - Tab

**Properties:**
- `.length` - Number of characters

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.contains(substring)` | Boolean | True if string contains substring |
| `.containsAll(str...)` | Boolean | True if string contains all arguments |
| `.containsAny(str...)` | Boolean | True if string contains any argument |
| `.startsWith(prefix)` | Boolean | True if string starts with prefix |
| `.endsWith(suffix)` | Boolean | True if string ends with suffix |
| `.isEmpty()` | Boolean | True if string is empty or null |
| `.lower()` | String | Lowercase version |
| `.title()` | String | Title Case Version |
| `.trim()` | String | Remove leading/trailing whitespace |
| `.reverse()` | String | Reversed string |
| `.slice(start, end?)` | String | Substring from start to end |
| `.split(delimiter)` | List | Split into list of substrings |
| `.replace(pattern, replacement)` | String | Replace pattern with replacement |
| `.icon()` | String | Extract emoji/icon from start of string |
| `.toString()` | String | Identity (already a string) |

**Examples:**
```yaml
formula: "file.name.startsWith('Project')"
formula: "note.title.lower().contains('important')"
formula: "note.tags.join(', ')"
```

### Number

IEEE 754 double-precision floating-point numbers.

**Literals:**
```yaml
formula: "42"
formula: "3.14159"
formula: "-17.5"
```

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.abs()` | Number | Absolute value |
| `.ceil()` | Number | Round up to nearest integer |
| `.floor()` | Number | Round down to nearest integer |
| `.round()` | Number | Round to nearest integer |
| `.toFixed(precision)` | String | Format with fixed decimal places |
| `.isEmpty()` | Boolean | True if null |
| `.toString()` | String | Convert to string |

**Examples:**
```yaml
formula: "note.price.toFixed(2)"
formula: "(now() - file.ctime).abs()"
formula: "note.score.round()"
```

### Date and DateTime

ISO 8601 formatted dates and datetimes.

**Formats:**
- Date: `YYYY-MM-DD` (e.g., `2025-01-31`)
- DateTime: `YYYY-MM-DDTHH:mm:ss` (e.g., `2025-01-31T14:30:00`)

**Properties:**
- `.year` - Four-digit year
- `.month` - Month (1-12)
- `.day` - Day of month (1-31)
- `.hour` - Hour (0-23, null for dates)
- `.minute` - Minute (0-59, null for dates)
- `.second` - Second (0-59, null for dates)
- `.millisecond` - Millisecond (0-999, null for dates)

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.date()` | Date | Date portion (strips time) |
| `.time()` | String | Time portion as HH:mm:ss |
| `.format(pattern)` | String | Format using pattern string |
| `.relative()` | String | Human-readable relative time |
| `.isEmpty()` | Boolean | True if null |

**Format Patterns:**
- `YYYY` - Four-digit year
- `MM` - Two-digit month
- `DD` - Two-digit day
- `HH` - Two-digit hour (24-hour)
- `mm` - Two-digit minute
- `ss` - Two-digit second

**Examples:**
```yaml
formula: "note.created.format('MM/DD/YYYY')"
formula: "note.deadline.relative()"
formula: "file.mtime.year"
```

### Duration

Time spans expressed as strings with units.

**Formats:**
```yaml
formula: "'1d'"       # One day
formula: "'2 hours'"  # Two hours
formula: "'3w'"       # Three weeks
formula: "'1y 6M'"    # One year and six months
```

**Units:**
- `y`, `year`, `years` - Years
- `M`, `month`, `months` - Months
- `w`, `week`, `weeks` - Weeks
- `d`, `day`, `days` - Days
- `h`, `hour`, `hours` - Hours
- `m`, `minute`, `minutes` - Minutes
- `s`, `second`, `seconds` - Seconds

**Arithmetic:**

| Operation | Result | Description |
|-----------|--------|-------------|
| `date + duration` | Date | Add duration to date |
| `date - duration` | Date | Subtract duration from date |
| `date - date` | Number | Milliseconds between dates |
| `duration * number` | Duration | Scale duration |

**Examples:**
```yaml
formula: "note.due - today()"              # Days until due
formula: "note.deadline - duration('1w')"  # One week before deadline
formula: "today() + duration('30d')"       # 30 days from now
```

### List

Ordered collections with zero-based indexing.

**Literals:**
```yaml
formula: "[1, 2, 3]"
formula: "['red', 'green', 'blue']"
formula: "[file.name, note.status, note.priority]"
```

**Indexing:**
```yaml
formula: "note.tags[0]"      # First element
formula: "note.tags[1]"      # Second element
formula: "note.tags[-1]"     # Last element
formula: "note.tags[-2]"     # Second to last
```

**Properties:**
- `.length` - Number of elements

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.contains(value)` | Boolean | True if list contains value |
| `.containsAll(val...)` | Boolean | True if list contains all arguments |
| `.containsAny(val...)` | Boolean | True if list contains any argument |
| `.isEmpty()` | Boolean | True if list is empty or null |
| `.join(separator)` | String | Join elements with separator |
| `.reverse()` | List | Reversed list |
| `.sort()` | List | Sorted list (ascending) |
| `.flat()` | List | Flatten nested lists |
| `.unique()` | List | Remove duplicates |
| `.slice(start, end?)` | List | Sublist from start to end |
| `.map(expr)` | List | Transform each element |
| `.filter(expr)` | List | Keep elements matching condition |

**Higher-Order Functions:**

The `.map()` and `.filter()` methods use an implicit `value` variable representing each element:

```yaml
# Filter tags containing "project"
formula: "note.tags.filter(value.contains('project'))"

# Apply 10% markup to all prices
formula: "note.prices.map(value * 1.1)"

# Get years from list of dates
formula: "note.milestones.map(value.year)"
```

**Examples:**
```yaml
formula: "note.tags.filter(value.startsWith('status/'))"
formula: "note.scores.map(value.round())"
formula: "note.items.sort().reverse()"
formula: "note.tags.join(', ')"
```

### Link

Internal links to other notes in the vault.

**Creation:**

Using the `link()` function:
```yaml
formula: "link(file.path)"
formula: "link('Projects/Main', 'Main Project')"
```

Wikilink strings automatically convert to Link objects:
```yaml
formula: "note.related"  # If "related" property is "[[Other Note]]"
```

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.linksTo(file)` | Boolean | True if link points to the given file |

**Examples:**
```yaml
filters:
  note.parent.linksTo(this.file)
```

### File

Represents a file in the vault with metadata and content properties.

**Properties:**

| Property | Type | Description |
|----------|------|-------------|
| `file.name` | String | Filename without extension |
| `file.path` | String | Full vault path |
| `file.folder` | String | Parent folder path |
| `file.ext` | String | File extension |
| `file.size` | Number | Size in bytes |
| `file.ctime` | DateTime | Creation timestamp |
| `file.mtime` | DateTime | Last modification timestamp |
| `file.links` | List | Internal links in the note |
| `file.embeds` | List | Embedded files in the note |

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.hasTag(tag...)` | Boolean | True if file has any of the given tags |
| `.hasLink(path)` | Boolean | True if file links to the given path |
| `.inFolder(folder)` | Boolean | True if file is in the given folder |
| `.asLink(display?)` | Link | Create a link to this file |

**Examples:**
```yaml
filters:
  and:
    - file.hasTag("project", "active")
    - file.inFolder("Work")
    - file.mtime > date("2025-01-01")

formula: "file.name.upper()"
formula: "file.folder + '/' + file.name"
```

### Regex

Regular expressions for pattern matching.

**Syntax:**
```yaml
formula: "/pattern/flags"
```

The `g` flag is optional for global matching.

**Methods:**

| Method | Returns | Description |
|--------|---------|-------------|
| `.matches(string)` | Boolean | True if pattern matches string |

**Examples:**
```yaml
formula: "/^[A-Z]{3}-\d+$/.matches(file.name)"  # Match "ABC-123" format
formula: "/project/i.matches(note.title)"        # Case-insensitive match
```

### Image

Image references for display in card views.

**Creation:**

Using the `image()` function with:
- Vault path: `image("attachments/photo.jpg")`
- URL: `image("https://example.com/image.png")`
- Hex color: `image("#3498db")`
- File object: `image(file)`

**Examples:**
```yaml
views:
  - type: cards
    image: "image(note.cover_image)"
```

## Global Functions

Functions available in all expressions:

| Function | Signature | Description |
|----------|-----------|-------------|
| `date(str)` | `string -> Date` | Parse ISO date string |
| `today()` | `-> Date` | Current date at 00:00 |
| `now()` | `-> DateTime` | Current date and time |
| `if(cond, true, false?)` | `any, any, any? -> any` | Conditional expression |
| `image(path)` | `string\|File -> Image` | Create image reference |
| `max(n...)` | `number... -> number` | Maximum of arguments |
| `min(n...)` | `number... -> number` | Minimum of arguments |
| `link(path, display?)` | `string, string? -> Link` | Create link |
| `list(elem)` | `any -> List` | Wrap value in list |
| `number(val)` | `any -> number` | Convert to number |
| `duration(str)` | `string -> Duration` | Parse duration string |

**Examples:**
```yaml
formula: "if(note.score > 80, 'Pass', 'Fail')"
formula: "max(note.q1_score, note.q2_score, note.q3_score, note.q4_score)"
formula: "today() + duration('7d')"
```

## Type Coercion

Automatic type conversion rules when values are used in different contexts:

| From | To Number | To String | To Boolean |
|------|-----------|-----------|------------|
| String | Parse decimal or NaN | Identity | Non-empty = true |
| Number | Identity | Decimal format | Non-zero = true |
| Boolean | `1` or `0` | `"true"` or `"false"` | Identity |
| Date | Milliseconds since epoch | ISO 8601 string | Always true |
| List | NaN | Comma-joined | Non-empty = true |
| `null` | NaN | `""` (empty string) | false |

**Examples:**
```yaml
# String "123" coerced to number 123
formula: "note.count + 1"

# Number 42 coerced to string "42"
formula: "note.id.startsWith('4')"

# Empty list coerced to false
formula: "if(note.tags, 'Tagged', 'Untagged')"
```

## Property Namespaces

Properties are resolved using explicit prefixes to distinguish between different sources:

- `note.*` - Frontmatter properties from the note (default if no prefix)
- `file.*` - Implicit file metadata (path, size, timestamps, etc.)
- `formula.*` - Computed values from the formulas section
- `this.*` - Properties from the embedding context file

### Default Namespace

When no prefix is specified, the property is assumed to be in the `note.*` namespace:

```yaml
# These are equivalent:
formula: "status"
formula: "note.status"
```

### Bracket Notation

Use bracket notation for properties with special characters or spaces:

```yaml
formula: "note['Property With Spaces']"
formula: "note['kebab-case-property']"
formula: "note['123-starts-with-number']"
```

### The `this` Context

The `this` namespace provides access to the file that contains or displays the base:

| Context | `this` Resolves To |
|---------|-------------------|
| Embedded in note | The containing note |
| Sidebar panel | Currently active file |
| Canvas node | File embedding the base |
| Not embedded | `null` |

**Examples:**

Show all notes that link to the current note:
```yaml
filters:
  file.hasLink(this.file.path)
```

Show tasks assigned to the current project:
```yaml
filters:
  note.project.linksTo(this.file)
```

Access properties from the embedding note:
```yaml
formula: "this.note.priority"
formula: "if(note.category == this.note.focus_area, 'Relevant', '')"
```

## View Definitions

Views define how the filtered data is displayed. Each base can have multiple views.

### Common View Properties

All view types support these properties:

```yaml
views:
  - type: table           # Required: "table", "cards", or "map"
    name: "View Name"     # Optional: Display name
    limit: 25             # Optional: Max number of items
    filters: ...          # Optional: View-specific filters
    group_by: "property"  # Optional: Group by property value
```

### Table View

Display data in rows and columns.

**Properties:**

```yaml
views:
  - type: table
    name: "Active Projects"
    limit: 25
    filters:
      note.status == "active"
    group_by: "priority"
    order: [file.name, status, priority, formula.days_remaining]
    sort:
      - column: priority
        direction: DESC
      - column: file.name
        direction: ASC
    summaries:
      note.score: "average"
      formula.total: "sum"
```

**Sort Directions:**
- `ASC` - Ascending (A to Z, 0 to 9, oldest to newest)
- `DESC` - Descending (Z to A, 9 to 0, newest to oldest)

**Multiple Sorts:**

Rows are sorted by the first column, then ties are broken by the second column, and so on:

```yaml
sort:
  - column: priority      # Sort by priority first
    direction: DESC
  - column: due           # Then by due date
    direction: ASC
  - column: file.name     # Then by name
    direction: ASC
```

### Table Summaries

The `summaries` property defines aggregation functions for table columns. Each key is a property name, and each value is either a built-in function name or a custom formula.

**Built-in Aggregation Functions:**

| Category | Function | Description |
|----------|----------|-------------|
| Universal | `empty` | Count of empty/null values |
| Universal | `filled` | Count of non-empty values |
| Universal | `unique` | Count of unique values |
| Numeric | `sum` | Sum of all values |
| Numeric | `average` | Mean of all values |
| Numeric | `median` | Median value |
| Numeric | `min` | Minimum value |
| Numeric | `max` | Maximum value |
| Numeric | `range` | Difference between max and min |
| Numeric | `stddev` | Standard deviation |
| Date | `earliest` | Earliest date |
| Date | `latest` | Latest date |
| Date | `date_range` | Time span between earliest and latest |
| Checkbox | `checked` | Count of true values |
| Checkbox | `unchecked` | Count of false values |

**Examples:**

```yaml
summaries:
  note.score: "average"
  note.revenue: "sum"
  note.priority: "unique"
  note.completed: "checked"
  formula.days_remaining: "min"
```

**Custom Summary Formulas:**

For custom aggregations, write an expression that uses the `values` variable, which is bound to a list of all column values:

```yaml
summaries:
  note.score: "values.filter(value > 50).length"
  note.price: "max(values) - min(values)"
  note.status: "if(values.contains('blocked'), 'At Risk', 'On Track')"
```

The `values` list contains only the values from the current column across all visible rows.

### Cards View

Display data as a grid of cards with images.

**Properties:**

```yaml
views:
  - type: cards
    name: "Book Collection"
    image: "cover_image"
    filters:
      file.hasTag("book")
```

The `image` property specifies which note property contains the image reference. The property value can be:
- Vault path: `"attachments/cover.jpg"`
- URL: `"https://example.com/image.png"`
- Hex color: `"#3498db"`
- Image function: `image("path/to/file")`

### Map View

Display data as markers on a geographic map.

**Properties:**

```yaml
views:
  - type: map
    name: "Locations"
    lat: latitude
    long: longitude
    title: file.name
    filters:
      file.hasTag("location")
```

Required properties:
- `lat` - Property containing latitude (number between -90 and 90)
- `long` - Property containing longitude (number between -180 and 180)
- `title` - Property to display as marker title

## Frontmatter Property Types

Obsidian recognizes several property types in frontmatter. The type affects how values are parsed and displayed.

### Property Type Reference

| Type | YAML Syntax | Example |
|------|-------------|---------|
| Text | `key: "value"` | `title: "My Document"` |
| Multitext | `key: [val1, val2]` | `tags: [project, active]` |
| Number | `key: 123` | `priority: 5` |
| Checkbox | `key: true` | `published: true` |
| Date | `key: YYYY-MM-DD` | `created: 2025-01-15` |
| DateTime | `key: YYYY-MM-DDTHH:mm:ss` | `updated: 2025-01-27T14:30:00` |

### Text Properties

Single-line text values:

```yaml
title: "Project Alpha"
status: "active"
author: "Jane Smith"
```

### Multitext Properties

Lists of text values can be written in two formats:

**Inline:**
```yaml
tags: [project, active, high-priority]
```

**Block:**
```yaml
tags:
  - project
  - active
  - high-priority
```

### Number Properties

Integers or decimals:

```yaml
priority: 5
score: 87.5
count: 42
```

### Checkbox Properties

Boolean values:

```yaml
published: true
archived: false
completed: true
```

### Date and DateTime Properties

ISO 8601 format without quotes:

```yaml
created: 2025-01-15
deadline: 2025-02-01
updated: 2025-01-27T14:30:00
```

### Link Properties

Internal links must be quoted:

```yaml
parent: "[[Projects/Main]]"
related: "[[Other Note]]"
```

### Reserved Properties

Some properties have special meaning in Obsidian and must be lists:

```yaml
tags: [tag1, tag2]        # Must be a list
aliases: [alias1, alias2]  # Must be a list
cssclasses: [class1]       # Must be a list
```

## Edge Cases and Gotchas

### YAML String Escaping

When writing expressions in YAML, you need to escape quotes properly. Two approaches:

**Outer single quotes, inner double quotes:**
```yaml
formula: 'if(status == "done", "Complete", "Pending")'
formula: 'file.name.contains("Project")'
```

**Outer double quotes, escaped inner quotes:**
```yaml
formula: "if(status == \"done\", \"Complete\", \"Pending\")"
formula: "file.name.contains(\"Project\")"
```

The single-quote approach is usually clearer and less error-prone.

### Arithmetic Spacing

**REQUIRED:** All arithmetic operators must be surrounded by whitespace.

```yaml
# VALID
formula: "price * quantity"
formula: "total - discount"
formula: "count + 1"
formula: "hours / 8"
formula: "total % 10"

# INVALID - Parser errors
formula: "price*quantity"
formula: "total-discount"
formula: "count+1"
```

This is necessary because property names can contain hyphens, and we need to distinguish between `start-date` (property name) and `start - date` (subtraction).

### The Implicit `value` Variable

The `value` variable only exists inside `.map()` and `.filter()` arguments:

```yaml
# VALID
formula: "tags.map(value.upper())"
formula: "scores.filter(value > 50)"

# INVALID - `value` not defined
formula: "value.upper()"
```

### Null Handling

Empty or missing properties are treated as `null`. Various operations handle `null` consistently:

| Expression | Result When Property Is Null |
|------------|------------------------------|
| `prop.isEmpty()` | `true` |
| `if(prop, ...)` | Takes false branch |
| `prop == null` | `true` |
| `prop == ""` | `true` |
| `prop.toString()` | `""` (empty string) |
| `number(prop)` | `NaN` |

**Examples:**
```yaml
# Check for missing values
formula: "if(note.priority.isEmpty(), 'None', note.priority)"

# Default values
formula: "if(note.status, note.status, 'unknown')"

# Null-safe comparisons
formula: "note.score != null && note.score > 80"
```

### Tag Matching

The `file.hasTag()` method is case-insensitive and matches tag hierarchies:

```yaml
filters:
  file.hasTag("project")
```

This matches:
- `#project`
- `#Project` (case-insensitive)
- `#project/active` (hierarchy match)
- `#project/archived` (hierarchy match)

It does NOT match:
- `#projects` (different tag)
- `#my-project` (different tag)

### Link Equality

Two links are considered equal if:
1. They resolve to the same file in the vault, OR
2. If the target doesn't exist, their link text matches exactly

```yaml
# These are equal if they point to the same file
link("Projects/Main") == link("Main")

# These are equal even if file doesn't exist
link("Missing") == link("Missing")
```

### Date Subtraction

Subtracting two dates returns the difference in milliseconds as a number:

```yaml
# Returns milliseconds between now and creation time
formula: "now() - file.ctime"

# Convert to days
formula: "(now() - file.ctime) / (1000 * 60 * 60 * 24)"

# Better: use durations
formula: "now() - file.ctime > duration('7d')"
```

### Circular Formula Dependencies

Formulas cannot reference each other in circular ways:

```yaml
# INVALID - Circular dependency
formulas:
  a: "formula.b + 1"
  b: "formula.a + 1"

# INVALID - Self-reference
formulas:
  count: "formula.count + 1"
```

This will cause an error when the base is evaluated.

### Division by Zero

Division by zero produces `Infinity` or `-Infinity`:

```yaml
formula: "10 / 0"  # Returns Infinity
formula: "0 / 0"   # Returns NaN
```

Use guards to prevent division by zero:

```yaml
formula: "if(total > 0, completed / total, 0)"
```

### Property Name Conflicts

If a formula has the same name as a note property, the formula takes precedence when accessed via `formula.*`, but the note property is still accessible via `note.*`:

```yaml
# Note has: priority: "high"
formulas:
  priority: "if(note.score > 80, 'urgent', 'normal')"

# In expressions:
# formula.priority -> "urgent" or "normal" (computed)
# note.priority    -> "high" (from frontmatter)
# priority         -> "high" (defaults to note.*)
```

### Empty Lists vs Null

An empty list `[]` is different from `null`:

```yaml
# Empty list
note.tags.isEmpty()  # true
note.tags == null    # false
note.tags.length     # 0

# Null property
note.missing.isEmpty()  # true
note.missing == null    # true
note.missing.length     # Error
```

Use `.isEmpty()` to handle both cases safely.

---

This reference covers the complete syntax and semantics of the Bases query language. For practical examples and tutorials, see the [User Guide](user-guide.md).
