
local lib = require "api.lib"
local coin_tiers = require "api.coin_tiers"
local item_values = require "api.item_values"

local item_buffs = {}



local buff_type_actions = {
    ["mining-speed"] = function(value)
        game.forces.player.manual_mining_speed_modifier = game.forces.player.manual_mining_speed_modifier + value
    end,
    ["moving-speed"] = function(value)
        game.forces.player.character_running_speed_modifier = game.forces.player.character_running_speed_modifier + value
    end,
    ["reach-distance"] = function(value)
        game.forces.player.character_reach_distance_bonus = game.forces.player.character_reach_distance_bonus + value
    end,
    ["build-distance"] = function(value)
        game.forces.player.character_build_distance_bonus = game.forces.player.character_build_distance_bonus + value
    end,
    ["robot-battery"] = function(value)
        game.forces.player.worker_robots_battery_modifier = game.forces.player.worker_robots_battery_modifier + value
    end,
    ["robot-speed"] = function(value)
        game.forces.player.worker_robots_speed_modifier = game.forces.player.worker_robots_speed_modifier + value
    end,
    ["crafting-speed"] = function(value)
        game.forces.player.manual_crafting_speed_modifier = game.forces.player.manual_crafting_speed_modifier + value
    end,
    ["mining-productivity"] = function(value)
        game.forces.player.mining_drill_productivity_bonus = game.forces.player.mining_drill_productivity_bonus + value
    end,
    ["inventory-size"] = function(value)
        game.forces.player.character_inventory_slots_bonus = game.forces.player.character_inventory_slots_bonus + value
    end,
    ["beacon-efficiency"] = function(value)
        game.forces.player.beacon_distribution_modifier = game.forces.player.beacon_distribution_modifier + value
    end,
    ["belt-stack-size"] = function(value)
        game.forces.player.belt_stack_size_bonus = game.forces.player.belt_stack_size_bonus + value
    end,
    ["trade-productivity"] = function(value)
        storage.trades.base_productivity = storage.trades.base_productivity + value
    end,
    ["all-buffs-level"] = function(value)
        storage.item_buffs.level_bonus = storage.item_buffs.level_bonus + value

        -- todo: optimize this PLEASE
        -- by making set_item_buff_level use incremental buffs for linearly modified bonuses (e.g. inventory size but NOT cost reduction)
        for item_name, level in pairs(storage.item_buffs.levels) do
            if level >= 1 and not item_buffs.gives_buff_of_type(item_name, "all-buffs-level") then
                item_buffs.set_item_buff_level(item_name, item_buffs.get_item_buff_level(item_name) + value)
            end
        end
    end,
    ["all-buffs-cost-reduced"] = function(value)
        if value < 0 then
            storage.item_buffs.cost_multiplier = storage.item_buffs.cost_multiplier * (1 - value)
        else
            storage.item_buffs.cost_multiplier = storage.item_buffs.cost_multiplier / (1 + value)
        end
    end,

    ["recipe-productivity"] = function(recipe_name, value)
        game.forces.player.recipes[recipe_name].productivity_bonus = game.forces.player.recipes[recipe_name].productivity_bonus + value
    end,
}



---Get the item buff values scaled by the given level.
---@param buff ItemBuff
---@param level int
---@return float[]|nil
function item_buffs.get_scaled_buff_values(buff, level)
    local modifiers = {}
    local level_scalings = {}

    if buff.values then
        for i, modifier in ipairs(buff.values) do
            modifiers[i] = modifier
        end
    end

    if buff.level_scalings then
        for i, level_scaling in ipairs(buff.level_scalings) do
            level_scalings[i] = level_scaling
        end
    end

    if buff.value then
        table.insert(modifiers, buff.value)
    end

    if buff.level_scaling then
        table.insert(level_scalings, buff.level_scaling)
    end

    if not next(modifiers) then
        lib.log_error("item_buffs.get_scaled_buff_values: No modifiers found for buff of type " .. buff.type)
        return
    end

    if not next(level_scalings) then
        lib.log("item_buffs.get_scaled_buff_values: No level scaling factors found for buff of type " .. buff.type)
        return
    end

    if #level_scalings == 1 and #modifiers > 1 then
        local first = level_scalings[1]
        for i = 2, #modifiers do
            level_scalings[i] = first
        end
    end

    if #level_scalings ~= #modifiers then
        lib.log_error("item_buffs.get_scaled_buff_values: Mismatched numbers of level scaling factors and modifiers in buff of type " .. buff.type)
        if #level_scalings < #modifiers then
            -- Can still continue in the opposite case.
            return
        end
    end

    -- Scale the modifiers by the level
    for i, v in ipairs(modifiers) do
        if type(v) == "number" then
            modifiers[i] = v * level_scalings[i] ^ (level - 1)
        end
    end

    return modifiers
end

---Apply or remove buff modifiers
---@param buff ItemBuff
---@param level int
---@param removing boolean
function item_buffs.apply_buff_modifiers(buff, level, removing)
    local modifiers = item_buffs.get_scaled_buff_values(buff, level)
    if not modifiers then return end

    if removing then
        for i, v in ipairs(modifiers) do
            if type(v) == "number" then
                modifiers[i] = -v
            end
        end
    end

    if storage.item_buffs.is_fractional[buff.type] then
        for i, v in ipairs(modifiers) do
            if type(v) == "number" then
                local t = storage.item_buffs.fractional_bonuses[buff.type]
                if not t then
                    t = {}
                    storage.item_buffs.fractional_bonuses[buff.type] = t
                end

                local prev = t[i] or 0
                t[i] = prev + v

                -- This is just sending the difference in rounded values to the buff application while keeping track of the combined fractional values.
                modifiers[i] = item_buffs.rounded_buff_value(t[i]) - item_buffs.rounded_buff_value(prev)
            end
        end
    end

    local all_zero = true
    for i, v in ipairs(modifiers) do
        if v ~= 0 then
            all_zero = false
        end
    end

    if all_zero then return end

    local action = buff_type_actions[buff.type]
    if not action then
        lib.log_error("item_buffs.apply_buff_modifiers: no effects being applied for buff of type " .. buff.type)
        return
    end

    action(table.unpack(modifiers))
end

---Get the list of item buffs that an item is able to provide when unlocked.
---@param item_name string
---@return ItemBuff[]
function item_buffs.get_buffs(item_name)
    local buffs = storage.item_buffs.item_buffs[item_name]
    if not buffs or not next(buffs) then
        lib.log_error("item_buffs.get_buffs: " .. item_name .. " has no buffs")
        buffs = {}
    end
    return buffs
end

---Get the combined list of currently unlocked and enabled buffs from all items.
---@return ItemBuff[]
function item_buffs.get_all_item_buffs()
    local all_buffs = {}

    for item_name, _ in pairs(storage.item_buffs.enabled) do
        local buffs = storage.item_buffs.item_buffs[item_name]
        if buffs and next(buffs) then
            local start_idx = #all_buffs + 1
            for i = 1, #buffs do
                item_buffs[start_idx + i] = buffs[i]
            end
        end
    end

    return all_buffs
end

---Return whether the given item's buff has been unlocked.
---@param item_name string
---@return boolean
function item_buffs.is_unlocked(item_name)
    return storage.item_buffs.unlocked[item_name] == true
end

---Unlock an item's unique buffs.
---@param item_name string
function item_buffs.unlock(item_name)
    if item_buffs.is_unlocked(item_name) then
        return
    end

    storage.item_buffs.unlocked[item_name] = true
    item_buffs.set_enabled(item_name, true)
end

---Return whether an item's buff is unlocked and enabled.
---@param item_name string
---@return boolean
function item_buffs.is_enabled(item_name)
    return storage.item_buffs.enabled[item_name] == true and item_buffs.is_unlocked(item_name)
end

---Set whether an item's buff is enabled.
---@param item_name string
---@param flag boolean
function item_buffs.set_enabled(item_name, flag)
    if flag and not item_buffs.is_unlocked(item_name) then
        return
    end

    local prev = storage.item_buffs.enabled[item_name] == true
    storage.item_buffs.enabled[item_name] = flag

    if prev ~= flag then
        item_buffs.on_item_buff_toggled(item_name)
    end
end

---Called when an item buff is toggled.
---@param item_name string
function item_buffs.on_item_buff_toggled(item_name)
    local buffs = item_buffs.get_buffs(item_name)
    local removing = not item_buffs.is_enabled(item_name)
    local level = item_buffs.get_item_buff_level(item_name)
    for _, buff in pairs(buffs) do
        item_buffs.apply_buff_modifiers(buff, level, removing)
    end
end

---Get the level of the item's buff.  0 = locked, 1 = first level of unlocked buff, etc.
---@param item_name string
---@return int
function item_buffs.get_item_buff_level(item_name)
    if not storage.item_buffs.levels[item_name] then
        local level
        if item_buffs.is_unlocked(item_name) then
            level = 1
        else
            level = 0
        end
        item_buffs.set_item_buff_level(item_name, level)
    end
    return storage.item_buffs.levels[item_name]
end

---Set the level of the item's buff.  0 = locked, 1 = first level of unlocked buff, etc.
---Automatically triggers the unlock if the item is currently at level 0 (locked).
---@param item_name string
---@param level int
function item_buffs.set_item_buff_level(item_name, level)
    local prev_level = storage.item_buffs.levels[item_name]
    if prev_level == level then
        return
    end

    local reapply = false
    local buffs
    if item_buffs.is_enabled(item_name) then
        reapply = true
        buffs = item_buffs.get_buffs(item_name)
        for _, buff in pairs(buffs) do
            if storage.item_buffs.is_nonlinear[buff.type] then
                -- If nonlinear, it is easier to fully remove the current effect and reapply it at the new level.
                item_buffs.apply_buff_modifiers(buff, prev_level, true)
            end
        end
    end

    storage.item_buffs.levels[item_name] = level

    if prev_level == 0 and not item_buffs.is_unlocked(item_name) then
        item_buffs.unlock(item_name)
    end

    if reapply then
        for _, buff in pairs(buffs) do
            if storage.item_buffs.is_nonlinear[buff.type] then
                item_buffs.apply_buff_modifiers(buff, level, false)
            else
                -- Apply a "level one" version of the increment from the previous level to the new level, skipping some calculations to achieve the same thing.
                item_buffs.apply_buff_modifiers(item_buffs.get_incremental_buff(buff, level - 1), 1, false)
            end
        end
    end
end

---Recalculate the cost of an item's buff at its current level.
---@param item_name string
---@return Coin
function item_buffs.get_item_buff_cost(item_name)
    if storage.item_buffs.fetch_settings then
        item_buffs.fetch_settings()
    end

    if not storage.item_buffs.levels[item_name] then
        item_buffs.set_item_buff_level(item_name, 0)
    end

    local level = storage.item_buffs.levels[item_name]

    local level_bonus
    if item_buffs.gives_buff_of_type(item_name, "all-buffs-level") then
        level_bonus = 0
    else
        level_bonus = item_buffs.rounded_buff_value(storage.item_buffs.level_bonus)
    end

    local coin = coin_tiers.from_base_value(item_values.get_minimal_item_value(item_name) * storage.item_buffs.cost_multiplier / item_values.get_item_value("nauvis", "hex-coin"))

    coin = coin_tiers.multiply(coin, storage.item_buffs.cost_scale)
    for i = level_bonus + 1, level do
        coin = coin_tiers.multiply(coin, storage.item_buffs.cost_base) -- Separate function calls to avoid potential integer overflow in raw exponentiation
    end
    coin = coin_tiers.floor(coin)

    return coin
end

---Return a new ItemBuff representing the increment to the modifiers that would occur if the given buff was leveled up once from the given level.
---@param buff ItemBuff
---@return ItemBuff
function item_buffs.get_incremental_buff(buff, level)
    local current_buff_values = item_buffs.get_scaled_buff_values(buff, level)
    local leveled_up_buff_values = item_buffs.get_scaled_buff_values(buff, level+1)

    if not current_buff_values or not leveled_up_buff_values then
        current_buff_values = {}
        leveled_up_buff_values = {}
    end

    local incremental_buff = table.deepcopy(buff)

    if buff.value then
        incremental_buff.value = leveled_up_buff_values[1] - current_buff_values[1]
    else
        for i, v in pairs(leveled_up_buff_values) do
            if type(v) == "number" then
                incremental_buff.values[i] = v - current_buff_values[i]
            end
        end
    end

    log("for buff: " .. serpent.line(buff))
    log("increment: " .. serpent.line(incremental_buff))

    return incremental_buff
end

---Return a rounded value for a buff where negative midpoints are rounded down instead of up (like -0.5 -> -1 instead of 0).
---@param value float
---@return float
function item_buffs.rounded_buff_value(value)
    if value < 0 then
        return -math.floor(0.5 - value)
    end
    return math.floor(0.5 + value)
end

---Return whether the given item offers a specific type of buff.
---@param item_name string
---@param buff_type ItemBuffType
function item_buffs.gives_buff_of_type(item_name, buff_type)
    for _, buff in pairs(item_buffs.get_buffs(item_name)) do
        if buff.type == buff_type then
            return true
        end
    end
    return false
end

function item_buffs.fetch_settings()

    local cost_scale = lib.runtime_setting_value "item-buff-cost-scale"
    ---@cast cost_scale number
    storage.item_buffs.cost_scale = cost_scale

    local cost_base = lib.runtime_setting_value "item-buff-cost-base"
    ---@cast cost_base number
    storage.item_buffs.cost_base = cost_base

    -- Set the flag back to true to re-fetch the settings.
    storage.item_buffs.fetch_settings = false
end



return item_buffs
