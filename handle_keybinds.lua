
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local quests = require "api.quests"



script.on_event("teleport-to-hex-core", function(event)
    event = event--[[@as {player_index: int}]] -- suppress warnings
    local player = game.get_player(event.player_index)
    if not player then return end
    if not player.character then return end

    local target = player.opened or player.selected
    if not target then return end
    ---@cast target LuaEntity

    local hex_core = lib.get_hex_core_from_entity(target)
    if not hex_core then return end
    if hex_core.name ~= "hex-core" then return end

    if not quests.is_feature_unlocked "teleportation" then
        player.print(lib.color_localized_string({"hextorio.teleportation-locked"}, "red"))
        return
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end
    if not state.claimed then
        player.print(lib.color_localized_string({"hextorio.cannot-teleport-to-unclaimed"}, "red"))
        return
    end

    if hex_core.surface.name ~= player.character.surface.name then
        player.print(lib.color_localized_string({"hextorio.cannot-teleport-to-other-planets"}, "red"))
        return
    end

    lib.teleport_player(player, hex_core.position, hex_core.surface)
end)

script.on_event("claim-hex-core", function(event)
    event = event--[[@as {player_index: int}]] -- suppress warnings
    local player = game.get_player(event.player_index)
    if not player then return end

    local target = player.opened or player.selected
    if not target then return end
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

    hex_grid.add_hex_to_claim_queue(surface, hex_pos, player, false)
end)


