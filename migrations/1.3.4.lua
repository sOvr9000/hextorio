
local hex_grid = require "api.hex_grid"
local train_trading = require "api.train_trading"

return function()
    train_trading.init()

    for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
        for _, state in pairs(hex_grid.get_flattened_surface_hexes(surface_id)) do
            -- Enable this by default.
            state.send_outputs_to_cargo_wagons = true
        end
    end
end
