
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local quests = require "api.quests"



script.on_event("teleport-to-hex-core", function(event)
    event = event--[[@as {player_index: int}]] -- suppress warnings
    local player = game.get_player(event.player_index)
    if not player then return end
    if not player.character then return end

    local hex_core = player.opened or player.selected
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

    local hex_core = player.opened or player.selected
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

    hex_grid.claim_hex(surface, hex_pos, player, false)
end)


