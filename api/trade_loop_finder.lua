
local lib = require "api.lib"
local data_trade_loop_finder = require "data.trade_loop_finder"

local trade_loop_finder = {}



function trade_loop_finder.init()
    storage.trade_loop_finder = data_trade_loop_finder
end

function trade_loop_finder.reset()
    storage.trade_loop_finder.state.reset = true
end

function trade_loop_finder._reset_state()
    local state = storage.trade_loop_finder.state
    state.reset = false
    state.total_iterations = 0
    state.total_steps = 0

    state.total_list_steps = 0
    state.trades_list = {}
    state.list_computed = false

    state.total_tree_steps = 0
    state.trades_tree = {}
    state.tree_computed = false

    state.dfs_trade_indices = {1}

    -- Quickly determine indices of hex state arrays for iterated processing
    state.Q_indices = {}
    for surface_name, surface_hexes in pairs(storage.hex_grid.surface_hexes) do
        for i, _ in ipairs(surface_hexes) do
            table.insert(state.Q_indices, {surface_name, i})
        end
    end
end

function trade_loop_finder.new_cycle()
    local cycle = {
        trades = {},
    }
    return cycle
end

function trade_loop_finder.step()
    local params = storage.trade_loop_finder.params
    local state = storage.trade_loop_finder.state

    if state.reset then
        trade_loop_finder._reset_state()
        return
    elseif not state.list_computed then
        for i = 1, params.max_steps_per_iteration do
            local idx = state.total_list_steps + i
            if idx > #state.Q_indices then
                state.list_computed = true
                break
            end

            local Q_index = state.Q_indices[idx]
            local surface_name = Q_index[1]
            local q = Q_index[2]
            local hex_states = storage.hex_grid.surface_hexes[surface_name][q]
            for _, hex_state in pairs(hex_states) do
                if hex_state.trades then
                    for _, trade in pairs(hex_state.trades) do
                        table.insert(state.trades_list, trade)
                    end
                end
            end
        end

        state.total_list_steps = state.total_list_steps + i
    elseif not state.tree_computed then
        for i = 1, params.max_steps_per_iteration do
            local idx = state.total_tree_steps + i
            if idx > #state.trades_list then
                state.tree_computed = true
                break
            end

            local trade = state.trades_list[idx]
            for _, input in pairs(trade.input_items) do
                if not state.trades_tree[input.name] then
                    state.trades_tree[input.name] = {trade}
                else
                    table.insert(state.trades_tree[input.name], trade)
                end
            end
        end

        state.total_tree_steps = state.total_tree_steps + i
    else
        trade_loop_finder._dfs(state.dfs_trade_indices, params.max_steps_per_iteration)
    end

    state.total_iterations = state.total_iterations + 1
end

function trade_loop_finder._dfs(trade_indices, max_cycles)
    -- todo
    -- search only trades that can consume at least one of the produced items of the other trades
end

function trade_loop_finder.test_cycle(trade_indices)
    -- Check if this trade loop is worth saving
    local params = storage.trade_loop_finder.params
    local state = storage.trade_loop_finder.state
    local cycle = {}
    for _, idx in pairs(trade_indices) do
        local trade = state.trades_list[idx]
        table.insert(cycle, trade)
    end
    -- todo
    -- implement convex quadratic program solver
end



return trade_loop_finder
