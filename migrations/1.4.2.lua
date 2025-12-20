
local lib = require "api.lib"

return function()
    storage.trades.batch_processing_threshold = lib.runtime_setting_value "trade-batching-threshold"
    storage.trades.collection_batch_size = lib.runtime_setting_value "trade-collection-batch-size"
    storage.trades.filtering_batch_size = lib.runtime_setting_value "trade-filtering-batch-size"
    storage.trades.sorting_batch_size = lib.runtime_setting_value "trade-sorting-batch-size"
    storage.hex_grid.pool_size = lib.runtime_setting_value "hex-pool-size"
end
