
local trades = require "api.trades"

return function()
    for _, trade in pairs(trades.get_all_trades(true)) do
        local total = trades.get_estimated_total_batches_processed(trade)
        if total > 0 then
            trade.total_batches_processed = total
        end
    end
end
