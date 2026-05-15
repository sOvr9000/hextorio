
local spider_network = require "api.spider_network"
local hex_state_manager = require "api.hex_state_manager"
local hex_pathfinding   = require "api.hex_pathfinding"

return function()
    for _, surface in pairs(game.surfaces) do
        local surface_index = surface.index

        for _, e in pairs(surface.find_entities_filtered {name = "sentient-spider"}) do
            spider_network.register_spider(e)
        end

        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
            state.surface_index = surface_index
            if state.claimed then
                hex_pathfinding.recalculate_hex_traversability(state)
            end
        end
    end
end
