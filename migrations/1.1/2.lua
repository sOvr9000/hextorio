
local hex_grid = require "api.hex_grid"

return function()
    -- Recalculate trade volume base per planet.
    for surface_name, _ in pairs(storage.trades.trade_volume_base) do
        storage.trades.trade_volume_base[surface_name] = nil -- Triggers recalculating the correct value
        hex_grid.get_trade_volume_base(surface_name) -- Stores a value for above
    end

    storage.item_ranks.productivity_requirements = {
        [2] = 0.1, -- Bronze -> Silver
        [3] = 0.7, -- Silver -> Gold
        [4] = 1.1 -- Gold -> Red
    }
end
