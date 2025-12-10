
local trades = require "api.trades"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"

local data_item_buffs = require "data.item_buffs"
local data_item_values = require "data.item_values"

return function()
    storage.item_buffs.item_buffs = data_item_buffs.item_buffs

    item_values.reset_storage()
    storage.item_values.values = data_item_values.values

    storage.initialization = storage.events
    storage.events = nil

    hex_grid.set_pool_size(storage.hex_grid.pool_size / 5)

    for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
        for _, state in pairs(hex_grid.get_flattened_surface_hexes(surface_id)) do
            -- Fix hexlight/hexport bug
            if not state.hex_core then
                if state.hexlight or state.hexlight2 then
                    hex_grid.remove_hexlight(state)
                end
                if state.hexport then
                    hex_grid.remove_hexport(state)
                end
            end
        end
    end

    for _, trade in pairs(trades.get_all_trades(true)) do
        local surface_trades = storage.trades.tree.by_surface[trade.surface_name]
        if not surface_trades then
            surface_trades = {}
            storage.trades.tree.by_surface[trade.surface_name] = surface_trades
        end
        surface_trades[trade.id] = true
    end
end
