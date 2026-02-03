local gameplay_statistics = require "api.gameplay_statistics"

return function()
    for _, surface in pairs(game.surfaces) do
        local hex_core_loaders = surface.find_entities_filtered {
            name = "hex-core-loader",
        }

        for _, loader in pairs(hex_core_loaders) do
            loader.rotatable = true
        end
    end

    gameplay_statistics.recalculate("items-at-rank", 2)
    gameplay_statistics.recalculate("items-at-rank", 3)
    gameplay_statistics.recalculate("items-at-rank", 4)
    gameplay_statistics.recalculate("items-at-rank", 5)
end
