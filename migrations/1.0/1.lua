
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_state_manager = require "api.hex_state_manager"

return function()
    -- Add ore entities to states
    for _, surface in pairs(game.surfaces) do
        local transformation = terrain.get_surface_transformation(surface)
        local ore_entities = surface.find_entities_filtered {type = "resource"}
        for _, e in pairs(ore_entities) do
            local hex_pos = axial.get_hex_containing(e.position, transformation.scale, transformation.rotation)
            local state = hex_state_manager.get_hex_state(surface.index, hex_pos)
            if state then
                if not state.ore_entities then state.ore_entities = {} end
                table.insert(state.ore_entities, e)
            end
        end
    end
end
