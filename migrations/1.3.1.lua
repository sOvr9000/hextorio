
local item_buffs = require "api.item_buffs"

local data_item_buffs = require "data.item_buffs"

return function()
    item_buffs.migrate_buff_changes(data_item_buffs.item_buffs)

    storage.item_buffs.item_buffs = data_item_buffs.item_buffs
    storage.item_buffs.has_description = data_item_buffs.has_description
    storage.item_buffs.passive_coins_rate = 0
end
