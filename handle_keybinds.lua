
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local quests = require "api.quests"
local gui = require "api.gui"
local event_system = require "api.event_system"



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

    lib.teleport_player(player, hex_core.position, hex_core.surface, true)
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


