
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local coin_tiers = require "api.coin_tiers"
local gui = require "api.gui"
local events = require "api.events"
local sets = require "api.sets"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local event_system= require "api.event_system"
local migrations = require "api.migrations"
local trades = require "api.trades"
local item_ranks = require "api.item_ranks"
local quests = require "api.quests"

hex_grid.register_events()
trades.register_events()
item_ranks.register_events()
gui.register_events()

require "commands"

local data_constants = require "data.constants"
local data_events = require "data.events"
local data_item_values = require "data.item_values"
local data_hex_grid = require "data.hex_grid"
local data_coin_tiers = require "data.coin_tiers"
local data_surface_properties = require "data.surface_properties"
local data_trades = require "data.trades"
local data_quests = require "data.quests"
local data_item_ranks = require "data.item_ranks"
local data_event_system = require "data.event_system"
local data_trade_overview = require "data.trade_overview"



local function attempt_initialization()
    if #game.players == 0 then return end
    if not storage.events.is_temp_surface_ready then return end
    if storage.events.is_nauvis_generating then return end
    game.print {"hextorio-info.initializing"}
    events.on_nauvis_generating()
end

script.on_init(function()
    storage.constants = data_constants
    storage.events = data_events
    storage.item_values = data_item_values
    storage.hex_grid = data_hex_grid
    storage.coin_tiers = data_coin_tiers
    storage.surface_properties = data_surface_properties
    storage.trades = data_trades
    storage.quests = data_quests
    storage.item_ranks = data_item_ranks
    storage.event_system = data_event_system
    storage.trade_overview = data_trade_overview

    for _, surface_vals in pairs(storage.item_values.values) do
        surface_vals['hex-coin'] = 10
        surface_vals['gravity-coin'] = 100000 * surface_vals['hex-coin']
        surface_vals['meteor-coin'] = 100000 * surface_vals['gravity-coin']
        surface_vals['hexaprism-coin'] = 100000 * surface_vals['meteor-coin']
    end

    storage.hex_grid.nauvis_mgs_original = game.surfaces.nauvis.map_gen_settings -- makes a copy

    local mgs = game.surfaces.nauvis.map_gen_settings
    mgs.autoplace_controls.water.size = 0
    mgs.autoplace_controls.coal.size = 0
    mgs.autoplace_controls.stone.size = 0
    mgs.autoplace_controls["copper-ore"].size = 0
    mgs.autoplace_controls["iron-ore"].size = 0
    mgs.autoplace_controls["uranium-ore"].size = 0
    mgs.autoplace_controls["crude-oil"].size = 0
    mgs.autoplace_controls["enemy-base"].size = 0
    mgs.autoplace_settings.tile.settings.water.size = 0
    mgs.autoplace_settings.tile.settings.deepwater.size = 0
    game.surfaces.nauvis.map_gen_settings = mgs

    local iron_frequency = lib.runtime_setting_value "iron-ore-frequency"
    local copper_ore_frequency = lib.runtime_setting_value "copper-ore-frequency"
    local coal_frequency = lib.runtime_setting_value "coal-frequency"
    local stone_frequency = lib.runtime_setting_value "stone-frequency"
    local uranium_ore_frequency = lib.runtime_setting_value "uranium-ore-frequency"

    local mgso = storage.hex_grid.nauvis_mgs_original
    -- Define default nauvis resource randomization based on map gen settings frequencies
    storage.hex_grid.nauvis_resource_weighted_choice = weighted_choice.new {
        ["iron-ore"] = mgso.autoplace_controls["iron-ore"].size * iron_frequency,
        ["copper-ore"] = mgso.autoplace_controls["copper-ore"].size * copper_ore_frequency,
        ["coal"] = mgso.autoplace_controls["coal"].size * coal_frequency,
        ["stone"] = mgso.autoplace_controls["stone"].size * stone_frequency,
        ["uranium-ore"] = mgso.autoplace_controls["uranium-ore"].size * uranium_ore_frequency,
    }

    -- log(serpent.block(storage.hex_grid.nauvis_resource_weighted_choice))

    -- Resource randomization in starting hex
    storage.hex_grid.starting_resource_weighted_choice = weighted_choice.copy(storage.hex_grid.nauvis_resource_weighted_choice)
    weighted_choice.set_weight(storage.hex_grid.starting_resource_weighted_choice, "uranium-ore", 0)

    -- Resource randomization without uranium
    storage.hex_grid.non_uranium_resource_weighted_choice = weighted_choice.copy(storage.hex_grid.nauvis_resource_weighted_choice)
    weighted_choice.set_weight(storage.hex_grid.non_uranium_resource_weighted_choice, "uranium-ore", 0)

    local temp = game.create_surface("hextorio-temp", mgs)
    temp.request_to_generate_chunks({0, 0}, 0)

    item_values.init()
    quests.init()

    -- Disable crash site generation, may be done by other mods anyway.
    if remote.interfaces.freeplay then
        storage.disable_crashsite = remote.call("freeplay", "get_disable_crashsite")
        storage.skip_intro = remote.call("freeplay", "get_skip_intro")

        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", true)
    end

end)

script.on_event(defines.events.on_tick, function (event)
    if storage.events.has_game_started and not storage.events.intro_finished then
        if event.tick == storage.events.game_start_tick + 60 then
            game.print("[color=black]<_>-<_>-<_>-<_>-<_>-<_>-<_>-<_>-<_>-<_>[.color]")
            game.print(lib.color_localized_string({"hextorio-info.game-started-0"}, "green"))
        elseif event.tick == storage.events.game_start_tick + 180 then
            game.print(lib.color_localized_string({"hextorio-info.game-started-1"}, "yellow"))
        elseif event.tick == storage.events.game_start_tick + 320 then
            game.print(lib.color_localized_string({"hextorio-info.game-started-2"}, "cyan"))
        elseif event.tick == storage.events.game_start_tick + 600 then
            game.print(lib.color_localized_string({"hextorio-info.game-started-3"}, "purple"))
            storage.events.intro_finished = true
        end
    end
end)

script.on_event(defines.events.on_chunk_generated, function(event)
    local surface = event.surface
    local chunk_position = event.position

    if surface.name == "hextorio-temp" then
        if chunk_position.x == 0 and chunk_position.y == 0 then
            storage.events.is_temp_surface_ready = true
            attempt_initialization()
            return
        end
    end

    if surface.name == "nauvis" then
        if chunk_position.x == 0 and chunk_position.y == 0 then
            if storage.events.is_nauvis_generating then
                events.on_nauvis_generated()
                return
            end
        end
    end

    if surface.name == "space-platform" then return end
    if surface.name == "hextorio-temp" then return end
    if storage.events.is_nauvis_generating then return end

    hex_grid.on_chunk_generated(surface.name, chunk_position)
end)

script.on_nth_tick(60, function()
    -- The nil character issue is really hard to fix "correctly".  This is a surefire way to do it.
    if not storage.events.has_game_started or storage.events.stop_checking_nil_character then return end
    local all = true
    for _, player in pairs(game.players) do
        if not player.character then
            player.create_character()
            all = false
        end
    end
    if all then
        storage.events.stop_checking_nil_character = true
    end
end)

script.on_nth_tick(120, function()
    hex_grid.update_all_hex_cores()
end)

script.on_event(defines.events.on_player_main_inventory_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    coin_tiers.normalize_inventory(player.get_inventory(defines.inventory.character_main))
end)

script.on_event(defines.events.on_player_trash_inventory_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    coin_tiers.normalize_inventory(player.get_inventory(defines.inventory.character_trash))
end)

script.on_event(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    lib.unstuck_player(player)
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    -- lib.in_spawn(player)
    attempt_initialization()
end)

script.on_event(defines.events.on_player_joined_game, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end
    lib.unstuck_player(player)
    gui.reinitialize_everything(player)
end)

script.on_event(defines.events.on_gui_opened, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.entity then
        if event.entity.name == "hex-core" then
            gui.show_hex_core(player)
        end
    end
end)

script.on_event(defines.events.on_gui_click, function (event)
    gui.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_closed, function (event)
    gui.on_gui_closed(event)
end)

script.on_event(defines.events.on_gui_confirmed, function (event)
    gui.on_gui_confirmed(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function (event)
    gui.on_gui_elem_changed(event)
end)

script.on_configuration_changed(function(handler)

    -- log("mod updated?")
    
    local changes = handler.mod_changes.hextorio
    if changes and changes.old_version ~= changes.new_version then
        migrations.on_mod_updated(changes.old_version, changes.new_version)
    end
    
    for _, player in pairs(game.players) do
        player.gui.relative.clear()
        gui.init_hex_core(player)
    end
end)
