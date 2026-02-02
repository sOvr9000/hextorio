
local lib = require "api.lib"
local hex_state_manager = require "api.hex_state_manager"
local hex_grid          = require "api.hex_grid"
local gameplay_statistics = require "api.gameplay_statistics"
local hex_rank            = require "api.hex_rank"

return function()
    storage.train_trading.allow_two_headed_trains = lib.runtime_setting_value_as_boolean "allow-two-headed-trains"

    for _, surface in pairs(game.surfaces) do
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
            if (state.deleted or not state.hex_core or not state.hex_core.valid) and state.strongboxes and next(state.strongboxes) then
                hex_grid.remove_strongboxes(state)
            end
        end
    end

    hex_rank.init()

    for stat_type, _ in pairs(storage.hex_rank.factor_metadata) do
        gameplay_statistics.recalculate(stat_type)
    end
end
