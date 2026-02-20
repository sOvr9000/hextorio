
local item_value_solver = require "api.item_value_solver"
local item_tradability_solver = require "api.item_tradability_solver"
local trades                  = require "api.trades"
local lib                     = require "api.lib"
local hex_grid                = require "api.hex_grid"
local hex_state_manager       = require "api.hex_state_manager"

local data_item_values = require "data.item_values"

return function()
    storage.SUPPORTED_PLANETS = {
        nauvis = true,
        vulcanus = true,
        fulgora = true,
        gleba = true,
        aquilo = true,
    }

    storage.item_values = data_item_values

    game.print("Migrating Hextorio version [color=blue]1.6.11[.color] to [color=blue]1.7.0[.color].  [color=pink]Significant changes have been made.[.color]")
    item_tradability_solver.init()
    item_value_solver.init()

    for _, trade in pairs(trades.get_all_trades(false)) do
        for _, item in pairs(trade.input_items or {}) do
            if not lib.is_coin(item.name) then
                trade.has_items_in_input = true
            end
        end
        for _, item in pairs(trade.output_items or {}) do
            if not lib.is_coin(item.name) then
                trade.has_items_in_output = true
            end
        end
    end

    for _, surface in pairs(game.surfaces) do
        if storage.SUPPORTED_PLANETS[surface.name] then
            for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
                state.claim_price = hex_grid.calculate_hex_claim_price(surface, state.position)
            end
        end
    end
end
