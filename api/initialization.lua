
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local coin_tiers        = require "api.coin_tiers"
local hex_util          = require "api.hex_util"
local hex_island        = require "api.hex_island"
local hex_sets          = require "api.hex_sets"
local event_system      = require "api.event_system"
local item_value_solver = require "api.item_value_solver"

local initialization = {}




-- Called when the game is ready to start
function initialization.on_game_started()
    for _, player in pairs(game.connected_players) do
        lib.unstuck_player(player)
    end

    storage.initialization.game_start_tick = game.tick
    storage.initialization.has_game_started = true
    storage.initialization.is_ready_to_start = false

    local surface = game.get_surface "nauvis"
    if not surface or not surface.valid then
        lib.log_error("initialization.on_game_started: Failed to find the Nauvis surface")
        return
    end

    local spawn_hex = {q=0, r=0}
    local island = hex_island.get_island_hex_set "nauvis"
    local hexes_in_range, _ = hex_util.all_hexes_within_range(spawn_hex, 1, island)
    local hex_list = hex_sets.to_array(hexes_in_range)
    local second_cost = 0
    if hex_list[2] then
        second_cost = coin_tiers.to_base_value(hex_grid.calculate_hex_claim_price(surface, hex_list[2]))
    end

    local first_cost = coin_tiers.to_base_value(hex_grid.calculate_hex_claim_price(surface, spawn_hex))
    local cost_of_first_hexes = first_cost + second_cost
    if cost_of_first_hexes <= 0 then cost_of_first_hexes = 1 end

    for _, player in pairs(game.connected_players) do
        -- Make sure that all players have a character
        if not player.character then
            player.set_controller {type = defines.controllers.god}
            if not player.create_character() then
                lib.log_error("Failed to create character for player " .. player.name)
            end
        end

        -- Give starting items
        player.insert{name = "hex-coin", count = cost_of_first_hexes}

        -- And whatever other items the player should have from other mods
        for _, item in pairs(storage.initialization.player_starter_inv) do
            player.insert(item)
        end

        -- JOIN DISCORD PLEASE :D
        game.forces.player.add_chart_tag("nauvis", {position = {0, 0}, text = "Join the Discord to ask questions, report bugs, share your ideas, or just hang out!"})
        game.forces.player.add_chart_tag("nauvis", {position = {0, 4}, text = "https://discord.gg/huJY7QK6UG"})
    end

    event_system.trigger "game-started"
end

-- Called when the player is on Nauvis and the origin chunk on the temporary surface is generated
function initialization.on_nauvis_generating()
    local temp = game.surfaces["hextorio-temp"]
    if not temp then
        lib.log_error("Temporary surface does not exist")
        return
    end

    item_value_solver.run()

    -- Teleport players to temporary surface
    for _, player in pairs(game.connected_players) do
        if player and player.valid then
            -- Check for items in inventory
            storage.initialization.player_starter_inv = {}
            local inv = lib.get_player_inventory(player)
            if inv then
                for _, item in pairs(inv.get_contents()) do
                    table.insert(storage.initialization.player_starter_inv, item)
                end
            else
                lib.log_error("Failed to get player inventory for player " .. player.name .. " - skipping starter items")
            end
            lib.teleport_player(player, {16, 16}, temp)
            player.character = nil -- Force nil character so that going into map view doesn't crash the game
        end
    end

    -- Set flag to enable hex initialization on Nauvis
    storage.initialization.is_nauvis_generating = true

    -- Regenerate chunks in Nauvis starting area
    for chunk in game.surfaces.nauvis.get_chunks() do
        game.surfaces.nauvis.delete_chunk({chunk.x, chunk.y})
        game.surfaces.nauvis.set_chunk_generated_status({chunk.x, chunk.y}, defines.chunk_generated_status.tiles)
    end

    -- Trigger chunk and hex generation on Nauvis
    game.surfaces.nauvis.request_to_generate_chunks({0, 0}, 0)
end

-- Called when the player is on the temporary surface and the origin chunk on Nauvis is generated
function initialization.on_nauvis_generated()
    -- Delete temporary surface
    game.delete_surface(game.surfaces["hextorio-temp"])

    storage.initialization.is_nauvis_generating = false
    storage.initialization.is_ready_to_start = true

    -- Trigger game started event
    initialization.on_game_started()
end



return initialization
