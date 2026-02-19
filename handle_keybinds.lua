
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local quests = require "api.quests"
local gui = require "api.gui"
local event_system = require "api.event_system"
local axial        = require "api.axial"
local dungeons     = require "api.dungeons"
local hex_state_manager = require "api.hex_state_manager"



script.on_event("toggle-questbook", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    if gui.core_gui.is_frame_open(player, "questbook") then
        gui.questbook.hide_questbook(player)
    else
        gui.questbook.show_questbook(player)
    end
end)

script.on_event("toggle-catalog", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    if not quests.is_feature_unlocked "catalog" then return end

    if gui.core_gui.is_frame_open(player, "catalog") then
        gui.catalog.hide_catalog(player)
    else
        gui.catalog.show_catalog(player)
    end
end)

script.on_event("toggle-trade-overview", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    if not quests.is_feature_unlocked "trade-overview" then return end

    if gui.core_gui.is_frame_open(player, "trade-overview") then
        gui.trade_overview.hide_trade_overview(player)
    else
        gui.trade_overview.show_trade_overview(player)
    end
end)

script.on_event("toggle-hex-rank", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    if not quests.is_feature_unlocked "hex-rank" then return end

    if gui.core_gui.is_frame_open(player, "hex-rank") then
        gui.hex_rank.hide_hex_rank(player)
    else
        gui.hex_rank.show_hex_rank(player)
    end
end)

script.on_event("teleport-to-hex-core", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end
    if not player.character then return end

    local target = lib.get_player_opened_or_selected_entity(player)
    if not target then return end

    local hex_core = lib.get_hex_core_from_entity(target)
    if not hex_core then return end
    if hex_core.name ~= "hex-core" then return end

    if not (quests.is_feature_unlocked "teleportation" or quests.is_feature_unlocked "teleportation-cross-planet") then
        player.print(lib.color_localized_string({"hextorio.teleportation-locked"}, "red"))
        return
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end
    if not state.claimed then
        player.print(lib.color_localized_string({"hextorio.cannot-teleport-to-unclaimed"}, "red"))
        return
    end

    if quests.is_feature_unlocked "teleportation-cross-planet" then
        if not lib.teleport_player_cross_surface(player, hex_core.position, hex_core.surface, true) then
            player.print({"hextorio.empty-character-inventories"})
            if player.character.vehicle then
                player.print({"hextorio.empty-vehicle-inventories"})
            end
        end
        return
    end

    if hex_core.surface.name ~= player.character.surface.name then
        player.print(lib.color_localized_string({"hextorio.teleportation-cross-planet-locked"}, "red"))
        return
    end

    local surface = hex_core.surface
    local hex_pos = state.position

    local bad_tp = false
    for _, adj_pos in pairs(axial.get_adjacent_hexes(hex_pos)) do
        local adj_state = hex_state_manager.get_hex_state(surface, adj_pos)
        -- local dungeon = dungeons.get_dungeon_at_hex_pos(surface.index, adj_pos, false)
        -- if dungeon and not dungeon.is_looted then
        if adj_state and adj_state.is_dungeon then
            bad_tp = true
            break
        end
    end

    if not storage.hex_grid.player_last_teleport_attempts then
        storage.hex_grid.player_last_teleport_attempts = {}
    end

    local last_tp = storage.hex_grid.player_last_teleport_attempts[player.index]
    local tp_attempt = {surface_id = surface.index, hex_pos = hex_pos}
    if bad_tp and (not last_tp or not lib.tables_equal(last_tp, tp_attempt)) then
        player.print(lib.color_localized_string({"hextorio.dungeon-nearby-prevented-tp"}, "yellow"))
        storage.hex_grid.player_last_teleport_attempts[player.index] = tp_attempt
        return
    end

    storage.hex_grid.player_last_teleport_attempts[player.index] = nil

    lib.teleport_player(player, hex_core.position, surface, true)
end)

script.on_event("claim-hex-core", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    local target = player.opened or player.selected
    if not target or not target.surface then return end
    ---@cast target LuaEntity

    local hex_core = lib.get_hex_core_from_entity(target)
    if not hex_core then return end
    if hex_core.name ~= "hex-core" then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end
    if state.claimed then return end

    local surface = hex_core.surface
    local hex_pos = state.position

    if not hex_grid.can_claim_hex(player, surface, hex_pos, false) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford"}, "red"))
        return
    end

    hex_grid.add_hex_to_claim_queue(surface, hex_pos, player, false, true)
end)

-- script.on_event("favorite-trade", function(event)
--     event = event--[[@as {player_index: int}]] -- suppress warnings
--     local player = game.get_player(event.player_index)
--     if not player then return end

--     event_system.trigger("favorite-trade-key-pressed", player)
-- end)

script.on_event("pickup-nearby-items", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end
    if not player.character then return end

    local pickup_radius = 20
    local player_position = player.character.position
    local surface = player.character.surface

    local search_area = {
        {player_position.x - pickup_radius, player_position.y - pickup_radius},
        {player_position.x + pickup_radius, player_position.y + pickup_radius}
    }

    local items_on_ground = surface.find_entities_filtered {
        area = search_area,
        type = "item-entity",
    }

    local total_picked_up = 0
    local items_left_behind = 0

    for _, item_entity in pairs(items_on_ground) do
        if item_entity.valid then
            local stack = item_entity.stack
            local inserted = player.insert(stack)

            if inserted > 0 then
                total_picked_up = total_picked_up + inserted
                if inserted == stack.count then
                    item_entity.destroy()
                else
                    stack.count = stack.count - inserted
                    item_entity.stack = stack
                    items_left_behind = items_left_behind + stack.count
                end
            else
                items_left_behind = items_left_behind + stack.count
            end
        end
    end

    if total_picked_up > 0 then
        player.create_local_flying_text {
            text = {"", "[img=entity.item-on-ground] +", total_picked_up},
            create_at_cursor = false,
            position = player_position,
        }
        if items_left_behind > 0 then
            player.print({"", "[color=yellow]Picked up ", total_picked_up, " items. ", items_left_behind, " items left behind (inventory full).[/color]"})
        end
    end
end)

script.on_event("hextorio-control-gui-back", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    event_system.trigger "control-gui-back"
end)

script.on_event("hextorio-control-gui-forward", function(event)
    ---@cast event {player_index: int}
    local player = game.get_player(event.player_index)
    if not player then return end

    event_system.trigger "control-gui-forward"
end)


