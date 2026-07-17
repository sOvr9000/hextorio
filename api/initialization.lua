
local lib               = require "api.lib"
local sets              = require "api.sets"
local hex_grid          = require "api.hex_grid"
local trades            = require "api.trades"
local coin_tiers        = require "api.coin_tiers"
local hex_util          = require "api.hex_util"
local hex_island        = require "api.hex_island"
local hex_sets          = require "api.hex_sets"
local event_system      = require "api.event_system"
local item_value_solver = require "api.item_value_solver"
local weighted_choice   = require "api.weighted_choice"
local mgs_util          = require "api.util.mgs"

local initialization = {}



function initialization.register_events()
    event_system.register("player-created", initialization.on_player_created)
    event_system.register("starting-hex-initialized", initialization.on_starting_hex_initialized)
end

function initialization.init()
    -- Disable crash site generation, may be done by other mods anyway.
    if remote.interfaces.freeplay then
        storage.disable_crashsite = remote.call("freeplay", "get_disable_crashsite")
        storage.skip_intro = remote.call("freeplay", "get_skip_intro")

        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", true)
    end

    local surface = game.surfaces.nauvis

    local mgs_original = surface.map_gen_settings -- makes a copy
    storage.hex_grid.mgs["nauvis"] = mgs_original

    local mgs = surface.map_gen_settings -- makes another copy
    mgs_util.zero_freq_rich_size(mgs.autoplace_controls, {"water", "coal", "stone", "copper-ore", "iron-ore", "uranium-ore", "crude-oil", "enemy-base"})
    mgs_util.zero_freq_rich_size(mgs.autoplace_settings.tile.settings, {"water", "deepwater"}) -- frequency doesn't get set to zero for water, but this has no effect compared to previous behavior
    mgs_util.zero_freq_rich_size(mgs.autoplace_settings.entity.settings, {"coal", "iron-ore", "copper-ore", "uranium-ore", "stone"})

    surface.map_gen_settings = mgs

    local water_names = {"water", "deepwater", "water-green", "deepwater-green", "water-shallow", "water-mud"}
    local water_set = sets.new(water_names)

    local default_tile = surface.get_tile(0, 0).name

    local function nearest_land_tile(pos)
        for radius = 1, 4 do
            for dx = -radius, radius do
                for dy = -radius, radius do
                    if math.abs(dx) == radius or math.abs(dy) == radius then
                        local t = surface.get_tile(pos.x + dx, pos.y + dy)
                        if t.valid and not water_set[t.name] then return t.name end
                    end
                end
            end
        end
        return default_tile
    end

    for chunk in surface.get_chunks() do
        local area = {
            {chunk.x * 32, chunk.y * 32},
            {chunk.x * 32 + 32, chunk.y * 32 + 32},
        }
        for _, entity in pairs(surface.find_entities_filtered{type = "resource", area = area}) do
            entity.destroy()
        end
        local water_tiles = surface.find_tiles_filtered{area = area, name = water_names}
        if #water_tiles > 0 then
            local replacements = {}
            for _, tile in pairs(water_tiles) do
                replacements[#replacements + 1] = {name = nearest_land_tile(tile.position), position = tile.position}
            end
            surface.set_tiles(replacements)
        end
    end

    local iron_frequency = lib.runtime_setting_value "iron-ore-frequency"
    local copper_ore_frequency = lib.runtime_setting_value "copper-ore-frequency"
    local coal_frequency = lib.runtime_setting_value "nauvis-coal-frequency"
    local stone_frequency = lib.runtime_setting_value "nauvis-stone-frequency"
    -- local uranium_ore_frequency = lib.runtime_setting_value "uranium-ore-frequency"

    -- Define default nauvis resource randomization based on map gen settings frequencies
    storage.hex_grid.resource_weighted_choice.nauvis = {}
    storage.hex_grid.resource_weighted_choice.nauvis.resources = weighted_choice.new {
        ["iron-ore"] = mgs_original.autoplace_controls["iron-ore"].size * iron_frequency,
        ["copper-ore"] = mgs_original.autoplace_controls["copper-ore"].size * copper_ore_frequency,
        ["coal"] = mgs_original.autoplace_controls["coal"].size * coal_frequency,
        ["stone"] = mgs_original.autoplace_controls["stone"].size * stone_frequency,
        -- ["uranium-ore"] = mgs_original.autoplace_controls["uranium-ore"].size * uranium_ore_frequency,
    }
    storage.hex_grid.resource_weighted_choice.nauvis.wells = weighted_choice.new {
        ["crude-oil"] = 1,
    }
    storage.hex_grid.resource_weighted_choice.nauvis.uranium = weighted_choice.new {
        ["uranium-ore"] = 1,
    }

    local num_trades = lib.runtime_setting_value "rank-3-effect" --[[@as int]]
    trades.generate_interplanetary_trade_locations("nauvis", num_trades)

    -- Set enemy force color.
    game.forces.enemy.custom_color = {0.6, 0.1, 0.6}

    game.print(lib.color_localized_string({"hextorio.intro"}, "yellow", "heading-1"))
    if not lib.is_hextreme_enabled() then
        game.print(lib.color_localized_string({"hextorio.hextreme-disabled"}, "pink", "heading-1"))
    end

    -- JOIN DISCORD PLEASE :D
    game.forces.player.add_chart_tag("nauvis", {position = {0, 0}, text = "Join the Discord to ask questions, report bugs, share your ideas, or just hang out!"})
    game.forces.player.add_chart_tag("nauvis", {position = {0, 4}, text = "https://discord.gg/huJY7QK6UG"})

    event_system.trigger "game-started"
    item_value_solver.init()
end

---@param player LuaPlayer
function initialization.give_starting_coins(player)
    local surface = player.surface

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

    -- Give starting items
    player.insert{name = "hex-coin", count = cost_of_first_hexes}
end

---@param player LuaPlayer
function initialization.on_player_created(player)
    initialization.give_starting_coins(player)
end

-- Called when the player is on Nauvis and the origin chunk on the temporary surface is generated
function initialization.on_nauvis_generating()
    local temp = game.surfaces["hextorio-temp"]
    if not temp then
        lib.log_error("Temporary surface does not exist")
        return
    end

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
    initialization.init()
end

---@param surface_id int
function initialization.on_starting_hex_initialized(surface_id)
    local surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("initialization.on_starting_hex_initialized: Could not find surface by id " .. surface_id)
        return
    end

    if surface.name == "fulgora" then
        surface.create_entity {
            name = "fulgoran-ruin-attractor",
            quality = lib.get_hextreme_or_next_highest_quality(),
            position = {0, -5},
            force = "player",
        }
    elseif surface.name == "vulcanus" then
        for i = 1, 48 do
            local pos = surface.find_non_colliding_position("huge-volcanic-rock", {x = math.random(-20, 20), y = math.random(-20, 20)}, 10, 0.5, false)
            if pos then
                surface.create_entity {
                    name = "huge-volcanic-rock",
                    position = pos,
                    force = "neutral",
                }
            end
        end
    elseif surface.name == "nauvis" then
        if lib.runtime_setting_value "nauvis-grace" then
            local turrets = {}
            for _, pos in pairs {
                {-5, -5},
                {-5, 6},
                {6, -5},
                {6, 6},
            } do
                table.insert(turrets, surface.create_entity {
                    name = "gun-turret",
                    position = pos,
                    force = "player",
                    quality = "epic",
                })
            end
            lib.reload_turrets(turrets, {bullet_type = "piercing-rounds-magazine", bullet_count = 30})
        end
        for _, player in pairs(game.connected_players) do
            if player.character then
                lib.teleport_player(player, {0, 5}, surface)
            end
        end
    end
end



return initialization
