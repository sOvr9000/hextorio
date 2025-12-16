
local lib = require "api.lib"
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_grid = require "api.hex_grid"
local coin_tiers = require "api.coin_tiers"
local quests = require "api.quests"



---@param player LuaPlayer
---@param surface LuaSurface
---@param entities LuaEntity[]
---@param area BoundingBox
---@param reverse boolean
---@param alt boolean
local function on_claim_tool_used(player, surface, entities, area, reverse, alt)
    local params = {}
    local transformation = terrain.get_surface_transformation(surface)

    local player_inventory_coins
    if not reverse then
        local inv = lib.get_player_inventory(player)
        if inv then
            player_inventory_coins = coin_tiers.get_coin_from_inventory(inv)
        end
    end

    if alt then
        -- Include ALL hexes, not just ones that have hex cores currently.
        local overlapping = axial.get_overlapping_hexes(area.left_top, area.right_bottom, transformation.scale, transformation.rotation, false)
        for _, hex_pos in pairs(overlapping) do
            if reverse or hex_grid.can_claim_hex(player, surface, hex_pos, false, true, player_inventory_coins) then
                local center = axial.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
                if lib.is_position_in_rect(center, area.left_top, area.right_bottom) then
                    table.insert(params, {surface, hex_pos, player, false})
                end
            end
        end
    else
        -- Only include the hexes with hex cores.
        for _, e in pairs(entities) do
            if e.name == "hex-core" then
                local hex_pos = axial.get_hex_containing(e.position, transformation.scale, transformation.rotation)
                if reverse or hex_grid.can_claim_hex(player, surface, hex_pos, false, true, player_inventory_coins) then
                    table.insert(params, {surface, hex_pos, player, false})
                end
            end
        end
    end

    for _, param in pairs(params) do
        if reverse then
            hex_grid.remove_hex_from_claim_queue(table.unpack(param, 1, 2))
        else
            hex_grid.add_hex_to_claim_queue(table.unpack(param))
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
                    failed = true
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

local function on_hexport_tool_used(player, entities, reverse)
    if not quests.is_feature_unlocked "hexports" then
        player.print {"hextorio.hexports-not-unlocked"}
        return
    end

    for _, e in pairs(entities) do
        if e.name == "hex-core" then
            local state = hex_grid.get_hex_state_from_core(e)
            if state and state.claimed then
                if reverse then
                    if state.hexport then
                        hex_grid.remove_hexport(state)
                    end
                else
                    if not state.hexport then
                        hex_grid.spawn_hexport(state)
                    end
                end
            end
        end
    end
end

script.on_event(defines.events.on_player_selected_area, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.item == "claim-tool" then
        on_claim_tool_used(player, event.surface, event.entities, event.area, false, false)
    elseif event.item == "delete-core-tool" then
        on_delete_core_tool_used(player, event.entities)
    elseif event.item == "hexport-tool" then
        on_hexport_tool_used(player, event.entities, false)
    end
end)

script.on_event(defines.events.on_player_reverse_selected_area, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.item == "claim-tool" then
        on_claim_tool_used(player, event.surface, event.entities, event.area, true, false)
    elseif event.item == "hexport-tool" then
        on_hexport_tool_used(player, event.entities, true)
    end
end)

script.on_event(defines.events.on_player_alt_selected_area, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.item == "claim-tool" then
        on_claim_tool_used(player, event.surface, event.entities, event.area, false, true)
    end
end)

script.on_event(defines.events.on_player_alt_reverse_selected_area, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.item == "claim-tool" then
        on_claim_tool_used(player, event.surface, event.entities, event.area, true, true)
    end
end)
