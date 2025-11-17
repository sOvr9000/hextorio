
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
}

local modifier_selectors = {
    ["trade-productivity"] = function(index)
        return storage.trades, "base_productivity"
    end,
    ["all-buffs-amplified"] = function(index)
        return storage.item_buffs, "global_amplifier"
    end,
    ["all-buffs-cost-reduction"] = function(index)
        return storage.item_buffs, "global_cost_reduction"
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
        modifiers[i] = v * level_scalings[i] ^ (level - 1)
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
            modifiers[i] = -v
        end
    end

    local action = buff_type_actions[buff.type]
    if action then
        action(table.unpack(modifiers))
        return
    end

    local selector = modifier_selectors[buff.type]
    if not action and not selector then
        lib.log_error("item_buffs.apply_buff_modifiers: no effects being applied for buff of type " .. buff.type)
        return
    end

    if selector then return end

    for i = 1, #modifiers do
        local t, key = selector(i)
        t[key] = t[key] + modifiers[i]
    end
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
            item_buffs.apply_buff_modifiers(buff, prev_level, true)
        end
    end

    storage.item_buffs.levels[item_name] = level

    if prev_level == 0 and not item_buffs.is_unlocked(item_name) then
        item_buffs.unlock(item_name)
    end

    if reapply then
        for _, buff in pairs(buffs) do
            item_buffs.apply_buff_modifiers(buff, level, false)
        end
    end
end

---Recalculate the cost of an item's buff at its current level.
---@param item_name string
---@return Coin
function item_buffs.get_item_buff_cost(item_name)
    if not storage.item_buffs.levels[item_name] then
        item_buffs.set_item_buff_level(item_name, 0)
    end

    local level = storage.item_buffs.levels[item_name]
    local coin = coin_tiers.from_base_value(item_values.get_minimal_item_value(item_name) / item_values.get_item_value("nauvis", "hex-coin"))

    coin = coin_tiers.multiply(coin, 2000 * 4 ^ level)
    coin = coin_tiers.floor(coin)

    return coin
end



return item_buffs
