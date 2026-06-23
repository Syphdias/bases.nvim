--- Custom YAML parser for frontmatter and .base files
--- Supports a subset of YAML 1.1 suitable for Obsidian metadata
local M = {}

--- Trim whitespace from both ends of a string
---@param s string
---@return string
local function trim(s)
  return s:match("^%s*(.-)%s*$")
end

--- Check if a string is a YAML boolean value
---@param s string
---@return boolean|nil
local function parse_boolean(s)
  local lower = s:lower()
  if lower == "true" or lower == "yes" or lower == "on" then
    return true
  elseif lower == "false" or lower == "no" or lower == "off" then
    return false
  end
  return nil
end

--- Check if a string is a YAML null value
---@param s string
---@return boolean
local function is_null(s)
  return s == "null" or s == "~" or s == ""
end

--- Parse a number from a string
---@param s string
---@return number|nil
local function parse_number(s)
  local num = tonumber(s)
  return num
end

--- Unescape a double-quoted string
---@param s string
---@return string
local function unescape_double_quoted(s)
  return (s
    :gsub("\\n", "\n")
    :gsub("\\r", "\r")
    :gsub("\\t", "\t")
    :gsub("\\\\", "\\")
    :gsub('\\"', '"')
    :gsub("\\'", "'"))
end

--- Parse a single YAML value (bare, quoted, number, boolean, null)
---@param raw string
---@return any
function M.parse_value(raw)
  local trimmed = trim(raw)

  if trimmed == "" then
    return nil
  end

  -- Handle quoted strings
  if trimmed:match('^".*"$') then
    local content = trimmed:sub(2, -2)
    return unescape_double_quoted(content)
  end

  if trimmed:match("^'.*'$") then
    return (trimmed:sub(2, -2):gsub("''", "'"))
  end

  -- Handle null
  if is_null(trimmed) then
    return nil
  end

  -- Handle boolean
  local bool = parse_boolean(trimmed)
  if bool ~= nil then
    return bool
  end

  -- Handle number
  local num = parse_number(trimmed)
  if num then
    return num
  end

  -- Default: bare string
  return trimmed
end

--- Parse a flow sequence: [a, b, c]
---@param s string
---@return table
local function parse_flow_sequence(s)
  local result = {}
  local content = s:match("^%[(.*)%]$")
  if not content then
    return result
  end

  content = trim(content)
  if content == "" then
    return result
  end

  -- Simple comma split (doesn't handle nested structures)
  for item in content:gmatch("([^,]+)") do
    table.insert(result, M.parse_value(item))
  end

  return result
end

--- Parse a flow mapping: {key: value, key2: value2}
---@param s string
---@return table
local function parse_flow_mapping(s)
  local result = {}
  local content = s:match("^{(.*)}$")
  if not content then
    return result
  end

  content = trim(content)
  if content == "" then
    return result
  end

  -- Split by comma, then by colon
  for pair in content:gmatch("([^,]+)") do
    local key, value = pair:match("^%s*([^:]+):%s*(.*)$")
    if key and value then
      result[trim(key)] = M.parse_value(value)
    end
  end

  return result
end

--- Get indentation level of a line
---@param line string
---@return number
local function get_indent(line)
  local spaces = line:match("^( *)")
  return #spaces
end

--- Remove inline comments from a line
---@param line string
---@return string
local function strip_comment(line)
  -- Simple approach: find # not in quotes
  local result = ""
  local in_single = false
  local in_double = false
  local escape = false

  for i = 1, #line do
    local c = line:sub(i, i)

    if escape then
      result = result .. c
      escape = false
    elseif c == "\\" and (in_single or in_double) then
      result = result .. c
      escape = true
    elseif c == "'" and not in_double then
      in_single = not in_single
      result = result .. c
    elseif c == '"' and not in_single then
      in_double = not in_double
      result = result .. c
    elseif c == "#" and not in_single and not in_double then
      break
    else
      result = result .. c
    end
  end

  return result
end

--- Parse YAML lines into a table
---@param lines string[]
---@param start_idx number
---@param base_indent number
---@return table, number
local function parse_block(lines, start_idx, base_indent)
  local result = {}
  local i = start_idx
  local current_key = nil
  local collecting_literal = false
  local collecting_folded = false
  local literal_indent = 0
  local literal_content = {}

  while i <= #lines do
    local line = lines[i]
    local clean_line = strip_comment(line)
    local indent = get_indent(clean_line)
    local trimmed = trim(clean_line)

    -- Skip empty lines and comments
    if trimmed == "" or trimmed:match("^#") then
      if collecting_literal or collecting_folded then
        table.insert(literal_content, "")
      end
      i = i + 1
      goto continue
    end

    -- End of current block
    if indent < base_indent then
      break
    end

    -- Handle literal block collection
    if collecting_literal or collecting_folded then
      if indent > literal_indent or trimmed == "" then
        local content_line = clean_line:sub(literal_indent + 1)
        table.insert(literal_content, content_line)
        i = i + 1
        goto continue
      else
        -- End of literal block
        local text
        if collecting_literal then
          text = table.concat(literal_content, "\n")
        else
          text = table.concat(literal_content, " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        end
        result[current_key] = text
        collecting_literal = false
        collecting_folded = false
        literal_content = {}
        -- Don't increment i, reprocess this line
        goto continue
      end
    end

    -- Block list item
    if trimmed:match("^%-[%s]") then
      local item_content = trimmed:sub(2)
      item_content = trim(item_content)

      -- Check if it's a nested structure
      if item_content == "" or item_content:match(":$") then
        -- Nested map in list (content on next lines)
        local nested_map, next_i = parse_block(lines, i + 1, indent + 2)
        table.insert(result, nested_map)
        i = next_i
      elseif item_content:match("^{.*}$") then
        -- Flow mapping in list item (e.g., "- {key: value}")
        table.insert(result, parse_flow_mapping(item_content))
        i = i + 1
      elseif item_content:match("^%[.*%]$") then
        -- Flow sequence in list item (e.g., "- [a, b, c]")
        table.insert(result, parse_flow_sequence(item_content))
        i = i + 1
      elseif item_content:match("^[^:]+:%s") then
        -- Inline key-value in list item (e.g., "- type: table")
        -- Parse continuation lines at the item's content indent
        local nested_map, next_i = parse_block(lines, i + 1, indent + 2)
        -- Add the inline key-value to the map
        local item_key, item_value = item_content:match("^([^:]+):%s*(.*)$")
        item_key = trim(item_key)
        item_value = trim(item_value)
        if item_value:match("^%[.*%]$") then
          nested_map[item_key] = parse_flow_sequence(item_value)
        elseif item_value:match("^{.*}$") then
          nested_map[item_key] = parse_flow_mapping(item_value)
        else
          nested_map[item_key] = M.parse_value(item_value)
        end
        table.insert(result, nested_map)
        i = next_i
      else
        table.insert(result, M.parse_value(item_content))
        i = i + 1
      end
      goto continue
    end

    -- Key-value pair
    local key, value = trimmed:match("^([^:]+):%s*(.*)$")
    if key then
      key = trim(key)
      value = trim(value)

      -- Literal block scalar
      if value == "|" then
        current_key = key
        collecting_literal = true
        literal_indent = indent + 2
        literal_content = {}
        i = i + 1
        goto continue
      end

      -- Folded block scalar
      if value == ">" then
        current_key = key
        collecting_folded = true
        literal_indent = indent + 2
        literal_content = {}
        i = i + 1
        goto continue
      end

      -- Flow sequence
      if value:match("^%[.*%]$") then
        result[key] = parse_flow_sequence(value)
        i = i + 1
        goto continue
      end

      -- Flow mapping
      if value:match("^{.*}$") then
        result[key] = parse_flow_mapping(value)
        i = i + 1
        goto continue
      end

      -- Empty value or nested structure
      if value == "" then
        -- Check next line to see if it's nested
        if i < #lines then
          local next_line = lines[i + 1]
          local next_clean = strip_comment(next_line)
          local next_trimmed = trim(next_clean)
          local next_indent = get_indent(next_clean)
          -- Block sequence at the SAME indent as the key (YAML spec allows this):
          --   authors:
          --   - "x"
          --   - "y"
          -- We collect items directly here because the recursive parse_block
          -- would otherwise treat the next sibling key as part of the sequence.
          if next_indent == indent and next_trimmed:match("^%-[%s]") then
            local seq = {}
            local j = i + 1
            while j <= #lines do
              local jline = strip_comment(lines[j])
              local jtrim = trim(jline)
              if not jtrim:match("^%-[%s]") then break end
              local item_content = trim(jtrim:sub(2))
              if item_content:match("^%[.*%]$") then
                table.insert(seq, parse_flow_sequence(item_content))
              elseif item_content:match("^{.*}$") then
                table.insert(seq, parse_flow_mapping(item_content))
              else
                table.insert(seq, M.parse_value(item_content))
              end
              j = j + 1
            end
            result[key] = seq
            i = j
            goto continue
          end
          if next_indent > indent then
            local nested, next_i = parse_block(lines, i + 1, indent + 2)
            result[key] = nested
            i = next_i
            goto continue
          end
        end
        result[key] = nil
        i = i + 1
        goto continue
      end

      -- Simple value
      result[key] = M.parse_value(value)
      i = i + 1
      goto continue
    end

    -- If we get here, skip the line
    i = i + 1
    ::continue::
  end

  -- Handle any remaining literal content
  if collecting_literal or collecting_folded and current_key then
    local text
    if collecting_literal then
      text = table.concat(literal_content, "\n")
    else
      text = table.concat(literal_content, " "):gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    end
    result[current_key] = text
  end

  return result, i
end

--- Parse a YAML document string into a Lua table
---@param yaml_string string
---@return table
function M.parse(yaml_string)
  if not yaml_string or yaml_string == "" then
    return {}
  end

  -- Split into lines
  local lines = {}
  for line in yaml_string:gmatch("([^\n]*)\n?") do
    table.insert(lines, line)
  end

  -- Remove empty last line if present
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end

  -- Handle frontmatter delimiters
  local start_idx = 1
  if lines[1] and trim(lines[1]) == "---" then
    start_idx = 2
    -- Find closing delimiter
    for i = 2, #lines do
      if trim(lines[i]) == "---" or trim(lines[i]) == "..." then
        -- Remove lines after closing delimiter
        while #lines >= i do
          table.remove(lines)
        end
        break
      end
    end
  end

  if #lines == 0 then
    return {}
  end

  local result, _ = parse_block(lines, start_idx, 0)
  return result
end

return M
