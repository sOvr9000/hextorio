
local lib = require "api.lib"
local hex_state_manager = require "api.hex_state_manager"
local hex_grid          = require "api.hex_grid"

return function()
    storage.train_trading.allow_two_headed_trains = lib.runtime_setting_value_as_boolean "allow-two-headed-trains"

    for _, surface in pairs(game.surfaces) do
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
            if (state.deleted or not state.hex_core or not state.hex_core.valid) and state.strongboxes and next(state.strongboxes) then
                hex_grid.remove_strongboxes(state)
            end
        end
    end
end
