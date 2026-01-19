
local hex_state_manager = require "api.hex_state_manager"
local hex_grid = require "api.hex_grid"
local strongboxes = require "api.strongboxes"

local data_strongboxes = require "data.strongboxes"

return function()
    storage.strongboxes = data_strongboxes
    storage.item_buffs.strongbox_loot = 1

    strongboxes.init()

    for surface_name, _ in pairs(storage.item_values.values) do
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
            hex_grid.try_generate_strongbox(state)
        end
    end
end
