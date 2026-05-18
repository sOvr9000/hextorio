
local item_buffs = require "api.item_buffs"

local data_item_buffs = require "data.item_buffs"

return function()
    storage.item_buffs.train_trading_capacity = data_item_buffs.train_trading_capacity

    item_buffs.migrate_buff_changes(data_item_buffs)
end
