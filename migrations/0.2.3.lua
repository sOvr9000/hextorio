
local lib = require "api.lib"
local trades = require "api.trades"
local hex_grid = require "api.hex_grid"
local hex_state_manager = require "api.hex_state_manager"
local blueprints = require "api.blueprints"
local weighted_choice = require "api.weighted_choice"

local data_trades = require "data.trades"
local data_blueprints = require "data.blueprints"
local data_item_values = require "data.item_values"

return function()
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
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_id)) do
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
end
