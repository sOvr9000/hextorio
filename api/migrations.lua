
local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local gui = require "api.gui"

local data_item_ranks = require "data.item_ranks"
local data_trade_overview = require "data.trade_overview"

local migrations = {}



function migrations.on_mod_updated(old_version, new_version)
    log("old version: " .. old_version .. ", new version: " .. new_version)
    if old_version == "0.0.1" then
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

    elseif old_version == "0.1.0" then
        storage.item_values.values.nauvis["uranium-ore"] = 10
    elseif old_version == "0.1.1" then
        storage.trade_overview = data_trade_overview
    elseif old_version == "0.1.2" then
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
    elseif old_version == "0.1.3" then
    elseif old_version == "0.1.4" then
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
    end

    -- Reinitialize GUIs
    for _, player in pairs(game.players) do
        gui.reinitialize_everything(player)
    end
end



return migrations


