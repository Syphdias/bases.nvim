---@class FilterNode
---@field type "expression"|"and"|"or"|"not"
---@field expression string|nil -- Only for type "expression"
---@field children FilterNode[]|nil -- Only for type "and", "or", "not"

---@class PropertyConfig
---@field display_name string|nil

---@class SortConfig
---@field column string
---@field direction "ASC"|"DESC"

---@class ViewConfig
---@field type "table"|"cards"|"map"
---@field name string
---@field order string[]|nil
---@field limit number|nil
---@field filters FilterNode|nil
---@field sort SortConfig[]|nil
---@field group_by string|nil
---@field image string|nil -- For cards view
---@field lat string|nil -- For map view
---@field long string|nil -- For map view
---@field title string|nil -- For map view
---@field summaries table<string, string>|nil -- Column summaries config

---@class QueryConfig
---@field filters FilterNode|nil
---@field formulas table<string, string>|nil
---@field properties table<string, PropertyConfig>|nil
---@field views ViewConfig[]

local M = {}

-- Known file properties that should keep their file. prefix
local FILE_PROPERTIES = {
	["file.name"] = true,
	["file.path"] = true,
	["file.folder"] = true,
	["file.ext"] = true,
	["file.size"] = true,
	["file.ctime"] = true,
	["file.mtime"] = true,
	["file.links"] = true,
	["file.embeds"] = true,
	["file.file"] = true,
}

---Normalize a property name by adding appropriate prefix
---@param prop_name string
---@return string
local function normalize_property_name(prop_name)
	-- Already has a recognized prefix
	if prop_name:match("^file%.") or prop_name:match("^note%.") or prop_name:match("^formula%.") then
		return prop_name
	end

	-- Known file property without prefix - add it
	local with_file_prefix = "file." .. prop_name
	if FILE_PROPERTIES[with_file_prefix] then
		return with_file_prefix
	end

	-- Default to note. prefix for unprefixed properties
	return "note." .. prop_name
end

---Parse a filter node recursively
---@param filter_data any
---@return FilterNode|nil, string|nil
local function parse_filter_node(filter_data)
	if not filter_data then
		return nil, nil
	end

	-- String expression
	if type(filter_data) == "string" then
		return {
			type = "expression",
			expression = filter_data,
		}, nil
	end

	-- Must be a table
	if type(filter_data) ~= "table" then
		return nil, "Filter must be a string or table, got " .. type(filter_data)
	end

	-- Check for boolean combinators
	if filter_data["and"] then
		local children = {}
		for _, child in ipairs(filter_data["and"]) do
			local parsed_child, err = parse_filter_node(child)
			if err then
				return nil, "Error in 'and' child: " .. err
			end
			table.insert(children, parsed_child)
		end
		return {
			type = "and",
			children = children,
		}, nil
	end

	if filter_data["or"] then
		local children = {}
		for _, child in ipairs(filter_data["or"]) do
			local parsed_child, err = parse_filter_node(child)
			if err then
				return nil, "Error in 'or' child: " .. err
			end
			table.insert(children, parsed_child)
		end
		return {
			type = "or",
			children = children,
		}, nil
	end

	if filter_data["not"] then
		local children = {}
		local not_data = filter_data["not"]
		-- 'not' can be a single item or array
		if type(not_data) == "table" and not_data[1] then
			-- Array of children
			for _, child in ipairs(not_data) do
				local parsed_child, err = parse_filter_node(child)
				if err then
					return nil, "Error in 'not' child: " .. err
				end
				table.insert(children, parsed_child)
			end
		else
			-- Single child
			local parsed_child, err = parse_filter_node(not_data)
			if err then
				return nil, "Error in 'not' child: " .. err
			end
			table.insert(children, parsed_child)
		end
		return {
			type = "not",
			children = children,
		}, nil
	end

	return nil, "Filter must have 'and', 'or', 'not', or be a string expression"
end

---Parse a view configuration
---@param view_data table
---@param index number
---@return ViewConfig|nil, string|nil
local function parse_view(view_data, index)
	if type(view_data) ~= "table" then
		return nil, "View must be a table, got " .. type(view_data)
	end

	local view = {
		type = view_data.type or "table",
		name = view_data.name or ("View " .. index),
	}

	-- Validate type
	if view.type ~= "table" and view.type ~= "cards" and view.type ~= "map" then
		return nil, "Invalid view type: " .. view.type
	end

	-- Parse limit
	if view_data.limit then
		if type(view_data.limit) ~= "number" then
			return nil, "View limit must be a number"
		end
		view.limit = view_data.limit
	end

	-- Parse order with property name normalization
	if view_data.order then
		if type(view_data.order) ~= "table" then
			return nil, "View order must be a list"
		end
		view.order = {}
		for _, prop in ipairs(view_data.order) do
			if type(prop) ~= "string" then
				return nil, "Order entry must be a string"
			end
			table.insert(view.order, normalize_property_name(prop))
		end
	end

	-- Parse sort
	if view_data.sort then
		if type(view_data.sort) ~= "table" then
			return nil, "View sort must be a list"
		end
		view.sort = {}
		for _, sort_entry in ipairs(view_data.sort) do
			if type(sort_entry) ~= "table" then
				return nil, "Sort entry must be a table"
			end
			local col = sort_entry.column or sort_entry.property
			if not col then
				return nil, "Sort entry missing 'column' (or 'property') field"
			end
			local direction = sort_entry.direction or "ASC"
			if direction ~= "ASC" and direction ~= "DESC" then
				return nil, "Sort direction must be ASC or DESC"
			end
			table.insert(view.sort, {
				column = normalize_property_name(col),
				direction = direction,
			})
		end
	end

	-- Parse group_by
	if view_data.group_by then
		if type(view_data.group_by) ~= "string" then
			return nil, "View group_by must be a string"
		end
		view.group_by = normalize_property_name(view_data.group_by)
	end

	-- Parse filters
	if view_data.filters then
		local filters, err = parse_filter_node(view_data.filters)
		if err then
			return nil, "Error in view filters: " .. err
		end
		view.filters = filters
	end

	-- Parse view-specific fields
	if view.type == "cards" and view_data.image then
		view.image = normalize_property_name(view_data.image)
	end

	if view.type == "map" then
		if view_data.lat then
			view.lat = normalize_property_name(view_data.lat)
		end
		if view_data.long then
			view.long = normalize_property_name(view_data.long)
		end
		if view_data.title then
			view.title = normalize_property_name(view_data.title)
		end
	end

	-- Parse summaries
	if view_data.summaries then
		if type(view_data.summaries) ~= "table" then
			return nil, "View summaries must be a map"
		end
		view.summaries = {}
		for prop, func_or_expr in pairs(view_data.summaries) do
			if type(prop) ~= "string" then
				return nil, "Summary key must be a string"
			end
			if type(func_or_expr) ~= "string" then
				return nil, "Summary value for '" .. prop .. "' must be a string"
			end
			view.summaries[normalize_property_name(prop)] = func_or_expr
		end
	end

	return view, nil
end

---Parse a YAML string into a QueryConfig
---@param yaml_string string
---@return QueryConfig|nil, string|nil
function M.parse_string(yaml_string)
	local yaml = require("bases.engine.yaml")

	-- Parse YAML
	local ok, data = pcall(yaml.parse, yaml_string)
	if not ok then
		return nil, "YAML parse error: " .. tostring(data)
	end

	if type(data) ~= "table" then
		return nil, "Base file must contain a YAML object"
	end

	local config = {
		views = {},
	}

	-- Parse top-level filters
	if data.filters then
		local filters, err = parse_filter_node(data.filters)
		if err then
			return nil, "Error parsing filters: " .. err
		end
		config.filters = filters
	end

	-- Parse formulas (pass through as-is)
	if data.formulas then
		if type(data.formulas) ~= "table" then
			return nil, "Formulas must be a map"
		end
		config.formulas = {}
		for name, expr in pairs(data.formulas) do
			if type(expr) ~= "string" then
				return nil, "Formula '" .. name .. "' must have a string expression"
			end
			config.formulas[name] = expr
		end
	end

	-- Parse properties
	if data.properties then
		if type(data.properties) ~= "table" then
			return nil, "Properties must be a map"
		end
		config.properties = {}
		for name, prop_config in pairs(data.properties) do
			if type(prop_config) ~= "table" then
				return nil, "Property '" .. name .. "' config must be a table"
			end
			config.properties[name] = {}
			if prop_config.display_name then
				if type(prop_config.display_name) ~= "string" then
					return nil, "Property '" .. name .. "' display_name must be a string"
				end
				config.properties[name].display_name = prop_config.display_name
			end
		end
	end

	-- Parse views
	if data.views then
		if type(data.views) ~= "table" then
			return nil, "Views must be a list"
		end
		for i, view_data in ipairs(data.views) do
			local view, err = parse_view(view_data, i)
			if err then
				return nil, "Error parsing view " .. i .. ": " .. err
			end
			table.insert(config.views, view)
		end
	end

	-- Create default view if none specified
	if #config.views == 0 then
		table.insert(config.views, {
			type = "table",
			name = "Default",
		})
	end

	return config, nil
end

---Parse a .base file into a QueryConfig
---@param file_path string
---@return QueryConfig|nil, string|nil
function M.parse(file_path)
	-- Read file
	local ok, lines = pcall(vim.fn.readfile, file_path)
	if not ok then
		return nil, "Failed to read file: " .. tostring(lines)
	end

	if type(lines) ~= "table" then
		return nil, "Failed to read file: unexpected result type"
	end

	-- Join lines into string
	local content = table.concat(lines, "\n")

	-- Parse the content
	return M.parse_string(content)
end

---Find the 0-based index of a view by name in a QueryConfig
---The match is exact and case-sensitive. Returns the index of the first
---view whose `name` field equals `view_name`.
---@param query_config QueryConfig
---@param view_name string
---@return number|nil, string|nil Returns 0-based index on success, or nil + error message on failure
function M.find_view_index(query_config, view_name)
	if query_config == nil then
		return nil, 'Query config is nil'
	end

	if type(query_config) ~= 'table' then
		return nil, 'Query config must be a table, got ' .. type(query_config)
	end

	if view_name == nil then
		return nil, 'View name is nil'
	end

	if type(view_name) ~= 'string' then
		return nil, 'View name must be a string, got ' .. type(view_name)
	end

	local views = query_config.views
	if not views or #views == 0 then
		return nil, "No views defined in query config"
	end

	for i, view in ipairs(views) do
		if view.name == view_name then
			return i - 1, nil
		end
	end

	return nil, "View '" .. view_name .. "' not found"
end

return M
