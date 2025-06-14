
local lib = require "api.lib"
local axial = require "api.axial"
local terrain = require "api.terrain"
local sets = require "api.sets"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local gui = require "api.gui"
local quests = require "api.quests"
local weighted_choice = require "api.weighted_choice"
local blueprints = require "api.blueprints"
local loot_tables = require "api.loot_tables"
local dungeons = require "api.dungeons"
local spiders = require "api.spiders"

local data_item_ranks = require "data.item_ranks"
local data_trade_overview = require "data.trade_overview"
local data_item_values = require "data.item_values"
local data_quests = require "data.quests"
local data_blueprints = require "data.blueprints"
local data_trades = require "data.trades"
local data_hex_grid = require "data.hex_grid"
local data_dungeons = require "data.dungeons"
local data_spiders = require "data.spiders"

local migrations = {}



local versions = {
    "0.0.1",
    "0.1.0",
    "0.1.1",
    "0.1.2",
    "0.1.3",
    "0.1.4",
    "0.1.5",
    "0.2.0",
    "0.2.1",
    "0.2.2",
    "0.2.3",
    "0.3.0",
    "0.3.1",
    "0.3.2",
    "0.4.0",
    "0.4.1",
    "0.4.2",
    "0.4.3",
    "1.0.0",
    "1.0.1",
}

local version_stepping = {}
for i = 1, #versions - 1 do
    version_stepping[versions[i]] = versions[i + 1]
end

local process_migration = {
    ["0.0.1"] = function()
        storage.trades.discovered_items = {}
        storage.trades.total_items_traded = {}
        storage.trades.total_items_bought = {}
        storage.trades.total_items_sold = {}

        storage.item_ranks = data_item_ranks

        for _, state in pairs(hex_grid.get_flattened_surface_hexes(game.surfaces.nauvis)) do
            state.hex_core_output_inventory = state.hex_core_input_inventory
            if state.trades then
                if state.claimed then
                    trades.discover_items_in_trades(state.trades)
                end
                for _, trade in pairs(state.trades) do
                    trade.surface_name = "nauvis"
                    trade.active = true
                end
                state.trades_original = trades.copy(state.trades)
            end
        end

        local surface_hexes = hex_grid.get_surface_hexes(game.surfaces.nauvis)
        local state = surface_hexes[0][0]
        table.insert(storage.trades.starting_trades, {{"low-density-structure"}, {"hex-coin"}})
        local trade = trades.from_item_names("nauvis", {"low-density-structure"}, {"hex-coin"})
        -- lib.log(serpent.block(trade))
        hex_grid.add_trade(state, trade)

        for _, state in pairs(hex_grid.get_flattened_surface_hexes(game.surfaces.nauvis)) do
            if state.hex_core then
                state.output_loader = game.surfaces.nauvis.find_entity("hex-core-loader", {x=state.hex_core.position.x+1, y=state.hex_core.position.y+2})
                state.output_loader.loader_filter_mode = "whitelist"
                hex_grid.update_hex_core_inventory_filters(state)
                hex_grid.update_loader_filters(state)
            end
        end
    end,
    ["0.1.0"] = function()
        storage.item_values.values.nauvis["uranium-ore"] = 10
    end,
    ["0.1.1"] = function()
        storage.trade_overview = data_trade_overview
    end,
    ["0.1.2"] = function()
        table.insert(storage.trades.starting_trades, {{"copper-cable", "boiler"}, {"wood", "raw-fish"}})
        local trade = trades.from_item_names("nauvis", {"copper-cable", "boiler"}, {"wood", "raw-fish"})
        local starter_hex_state = hex_grid.get_hex_state("nauvis", {q=0, r=0})
        hex_grid.remove_trade_by_index(starter_hex_state, 4)
        hex_grid.add_trade(starter_hex_state, trade)

        -- Revert trades to original
        for _, state in pairs(hex_grid.get_flattened_surface_hexes(game.surfaces.nauvis)) do
            if state.trades and state.trades_original then
                for _, trade in pairs(state.trades) do
                    trade.trades = trade.trades_original
                    trade.trades_original = nil
                end
            end
        end

        storage.item_values.values.nauvis["biter-egg"] = 9001

        hex_grid.update_all_trades()
    end,
    ["0.1.3"] = function()

    end,
    ["0.1.4"] = function()
        for item_name, _ in pairs(storage.item_values.values.nauvis) do
            if lib.is_catalog_item(item_name) then
                local rank = item_ranks.get_item_rank(item_name)
                if rank >= 2 then
                    hex_grid.apply_extra_trades_bonus_retro(item_name)
                end
            end
        end

        for _, state in pairs(hex_grid.get_flattened_surface_hexes(game.surfaces.nauvis)) do
            hex_grid.generate_loaders(state)
        end
    end,
    ["0.1.5"] = function()
        storage.quests = data_quests
        storage.trade_overview = data_trade_overview

        -- log(serpent.block(storage.quests))

        -- Reinitialize GUIs
        for _, player in pairs(game.players) do
            gui.reinitialize_everything(player)
        end

        quests.init()

        quests.reveal_quest(quests.get_quest_from_name "ground-zero")
    end,
    ["0.2.0"] = function()
        storage.quests.quest_defs = data_quests.quest_defs -- only copy this over so that quest progress isn't reset
        storage.quests.players_rewarded = {}
        storage.quests.players_quest_selected = {}
        storage.quests.notes_per_reward_type = {
            ["receive-items"] = {"new-players-receive"},
        }
        storage.quests.notes_per_condition_type = {
            ["trades-found"] = {"finding-counts-unclaimed"},
        }
        storage.hex_grid.hex_span = {}

        for _, quest in pairs(storage.quests.quests) do
            quest.order = 0
        end

        quests.reinitialize_everything()
    end,
    ["0.2.1"] = function()
        hex_grid.regenerate_all_hex_core_loaders()
        hex_grid.update_all_trades()
    end,
    ["0.2.2"] = function()
        storage.quests.quest_defs = data_quests.quest_defs -- only copy this over so that quest progress isn't reset
        storage.quests.quests["biter-rammer"].rewards[1].value = 25
        quests.reinitialize_everything()

        for _, quest in pairs(storage.quests.quests) do
            if quest.complete then
                for _, reward in pairs(quest.rewards) do
                    if reward.type == "claim-free-hexes" then
                        hex_grid.add_free_hex_claims(reward.value[1], reward.value[2])
                    end
                end
            end
        end
    end,
    ["0.2.3"] = function()
        storage.item_values.value_multipliers = data_item_values.value_multipliers
        for surface_name, surface_vals in pairs(data_item_values.values) do
            if not storage.item_values.values[surface_name] then
                storage.item_values.values[surface_name] = {}
            end
            lib.update_table(storage.item_values.values[surface_name], surface_vals)
        end

        storage.hex_grid.resource_weighted_choice = {}
        storage.hex_grid.mgs = {}

        local mgs_original = {autoplace_controls = {coal = {frequency = 1, richness = 1, size = 1}, ["copper-ore"] = {frequency = 1, richness = 1, size = 1}, ["crude-oil"] = {frequency = 1, richness = 1, size = 1}, ["enemy-base"] = {frequency = 1, richness = 1, size = 1}, ["iron-ore"] = {frequency = 1, richness = 1, size = 1}, nauvis_cliff = {frequency = 1, richness = 1, size = 1}, rocks = {frequency = 1, richness = 1, size = 1}, starting_area_moisture = {frequency = 1, richness = 1, size = 1}, stone = {frequency = 1, richness = 1, size = 1}, trees = {frequency = 1, richness = 1, size = 1}, ["uranium-ore"] = {frequency = 1, richness = 1, size = 1}, water = {frequency = 1, richness = 1, size = 1}}, autoplace_settings = {decorative = {settings = {["brown-asterisk"] = {frequency = 1, richness = 1, size = 1}, ["brown-asterisk-mini"] = {frequency = 1, richness = 1, size = 1}, ["brown-carpet-grass"] = {frequency = 1, richness = 1, size = 1}, ["brown-fluff"] = {frequency = 1, richness = 1, size = 1}, ["brown-fluff-dry"] = {frequency = 1, richness = 1, size = 1}, ["brown-hairy-grass"] = {frequency = 1, richness = 1, size = 1}, ["cracked-mud-decal"] = {frequency = 1, richness = 1, size = 1}, ["dark-mud-decal"] = {frequency = 1, richness = 1, size = 1}, garballo = {frequency = 1, richness = 1, size = 1}, ["garballo-mini-dry"] = {frequency = 1, richness = 1, size = 1}, ["green-asterisk"] = {frequency = 1, richness = 1, size = 1}, ["green-asterisk-mini"] = {frequency = 1, richness = 1, size = 1}, ["green-bush-mini"] = {frequency = 1, richness = 1, ize = 1}, ["green-carpet-grass"] = {frequency = 1, richness = 1, size = 1}, ["green-croton"] = {frequency = 1, richness = 1, size = 1}, ["green-desert-bush"] = {frequency = 1, richness = 1, size = 1}, ["greegrass"] = {frequency = 1, richness = 1, size = 1}, ["green-pita"] = {frequency = 1, richness = 1, size = 1}, ["green-pita-mini"] = {frequency = 1, richness = 1, size = 1}, ["green-small-grass"] = {frequency = 1, richness = 1, size = 1}, ["light-mud-decal"] = {frequency = 1, richness = 1, size = 1}, ["medium-rock"] = {frequency = 1, richness = 1, size = 1}, ["medium-sand-rock"] = {frequency = 1, richness = 1, size = 1}, ["red-asterisk"] = {frequency = 1, richness = 1, size = 1}, ["red-croton"] = {frequency = 1, richness = 1, size = 1}, ["red-desert-bush"] = {frequency = 1, richness = 1, size = 1}, ["red-desert-decal"] = {frequency = 1, richness = 1, size = 1}, ["red-pita"] = {frequency = 1, richness = 1, size = 1}, ["sand-decal"] = {frequency = 1, richness = 1, size = 1}, ["sand-dune-decal"] = {frequency = 1, richness = 1, size = 1}, ["small-rock"] = {frequency = 1, richness = 1, size = 1}, ["small-sand-rock"] = {frequency = 1, richness = 1, size = 1}, ["tiny-rock"] = {frequency = 1, richness = 1, size = 1}, ["white-desert-bush"] = {frequency = 1, richness = 1, size = 1}}, treat_missing_as_default = true}, entity = {settings = {["big-rock"] = {frequency = 1, richness = 1, size = 1}, ["big-sand-rock"] = {frequency = 1, richness = 1, size = 1}, coal = {frequency = 1, richness = 1, size = 1}, ["copper-ore"] = {frequency = 1, richness = 1, size = 1}, ["crude-oil"] = {frequency = 1, richness = 1, size = 1}, fish = {frequency = 1, richness = 1, size = 1}, ["huge-rock"] = {frequency = 1, richness = 1, size = 1}, ["iron-ore"] = {frequency = 1, richness = 1, size = 1}, stone = {frequency = 1, richness = 1, size = 1}, ["uranium-ore"] = {frequency = 1, richness = 1, size = 1}}, treat_missing_as_default = true}, tile = {settings = {deepwater = {frequency = 1, richness = 1, size = 1}, ["dirt-1"] = {frequency = 1, richness = 1, size = 1}, ["dirt-2"] = {frequency = 1, richness = 1, size = 1}, ["dirt-3"] = {frequency = 1, richness = 1, size = 1}, ["dirt-4"] = {frequency = 1, richness = 1, size = 1}, ["dirt-5"] = {frequency = 1, richness = 1, size = 1}, ["dirt-6"] = {frequency = 1, richness = 1, size = 1}, ["dirt-7"] = {frequency = 1, richness = 1, size = 1}, ["dry-dirt"] = {frequency = 1, richness = 1, size = 1}, ["grass-1"] = {frequency = 1, richness = 1, size = 1}, ["grass-2"] = {frequency = 1, richness = 1, size = 1}, ["grass-3"] = {frequency = 1, richness = 1, size = 1}, ["grass-4"] = {frequency = 1, richness = 1, size = 1}, ["red-desert-0"] = {frequency = 1, richness = 1, size = 1}, ["red-desert-1"] = {frequency = 1, richness = 1, size = 1}, ["red-desert-2"] = {frequency = 1, richness = 1, size = 1}, ["red-desert-3"] = {frequency = 1, richness = 1, size = 1}, ["sand-1"] = {frequency = 1, richness = 1, size = 1}, ["sand-2"] = {frequency = 1, richness = 1, size = 1}, ["sand-3"] = {frequency = 1, richness = 1, size = 1}, water = {frequency = 1, richness = 1, size = 1}}, treat_missing_as_default = true}}, cliff_settings = {cliff_elevation_0 = 10, cliff_elevation_interval = 40, cliff_smoothing = 0, control = "nauvis_cliff", name = "cliff", richness = 1}, default_enable_all_autoplace_controls = false, height = 2000000, no_enemies_mode = false, peaceful_mode = false, property_expression_names = {}, seed = 805764077, starting_area = 1, starting_points = {{x = 0, y = 0}}, width = 2000000}

        storage.hex_grid.mgs.nauvis = mgs_original

        storage.hex_grid.resource_weighted_choice.nauvis = {}
        storage.hex_grid.resource_weighted_choice.nauvis.resources = weighted_choice.new {
            ["iron-ore"] = mgs_original.autoplace_controls["iron-ore"].size * 6,
            ["copper-ore"] = mgs_original.autoplace_controls["copper-ore"].size * 4.5,
            ["coal"] = mgs_original.autoplace_controls["coal"].size * 2.5,
            ["stone"] = mgs_original.autoplace_controls["stone"].size * 2,
        }
        storage.hex_grid.resource_weighted_choice.nauvis.wells = weighted_choice.new {
            ["crude-oil"] = 1,
        }
        storage.hex_grid.resource_weighted_choice.nauvis.uranium = weighted_choice.new {
            ["uranium-ore"] = 1,
        }

        storage.blueprints = data_blueprints
        blueprints.init()

        storage.trades.starting_trades = data_trades.starting_trades

        for surface_id, _ in pairs(game.surfaces) do
            for _, state in pairs(hex_grid.get_flattened_surface_hexes(surface_id)) do
                if state.trades then
                    local params
                    if state.mode == "generator" or state.mode == "sink" then
                        params = {target_efficiency = 0.1}
                    end
                    local new_trades = {}
                    for i = #state.trades, 1, -1 do
                        local trade = state.trades[i]
                        local input_names, output_names = trades.get_input_output_item_names_of_trade(trade)
                        local volume = trades.get_volume_of_trade(trade.surface_name, trade)
                        trades._check_coin_names_for_volume(input_names, volume)
                        trades._check_coin_names_for_volume(output_names, volume)
                        hex_grid.remove_trade_by_index(state, i)
                        local new_trade = trades.from_item_names(trade.surface_name, input_names, output_names, params)
                        new_trade.active = trade.active
                        table.insert(new_trades, new_trade)
                        -- trades.set_productivity(new_trade, trades.get_productivity(trade))
                        trades.set_current_prod_value(new_trade, trades.get_current_prod_value(trade))
                    end
                    for _, new_trade in pairs(new_trades) do
                        hex_grid.add_trade(state, new_trade)
                    end
                end
            end
        end

        hex_grid.update_all_trades()
        game.forces.player.technologies["planet-discovery-vulcanus"].enabled = true
    end,
    ["0.3.0"] = function()
        game.forces.player.technologies["planet-discovery-vulcanus"].enabled = true

        for _, tab_name in pairs {"by_input", "by_output"} do
            local new_table = {}
            for item_name, trade_ids in pairs(storage.trades.tree[tab_name]) do
                new_table[item_name] = {}
                for _, trade_id in pairs(trade_ids) do
                    new_table[item_name][trade_id] = true
                end
            end
            storage.trades.tree[tab_name] = new_table
        end
    end,
    ["0.3.1"] = function()
        game.forces.player.technologies["planet-discovery-fulgora"].enabled = true
        storage.trades.starting_trades.fulgora = data_trades.starting_trades.fulgora
        storage.item_values.values.vulcanus = data_item_values.values.vulcanus -- fixes crude oil barrel bug
        storage.item_values.values.fulgora = data_item_values.values.fulgora
        storage.hex_grid.pool_size = 50
    end,
    ["0.3.2"] = function()
        game.forces.player.technologies["planet-discovery-gleba"].enabled = true
        storage.trades.starting_trades.gleba = data_trades.starting_trades.gleba
        storage.item_values.values = data_item_values.values
        storage.quests.quest_defs = data_quests.quest_defs
        quests.reinitialize_everything()
    end,
    ["0.4.0"] = function()
        storage.hex_grid.gleba_ignore_tiles = data_hex_grid.gleba_ignore_tiles
    end,
    ["0.4.1"] = function()
        storage.hex_grid.gleba_ignore_tiles = data_hex_grid.gleba_ignore_tiles
        storage.quests.quest_defs = data_quests.quest_defs -- only copy this over so that quest progress isn't reset
        storage.quests.quest_ids_by_name = {}
        storage.quests.quests_by_condition_type = {}

        local quest_id = 0
        local quest_names = sets.to_array(storage.quests.quests)
        for _, quest_name in pairs(quest_names) do
            local quest = storage.quests.quests[quest_name]
            quest_id = quest_id + 1
            storage.quests.quest_ids_by_name[quest_name] = quest_id
            storage.quests.quests[quest_name] = nil
            storage.quests.quests[quest_id] = quest
            quest.id = quest_id
            quests.index_by_condition_types(quest)
        end

        for _, player in pairs(game.players) do
            gui.reinitialize_everything(player)
        end
        quests.reinitialize_everything()

        for _, surface_name in pairs {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"} do
            if game.get_surface(surface_name) then
                trades.generate_interplanetary_trade_locations(surface_name)
            end
        end

        for _, trade in pairs(trades.get_all_trades(false)) do
            local cpv = trade.current_prod_value --[[@as number]]
            trade.current_prod_value = {}
            for _, q in pairs(prototypes.quality) do
                if q.name == "normal" then
                    trade.current_prod_value[q.name] = cpv
                else
                    trade.current_prod_value[q.name] = 0
                end
            end
        end

        for _, pool in pairs(storage.hex_grid.pool) do
            for _, params in pairs(pool) do
                params.hex_pos = {q = params.q, r = params.r}
                params.q = nil
                params.r = nil
            end
        end
        hex_grid.set_pool_size(data_hex_grid.pool_size)
    end,
    ["0.4.2"] = function()
        storage.cached = {}
        storage.hex_grid.chunk_generation_range_per_player = data_hex_grid.chunk_generation_range_per_player
        storage.item_values.values = data_item_values.values
        quests.reinitialize_everything()

        storage.dungeons = data_dungeons
        loot_tables.init()
        dungeons.init()
    end,
    ["0.4.3"] = function()
        storage.spiders = data_spiders
        spiders.register_events()
        spiders.init()
        spiders.reindex_spiders()
    end,
    ["1.0.0"] = function()
        storage.quests.quest_defs = data_quests.quest_defs
        quests.reinitialize_everything()

        -- Add ore entities to states
        for _, surface in pairs(game.surfaces) do
            local transformation = terrain.get_surface_transformation(surface)
            local ore_entities = surface.find_entities_filtered {type = "resource"}
            for _, e in pairs(ore_entities) do
                local hex_pos = axial.get_hex_containing(e.position, transformation.scale, transformation.rotation)
                local state = hex_grid.get_hex_state(surface.index, hex_pos)
                if state then
                    if not state.ore_entities then state.ore_entities = {} end
                    table.insert(state.ore_entities, e)
                end
            end
        end
    end,
}

function migrations.on_mod_updated(old_version, new_version)
    lib.log("Checking migration for version " .. old_version .. " -> " .. new_version)
    local latest = versions[#versions]
    while true do
        if not old_version or old_version == latest or old_version == new_version then
            lib.log("migrated to " .. old_version)
            break
        end
        local func = process_migration[old_version]
        if not func then
            error("missing migration for " .. old_version .. " -> " .. version_stepping[old_version])
        end
        lib.log("migrating " .. old_version .. " -> " .. version_stepping[old_version])
        func()
        old_version = version_stepping[old_version]
    end

    -- Reinitialize GUIs
    for _, player in pairs(game.players) do
        gui.reinitialize_everything(player)
    end
end



return migrations


