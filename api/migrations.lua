
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local gui = require "api.gui"
local quests = require "api.quests"

local data_item_ranks = require "data.item_ranks"
local data_trade_overview = require "data.trade_overview"
local data_quests = require "data.quests"

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
                state.trades_original = trades.copy_trade(state.trades)
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
        hex_grid.remove_trade(starter_hex_state, 4)
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

        quests.reveal_quest(quests.get_quest "ground-zero")
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

        -- for _, player in pairs(game.players) do
        --     gui.repopulate_quest_lists(player)
        -- end
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


