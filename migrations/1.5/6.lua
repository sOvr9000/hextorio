
local item_buffs = require "api.item_buffs"

local data_item_buffs = require "data.item_buffs"

return function()
    item_buffs.migrate_buff_changes(data_item_buffs)
end
