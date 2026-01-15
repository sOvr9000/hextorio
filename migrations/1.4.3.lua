
local trades = require "api.trades"
local hex_grid = require "api.hex_grid"

return function()
    trades.fetch_base_trade_efficiency_settings()
    hex_grid.fetch_claim_cost_multiplier_settings()
end
