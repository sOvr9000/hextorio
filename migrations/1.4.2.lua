
local lib = require "api.lib"
local item_buffs = require "api.item_buffs"

local data_item_buffs = require "data.item_buffs"

return function()
    storage.trades.batch_processing_threshold = lib.runtime_setting_value "trade-batching-threshold"
    storage.trades.collection_batch_size = lib.runtime_setting_value "trade-collection-batch-size"
    storage.trades.filtering_batch_size = lib.runtime_setting_value "trade-filtering-batch-size"
    storage.trades.sorting_batch_size = lib.runtime_setting_value "trade-sorting-batch-size"
    storage.hex_grid.pool_size = lib.runtime_setting_value "hex-pool-size"

    item_buffs.migrate_buff_changes(data_item_buffs)
end
