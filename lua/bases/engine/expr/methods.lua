---Type method dispatch for the expression engine
local types = require("bases.engine.expr.types")

local M = {}

---Dispatch a method call on a typed value
---@param receiver TypedValue The object to call the method on
---@param method_name string The method name
---@param args TypedValue[] The evaluated arguments
---@param evaluator Evaluator The evaluator instance (for .map()/.filter())
---@param raw_args ASTNode[]|nil The unevaluated AST nodes (for .map()/.filter())
---@return TypedValue
function M.dispatch(receiver, method_name, args, evaluator, raw_args)
	-- Handle null receiver
	if receiver.type == "null" then
		if method_name == "isEmpty" then
			return types.boolean(true)
		end
		return types.null()
	end

	-- Dispatch by receiver type
	if receiver.type == "string" then
		return M.dispatch_string(receiver, method_name, args)
	elseif receiver.type == "number" then
		return M.dispatch_number(receiver, method_name, args)
	elseif receiver.type == "date" then
		return M.dispatch_date(receiver, method_name, args)
	elseif receiver.type == "list" then
		return M.dispatch_list(receiver, method_name, args, evaluator, raw_args)
	elseif receiver.type == "file" then
		return M.dispatch_file(receiver, method_name, args)
	elseif receiver.type == "link" then
		return M.dispatch_link(receiver, method_name, args)
	elseif receiver.type == "regex" then
		return M.dispatch_regex(receiver, method_name, args)
	end

	return types.null()
end

---Get a field value from a typed value (non-method member access)
---@param receiver TypedValue
---@param field_name string
---@return TypedValue|nil
function M.get_field(receiver, field_name)
	if receiver.type == "string" and field_name == "length" then
		return types.number(#receiver.value)
	elseif receiver.type == "list" and field_name == "length" then
		return types.number(#receiver.value)
	elseif receiver.type == "date" then
		return M.get_date_field(receiver, field_name)
	end

	return nil
end

---Get a date field value
---@param receiver TypedValue
---@param field_name string
---@return TypedValue|nil
function M.get_date_field(receiver, field_name)
	local t = os.date("*t", math.floor(receiver.value / 1000))

	if field_name == "year" then
		return types.number(t.year)
	elseif field_name == "month" then
		return types.number(t.month)
	elseif field_name == "day" then
		return types.number(t.day)
	elseif field_name == "hour" then
		return types.number(t.hour)
	elseif field_name == "minute" then
		return types.number(t.min)
	elseif field_name == "second" then
		return types.number(t.sec)
	elseif field_name == "millisecond" then
		return types.number(receiver.value % 1000)
	end

	return nil
end

---Dispatch string methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@return TypedValue
function M.dispatch_string(receiver, method_name, args)
	local str = receiver.value

	if method_name == "contains" then
		if #args == 0 then
			return types.boolean(false)
		end
		local search = types.to_string(args[1])
		return types.boolean(str:find(search, 1, true) ~= nil)
	elseif method_name == "containsAll" then
		if #args == 0 then
			return types.boolean(true)
		end
		local items = args[1]
		if items.type == "list" then
			for _, item in ipairs(items.value) do
				local search = types.to_string(item)
				if not str:find(search, 1, true) then
					return types.boolean(false)
				end
			end
			return types.boolean(true)
		end
		return types.boolean(false)
	elseif method_name == "containsAny" then
		if #args == 0 then
			return types.boolean(false)
		end
		local items = args[1]
		if items.type == "list" then
			for _, item in ipairs(items.value) do
				local search = types.to_string(item)
				if str:find(search, 1, true) then
					return types.boolean(true)
				end
			end
			return types.boolean(false)
		end
		return types.boolean(false)
	elseif method_name == "startsWith" then
		if #args == 0 then
			return types.boolean(false)
		end
		local prefix = types.to_string(args[1])
		return types.boolean(vim.startswith(str, prefix))
	elseif method_name == "endsWith" then
		if #args == 0 then
			return types.boolean(false)
		end
		local suffix = types.to_string(args[1])
		return types.boolean(vim.endswith(str, suffix))
	elseif method_name == "isEmpty" then
		return types.boolean(str == "" or str == nil)
	elseif method_name == "lower" then
		return types.string(str:lower())
	elseif method_name == "title" then
		local result = str:gsub("(%a)([%w_']*)", function(first, rest)
			return first:upper() .. rest:lower()
		end)
		return types.string(result)
	elseif method_name == "trim" then
		return types.string(vim.trim(str))
	elseif method_name == "reverse" then
		return types.string(str:reverse())
	elseif method_name == "slice" then
		return M.string_slice(str, args)
	elseif method_name == "split" then
		return M.string_split(str, args)
	elseif method_name == "replace" then
		if #args < 2 then
			return receiver
		end
		local old = types.to_string(args[1])
		local new = types.to_string(args[2])
		local result = str:gsub(vim.pesc(old), new)
		return types.string(result)
	elseif method_name == "toString" then
		return receiver
	elseif method_name == "icon" then
		return receiver
	end

	return types.null()
end

---String slice implementation
---@param str string
---@param args TypedValue[]
---@return TypedValue
function M.string_slice(str, args)
	if #args == 0 then
		return types.string(str)
	end

	local start_idx = types.to_number(args[1])
	if not start_idx then
		return types.string(str)
	end

	-- Convert 0-based to 1-based, handle negative indices
	local len = #str
	if start_idx < 0 then
		start_idx = len + start_idx
	end
	start_idx = math.floor(start_idx) + 1

	local end_idx = len
	if #args >= 2 then
		local end_arg = types.to_number(args[2])
		if end_arg then
			if end_arg < 0 then
				end_idx = len + end_arg
			else
				end_idx = math.floor(end_arg)
			end
		end
	end

	if start_idx < 1 then
		start_idx = 1
	end
	if end_idx > len then
		end_idx = len
	end

	if start_idx > end_idx then
		return types.string("")
	end

	return types.string(str:sub(start_idx, end_idx))
end

---String split implementation
---@param str string
---@param args TypedValue[]
---@return TypedValue
function M.string_split(str, args)
	if #args == 0 then
		return types.list({ types.string(str) })
	end

	local sep = types.to_string(args[1])
	local parts = {}

	if sep == "" then
		-- Split into characters
		for i = 1, #str do
			table.insert(parts, types.string(str:sub(i, i)))
		end
	else
		-- Split by separator
		local pattern = vim.pesc(sep)
		local pos = 1
		while true do
			local start_pos, end_pos = str:find(pattern, pos)
			if not start_pos then
				table.insert(parts, types.string(str:sub(pos)))
				break
			end
			table.insert(parts, types.string(str:sub(pos, start_pos - 1)))
			pos = end_pos + 1
		end
	end

	return types.list(parts)
end

---Dispatch number methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@return TypedValue
function M.dispatch_number(receiver, method_name, args)
	local num = receiver.value

	if method_name == "abs" then
		return types.number(math.abs(num))
	elseif method_name == "ceil" then
		return types.number(math.ceil(num))
	elseif method_name == "floor" then
		return types.number(math.floor(num))
	elseif method_name == "round" then
		return types.number(math.floor(num + 0.5))
	elseif method_name == "toFixed" then
		if #args == 0 then
			return types.string(tostring(num))
		end
		local precision = types.to_number(args[1])
		if precision then
			local format_str = string.format("%%.%df", math.floor(precision))
			return types.string(string.format(format_str, num))
		end
		return types.string(tostring(num))
	elseif method_name == "isEmpty" then
		return types.boolean(num == nil)
	elseif method_name == "toString" then
		return types.string(tostring(num))
	end

	return types.null()
end

---Dispatch date methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@return TypedValue
function M.dispatch_date(receiver, method_name, args)
	local ms = receiver.value

	if method_name == "date" then
		-- Strip time component (set to midnight)
		local t = os.date("*t", math.floor(ms / 1000))
		local midnight = os.time({
			year = t.year,
			month = t.month,
			day = t.day,
			hour = 0,
			min = 0,
			sec = 0,
		})
		return types.date(midnight * 1000)
	elseif method_name == "time" then
		local t = os.date("*t", math.floor(ms / 1000))
		return types.string(string.format("%02d:%02d:%02d", t.hour, t.min, t.sec))
	elseif method_name == "format" then
		if #args == 0 then
			return types.string(types.date_to_iso(ms))
		end
		local pattern = types.to_string(args[1])
		return types.string(os.date(pattern, math.floor(ms / 1000)))
	elseif method_name == "relative" then
		return M.date_relative(ms)
	elseif method_name == "isEmpty" then
		return types.boolean(ms == nil)
	end

	return types.null()
end

---Format a date as a relative string
---@param ms number
---@return TypedValue
function M.date_relative(ms)
	local now = os.time() * 1000
	local diff = now - ms
	local abs_diff = math.abs(diff)

	local is_future = diff < 0

	local seconds = math.floor(abs_diff / 1000)
	local minutes = math.floor(seconds / 60)
	local hours = math.floor(minutes / 60)
	local days = math.floor(hours / 24)
	local weeks = math.floor(days / 7)
	local months = math.floor(days / 30)
	local years = math.floor(days / 365)

	local str
	if years > 0 then
		str = years == 1 and "1 year" or years .. " years"
	elseif months > 0 then
		str = months == 1 and "1 month" or months .. " months"
	elseif weeks > 0 then
		str = weeks == 1 and "1 week" or weeks .. " weeks"
	elseif days > 0 then
		str = days == 1 and "1 day" or days .. " days"
	elseif hours > 0 then
		str = hours == 1 and "1 hour" or hours .. " hours"
	elseif minutes > 0 then
		str = minutes == 1 and "1 minute" or minutes .. " minutes"
	else
		str = seconds == 1 and "1 second" or seconds .. " seconds"
	end

	if is_future then
		return types.string("in " .. str)
	else
		return types.string(str .. " ago")
	end
end

---Dispatch list methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@param evaluator Evaluator
---@param raw_args ASTNode[]|nil
---@return TypedValue
function M.dispatch_list(receiver, method_name, args, evaluator, raw_args)
	local list = receiver.value

	if method_name == "contains" then
		if #args == 0 then
			return types.boolean(false)
		end
		for _, item in ipairs(list) do
			if M.values_equal(item, args[1]) then
				return types.boolean(true)
			end
		end
		return types.boolean(false)
	elseif method_name == "containsAll" then
		if #args == 0 then
			return types.boolean(true)
		end
		local items = args[1]
		if items.type == "list" then
			for _, search_item in ipairs(items.value) do
				local found = false
				for _, item in ipairs(list) do
					if M.values_equal(item, search_item) then
						found = true
						break
					end
				end
				if not found then
					return types.boolean(false)
				end
			end
			return types.boolean(true)
		end
		return types.boolean(false)
	elseif method_name == "containsAny" then
		if #args == 0 then
			return types.boolean(false)
		end
		local items = args[1]
		if items.type == "list" then
			for _, search_item in ipairs(items.value) do
				for _, item in ipairs(list) do
					if M.values_equal(item, search_item) then
						return types.boolean(true)
					end
				end
			end
			return types.boolean(false)
		end
		return types.boolean(false)
	elseif method_name == "isEmpty" then
		return types.boolean(#list == 0)
	elseif method_name == "join" then
		return M.list_join(list, args)
	elseif method_name == "reverse" then
		local result = {}
		for i = #list, 1, -1 do
			table.insert(result, list[i])
		end
		return types.list(result)
	elseif method_name == "sort" then
		local result = vim.deepcopy(list)
		table.sort(result, function(a, b)
			local an = types.to_number(a)
			local bn = types.to_number(b)
			if an and bn then
				return an < bn
			end
			return types.to_string(a) < types.to_string(b)
		end)
		return types.list(result)
	elseif method_name == "flat" then
		return M.list_flat(list)
	elseif method_name == "unique" then
		return M.list_unique(list)
	elseif method_name == "slice" then
		return M.list_slice(list, args)
	elseif method_name == "map" then
		return M.list_map(list, raw_args, evaluator)
	elseif method_name == "filter" then
		return M.list_filter(list, raw_args, evaluator)
	end

	return types.null()
end

---Check if two typed values are equal
---@param left TypedValue
---@param right TypedValue
---@return boolean
function M.values_equal(left, right)
	if left.type == "null" and right.type == "null" then
		return true
	end
	if left.type == "null" or right.type == "null" then
		return false
	end

	if left.type == right.type then
		-- If both are strings, compare after stripping wiki-link brackets.
		-- This lets frontmatter values like "[[J.R.R. Tolkien]]" compare
		-- equal to a plain string "J.R.R. Tolkien" used elsewhere (e.g.
		-- as the `this` context for `list(authors).contains(this)`).
		-- The display-text form `[[link|display]]` is matched FIRST so the
		-- more specific pattern wins; otherwise the plain `[[...]]` form
		-- would greedy-match `link|display` and leave the pipes in place.
		if left.type == "string" then
			local l = left.value
			local r = right.value
			l = l:gsub("^%[%[([^%]]+)%|([^%]]+)%]%]$", "%1") -- [[link|display]]
			l = l:gsub("^%[%[([^%]]+)%]%]$", "%1")
			r = r:gsub("^%[%[([^%]]+)%|([^%]]+)%]%]$", "%1")
			r = r:gsub("^%[%[([^%]]+)%]%]$", "%1")
			return l == r
		end
		return left.value == right.value
	end

	-- Try numeric comparison
	local ln = types.to_number(left)
	local rn = types.to_number(right)
	if ln and rn then
		return ln == rn
	end

	-- Cross-type comparison: string vs link.
	-- A link's `value` is the display name (or path when no display is set);
	-- `path` is the underlying wiki-link target. Match the string against
	-- either, so frontmatter strings compare equal to links regardless of
	-- which alias the link used.
	if left.type == "string" and right.type == "link" then
		local s = left.value:gsub("^%[%[([^%]]+)%]%]$", "%1"):gsub("^%[%[([^%]]+)%|([^%]]+)%]%]$", "%1")
		return s == right.value or s == right.path
	elseif left.type == "link" and right.type == "string" then
		local s = right.value:gsub("^%[%[([^%]]+)%]%]$", "%1"):gsub("^%[%[([^%]]+)%|([^%]]+)%]%]$", "%1")
		return s == left.value or s == left.path
	end

	return false
end

---Join list elements into a string
---@param list TypedValue[]
---@param args TypedValue[]
---@return TypedValue
function M.list_join(list, args)
	local sep = ","
	if #args >= 1 then
		sep = types.to_string(args[1])
	end

	local parts = {}
	for _, item in ipairs(list) do
		table.insert(parts, types.to_string(item))
	end

	return types.string(table.concat(parts, sep))
end

---Flatten nested lists
---@param list TypedValue[]
---@return TypedValue
function M.list_flat(list)
	local result = {}

	local function flatten(items)
		for _, item in ipairs(items) do
			if item.type == "list" then
				flatten(item.value)
			else
				table.insert(result, item)
			end
		end
	end

	flatten(list)
	return types.list(result)
end

---Remove duplicate elements
---@param list TypedValue[]
---@return TypedValue
function M.list_unique(list)
	local seen = {}
	local result = {}

	for _, item in ipairs(list) do
		local key = types.to_string(item) .. "|" .. item.type
		if not seen[key] then
			seen[key] = true
			table.insert(result, item)
		end
	end

	return types.list(result)
end

---Slice a list
---@param list TypedValue[]
---@param args TypedValue[]
---@return TypedValue
function M.list_slice(list, args)
	if #args == 0 then
		return types.list(list)
	end

	local start_idx = types.to_number(args[1])
	if not start_idx then
		return types.list(list)
	end

	-- Convert 0-based to 1-based, handle negative indices
	local len = #list
	if start_idx < 0 then
		start_idx = len + start_idx
	end
	start_idx = math.floor(start_idx) + 1

	local end_idx = len
	if #args >= 2 then
		local end_arg = types.to_number(args[2])
		if end_arg then
			if end_arg < 0 then
				end_idx = len + end_arg
			else
				end_idx = math.floor(end_arg)
			end
		end
	end

	if start_idx < 1 then
		start_idx = 1
	end
	if end_idx > len then
		end_idx = len
	end

	local result = {}
	for i = start_idx, end_idx do
		if list[i] then
			table.insert(result, list[i])
		end
	end

	return types.list(result)
end

---Map a list using an expression
---@param list TypedValue[]
---@param raw_args ASTNode[]|nil
---@param evaluator Evaluator
---@return TypedValue
function M.list_map(list, raw_args, evaluator)
	if not raw_args or #raw_args == 0 then
		return types.list(list)
	end

	local expr_node = raw_args[1]
	local result = {}

	for _, item in ipairs(list) do
		evaluator.value_binding = item
		local mapped = evaluator:eval(expr_node)
		table.insert(result, mapped)
	end

	evaluator.value_binding = nil
	return types.list(result)
end

---Filter a list using an expression
---@param list TypedValue[]
---@param raw_args ASTNode[]|nil
---@param evaluator Evaluator
---@return TypedValue
function M.list_filter(list, raw_args, evaluator)
	if not raw_args or #raw_args == 0 then
		return types.list(list)
	end

	local expr_node = raw_args[1]
	local result = {}

	for _, item in ipairs(list) do
		evaluator.value_binding = item
		local test = evaluator:eval(expr_node)
		if types.is_truthy(test) then
			table.insert(result, item)
		end
	end

	evaluator.value_binding = nil
	return types.list(result)
end

---Dispatch file methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@return TypedValue
function M.dispatch_file(receiver, method_name, args)
	local note_data = receiver.value

	if method_name == "hasTag" then
		return M.file_has_tag(note_data, args)
	elseif method_name == "hasLink" then
		if #args == 0 then
			return types.boolean(false)
		end
		local link_path = types.to_string(args[1]):lower()
		if note_data.outgoing_link_set then
			-- Check exact match
			if note_data.outgoing_link_set[link_path] then
				return types.boolean(true)
			end
			-- Check case-insensitive
			for path, _ in pairs(note_data.outgoing_link_set) do
				if path:lower() == link_path then
					return types.boolean(true)
				end
			end
		end
		return types.boolean(false)
	elseif method_name == "inFolder" then
		if #args == 0 then
			return types.boolean(false)
		end
		local folder = types.to_string(args[1])
		local note_folder = note_data.folder or ""
		return types.boolean(vim.startswith(note_folder, folder) or note_folder == folder)
	elseif method_name == "asLink" then
		local display = note_data.basename
		if #args >= 1 then
			display = types.to_string(args[1])
		end
		return types.link(note_data.path, display)
	end

	return types.null()
end

---Check if file has tags
---@param note_data table
---@param args TypedValue[]
---@return TypedValue
function M.file_has_tag(note_data, args)
	if #args == 0 then
		return types.boolean(true)
	end

	if not note_data.tag_set then
		return types.boolean(false)
	end

	for _, tag_arg in ipairs(args) do
		local tag = types.to_string(tag_arg):lower()
		local found = false

		-- Check exact match or hierarchy match
		for note_tag, _ in pairs(note_data.tag_set) do
			local note_tag_lower = note_tag:lower()
			if note_tag_lower == tag or vim.startswith(note_tag_lower, tag .. "/") then
				found = true
				break
			end
		end

		if not found then
			return types.boolean(false)
		end
	end

	return types.boolean(true)
end

---Dispatch link methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@return TypedValue
function M.dispatch_link(receiver, method_name, args)
	if method_name == "linksTo" then
		if #args == 0 then
			return types.boolean(false)
		end
		local target = args[1]
		if target.type == "file" then
			return types.boolean(receiver.value.path == target.value.path)
		elseif target.type == "string" then
			return types.boolean(receiver.value.path == target.value)
		end
		return types.boolean(false)
	end

	return types.null()
end

---Dispatch regex methods
---@param receiver TypedValue
---@param method_name string
---@param args TypedValue[]
---@return TypedValue
function M.dispatch_regex(receiver, method_name, args)
	if method_name == "matches" then
		if #args == 0 then
			return types.boolean(false)
		end
		local str = types.to_string(args[1])
		local pattern = receiver.value.pattern
		-- Use Lua pattern matching as approximation
		local match = str:match(pattern)
		return types.boolean(match ~= nil)
	end

	return types.null()
end

return M
