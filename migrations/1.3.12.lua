
local hex_state_manager = require "api.hex_state_manager"
local lib               = require "api.lib"
local trades            = require "api.trades"

return function()
    storage.trades.productivity_update_jobs = {}
    storage.trades.trade_collection_jobs = {}
    storage.trades.trade_filtering_jobs = {}
    storage.trades.researched_items = {}
    storage.hex_grid.flattened_surface_hexes = {}

    storage.item_ranks.bronze_rank_bonus_effect = lib.runtime_setting_value "rank-2-effect"

    local penalty = lib.runtime_setting_value "unresearched-penalty"
    ---@cast penalty number

    storage.trades.unresearched_penalty = penalty

    -- Index all existing hexes
    for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
        local flattened_surface_hexes = {}

        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_id)) do
            local index = #flattened_surface_hexes+1
            state.flat_index = index
            flattened_surface_hexes[index] = state.position
        end

        storage.hex_grid.flattened_surface_hexes[surface_id] = flattened_surface_hexes
    end

    trades.queue_productivity_update_job()
end
