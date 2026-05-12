
local hex_state_manager = require "api.hex_state_manager"
local spider_network = require "api.spider_network"
local item_buffs = require "api.item_buffs"
local quests = require "api.quests"

local data_item_buffs = require "data.item_buffs"

return function()
    for _, surface in pairs(game.surfaces) do
        for _, e in pairs(surface.find_entities_filtered {name = "sentient-spider"}) do
            spider_network.register_spider(e)
        end
    end

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

    item_buffs.migrate_buff_changes(data_item_buffs)
end
