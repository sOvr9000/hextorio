
local lib = require "api.lib"
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_grid = require "api.hex_grid"
local coin_tiers = require "api.coin_tiers"
local quests = require "api.quests"



local function on_claim_tool_used(player, entities)
    for _, e in pairs(entities) do
        if e.name == "hex-core" then
            local transformation = terrain.get_surface_transformation(e.surface)
            local hex_pos = axial.get_hex_containing(e.position, transformation.scale, transformation.rotation)
            if hex_grid.can_claim_hex(player, e.surface, hex_pos) then
                hex_grid.add_hex_to_claim_queue(e.surface, hex_pos, player)
            end
        end
    end
end

local function on_delete_core_tool_used(player, entities)
    if not quests.is_feature_unlocked "hex-core-deletion" then
        player.print({"hextorio.core-deletion-not-unlocked"})
        return
    end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local failed = false
    for _, e in pairs(entities) do
        if e.name == "hex-core" then
            local cost = hex_grid.get_delete_core_cost(e)
            local current_coin = coin_tiers.get_coin_from_inventory(inv)
            if coin_tiers.ge(current_coin, cost) then
                if not hex_grid.delete_hex_core(e) then
                    -- This only happens when something goes wrong with data handling, so this should not actually inform the player.
                    -- failed = true
                end
                coin_tiers.remove_coin_from_inventory(inv, cost)
            else
                failed = true
            end
        end
    end

    if failed then
        player.print({"hextorio.hex-cores-not-deleted"})
    end
end

script.on_event(defines.events.on_player_selected_area, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.item == "claim-tool" then
        on_claim_tool_used(player, event.entities)
    elseif event.item == "delete-core-tool" then
        on_delete_core_tool_used(player, event.entities)
    end
end)
