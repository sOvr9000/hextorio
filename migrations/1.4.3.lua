
local trades = require "api.trades"

return function()
    trades.fetch_base_trade_efficiency_settings()
end
