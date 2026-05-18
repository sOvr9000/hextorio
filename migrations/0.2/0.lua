
local data_quests = require "data.quests"
local data_trade_overview = require "data.trade_overview"

return function()
    storage.quests = data_quests
    storage.trade_overview = data_trade_overview
end
