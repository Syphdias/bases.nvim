---@class Evaluator
---@field note_data NoteData The note being evaluated
---@field formulas table<string, string> Map of formula name to expression string
---@field note_index NoteIndex Index for link resolution
---@field this_file NoteData|nil The embedding context file
---@field formula_cache table<string, TypedValue> Cached formula results
---@field formula_stack table<string, boolean> Stack for circular reference detection
---@field value_binding TypedValue|nil Current value binding for .map()/.filter()
---@field values_binding TypedValue|nil Current values binding for summary formulas
local Evaluator = {}
Evaluator.__index = Evaluator

local types = require("bases.engine.expr.types")
local parser = require("bases.engine.expr.parser")
local functions = require("bases.engine.expr.functions")
local methods = require("bases.engine.expr.methods")

local M = {}

---Create a new evaluator instance
---@param note_data NoteData The note being evaluated
---@param formulas table<string, string> Map of formula name to expression string
---@param note_index NoteIndex Index for link resolution
---@param this_file NoteData|nil The embedding context file
---@return Evaluator
function M.new(note_data, formulas, note_index, this_file)
	local self = setmetatable({}, Evaluator)
	self.note_data = note_data
	self.formulas = formulas or {}
	self.note_index = note_index
	self.this_file = this_file
	self.formula_cache = {}
	self.formula_stack = {}
	self.value_binding = nil
	self.values_binding = nil
	return self
end

---Evaluate an AST node
---@param node ASTNode The AST node to evaluate
---@return TypedValue
function Evaluator:eval(node)
	if node.type == "literal" then
		return self:eval_literal(node)
	elseif node.type == "identifier" then
		return self:eval_identifier(node)
	elseif node.type == "binary_op" then
		return self:eval_binary_op(node)
	elseif node.type == "unary_op" then
		return self:eval_unary_op(node)
	elseif node.type == "call" then
		return self:eval_call(node)
	elseif node.type == "member" then
		return self:eval_member(node)
	elseif node.type == "index" then
		return self:eval_index(node)
	elseif node.type == "array" then
		return self:eval_array(node)
	elseif node.type == "object" then
		return self:eval_object(node)
	else
		return types.null()
	end
end

---Evaluate an expression string
---@param expr_string string The expression to evaluate
---@return TypedValue
function Evaluator:eval_string(expr_string)
	local ast, err = parser.parse_expression(expr_string)
	if err then
		-- Return null on parse error
		return types.null()
	end
	return self:eval(ast)
end

---Evaluate a literal node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_literal(node)
	return types.from_raw(node.value)
end

---Evaluate an identifier node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_identifier(node)
	local name = node.name

	-- Check for value binding first (for .map()/.filter())
	if name == "value" and self.value_binding then
		return self.value_binding
	end

	-- Check for values binding (for summary formulas)
	if name == "values" and self.values_binding then
		return self.values_binding
	end

	-- Handle bare namespace identifiers used as method receivers
	if name == "file" then
		return types.file(self.note_data)
	end

	-- Handle bare `this` (the embedding file's context). A bare `this`
	-- with no property is treated as the embedding file's basename,
	-- matching the convention used by demo bases like
	-- `list(authors).contains(this)` to filter notes whose frontmatter
	-- links resolve to the current page.
	if name == "this" then
		return self:resolve_this_property("")
	end

	-- Split on first dot to get namespace
	local namespace, rest = name:match("^([^.]+)%.(.+)$")

	if not namespace then
		-- No dot, default to note namespace (frontmatter lookup)
		return self:resolve_note_property(name)
	end

	if namespace == "file" then
		return self:resolve_file_property(rest)
	elseif namespace == "note" then
		return self:resolve_note_property(rest)
	elseif namespace == "formula" then
		return self:resolve_formula(rest)
	elseif namespace == "this" then
		return self:resolve_this_property(rest)
	else
		-- Unknown namespace, default to note
		return self:resolve_note_property(name)
	end
end

---Resolve a file namespace property
---@param property string
---@return TypedValue
function Evaluator:resolve_file_property(property)
	local note = self.note_data

	if property == "name" then
		return types.string(note.basename)
	elseif property == "path" then
		return types.string(note.path)
	elseif property == "folder" then
		return types.string(note.folder)
	elseif property == "ext" then
		return types.string(note.ext)
	elseif property == "size" then
		return types.number(note.size)
	elseif property == "ctime" then
		return types.date(note.ctime)
	elseif property == "mtime" then
		return types.date(note.mtime)
	elseif property == "links" then
		local link_list = {}
		for _, link in ipairs(note.links or {}) do
			table.insert(link_list, types.link(link.path, link.display))
		end
		return types.list(link_list)
	elseif property == "embeds" then
		return types.list({})
	elseif property == "file" then
		return types.file(note)
	else
		return types.null()
	end
end

---Resolve a note namespace property (frontmatter)
---@param property string
---@return TypedValue
function Evaluator:resolve_note_property(property)
	if not self.note_data.frontmatter then
		return types.null()
	end

	local value = self.note_data.frontmatter[property]
	if value == nil then
		return types.null()
	end

	return types.from_raw(value)
end

---Resolve a formula
---@param formula_name string
---@return TypedValue
function Evaluator:resolve_formula(formula_name)
	-- Check cache first
	if self.formula_cache[formula_name] then
		return self.formula_cache[formula_name]
	end

	-- Check for circular reference
	if self.formula_stack[formula_name] then
		-- Circular reference detected
		return types.null()
	end

	-- Get formula expression
	local expr = self.formulas[formula_name]
	if not expr then
		return types.null()
	end

	-- Mark as evaluating
	self.formula_stack[formula_name] = true

	-- Evaluate formula
	local result = self:eval_string(expr)

	-- Cache result and clear stack
	self.formula_cache[formula_name] = result
	self.formula_stack[formula_name] = nil

	return result
end

---Resolve a this namespace property
---@param property string|nil
---@return TypedValue
function Evaluator:resolve_this_property(property)
	if not self.this_file then
		return types.null()
	end

	-- If no property specified, return the this_file's basename. This is
	-- a convention that lets filters like `list(authors).contains(this)`
	-- work for "show rows where a wikilink target matches the embedding
	-- file's basename".
	if property == nil or property == "" then
		return types.string(self.this_file.basename or "")
	end

	if not self.this_file.frontmatter then
		return types.null()
	end

	local value = self.this_file.frontmatter[property]
	if value == nil then
		return types.null()
	end

	return types.from_raw(value)
end

---Evaluate a binary operation node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_binary_op(node)
	local op = node.operator

	-- Handle short-circuit operators
	if op == "&&" then
		local left = self:eval(node.left)
		if not types.is_truthy(left) then
			return left
		end
		return self:eval(node.right)
	elseif op == "||" then
		local left = self:eval(node.left)
		if types.is_truthy(left) then
			return left
		end
		return self:eval(node.right)
	end

	-- Evaluate both operands
	local left = self:eval(node.left)
	local right = self:eval(node.right)

	-- Comparison operators
	if op == "==" then
		return types.boolean(self:values_equal(left, right))
	elseif op == "!=" then
		return types.boolean(not self:values_equal(left, right))
	elseif op == "<" then
		local ln = types.to_number(left)
		local rn = types.to_number(right)
		if ln and rn then
			return types.boolean(ln < rn)
		end
		return types.boolean(false)
	elseif op == ">" then
		local ln = types.to_number(left)
		local rn = types.to_number(right)
		if ln and rn then
			return types.boolean(ln > rn)
		end
		return types.boolean(false)
	elseif op == "<=" then
		local ln = types.to_number(left)
		local rn = types.to_number(right)
		if ln and rn then
			return types.boolean(ln <= rn)
		end
		return types.boolean(false)
	elseif op == ">=" then
		local ln = types.to_number(left)
		local rn = types.to_number(right)
		if ln and rn then
			return types.boolean(ln >= rn)
		end
		return types.boolean(false)
	end

	-- Arithmetic and string operators
	if op == "+" then
		return self:eval_addition(left, right)
	elseif op == "-" then
		return self:eval_subtraction(left, right)
	elseif op == "*" then
		return self:eval_multiplication(left, right)
	elseif op == "/" then
		local ln = types.to_number(left)
		local rn = types.to_number(right)
		if ln and rn and rn ~= 0 then
			return types.number(ln / rn)
		end
		return types.null()
	elseif op == "%" then
		local ln = types.to_number(left)
		local rn = types.to_number(right)
		if ln and rn and rn ~= 0 then
			return types.number(ln % rn)
		end
		return types.null()
	end

	return types.null()
end

---Check if two typed values are equal
---@param left TypedValue
---@param right TypedValue
---@return boolean
function Evaluator:values_equal(left, right)
	-- Null equality
	if left.type == "null" and right.type == "null" then
		return true
	end
	if left.type == "null" or right.type == "null" then
		return false
	end

	-- Type coercion for comparison
	if left.type == right.type then
		if left.type == "list" then
			-- List equality: same length and all elements equal
			if #left.value ~= #right.value then
				return false
			end
			for i = 1, #left.value do
				if not self:values_equal(left.value[i], right.value[i]) then
					return false
				end
			end
			return true
		else
			return left.value == right.value
		end
	end

	-- Try numeric comparison
	local ln = types.to_number(left)
	local rn = types.to_number(right)
	if ln and rn then
		return ln == rn
	end

	-- Try string comparison
	local ls = types.to_string(left)
	local rs = types.to_string(right)
	return ls == rs
end

---Evaluate addition
---@param left TypedValue
---@param right TypedValue
---@return TypedValue
function Evaluator:eval_addition(left, right)
	-- Date + duration
	if left.type == "date" and right.type == "duration" then
		return types.date(left.value + right.value)
	elseif left.type == "duration" and right.type == "date" then
		return types.date(left.value + right.value)
	end

	-- Duration + duration
	if left.type == "duration" and right.type == "duration" then
		return types.duration(left.value + right.value)
	end

	-- String concatenation
	if left.type == "string" or right.type == "string" then
		return types.string(types.to_string(left) .. types.to_string(right))
	end

	-- Numeric addition
	local ln = types.to_number(left)
	local rn = types.to_number(right)
	if ln and rn then
		return types.number(ln + rn)
	end

	return types.null()
end

---Evaluate subtraction
---@param left TypedValue
---@param right TypedValue
---@return TypedValue
function Evaluator:eval_subtraction(left, right)
	-- Date - date = duration (milliseconds)
	if left.type == "date" and right.type == "date" then
		return types.number(left.value - right.value)
	end

	-- Date - duration = date
	if left.type == "date" and right.type == "duration" then
		return types.date(left.value - right.value)
	end

	-- Duration - duration
	if left.type == "duration" and right.type == "duration" then
		return types.duration(left.value - right.value)
	end

	-- Numeric subtraction
	local ln = types.to_number(left)
	local rn = types.to_number(right)
	if ln and rn then
		return types.number(ln - rn)
	end

	return types.null()
end

---Evaluate multiplication
---@param left TypedValue
---@param right TypedValue
---@return TypedValue
function Evaluator:eval_multiplication(left, right)
	-- Duration * number
	if left.type == "duration" then
		local rn = types.to_number(right)
		if rn then
			return types.duration(left.value * rn)
		end
	elseif right.type == "duration" then
		local ln = types.to_number(left)
		if ln then
			return types.duration(right.value * ln)
		end
	end

	-- Numeric multiplication
	local ln = types.to_number(left)
	local rn = types.to_number(right)
	if ln and rn then
		return types.number(ln * rn)
	end

	return types.null()
end

---Evaluate a unary operation node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_unary_op(node)
	local operand = self:eval(node.operand)

	if node.operator == "!" then
		return types.boolean(not types.is_truthy(operand))
	elseif node.operator == "-" then
		local n = types.to_number(operand)
		if n then
			return types.number(-n)
		end
		return types.null()
	end

	return types.null()
end

---Evaluate a call node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_call(node)
	-- Check if this is a method call
	if node.callee.type == "member" then
		local object = self:eval(node.callee.object)
		local method_name = node.callee.property

		-- Evaluate arguments
		local args = {}
		for _, arg_node in ipairs(node.args) do
			table.insert(args, self:eval(arg_node))
		end

		-- Dispatch method call (pass raw args for .map()/.filter())
		return methods.dispatch(object, method_name, args, self, node.args)
	end

	-- Global function call
	if node.callee.type == "identifier" then
		local func_name = node.callee.name

		-- Evaluate arguments
		local args = {}
		for _, arg_node in ipairs(node.args) do
			table.insert(args, self:eval(arg_node))
		end

		return functions.call(func_name, args, self)
	end

	return types.null()
end

---Evaluate a member access node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_member(node)
	-- Special case: check if the object is an identifier that represents a namespace
	if node.object.type == "identifier" then
		local namespace = node.object.name
		local property = node.property

		if namespace == "file" then
			return self:resolve_file_property(property)
		elseif namespace == "note" then
			return self:resolve_note_property(property)
		elseif namespace == "formula" then
			return self:resolve_formula(property)
		elseif namespace == "this" then
			return self:resolve_this_property(property)
		end
	end

	-- Evaluate the object
	local object = self:eval(node.object)

	-- Try to get field value first
	local field_value = methods.get_field(object, node.property)
	if field_value then
		return field_value
	end

	-- If not a field, treat as method access without call (return null for now)
	-- This shouldn't happen in practice, as methods require ()
	return types.null()
end

---Evaluate an index access node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_index(node)
	local object = self:eval(node.object)
	local index = self:eval(node.index)

	if object.type == "list" then
		local idx = types.to_number(index)
		if idx then
			-- Convert to 1-based index
			local lua_idx = math.floor(idx) + 1
			if lua_idx >= 1 and lua_idx <= #object.value then
				return object.value[lua_idx]
			end
		end
	elseif object.type == "object" then
		local key = types.to_string(index)
		local value = object.value[key]
		if value then
			return value
		end
	end

	return types.null()
end

---Evaluate an array literal node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_array(node)
	local elements = {}
	for _, elem_node in ipairs(node.elements) do
		table.insert(elements, self:eval(elem_node))
	end
	return types.list(elements)
end

---Evaluate an object literal node
---@param node ASTNode
---@return TypedValue
function Evaluator:eval_object(node)
	local entries = {}
	for _, entry in ipairs(node.entries) do
		local key = entry.key
		local value = self:eval(entry.value)
		entries[key] = value
	end
	return types.object(entries)
end

return M
