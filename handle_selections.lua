
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"



local function on_claim_tool_used(player, entities)
    for _, e in pairs(entities) do
        local transformation = hex_grid.get_surface_transformation(e.surface)
        local hex_pos = hex_grid.get_hex_containing(e.position, transformation.scale, transformation.rotation)
        if e.name == "hex-core" then
            if hex_grid.can_claim_hex(player, e.surface, hex_pos) then
                hex_grid.claim_hex(e.surface, hex_pos, player)
            end
        end
    end
end

script.on_event(defines.events.on_player_selected_area, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.item == "claim-tool" then
        on_claim_tool_used(player, event.entities)
    end
end)
