
local lib = require "api.lib"
local coin_tiers = require "api.coin_tiers"
local item_values = require "api.item_values"
local item_ranks = require "api.item_ranks"
local piggy_bank = require "api.piggy_bank"
local event_system = require "api.event_system"

local inventories = {}



function inventories.register_events()
    event_system.register("quest-reward-received", inventories.on_quest_reward_received)
end

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
        if not lib.is_coin(item_stack.name) then
            local rank = item_ranks.get_item_rank(item_stack.name)
            if rank >= min_rank then
                local stack = {name = item_stack.name, count = item_stack.count, quality = item_stack.quality}
                table.insert(removed, stack)
                inv.remove(stack)
            end
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

    for i, wagon in ipairs(cargo_wagons) do
        if i > wagon_limit then break end

        local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
        if inv then
            for _, stack in pairs(inv.get_contents()) do
                if lib.is_coin(stack.name) then
                    input_coin_values[stack.name] = (input_coin_values[stack.name] or 0) + stack.count
                else
                    local quality = stack.quality or "normal"
                    if not all_items_lookup[quality] then
                        all_items_lookup[quality] = {}
                    end
                    all_items_lookup[quality][stack.name] = (all_items_lookup[quality][stack.name] or 0) + stack.count
                end
            end
        end
    end

    local input_coin = coin_tiers.normalized(coin_tiers.from_coin_values_by_name(input_coin_values))
    return input_coin, all_items_lookup
end

---Get a coin object from the given inventory.
---@param inventory LuaInventory|LuaTrain
---@param cargo_wagons LuaEntity[]|nil
---@param use_piggy_bank boolean|nil Whether to use the piggy bank if the inventory belongs to a player.  Defaults to false.
---@return Coin
function inventories.get_coin_from_inventory(inventory, cargo_wagons, use_piggy_bank)
    if cargo_wagons then
        local coin_values = coin_tiers.new_coin_values()
        for i, wagon in ipairs(cargo_wagons) do
            if i > storage.item_buffs.train_trading_capacity then break end

            local values = {}
            for j, coin_name in ipairs(storage.coin_tiers.COIN_NAMES) do
                values[j] = wagon.get_item_count(coin_name)
            end

            coin_tiers.accumulate(coin_values, coin_tiers.new(values))
        end

        return coin_tiers.normalized(coin_tiers.new(coin_values))
    end

    local values = {}
    for j, coin_name in ipairs(storage.coin_tiers.COIN_NAMES) do
        values[j] = inventory.get_item_count(coin_name)
    end

    local coin = coin_tiers.new(values)

    if use_piggy_bank and inventory.object_name == "LuaInventory" then
        local player = lib.get_player_owner_of_inventory(inventory)
        if player then
            local stored_coins = piggy_bank.get_player_stored_coins(player.index)
            coin = coin_tiers.add(coin, stored_coins)
        end
    end

    return coin
end

---Update the inventory contents such that it contains the given coin.
---@param inventory LuaInventory|LuaTrain
---@param current_coin Coin
---@param new_coin Coin
---@param cargo_wagons LuaEntity[]|nil
---@param use_piggy_bank boolean|nil Whether to use the piggy bank if the inventory belongs to a player.  Defaults to false.
function inventories.update_inventory(inventory, current_coin, new_coin, cargo_wagons, use_piggy_bank)
    storage.coin_tiers.is_processing[inventory] = true

    local is_train = inventory.object_name == "LuaTrain"

    if use_piggy_bank and not is_train then
        local player = inventory.player_owner
        if player then
            piggy_bank.set_player_stored_coins(player.index, new_coin)

            for tier = 1, #storage.coin_tiers.COIN_NAMES do
                local coin_name = storage.coin_tiers.COIN_NAMES[tier]
                local count = inventory.get_item_count(coin_name)
                if count > 0 then
                    inventory.remove {name = coin_name, count = count}
                end
            end

            storage.coin_tiers.is_processing[inventory] = nil
            return
        end
    end

    -- List of functions and arguments to be called in a certain order to prevent inventory overflow during the coin value update.  (remove coin items before adding them, when applicable)
    -- The most common case is that no coins are being removed completely from the inventory, so this is only to handle a rare edge case.
    local call_order = {}

    for tier = 1, current_coin.max_coin_tier do
        local coin_name = lib.get_coin_name_of_tier(tier)
        local new_amount = new_coin.values[tier]
        local current_amount = current_coin.values[tier]

        local fn, args
        if new_amount > current_amount then
            if is_train then
                fn = lib.insert_into_train
                args = {cargo_wagons or {}, {name = coin_name, count = new_amount - current_amount}, storage.item_buffs.train_trading_capacity}
            else
                fn = inventory.insert
                args = {{name = coin_name, count = new_amount - current_amount}}
            end
            call_order[#call_order+1] = {fn, args}
        elseif new_amount < current_amount then
            if is_train then
                fn = lib.remove_from_train
                args = {cargo_wagons or {}, {name = coin_name, count = current_amount - new_amount}, storage.item_buffs.train_trading_capacity}
            else
                fn = inventory.remove
                args = {{name = coin_name, count = current_amount - new_amount}}
            end
            table.insert(call_order, 1, {fn, args})
        end
    end

    for _, call in pairs(call_order) do
        call[1](table.unpack(call[2]))
    end

    storage.coin_tiers.is_processing[inventory] = nil
end

-- ---Mark the given inventory as "skipped" for auto-normalization, automatically removing the mark once auto-normalization attempts to change it once.
-- ---@param inventory LuaInventory
-- function inventories.skip_auto_normalization(inventory)
--     storage.coin_tiers.skip_processing[inventory] = true
-- end

---Normalize the inventory, combining multiple stacks of coins into their next tiers.
---@param inventory LuaInventory
---@param use_piggy_bank boolean|nil Whether to use the piggy bank if the inventory belongs to a player.  Defaults to false.
---@return Coin|nil
function inventories.normalize_inventory(inventory, use_piggy_bank)
    if storage.coin_tiers.is_processing[inventory] then return end

    -- if storage.coin_tiers.skip_processing[inventory] then
    --     storage.coin_tiers.skip_processing[inventory] = nil
    --     storage.coin_tiers.is_processing[inventory] = nil
    --     return
    -- end

    storage.coin_tiers.is_processing[inventory] = true

    local coin = inventories.get_coin_from_inventory(inventory, nil, use_piggy_bank)
    local normalized_coin = coin_tiers.normalized(coin)
    inventories.update_inventory(inventory, coin, normalized_coin, nil, use_piggy_bank)
    storage.coin_tiers.is_processing[inventory] = nil

    return normalized_coin
end

---Add coins to the inventory.
---@param inventory LuaInventory|LuaTrain
---@param coin Coin
---@param cargo_wagons LuaEntity[]|nil
---@param use_piggy_bank boolean|nil Whether to use the piggy bank if the inventory belongs to a player.  Defaults to false.
function inventories.add_coin_to_inventory(inventory, coin, cargo_wagons, use_piggy_bank)
    local current_coin = inventories.get_coin_from_inventory(inventory, cargo_wagons, use_piggy_bank)
    local new_coin = coin_tiers.add(current_coin, coin)
    inventories.update_inventory(inventory, current_coin, new_coin, cargo_wagons, use_piggy_bank)
end

---Remove coins from the inventory.
---@param inventory LuaInventory|LuaTrain
---@param coin Coin
---@param cargo_wagons LuaEntity[]|nil
---@param use_piggy_bank boolean|nil Whether to use the piggy bank if the inventory belongs to a player.  Defaults to false.
function inventories.remove_coin_from_inventory(inventory, coin, cargo_wagons, use_piggy_bank)
    local current_coin = inventories.get_coin_from_inventory(inventory, cargo_wagons, use_piggy_bank)
    local new_coin = coin_tiers.subtract(current_coin, coin)
    inventories.update_inventory(inventory, current_coin, new_coin, cargo_wagons, use_piggy_bank)
end

---Return whether the coin amount can be inserted into the inventory.
---@param inventory LuaInventory
---@param coin Coin
---@return boolean
function inventories.can_insert_coin(inventory, coin)
    local current_coin = inventories.get_coin_from_inventory(inventory, nil, false) -- Note: If use_piggy_bank was true, this would always return true.
    local new_coin = coin_tiers.add(current_coin, coin)

    local current_tiers = coin_tiers.count_nonzero_tiers(current_coin)
    local new_tiers = coin_tiers.count_nonzero_tiers(new_coin)
    if new_tiers > current_tiers then
        local needed_slots = new_tiers - current_tiers
        return inventory.count_empty_stacks(false, false) >= needed_slots
    end

    return true
end

---@param reward_type QuestRewardType
---@param value any
function inventories.on_quest_reward_received(reward_type, value)
    if reward_type == "unlock-feature" then
        if value == "piggy-bank" then
            for _, player in pairs(game.players) do
                local inv = player.get_main_inventory()
                if inv then
                    inventories.normalize_inventory(inv, true)
                end
            end
        end
    end
end



return inventories
