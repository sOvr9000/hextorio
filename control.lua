
require "util" -- For table.deepcopy()
local item_buffs = require("api.item_buffs")

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
local blueprints = require "api.blueprints"
local space_platforms = require "api.space_platforms"
local loot_tables = require "api.loot_tables"
local dungeons = require "api.dungeons"
local spiders = require "api.spiders"
local hex_island = require "api.hex_island"

item_values.register_events()
hex_grid.register_events()
trades.register_events()
item_ranks.register_events()
gui.register_events()
quests.register_events()
dungeons.register_events()
spiders.register_events()
hex_island.register_events()
space_platforms.register_events()

require "commands"
require "handle_keybinds"
require "handle_selections"
require "handle_coin_splitting"

local data_constants = require "data.constants"
local data_events = require "data.events"
local data_item_values = require "data.item_values"
local data_hex_grid = require "data.hex_grid"
local data_coin_tiers = require "data.coin_tiers"
local data_trades = require "data.trades"
local data_quests = require "data.quests"
local data_item_ranks = require "data.item_ranks"
local data_event_system = require "data.event_system"
local data_trade_overview = require "data.trade_overview"
local data_blueprints = require "data.blueprints"
local data_dungeons = require "data.dungeons"
local data_spiders = require "data.spiders"
local data_hex_island = require "data.hex_island"
local data_item_buffs = require "data.item_buffs"



local function attempt_initialization()
    if #game.players == 0 then return end
    if not storage.events.is_temp_surface_ready then return end
    if storage.events.is_nauvis_generating then return end
    events.on_nauvis_generating()
end



script.on_init(function()
    storage.cached = {} -- For reusing results from expensive function calls like geometric calculations between axial and rectangular coordinate systems.
    storage.cooldowns = {} -- Player-specific cooldowns for various operations like performance-impacting commands (such as /simple-trade-loops)

    storage.constants = data_constants
    storage.events = data_events
    storage.item_values = data_item_values
    storage.hex_grid = data_hex_grid
    storage.coin_tiers = data_coin_tiers
    storage.trades = data_trades
    storage.quests = data_quests
    storage.item_ranks = data_item_ranks
    storage.event_system = data_event_system
    storage.trade_overview = data_trade_overview
    storage.blueprints = data_blueprints
    storage.dungeons = data_dungeons
    storage.spiders = data_spiders
    storage.hex_island = data_hex_island
    storage.item_buffs = data_item_buffs

    storage.ammo_type_per_entity = {
        ["dungeon-gun-turret"] = "bullet_type",
        ["dungeon-flamethrower-turret"] = "flamethrower_type",
        ["dungeon-rocket-turret"] = "rocket_type",
        ["dungeon-railgun-turret"] = "railgun_type",
    }

    local mgs_original = game.surfaces.nauvis.map_gen_settings -- makes a copy
    storage.hex_grid.mgs["nauvis"] = mgs_original

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

    local temp = game.create_surface("hextorio-temp", mgs)
    temp.request_to_generate_chunks({0, 0}, 0)

    item_values.init()
    quests.init()
    blueprints.init()
    loot_tables.init()
    dungeons.init()
    spiders.init()
    hex_island.init()

    -- Disable crash site generation, may be done by other mods anyway.
    if remote.interfaces.freeplay then
        storage.disable_crashsite = remote.call("freeplay", "get_disable_crashsite")
        storage.skip_intro = remote.call("freeplay", "get_skip_intro")

        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", true)
    end

    local num_trades = lib.runtime_setting_value "rank-3-effect" --[[@as int]]
    trades.generate_interplanetary_trade_locations("nauvis", num_trades)

    -- Set enemy force color.
    game.forces.enemy.custom_color = {0.6, 0.1, 0.6}
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

    if lib.is_space_platform(surface.name) then return end
    if surface.name == "hextorio-temp" then return end
    if storage.events.is_nauvis_generating then return end

    hex_grid.on_chunk_generated(surface.name, chunk_position)
end)

script.on_nth_tick(300, function()
    event_system.trigger("dungeon-update")
end)

script.on_nth_tick(60, function()
    -- The nil character issue is really hard to fix "correctly".  This is a surefire way to do it.
    if not storage.events.has_game_started or storage.events.stop_checking_nil_character then return end
    local all = true
    for _, player in pairs(game.connected_players) do
        if not player.character then
            player.create_character()
            all = false
        end
    end
    if all then
        storage.events.stop_checking_nil_character = true
    end
end)

script.on_nth_tick(20, function()
    hex_grid.process_claim_queue()
end)

script.on_nth_tick(10, function()
    hex_grid.process_hex_core_pool()
end)

script.on_event(defines.events.on_tick, function (event)
    if storage.events.has_game_started and not storage.events.intro_finished then
        if event.tick == storage.events.game_start_tick + 60 then
            game.print(lib.color_localized_string({"hextorio.intro"}, "yellow", "heading-1"))
            if not lib.is_hextreme_enabled() then
                game.print(lib.color_localized_string({"hextorio.hextreme-disabled"}, "pink", "heading-1"))
            end
            -- if not lib.startup_setting_value "pvp-mode" then
            --     game.print(lib.color_localized_string({"hextorio.try-pvp"}, "orange", "heading-1"))
            -- end
            storage.events.intro_finished = true
        end
    end

    dungeons._tick_turret_reload()
    item_buffs._enhance_all_item_buffs_tick()
    gui._process_trades_scroll_panes()
end)

script.on_event(defines.events.on_player_main_inventory_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local inv = player.get_inventory(defines.inventory.character_main)
    if not inv then return end

    local coin = coin_tiers.normalize_inventory(inv)
    if not coin then return end

    quests.set_progress_for_type("coins-in-inventory", coin_tiers.to_base_value(coin))
end)

script.on_event(defines.events.on_player_trash_inventory_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local inv = player.get_inventory(defines.inventory.character_trash)
    if not inv then return end

    coin_tiers.normalize_inventory(inv)
end)

script.on_event(defines.events.on_player_dropped_item_into_entity, function(event)
    local inv = event.entity.get_inventory(defines.inventory.chest)
    if not inv then return end

    coin_tiers.normalize_inventory(inv)
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
    quests.check_player_receive_items(player)
end)

script.on_event(defines.events.on_built_entity, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    event_system.trigger("player-built-entity", player, event.entity)
    event_system.trigger("entity-built", event.entity)
end)

script.on_event(defines.events.on_player_mined_entity, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    event_system.trigger("player-mined-entity", player, event.entity)
    event_system.trigger("entity-picked-up", event.entity)
end)

script.on_event(defines.events.on_robot_built_entity, function(event)
    event_system.trigger("player-built-entity", nil, event.entity)
    event_system.trigger("entity-built", event.entity)
end)

script.on_event(defines.events.on_robot_mined_entity, function(event)
    event_system.trigger("entity-picked-up", event.entity)
end)

script.on_event(defines.events.on_player_built_tile, function(event)
    quests.increment_progress_for_type("place-tile", #event.tiles, event.tile.name)
end)

script.on_event(defines.events.on_player_mined_tile, function(event)
    for _, tile in pairs(event.tiles) do
        quests.increment_progress_for_type("place-tile", -1, tile.old_tile.name)
    end
end)

script.on_event(defines.events.on_robot_built_tile, function(event)
    quests.increment_progress_for_type("place-tile", #event.tiles, event.tile.name)
end)

script.on_event(defines.events.on_robot_mined_tile, function(event)
    for _, tile in pairs(event.tiles) do
        quests.increment_progress_for_type("place-tile", -1, tile.old_tile.name)
    end
end)

script.on_event(defines.events.on_player_changed_position, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if game.tick > 1000 and not lib.player_is_in_remote_view(player) and lib.is_player_cooldown_ready(player.index, "scan-chunks") then
        log("scanning chunks!!!")
        player.surface.request_to_generate_chunks(player.position, storage.hex_grid.chunk_generation_range_per_player)
        lib.trigger_player_cooldown(player.index, "scan-chunks", 3 * 60)
    end
end)

script.on_event(defines.events.on_player_used_capsule, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    quests.increment_progress_for_type("use-capsule", 1, event.item.name)
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

script.on_event(defines.events.on_gui_value_changed, function (event)
    gui.on_gui_value_changed(event)
end)

script.on_event(defines.events.on_gui_selection_state_changed, function (event)
    gui.on_gui_item_selected(event)
end)

script.on_event(defines.events.on_gui_switch_state_changed, function (event)
    gui.on_gui_switch_state_changed(event)
end)

script.on_event(defines.events.on_entity_settings_pasted, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local source = event.source
    destination = event.destination

    hex_grid.on_entity_settings_pasted(player, source, destination)
end)

script.on_event(defines.events.on_entity_died, function (event)
    if event.cause and event.cause.force == game.forces.player then
        quests.increment_progress_for_type("kill-entity", 1, event.entity.name)
        if event.damage_type then
            if event.entity.force ~= game.forces.player then
                event_system.trigger("enemy-died-to-damage-type", event.entity, event.damage_type.name, event.cause)
            end
        end
    end
    if event.entity.name == "character" then
        -- This is not in on_player_died because the damage type for cause of death may be important.
        if event.damage_type then
            quests.increment_progress_for_type("die-to-damage-type", 1, event.damage_type.name)
        end
        if event.cause then
            if sets.new(lib.get_entity_ammo_categories(event.cause))["railgun"] then
                if event.cause.force == game.forces.player then
                    quests.increment_progress_for_type "die-to-railgun"
                end
            end
        end
    end
    if event.entity.name == "biter-spawner" or event.entity.name == "spitter-spawner" then
        if event.cause and (event.cause.name == "car" or event.cause.name == "tank") then
            event_system.trigger("spawner-rammed", event.entity, event.cause)
        end
    elseif event.entity.name == "space-platform-hub" then
        local inv = event.entity.get_inventory(defines.inventory.hub_main)
        if inv then
            local contents = inv.get_contents()
            for _, item in pairs(contents) do
                if lib.get_quality_tier(item.quality) >= 6 and item_ranks.get_item_rank(item.name) == 4 then
                    item_ranks.rank_up(item.name)
                end
            end
        end
    end
end)

script.on_event(defines.events.on_surface_created, function (event)
    local surface_id = event.surface_index
    local surface = game.get_surface(surface_id)
    if not surface then return end

    local mgs_original = surface.map_gen_settings -- makes copy
    storage.hex_grid.mgs[surface.name] = mgs_original

    local unknown = false

    if surface.name == "vulcanus" then
        local mgs = surface.map_gen_settings
        mgs.autoplace_controls.vulcanus_coal.size = 0
        mgs.autoplace_controls.calcite.size = 0
        mgs.autoplace_controls.tungsten_ore.size = 0
        mgs.autoplace_controls.sulfuric_acid_geyser.size = 0
        mgs.autoplace_controls.vulcanus_volcanism.size = 0
        mgs.autoplace_settings.tile.settings.lava.size = 0
        mgs.autoplace_settings.tile.settings["lava-hot"].size = 0
        surface.map_gen_settings = mgs

        local coal_frequency = lib.runtime_setting_value "vulcanus-coal-frequency"
        local calcite_frequency = lib.runtime_setting_value "calcite-frequency"
        local tungsten_ore_frequency = lib.runtime_setting_value "tungsten-ore-frequency"

        storage.hex_grid.resource_weighted_choice.vulcanus = {}
        storage.hex_grid.resource_weighted_choice.vulcanus.resources = weighted_choice.new {
            ["coal"] = mgs_original.autoplace_controls.vulcanus_coal.size * coal_frequency,
            ["calcite"] = mgs_original.autoplace_controls.calcite.size * calcite_frequency,
            ["tungsten-ore"] = mgs_original.autoplace_controls.tungsten_ore.size * tungsten_ore_frequency,
        }
        storage.hex_grid.resource_weighted_choice.vulcanus.wells = weighted_choice.new {
            ["sulfuric-acid-geyser"] = 1,
        }

        -- Resource randomization in starting hex
        storage.hex_grid.resource_weighted_choice.vulcanus.starting = weighted_choice.copy(storage.hex_grid.resource_weighted_choice.vulcanus.resources)
        weighted_choice.set_weight(storage.hex_grid.resource_weighted_choice.vulcanus.starting, "tungsten-ore", 0)

        -- Resource randomization without tungsten
        storage.hex_grid.resource_weighted_choice.vulcanus.non_tungsten = weighted_choice.copy(storage.hex_grid.resource_weighted_choice.vulcanus.starting)
    elseif surface.name == "fulgora" then
        local mgs = surface.map_gen_settings
        mgs.autoplace_controls.scrap.size = 0
        mgs.autoplace_controls.fulgora_islands.size = 0
        mgs.autoplace_controls.fulgora_cliff.size = 0
        mgs.autoplace_settings.tile.settings["oil-ocean-shallow"].size = 0
        mgs.autoplace_settings.tile.settings["oil-ocean-deep"].size = 0
        surface.map_gen_settings = mgs

        storage.hex_grid.resource_weighted_choice.fulgora = {}
        storage.hex_grid.resource_weighted_choice.fulgora.resources = weighted_choice.new {
            ["scrap"] = 1,
        }
    elseif surface.name == "gleba" then
        local mgs = surface.map_gen_settings
        -- log(serpent.block(mgs))
        mgs.autoplace_controls.gleba_stone.size = 0
        mgs.autoplace_controls.gleba_water.size = 0
        mgs.autoplace_controls.gleba_plants.size = 6
        mgs.autoplace_controls.gleba_plants.frequency = 1/6
        mgs.autoplace_controls.gleba_plants.size = 6
        mgs.autoplace_controls.gleba_plants.richness = 6
        mgs.autoplace_settings.tile.settings["gleba-deep-lake"].size = 0
        -- mgs.autoplace_settings.tile.settings["gleba-deep-lake"].frequency = 0
        -- mgs.autoplace_settings.tile.settings["gleba-deep-lake"].richness = 0
        surface.map_gen_settings = mgs

        storage.hex_grid.resource_weighted_choice.gleba = {}
        storage.hex_grid.resource_weighted_choice.gleba.resources = weighted_choice.new {
            ["stone"] = 1,
        }
    elseif surface.name == "aquilo" then
        local mgs = surface.map_gen_settings
        mgs.autoplace_controls.aquilo_crude_oil.size = 0
        mgs.autoplace_controls.lithium_brine.size = 0
        mgs.autoplace_controls.fluorine_vent.size = 0
        mgs.autoplace_settings.tile.settings["ammoniacal-ocean"].size = 0
        mgs.autoplace_settings.tile.settings["ammoniacal-ocean-2"].size = 0
        mgs.autoplace_settings.tile.settings["brash-ice"].size = 0
        surface.map_gen_settings = mgs

        local crude_oil_frequency = lib.runtime_setting_value "aquilo-crude-oil-frequency"
        local lithium_brine_frequency = lib.runtime_setting_value "lithium-brine-frequency"
        local fluorine_vent_frequency = lib.runtime_setting_value "fluorine-vent-frequency"

        storage.hex_grid.resource_weighted_choice.aquilo = {}
        storage.hex_grid.resource_weighted_choice.aquilo.wells = weighted_choice.new {
            ["crude-oil"] = mgs_original.autoplace_controls.aquilo_crude_oil.size * crude_oil_frequency,
            ["lithium-brine"] = mgs_original.autoplace_controls.lithium_brine.size * lithium_brine_frequency,
            ["fluorine-vent"] = mgs_original.autoplace_controls.fluorine_vent.size * fluorine_vent_frequency,
        }
    else
        unknown = true
    end

    if not unknown then
        event_system.trigger("surface-created", surface)
    end

    if storage.item_values.values[surface.name] then
        local num_trades = lib.runtime_setting_value "rank-3-effect" --[[@as int]]
        trades.generate_interplanetary_trade_locations(surface.name, num_trades)
    end
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    local setting = event.setting:sub(10)
    if event.setting_type == "runtime-per-user" then
        event_system.trigger("runtime-setting-changed-" .. setting, event.player_index)
    else
        event_system.trigger("runtime-setting-changed-" .. setting)
    end
end)

script.on_configuration_changed(function(handler)

    local changes = handler.mod_changes.hextorio
    if changes and changes.old_version ~= changes.new_version then
        migrations.on_mod_updated(changes.old_version, changes.new_version)
    end

    for _, player in pairs(game.players) do
        player.gui.relative.clear()
        gui.init_hex_core(player)
    end
end)
