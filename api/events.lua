
local lib = require "api.lib"
local gui = require "api.gui"

local events = {}




-- Called when the game is ready to start
function events.on_game_started()
    for _, player in pairs(game.connected_players) do
        lib.unstuck_player(player)
    end

    storage.events.game_start_tick = game.tick
    storage.events.has_game_started = true
    storage.events.is_ready_to_start = false

    for _, player in pairs(game.connected_players) do
        -- Make sure that all players have a character
        if not player.character then
            player.set_controller {type = defines.controllers.god}
            if not player.create_character() then
                lib.log_error("Failed to create character for player " .. player.name)
            end
        end

        -- Give starting items
        player.insert{name = "hex-coin", count = 5}

        -- And whatever other items the player should have from other mods
        for _, item in pairs(storage.events.player_starter_inv) do
            player.insert(item)
        end

        gui.init_all_buttons(player)

        -- JOIN DISCORD PLEASE :D
        game.forces.player.add_chart_tag("nauvis", {position = {0, 0}, text = "Join the Discord to ask questions, report bugs, share your ideas, or just hang out!"})
        game.forces.player.add_chart_tag("nauvis", {position = {0, 4}, text = "https://discord.gg/huJY7QK6UG"})
    end
end

-- Called when the player is on Nauvis and the origin chunk on the temporary surface is generated
function events.on_nauvis_generating()
    local temp = game.surfaces["hextorio-temp"]
    if not temp then
        lib.log_error("Temporary surface does not exist")
        return
    end

    -- Teleport players to temporary surface
    for _, player in pairs(game.connected_players) do
        if player and player.valid then
            -- Check for items in inventory
            storage.events.player_starter_inv = {}
            local inv = lib.get_player_inventory(player)
            if inv then
                for _, item in pairs(inv.get_contents()) do
                    table.insert(storage.events.player_starter_inv, item)
                end
            else
                lib.log_error("Failed to get player inventory for player " .. player.name .. " - skipping starter items")
            end
            lib.teleport_player(player, {16, 16}, temp)
            player.character = nil -- Force nil character so that going into map view doesn't crash the game
        end
    end

    -- Set flag to enable hex initialization on Nauvis
    storage.events.is_nauvis_generating = true

    -- Regenerate chunks in Nauvis starting area
    for chunk in game.surfaces.nauvis.get_chunks() do
        game.surfaces.nauvis.delete_chunk({chunk.x, chunk.y})
        game.surfaces.nauvis.set_chunk_generated_status({chunk.x, chunk.y}, defines.chunk_generated_status.tiles)
    end

    -- Trigger chunk and hex generation on Nauvis
    game.surfaces.nauvis.request_to_generate_chunks({0, 0}, 0)
end

-- Called when the player is on the temporary surface and the origin chunk on Nauvis is generated
function events.on_nauvis_generated()
    -- Delete temporary surface
    game.delete_surface(game.surfaces["hextorio-temp"])

    storage.events.is_nauvis_generating = false
    storage.events.is_ready_to_start = true

    -- Trigger game started event
    events.on_game_started()
end



return events
