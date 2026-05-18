
local gameplay_statistics = require "api.gameplay_statistics"

return function()
    if not storage.trades.uniquely_traded_items then
        storage.trades.uniquely_traded_items = {}
    else
        for item_name, _ in pairs(storage.trades.uniquely_traded_items) do
            if type(item_name) == "string" then
                storage.trades.uniquely_traded_items[item_name] = nil
            end
        end
    end
    gameplay_statistics.set("total-unique-items-traded", 0)
end
