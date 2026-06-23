---Public API for the Obsidian Bases query engine
---Replaces the HTTP-based api.lua with a local engine

local note_index_mod = require('bases.engine.note_index')
local base_parser    -- lazy: loaded on first query
local query_engine   -- lazy: loaded on first query

local function ensure_query_modules()
    if not base_parser then
        base_parser = require('bases.engine.base_parser')
    end
    if not query_engine then
        query_engine = require('bases.engine.query_engine')
    end
end

local M = {}

---@type NoteIndex|nil
local note_index = nil

---@type string|nil
local vault_path = nil

---@type boolean
local initialized = false

---@type boolean
local init_started = false

---@type boolean
local init_failed = false

---@type string|nil
local init_error = nil

---@type function[]
local ready_callbacks = {}

---@type FileWatcher|nil
local file_watcher = nil

---Flush all queued ready callbacks
---@param err string|nil
local function flush_ready_callbacks(err)
    local cbs = ready_callbacks
    ready_callbacks = {}
    for _, cb in ipairs(cbs) do
        cb(err)
    end
end

---Store the vault path without triggering initialization
---@param path string -- absolute path to the vault directory
function M.set_vault_path(path)
    vault_path = path
end

---Initialize the query engine with a vault path
---@param path string -- absolute path to the vault directory
---@param callback function|nil -- called when indexing completes: callback(err)
function M.init(path, callback)
    vault_path = path
    note_index = note_index_mod.new(vault_path)

    note_index:build(function(err)
        if err then
            init_failed = true
            init_error = err
            vim.schedule(function()
                flush_ready_callbacks(err)
                if callback then
                    callback(err)
                end
            end)
            return
        end

        initialized = true

        -- Start file watcher for incremental updates
        local watcher_mod = require('bases.engine.file_watcher')
        local watcher, watcher_err = watcher_mod.start(vault_path, function(event_type, rel_path)
            if event_type == "create" or event_type == "modify" then
                note_index:update_file(rel_path)
            elseif event_type == "delete" then
                note_index:remove_file(rel_path)
            end
        end)
        if watcher then
            file_watcher = watcher
        elseif watcher_err then
            vim.schedule(function()
                vim.notify('bases.nvim: file watcher failed: ' .. watcher_err, vim.log.levels.WARN)
            end)
        end

        vim.schedule(function()
            flush_ready_callbacks(nil)
            if callback then
                callback(nil)
            end
        end)
    end)
end

---Execute a query against a .base file
---@param base_path string -- path to the .base file (absolute or vault-relative)
---@param view_index number -- 0-based view index
---@param callback function -- callback(err, result): err is string|nil, result is SerializedResult|nil
---@param this_file_path string|nil -- vault-relative path of the embedding file (for `this` context)
function M.query(base_path, view_index, callback, this_file_path)
    vim.schedule(function()
        -- Validate initialization
        if not initialized then
            callback("Query engine not initialized. Call init() first.", nil)
            return
        end

        -- Execute query with error handling
        local success, result = pcall(function()
            ensure_query_modules()
            -- Parse the .base file
            local query_config, parse_err = base_parser.parse(base_path)
            if not query_config then
                error(parse_err or "Failed to parse base file")
            end

            -- Resolve this_file_path to NoteData if provided
            local this_file = nil
            if this_file_path and note_index then
                this_file = note_index:get(this_file_path)
            end

            -- Execute query
            local serialized_result = query_engine.execute(
                query_config,
                note_index,
                view_index,
                this_file
            )

            return serialized_result
        end)

        if not success then
            callback(tostring(result), nil)
        else
            callback(nil, result)
        end
    end)
end

---Execute a query from a YAML string (for inline ```base code blocks)
---@param yaml_string string YAML content of the base definition
---@param this_file_path string|nil Vault-relative path of the file containing the code block
---@param view_index number 0-based view index
---@param callback function callback(err, result): err is string|nil, result is SerializedResult|nil
function M.query_string(yaml_string, this_file_path, view_index, callback)
    vim.schedule(function()
        if not initialized then
            callback("Query engine not initialized. Call init() first.", nil)
            return
        end

        local success, result = pcall(function()
            ensure_query_modules()
            local query_config, parse_err = base_parser.parse_string(yaml_string)
            if not query_config then
                error(parse_err or "Failed to parse YAML")
            end

            -- Resolve this_file_path to NoteData if provided
            local this_file = nil
            if this_file_path and note_index then
                this_file = note_index:get(this_file_path)
            end

            local serialized_result = query_engine.execute(
                query_config,
                note_index,
                view_index,
                this_file
            )

            return serialized_result
        end)

        if not success then
            callback(tostring(result), nil)
        else
            callback(nil, result)
        end
    end)
end

---Check if the engine is ready to process queries
---@return boolean
function M.is_ready()
    return initialized
end

---Queue a callback to fire once the engine is ready.
---If already initialized, fires immediately via vim.schedule.
---If initialization failed, fires with the error.
---Otherwise, queues the callback for later.
---@param callback fun(err: string|nil)
function M.on_ready(callback)
    if initialized then
        vim.schedule(function() callback(nil) end)
    elseif init_failed then
        vim.schedule(function() callback(init_error or "Engine initialization failed") end)
    else
        table.insert(ready_callbacks, callback)
        if not init_started and vault_path then
            init_started = true
            M.init(vault_path, function(err)
                if err then
                    vim.schedule(function()
                        vim.notify('bases.nvim: engine init failed: ' .. err,
                            vim.log.levels.ERROR)
                    end)
                end
            end)
        end
    end
end

---Get the underlying NoteIndex instance
---@return NoteIndex|nil
function M.get_index()
    return note_index
end

---Get the current vault path
---@return string|nil
function M.get_vault_path()
    return vault_path
end

---Refresh the index for a specific file
---@param file_path string -- absolute path to the file
---@param callback function|nil -- called when update completes: callback(err)
function M.update_file(file_path, callback)
    if not initialized or not note_index then
        if callback then
            vim.schedule(function()
                callback("Query engine not initialized")
            end)
        end
        return
    end

    local success, err = pcall(function()
        note_index:update_file(file_path)
    end)

    if callback then
        vim.schedule(function()
            callback(success and nil or tostring(err))
        end)
    end
end

---Remove a file from the index
---@param file_path string -- absolute path to the file
---@param callback function|nil -- called when removal completes: callback(err)
function M.remove_file(file_path, callback)
    if not initialized or not note_index then
        if callback then
            vim.schedule(function()
                callback("Query engine not initialized")
            end)
        end
        return
    end

    local success, err = pcall(function()
        note_index:remove_file(file_path)
    end)

    if callback then
        vim.schedule(function()
            callback(success and nil or tostring(err))
        end)
    end
end

---Rebuild the entire index from scratch
---@param callback function|nil -- called when rebuild completes: callback(err)
function M.rebuild_index(callback)
    if not vault_path then
        if callback then
            vim.schedule(function()
                callback("No vault path set")
            end)
        end
        return
    end

    -- Stop existing watcher
    if file_watcher then
        file_watcher:stop()
        file_watcher = nil
    end

    initialized = false
    init_started = false
    init_failed = false
    init_error = nil
    M.init(vault_path, callback)
end

---Shutdown the engine and stop the file watcher
function M.shutdown()
    if file_watcher then
        file_watcher:stop()
        file_watcher = nil
    end
    -- Save cache before clearing state
    if note_index and vault_path then
        note_index:save_cache()
    end
    initialized = false
    init_started = false
    init_failed = false
    init_error = nil
    ready_callbacks = {}
    note_index = nil
    vault_path = nil
end

return M
