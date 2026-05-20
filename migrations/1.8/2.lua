
local trades = require "api.trades"

return function()
    trades.recalculate_researched_items()
end
