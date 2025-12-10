
local data_item_values = require "data.item_values"

return function()
    storage.item_values.values = data_item_values.values
end
