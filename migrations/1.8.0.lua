
local trade_generator = require "api.trade_generator"
local inventories     = require "api.inventories"

local data_trades = require "data.trades"

return function()
    storage.trades.trade_shape_weights_lookup = data_trades.trade_shape_weights_lookup
    storage.features = {unlocked_features = storage.quests.unlocked_features}
    storage.quests.unlocked_features = nil

    local entity_types = {"container", "logistic-container", "spider-vehicle", "car"}
    for _, surface in pairs(game.surfaces) do
        for _, entity_type in pairs(entity_types) do
            local entities = surface.find_entities_filtered {type = entity_type, force = game.forces.player}
            for _, entity in pairs(entities) do
                if entity.last_user then -- If it was built by someone...
                    inventories.try_track_entity(entity)
                end
            end
        end
    end

    trade_generator.init()
end
