
local hex_state_manager = require "api.hex_state_manager"
local spider_network = require "api.spider_network"

return function()
    for _, surface in pairs(game.surfaces) do
        for _, e in pairs(surface.find_entities_filtered {name = "sentient-spider"}) do
            spider_network.register_spider(e)
        end
    end
end
