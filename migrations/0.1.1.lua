
local data_trade_overview = require "data.trade_overview"

return function()
    storage.trade_overview = data_trade_overview
end
