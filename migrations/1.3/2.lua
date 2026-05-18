
local item_buffs = require "api.item_buffs"

local data_item_buffs = require "data.item_buffs"

return function()
    storage.item_buffs.passive_coins_rate = 0

    item_buffs.migrate_buff_changes(data_item_buffs)
end
