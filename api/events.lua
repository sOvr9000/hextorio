
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
            lib.log("Creating character for player " .. player.name)
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
    lib.log("Teleporting players to temporary surface")
    for _, player in pairs(game.connected_players) do
        if player and player.valid then
            -- Check for items in inventory
            storage.events.player_starter_inv = {}
            for _, item in pairs(lib.get_player_inventory(player).get_contents()) do
                table.insert(storage.events.player_starter_inv, item)
            end
            lib.teleport_player(player, {16, 16}, temp)
            player.character = nil -- Force nil character so that going into map view doesn't crash the game
        end
    end

    -- Set flag to enable hex initialization on Nauvis
    storage.events.is_nauvis_generating = true

    -- Regenerate chunks in Nauvis starting area
    for x = -7, 6 do
        for y = -7, 6 do
            game.surfaces.nauvis.delete_chunk({x, y})
            game.surfaces.nauvis.set_chunk_generated_status({x, y}, defines.chunk_generated_status.tiles)
        end
    end
    lib.log("Deleted Nauvis chunks")

    -- Trigger chunk and hex generation on Nauvis
    -- game.forces.player.chart(game.surfaces.nauvis, {{-10,-10},{10,10}})
    lib.log("Requesting chunk regeneration on Nauvis")
    game.surfaces.nauvis.request_to_generate_chunks({0, 0}, 0)
end

-- Called when the player is on the temporary surface and the origin chunk on Nauvis is generated
function events.on_nauvis_generated()
    -- Teleport players to Nauvis
    lib.log("Teleporting players to Nauvis")
    for _, player in pairs(game.connected_players) do
        lib.log("(pre-teleport) player character is nil: " .. tostring(player.character == nil))
        if player.character then
            lib.log("(pre-teleport) player character surface and position: " .. player.character.surface.name .. ", " .. serpent.block(player.character.position))
        end
        lib.teleport_player(player, {0, 5}, game.surfaces.nauvis)
        lib.log("(post-teleport) player character is nil: " .. tostring(player.character == nil))
        if player.character then
            lib.log("(post-teleport) player character surface and position: " .. player.character.surface.name .. ", " .. serpent.block(player.character.position))
        end
    end

    -- Delete temporary surface
    game.delete_surface(game.surfaces["hextorio-temp"])

    for _, player in pairs(game.connected_players) do
        lib.log("(post-surface deletion) player character is nil: " .. tostring(player.character == nil))
        if player.character then
            lib.log("(post-surface deletion) player character surface and position: " .. player.character.surface.name .. ", " .. serpent.block(player.character.position))
        end
    end

    storage.events.is_nauvis_generating = false
    storage.events.is_ready_to_start = true

    -- Trigger game started event
    events.on_game_started()
end



return events
