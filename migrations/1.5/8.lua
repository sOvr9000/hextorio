
local item_buffs = require "api.item_buffs"
local piggy_bank = require "api.piggy_bank"

local data_item_buffs = require "data.item_buffs"

return function()
    storage.coin_tiers.skip_processing = {}
    piggy_bank.init()

    item_buffs.migrate_buff_changes(data_item_buffs)
end
