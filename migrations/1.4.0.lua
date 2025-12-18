
local trades = require "api.trades"

return function()
    trades.recalculate_researched_items()
    trades.queue_productivity_update_job()
end
