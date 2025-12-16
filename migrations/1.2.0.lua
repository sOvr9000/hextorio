
local lib = require "api.lib"
local trades = require "api.trades"
local quests = require "api.quests"
local hex_grid = require "api.hex_grid"
local hex_state_manager = require "api.hex_state_manager"
local dungeons = require "api.dungeons"
local coin_tiers = require "api.coin_tiers"

local data_trades = require "data.trades"

return function()
    storage.cooldowns = {}
    storage.dungeons.min_dist = lib.runtime_setting_value "dungeon-min-dist"
    storage.dungeons.queued_reloads = {}
    storage.dungeons.queued_reload_dungeon_indices = {}
    storage.trades.surrounding_trades = data_trades.surrounding_trades
    storage.trades.guaranteed_trades = {}
    storage.hex_grid.show_trade_flying_text = {}
    hex_grid.update_hexlight_default_colors()

    storage.item_ranks.productivity_requirements = {
        [2] = 0.3, -- Bronze -> Silver
        [3] = 0.7, -- Silver -> Gold
        [4] = 1.2 -- Gold -> Red
    }

    storage.ammo_type_per_entity = {
        ["dungeon-gun-turret"] = "bullet_type",
        ["dungeon-flamethrower-turret"] = "flamethrower_type",
        ["dungeon-rocket-turret"] = "rocket_type",
        ["dungeon-railgun-turret"] = "railgun_type",
    }

    if quests.is_complete "catalog-initiate" then
        storage.trades.base_productivity = storage.trades.base_productivity - 0.05
    end

    for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_id)) do
            -- Fix dungeon claim bug
            if state.is_dungeon then
                if not dungeons.get_dungeon_at_hex_pos(surface_id, state.position, false) then
                    state.is_dungeon = nil
                end
            end
            -- Re-center hexports
            if state.hexport then
                hex_grid.spawn_hexport(state) -- Replaces existing
            end
            -- Add hexlights
            hex_grid.spawn_hexlight(state)
        end
    end

    -- Add flags to trades
    for _, trade in pairs(storage.trades.tree.all_trades_lookup) do
        local input_coins = trades.get_input_coins_of_trade(trade)
        if not coin_tiers.is_zero(input_coins) then
            trade.has_coins_in_input = true
        end

        local output_coins = trades.get_output_coins_of_trade(trade)
        if not coin_tiers.is_zero(output_coins) then
            trade.has_coins_in_output = true
        end
    end

    quests.unlock_feature "trade-configuration"
    hex_grid.update_all_trades()
end