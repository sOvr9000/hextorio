
local item_tradability_solver = require "api.item_tradability_solver"
local trades = require "api.trades"

return function()
    item_tradability_solver.solve()
    trades.queue_productivity_update_job()
end
