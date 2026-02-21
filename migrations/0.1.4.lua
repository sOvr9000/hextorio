
local lib = require "api.lib"
local item_ranks = require "api.item_ranks"
local hex_grid = require "api.hex_grid"
local hex_state_manager = require "api.hex_state_manager"

return function()
    for item_name, _ in pairs(storage.item_values.values.nauvis) do
        if lib.is_catalog_item("nauvis", item_name) then
            local rank = item_ranks.get_item_rank(item_name)
            if rank >= 2 then
                hex_grid.apply_extra_trades_bonus_retro(item_name)
            end
        end
    end

    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(game.surfaces.nauvis)) do
        hex_grid.generate_loaders(state)
    end
end
