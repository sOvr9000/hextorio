
local trade_generator = require "api.trade_generator"

local data_trades = require "data.trades"

return function()
    storage.trades.trade_shape_weights_lookup = data_trades.trade_shape_weights_lookup
    trade_generator.init()
end
