
local hex_grid = require "api.hex_grid"
local hex_state_manager = require "api.hex_state_manager"
local trades = require "api.trades"

local data_item_ranks = require "data.item_ranks"

return function()
    storage.trades.discovered_items = {}
    storage.trades.total_items_traded = {}
    storage.trades.total_items_bought = {}
    storage.trades.total_items_sold = {}

    storage.item_ranks = data_item_ranks

    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(game.surfaces.nauvis)) do
        state.hex_core_output_inventory = state.hex_core_input_inventory
        if state.trades then
            if state.claimed then
                trades.discover_items_in_trades(state.trades)
            end
            for _, trade in pairs(state.trades) do
                trade.surface_name = "nauvis"
                trade.active = true
            end
            state.trades_original = trades.copy(state.trades)
        end
    end

    local surface_hexes = hex_state_manager.get_surface_hexes(game.surfaces.nauvis)
    local state = surface_hexes[0][0]
    table.insert(storage.trades.starting_trades, {{"low-density-structure"}, {"hex-coin"}})
    local trade = trades.from_item_names("nauvis", {"low-density-structure"}, {"hex-coin"})
    -- lib.log(serpent.block(trade))
    hex_grid.add_trade(state, trade)

    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(game.surfaces.nauvis)) do
        if state.hex_core then
            state.output_loader = game.surfaces.nauvis.find_entity("hex-core-loader", {x=state.hex_core.position.x+1, y=state.hex_core.position.y+2})
            state.output_loader.loader_filter_mode = "whitelist"
            hex_grid.update_hex_core_inventory_filters(state)
            hex_grid.update_loader_filters(state)
        end
    end
end
