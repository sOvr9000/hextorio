
local hex_state_manager = require "api.hex_state_manager"
local item_buffs = require "api.item_buffs"

local data_item_buffs = require "data.item_buffs"

return function()
    -- Clean up any hex claim tool accidents.
    for surface_name, _ in pairs(storage.hex_grid.surface_hexes) do
        local surface_hexes = hex_state_manager.get_surface_hexes(surface_name)
        if surface_hexes then
            for _, Q in pairs(surface_hexes) do
                for r, state in pairs(Q) do
                    if state.generated == nil then
                        Q[r] = nil
                    end
                end
            end
        end
    end

    item_buffs.migrate_buff_changes(data_item_buffs)
end
