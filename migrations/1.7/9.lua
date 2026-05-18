
local hex_state_manager = require "api.hex_state_manager"
local item_buffs = require "api.item_buffs"
local quests = require "api.quests"
local trades = require "api.trades"

local data_item_buffs = require "data.item_buffs"

return function()
    -- Clean up any hex claim tool accidents.
    for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
        local surface_hexes = hex_state_manager.get_surface_hexes(surface_id)
        if surface_hexes then
            for _, Q in pairs(surface_hexes) do
                for r, state in pairs(Q) do
                    if state.generated == nil then
                        Q[r] = nil
                    end
                end
            end
        end
    end

    if quests.is_complete "grabbing-the-milk-nauvis" then
        -- Quick and dirty migration
        for _, player in pairs(game.players) do
            player.insert {name = "express-loader", count = 15}
        end
    end

    for _, trade in pairs(trades.get_all_trades(false)) do
        if trade.hex_core_state then
            trade.hex_state_flat_index = trade.hex_core_state.flat_index
            trade.hex_core_state = nil ---@diagnostic disable-line
        end
    end

    item_buffs.migrate_buff_changes(data_item_buffs)
end
