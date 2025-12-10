
local hex_grid = require "api.hex_grid"
local trades = require "api.trades"

return function()
    table.insert(storage.trades.starting_trades, {{"copper-cable", "boiler"}, {"wood", "raw-fish"}})
    local trade = trades.from_item_names("nauvis", {"copper-cable", "boiler"}, {"wood", "raw-fish"})
    local starter_hex_state = hex_grid.get_hex_state("nauvis", {q=0, r=0})
    hex_grid.remove_trade_by_index(starter_hex_state, 4)
    hex_grid.add_trade(starter_hex_state, trade)

    -- Revert trades to original
    for _, state in pairs(hex_grid.get_flattened_surface_hexes(game.surfaces.nauvis)) do
        if state.trades and state.trades_original then
            for _, trade in pairs(state.trades) do
                trade.trades = trade.trades_original
                trade.trades_original = nil
            end
        end
    end

    storage.item_values.values.nauvis["biter-egg"] = 9001

    hex_grid.update_all_trades()
end
