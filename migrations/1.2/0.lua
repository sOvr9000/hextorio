
local item_values = require "api.item_values"

local data_item_buffs = require "data.item_buffs"

return function()
    storage.item_values.values.gleba.biolab = 8652156.0021070931
    storage.item_values.values.gleba["stack-inserter"] = 315429.67844327178

    storage.item_buffs = data_item_buffs
end
