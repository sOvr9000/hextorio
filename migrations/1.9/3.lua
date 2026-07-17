
local hex_state_manager = require "api.hex_state_manager"

return function()
    local t = game.tick + 2
    for _, surface in pairs(game.surfaces) do
        if storage.SUPPORTED_PLANETS[surface.name] then
            for i, state in ipairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
                if state.hex_core then
                    state.loader_fix_tick = t
                end
            end
        end
    end
end
