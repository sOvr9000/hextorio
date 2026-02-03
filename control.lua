
require "util" -- For table.deepcopy()
require "remotes"

local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local coin_tiers = require "api.coin_tiers"
local gui = require "api.gui"
local initialization = require "api.initialization"
local sets = require "api.sets"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local event_system= require "api.event_system"
local migrations = require "api.migrations"
local trades = require "api.trades"
local item_ranks = require "api.item_ranks"
local item_buffs = require "api.item_buffs"
local quests = require "api.quests"
local blueprints = require "api.blueprints"
local space_platforms = require "api.space_platforms"
local loot_tables = require "api.loot_tables"
local dungeons = require "api.dungeons"
-- local spiders = require "api.spiders"
local hex_island = require "api.hex_island"
local train_trading = require "api.train_trading"
local inventories = require "api.inventories"
local strongboxes = require "api.strongboxes"
local piggy_bank = require "api.piggy_bank"
local passive_coin_buff = require "api.passive_coin_buff"
local hex_rank = require "api.hex_rank"
local gameplay_statistics = require "api.gameplay_statistics"
local gsr = require "api.gameplay_statistics_recalculators"

migrations.load_handlers()

item_values.register_events()
hex_grid.register_events()
trades.register_events()
item_ranks.register_events()
item_buffs.register_events()
quests.register_events()
dungeons.register_events()
-- spiders.register_events()
hex_island.register_events()
space_platforms.register_events()
train_trading.register_events()
strongboxes.register_events()
inventories.register_events()
hex_rank.register_events()
gameplay_statistics.register_events()
gsr.register_events()

gui.register_events()
event_system.bind_gui_events()

require "commands"
require "handle_keybinds"
require "handle_selections"
require "handle_coin_splitting"

local data_constants = require "data.constants"
local data_initialization = require "data.initialization"
local data_item_values = require "data.item_values"
local data_hex_grid = require "data.hex_grid"
local data_coin_tiers = require "data.coin_tiers"
local data_trades = require "data.trades"
local data_quests = require "data.quests"
local data_item_ranks = require "data.item_ranks"
local data_trade_overview = require "data.trade_overview"
local data_blueprints = require "data.blueprints"
local data_dungeons = require "data.dungeons"
-- local data_spiders = require "data.spiders"
local data_hex_island = require "data.hex_island"
local data_item_buffs = require "data.item_buffs"
local data_strongboxes = require "data.strongboxes"



local function attempt_initialization()
    if #game.players == 0 then return end
    if not storage.initialization.is_temp_surface_ready then return end
    if storage.initialization.is_nauvis_generating then return end
    initialization.on_nauvis_generating()
end



script.on_init(function()
    storage.cached = {} -- For reusing results from expensive function calls like geometric calculations between axial and rectangular coordinate systems.
    storage.cooldowns = {} -- Player-specific cooldowns for various operations like performance-impacting commands (such as /simple-trade-loops)

    storage.constants = data_constants
    storage.initialization = data_initialization
    storage.item_values = data_item_values
    storage.hex_grid = data_hex_grid
    storage.coin_tiers = data_coin_tiers
    storage.trades = data_trades
    storage.quests = data_quests
    storage.item_ranks = data_item_ranks
    storage.trade_overview = data_trade_overview
    storage.blueprints = data_blueprints
    storage.dungeons = data_dungeons
    -- storage.spiders = data_spiders
    storage.hex_island = data_hex_island
    storage.item_buffs = data_item_buffs
    storage.strongboxes = data_strongboxes

    hex_grid.update_hexlight_default_colors()
    hex_grid.fetch_claim_cost_multiplier_settings()
    trades.fetch_base_trade_productivity_settings()
    trades.fetch_base_trade_efficiency_settings()

    local penalty = lib.runtime_setting_value "unresearched-penalty"
    ---@cast penalty number

    storage.trades.unresearched_penalty = penalty
    storage.trades.batch_processing_threshold = lib.runtime_setting_value "trade-batching-threshold"
    storage.trades.collection_batch_size = lib.runtime_setting_value "trade-collection-batch-size"
    storage.trades.filtering_batch_size = lib.runtime_setting_value "trade-filtering-batch-size"
    storage.trades.sorting_batch_size = lib.runtime_setting_value "trade-sorting-batch-size"
    trades.recalculate_researched_items()

    storage.hex_grid.pool_size = lib.runtime_setting_value_as_int "hex-pool-size"

    storage.ammo_type_per_entity = {
        ["gun-turret"] = "bullet_type",
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

    coin_tiers.init()
    item_values.init()
    item_ranks.init()
    quests.init()
    trades.init()
    blueprints.init()
    loot_tables.init()
    dungeons.init()
    -- spiders.init()
    hex_island.init()
    train_trading.init()
    strongboxes.init()
    piggy_bank.init()

    -- Disable crash site generation, may be done by other mods anyway.
    if remote.interfaces.freeplay then
        storage.disable_crashsite = remote.call("freeplay", "get_disable_crashsite")
        storage.skip_intro = remote.call("freeplay", "get_skip_intro")

        remote.call("freeplay", "set_disable_crashsite", true)
        remote.call("freeplay", "set_skip_intro", true)
    end

    storage.item_ranks.bronze_rank_bonus_effect = lib.runtime_setting_value "rank-2-effect"

    local num_trades = lib.runtime_setting_value "rank-3-effect" --[[@as int]]
    trades.generate_interplanetary_trade_locations("nauvis", num_trades)

    -- Set enemy force color.
    game.forces.enemy.custom_color = {0.6, 0.1, 0.6}

    -- Testing lib functions
    -- for _, t in pairs {
    --     {0.427, 1000, 1000},
    --     {0.429, 1000, 1000},
    --     {0.6180339887},
    --     {0.6180339887, 128, 128},
    --     {0.25, 5000, 5000},
    -- } do
    --     local num, den = lib.get_rational_approximation(t[1], 1.0001, t[2], t[3])
    --     log(t[1] .. " = " .. num .. " / " .. den)
    -- end
end)

script.on_event(defines.events.on_chunk_generated, function(event)
    local surface = event.surface
    local chunk_position = event.position

    if surface.name == "hextorio-temp" then
        if chunk_position.x == 0 and chunk_position.y == 0 then
            storage.initialization.is_temp_surface_ready = true
            attempt_initialization()
            return
        end
    end

    if surface.name == "nauvis" then
        if chunk_position.x == 0 and chunk_position.y == 0 then
            if storage.initialization.is_nauvis_generating then
                initialization.on_nauvis_generated()
                return
            end
        end
    end

    if lib.is_space_platform(surface) then return end
    if surface.name == "hextorio-temp" then return end
    if storage.initialization.is_nauvis_generating then return end

    hex_grid.on_chunk_generated(surface.name, chunk_position)
end)

script.on_nth_tick(60 * 30, function()
    passive_coin_buff.process_accumulation()
end)

script.on_nth_tick(300, function()
    event_system.trigger "dynamic-stats-updating"
    event_system.trigger "dungeon-update"
end)

script.on_nth_tick(60, function()
    -- The nil character issue is really hard to fix "correctly".  This is a surefire way to do it.
    if not storage.initialization.has_game_started or storage.initialization.stop_checking_nil_character then return end
    local all = true
    for _, player in pairs(game.connected_players) do
        if not player.character then
            player.create_character()
            all = false
        end
    end
    if all then
        storage.initialization.stop_checking_nil_character = true
    end
end)

script.on_nth_tick(20, function()
    hex_grid.process_claim_queue()
end)

script.on_event(defines.events.on_tick, function (event)
    if reinit_guis then
        -- There's likely a better way to handle this.
        lib.log("Reinitializing GUIs for all players.")
        gui.reinitialize_everything()
        reinit_guis = false
    end

    if storage.initialization.has_game_started and not storage.initialization.intro_finished then
        if event.tick == storage.initialization.game_start_tick + 60 then
            game.print(lib.color_localized_string({"hextorio.intro"}, "yellow", "heading-1"))
            if not lib.is_hextreme_enabled() then
                game.print(lib.color_localized_string({"hextorio.hextreme-disabled"}, "pink", "heading-1"))
            end
            -- if not lib.startup_setting_value "pvp-mode" then
            --     game.print(lib.color_localized_string({"hextorio.try-pvp"}, "orange", "heading-1"))
            -- end
            storage.initialization.intro_finished = true
        end
    end

    hex_grid.process_hex_core_pool()
    dungeons._tick_turret_reload()
    item_buffs._enhance_all_item_buffs_tick()
    item_buffs.process_free_buffs()
    gui.trades._process_trades_scroll_panes()
    trades.process_trade_productivity_updates()
    trades.process_trade_collection_jobs()
    trades.process_trade_filtering_jobs()
    trades.process_trade_sorting_jobs()
    trades.process_trade_export_jobs()
    quests.process_lightning_acceleration()

    if storage.debug_spider then
        if not storage.debug_spider.valid then
            storage.debug_spider = nil
        else
            -- Make it LOUD brutha
            local r = storage.debug_spider.color.r
            local g = storage.debug_spider.color.g
            local b = storage.debug_spider.color.b
            storage.debug_spider.color = {math.sqrt(lib.lerp(r, math.random(), 0.5)), math.sqrt(lib.lerp(g, math.random(), 0.5)), math.sqrt(lib.lerp(b, math.random(), 0.5))}
        end
    end
end)

script.on_event(defines.events.on_player_main_inventory_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local inv = player.get_inventory(defines.inventory.character_main)
    if not inv then return end

    local coin = inventories.normalize_inventory(inv, false)
    if not coin then return end

    event_system.trigger("player-coins-base-value-changed", player, coin_tiers.to_base_value(coin))
end)

script.on_event(defines.events.on_player_trash_inventory_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local inv = player.get_inventory(defines.inventory.character_trash)
    if not inv then return end

    inventories.normalize_inventory(inv, false)
end)

script.on_event(defines.events.on_player_dropped_item_into_entity, function(event)
    local inv = event.entity.get_inventory(defines.inventory.chest)
    if not inv then return end

    inventories.normalize_inventory(inv, false)
end)

script.on_event(defines.events.on_player_respawned, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    lib.unstuck_player(player)
    event_system.trigger("player-respawned", player)
end)

script.on_event(defines.events.on_player_created, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

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
    gameplay_statistics.increment("place-tile", #event.tiles, event.tile.name)
end)

script.on_event(defines.events.on_player_mined_tile, function(event)
    for _, tile in pairs(event.tiles) do
        gameplay_statistics.increment("place-tile", -1, tile.old_tile.name)
    end
end)

script.on_event(defines.events.on_robot_built_tile, function(event)
    gameplay_statistics.increment("place-tile", #event.tiles, event.tile.name)
end)

script.on_event(defines.events.on_robot_mined_tile, function(event)
    for _, tile in pairs(event.tiles) do
        gameplay_statistics.increment("place-tile", -1, tile.old_tile.name)
    end
end)

script.on_event(defines.events.on_player_changed_position, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if game.tick > 1000 and not lib.player_is_in_remote_view(player) and lib.is_player_cooldown_ready(player.index, "scan-chunks") then
        player.surface.request_to_generate_chunks(player.position, storage.hex_grid.chunk_generation_range_per_player)
        lib.trigger_player_cooldown(player.index, "scan-chunks", 3 * 60)
    end
end)

script.on_event(defines.events.on_player_rotated_entity, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    event_system.trigger("player-rotated-entity", player, event.entity, event.previous_direction)
end)

script.on_event(defines.events.on_player_used_capsule, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    gameplay_statistics.increment("use-capsule", 1, event.item.name)
    event_system.trigger("player-used-capsule", player, event.item.name)
end)

script.on_event(defines.events.on_entity_settings_pasted, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local source = event.source
    destination = event.destination

    hex_grid.on_entity_settings_pasted(player, source, destination)
end)

script.on_event(defines.events.on_entity_died, function (event)
    event_system.trigger("entity-died", event.entity)

    if event.cause and event.cause.valid and event.entity.valid then
        event_system.trigger("entity-killed-entity", event.entity, event.cause, event.damage_type)
    end
end)

script.on_event(defines.events.on_entity_damaged, function (event)
    if not event.entity.valid then return end

    if event.entity.type == "character" then
        if event.source and event.source.valid then
            if event.source.type == "lightning" then
                event_system.trigger("lightning-struck-character", event.entity)
            end
        end
    end
end)

-- script.on_event(defines.events.on_pre_player_died, function (event)
--     local player = game.get_player(event.player_index)
--     if not player then return end

--     event_system.trigger("pre-player-died", player)
--     if event.cause and event.cause.valid then
--         event_system.trigger("pre-player-died-to-entity", player, event.cause)
--     end
-- end)

script.on_event(defines.events.on_resource_depleted, function (event)
    event_system.trigger("resource-depleted", event.entity)
end)

script.on_event(defines.events.on_rocket_launched, function (event)
    event_system.trigger("rocket-launched", event.rocket, event.rocket_silo)
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

script.on_event(defines.events.on_research_finished, function(event)
    trades.recalculate_researched_items()
    trades.queue_productivity_update_job()
    event_system.trigger("research-completed", event.research)
end)

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
    local setting = event.setting:sub(10)
    if event.setting_type == "runtime-per-user" then
        event_system.trigger("runtime-setting-changed-" .. setting, event.player_index)
    else
        event_system.trigger("runtime-setting-changed-" .. setting)
    end
end)

script.on_event(defines.events.on_player_display_scale_changed, function(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    event_system.trigger("player-display-scaled-changed", player)
end)

script.on_configuration_changed(function(handler)
    local changes = handler.mod_changes.hextorio
    if changes and changes.old_version ~= changes.new_version then
        migrations.on_mod_updated(changes.old_version, changes.new_version)
    end
end)
