
local data_trades = require "data.trades"

return function()
    storage.trades.batch_processing_threshold = data_trades.batch_processing_threshold
    storage.trades.collection_batch_size = data_trades.collection_batch_size
    storage.trades.filtering_batch_size = data_trades.filtering_batch_size
    storage.trades.sorting_batch_size = data_trades.sorting_batch_size
end
