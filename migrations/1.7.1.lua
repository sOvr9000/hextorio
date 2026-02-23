
local lib = require "api.lib"
local quests = require "api.quests"
local coin_tiers = require "api.coin_tiers"
local inventories = require "api.inventories"

return function()
    storage.coin_tiers.TIER_SCALING = 1000

    local coin_names = storage.coin_tiers.COIN_NAMES
    local num_coin_tiers = #coin_names

    local rescaling = {}
    for i = 1, num_coin_tiers do
        rescaling[i] = 100 ^ (i - 1)
    end

    ---@param inv LuaInventory
    ---@param use_piggy_bank boolean
    local function update_inv(inv, use_piggy_bank)
        local cur_coin_values = {}
        for i = 1, num_coin_tiers do
            local coin_name = coin_names[i]
            cur_coin_values[i] = inv.get_item_count(coin_name)
        end
        local cur_coin = coin_tiers.new(cur_coin_values)
        if coin_tiers.is_zero(cur_coin) then return end

        local new_coin_values = {}
        for i = 1, num_coin_tiers do
            new_coin_values[i] = cur_coin.values[i] * rescaling[i]
        end

        local new_coin = coin_tiers.new(new_coin_values)
        new_coin = coin_tiers.normalized(new_coin)

        -- if inv.entity_owner then
        --     log(inv.entity_owner)
        -- end
        -- log(serpent.line(cur_coin))
        -- log(serpent.line(new_coin))

        -- local before = 0
        -- local after = 0
        -- for i = 1, num_coin_tiers do
        --     before = before + cur_coin.values[i] * (100000 ^ (i - 1))
        --     after = after + new_coin.values[i] * (1000 ^ (i - 1))
        -- end
        -- if after ~= before then
        --     error("mismatch, before is not after: " .. before .. " ~= " .. after)
        -- end

        inventories.update_inventory(inv, cur_coin, new_coin, nil, use_piggy_bank)
    end

    for _, surface in pairs(game.surfaces) do
        local entities = surface.find_entities_filtered {type = "container"}
        for _, e in pairs(entities) do
            if e.valid then
                local iterated = {}
                for _, inv_type in pairs(defines.inventory) do
                    local inv = e.get_inventory(inv_type)
                    if inv and inv.valid and not iterated[inv.index or 0] then
                        iterated[inv.index or 0] = true
                        update_inv(inv, false)
                    end
                end
            end
        end
    end

    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    for _, player in pairs(game.players) do
        local inv = lib.get_player_inventory(player)
        if inv and inv.valid then
            update_inv(inv, is_piggy_bank_unlocked)
        end
    end
end
