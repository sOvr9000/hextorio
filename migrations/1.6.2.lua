
return function()
    for _, surface in pairs(game.surfaces) do
        local hex_core_loaders = surface.find_entities_filtered {
            name = "hex-core-loader",
        }

        for _, loader in pairs(hex_core_loaders) do
            loader.rotatable = true
        end
    end
end
