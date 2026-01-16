
local trades = require "api.trades"
local hex_grid = require "api.hex_grid"
local coin_tiers = require "api.coin_tiers"
local item_values = require "api.item_values"
local hex_state_manager = require "api.hex_state_manager"

local data_coin_tiers = require "data.coin_tiers"

return function()
    trades.fetch_base_trade_efficiency_settings()
    hex_grid.fetch_claim_cost_multiplier_settings()

    storage.coin_tiers.COIN_NAMES = data_coin_tiers.COIN_NAMES
    storage.coin_tiers.TIER_SCALING = data_coin_tiers.TIER_SCALING

    coin_tiers.init()

    for surface_name, _ in pairs(storage.item_values.values) do
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
            if state.claim_price then
                state.claim_price = coin_tiers.migrate_coin(state.claim_price)
            end
            if state.total_coins_consumed then
                state.total_coins_consumed = coin_tiers.migrate_coin(state.total_coins_consumed)
            end
            if state.total_coins_produced then
                state.total_coins_produced = coin_tiers.migrate_coin(state.total_coins_produced)
            end
        end
    end
end
