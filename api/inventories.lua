
local lib = require "api.lib"
local coin_tiers = require "api.coin_tiers"
local item_values = require "api.item_values"
local item_ranks = require "api.item_ranks"

local inventories = {}



---@param surface_name any
---@param inv LuaInventory|nil
---@return table
function inventories.get_total_coin_value(surface_name, inv, min_rank)
    if not inv then
        error("inventories.get_total_coin_value_in_inventory: inventory is nil")
        return coin_tiers.new()
    end

    if not min_rank then
        min_rank = 1
    end

    local coin = coin_tiers.new()
    for _, item in pairs(inv.get_contents()) do
        if not lib.is_coin(item.name) then
            local rank = item_ranks.get_item_rank(item.name)
            if rank >= min_rank then
                local item_value = item_values.get_item_value(surface_name, item.name, true, item.quality)
                coin = coin_tiers.add(coin, coin_tiers.from_base_value(item_value * item.count))
            end
        end
    end
    coin = coin_tiers.divide(coin, item_values.get_item_value("nauvis", "hex-coin"))

    return coin_tiers.normalized(coin)
end

---@param inv LuaInventory|nil
---@param min_rank int
---@return table
function inventories.remove_items_of_rank(inv, min_rank)
    if not inv then
        error("inventories.remove_items_of_rank: inventory is nil")
        return {}
    end

    local contents = inv.get_contents()
    local removed = {}
    for _, item_stack in pairs(contents) do
        local rank = item_ranks.get_item_rank(item_stack.name)
        if rank >= min_rank then
            local stack = {name = item_stack.name, count = item_stack.count, quality = item_stack.quality}
            table.insert(removed, stack)
            inv.remove(stack)
        end
    end

    return removed
end

---@param cargo_wagons LuaEntity[]
---@param wagon_limit int
---@return Coin, QualityItemCounts
function inventories.get_coins_and_items_on_train(cargo_wagons, wagon_limit)
    local input_coin_values = {}
    local all_items_lookup = {}

    for i, wagon in pairs(cargo_wagons) do
        if i > wagon_limit then break end

        local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
        if inv then
            for _, stack in pairs(inv.get_contents()) do
                if lib.is_coin(stack.name) then
                    input_coin_values[stack.name] = stack.count
                else
                    local quality = stack.quality or "normal"
                    if not all_items_lookup[quality] then
                        all_items_lookup[quality] = {}
                    end
                    all_items_lookup[quality][stack.name] = stack.count
                end
            end
        end
    end

    local input_coin = coin_tiers.normalized(coin_tiers.new(input_coin_values))
    return input_coin, all_items_lookup
end



return inventories
