
local lib = require "api.lib"
local coin_tiers = require "api.coin_tiers"
local item_values = require "api.item_values"
local item_ranks = require "api.item_ranks"
local event_system = require "api.event_system"
local inventories = require "api.inventories"
local quests      = require "api.quests"

local item_buffs = {}



---@alias ItemBuffType "moving-speed"|"mining-speed"|"reach-distance"|"build-distance"|"crafting-speed"|"inventory-size"|"trade-productivity"|"all-buffs-level"|"all-buffs-cost-reduced"|"unresearched-penalty-reduced"|"robot-battery"|"robot-speed"|"recipe-productivity"|"beacon-efficiency"|"belt-stack-size"|"passive-coins"|"train-trading-capacity"

---@class ItemBuff
---@field type ItemBuffType The type of buff effect to apply
---@field value float|nil Single modifier value at level 1, used when the buff has one effect
---@field values float[]|nil Array of modifier values at level 1, used when the buff has multiple effects
---@field level_scaling float|nil Scaling factor for how the buff grows per level, applied to the single value
---@field level_scalings float[]|nil Array of scaling factors for how each modifier grows per level



---Apply buff effect
---@param key string Key in storage.item_buffs
---@param value number
local function apply_nonlinear_buff(key, value)
    if value < 0 then
        storage.item_buffs[key] = storage.item_buffs[key] * (1 - value)
    else
        storage.item_buffs[key] = storage.item_buffs[key] / (1 + value)
    end
end

local function create_vanilla_buff_applier(key)
    return function(value)
        local new_value = game.forces.player[key] + value
        if new_value < 0 then
            lib.log_error("Tried to set a negative value for vanilla buff " .. key .. ": " .. value)
            new_value = 0
        end
        game.forces.player[key] = new_value
    end
end



local buff_type_actions = {
    ["mining-speed"] = create_vanilla_buff_applier "manual_mining_speed_modifier",
    ["moving-speed"] = create_vanilla_buff_applier "character_running_speed_modifier",
    ["reach-distance"] = create_vanilla_buff_applier "character_reach_distance_bonus",
    ["build-distance"] = create_vanilla_buff_applier "character_build_distance_bonus",
    ["robot-battery"] = create_vanilla_buff_applier "worker_robots_battery_modifier",
    ["robot-speed"] = create_vanilla_buff_applier "worker_robots_speed_modifier",
    ["robot-cargo-size"] = create_vanilla_buff_applier "worker_robots_storage_bonus",
    ["crafting-speed"] = create_vanilla_buff_applier "manual_crafting_speed_modifier",
    ["mining-productivity"] = create_vanilla_buff_applier "mining_drill_productivity_bonus",
    ["inventory-size"] = create_vanilla_buff_applier "character_inventory_slots_bonus",
    ["beacon-efficiency"] = create_vanilla_buff_applier "beacon_distribution_modifier",
    ["belt-stack-size"] = create_vanilla_buff_applier "belt_stack_size_bonus",
    ["bulk-inserter-capacity"] = create_vanilla_buff_applier "bulk_inserter_capacity_bonus",
    ["inserter-capacity"] = create_vanilla_buff_applier "inserter_stack_size_bonus",
    ["health"] = create_vanilla_buff_applier "character_health_bonus",
    ["combat-robot-lifetime"] = create_vanilla_buff_applier "following_robots_lifetime_modifier",
    ["research-productivity"] = create_vanilla_buff_applier "laboratory_productivity_bonus",
    ["research-speed"] = create_vanilla_buff_applier "laboratory_speed_modifier",
    ["braking-force"] = create_vanilla_buff_applier "train_braking_force_bonus",

    ["combat-robot-count"] = function(value)
        game.forces.player.maximum_following_robot_count = game.forces.player.maximum_following_robot_count + value
    end,
    ["bullet-damage"] = function(value)
        game.forces.player.set_ammo_damage_modifier("bullet", game.forces.player.get_ammo_damage_modifier("bullet") + value)
    end,
    ["bullet-shooting-speed"] = function(value)
        game.forces.player.set_gun_speed_modifier("bullet", game.forces.player.get_gun_speed_modifier("bullet") + value)
    end,
    ["laser-damage"] = function(value)
        game.forces.player.set_ammo_damage_modifier("laser", game.forces.player.get_ammo_damage_modifier("laser") + value)
    end,
    ["laser-shooting-speed"] = function(value)
        game.forces.player.set_gun_speed_modifier("laser", game.forces.player.get_gun_speed_modifier("laser") + value)
    end,
    ["explosion-damage"] = function(value)
        game.forces.player.set_ammo_damage_modifier("grenade", game.forces.player.get_ammo_damage_modifier("grenade") + value)
        game.forces.player.set_ammo_damage_modifier("landmine", game.forces.player.get_ammo_damage_modifier("landmine") + value)
        game.forces.player.set_ammo_damage_modifier("rocket", game.forces.player.get_ammo_damage_modifier("rocket") + value)
    end,
    ["rocket-shooting-speed"] = function(value)
        game.forces.player.set_gun_speed_modifier("rocket", game.forces.player.get_gun_speed_modifier("rocket") + value)
    end,
    ["fire-damage"] = function(value)
        game.forces.player.set_ammo_damage_modifier("flamethrower", game.forces.player.get_ammo_damage_modifier("flamethrower") + value)
    end,
    ["electric-damage"] = function(value)
        game.forces.player.set_ammo_damage_modifier("electric", game.forces.player.get_ammo_damage_modifier("electric") + value)
        game.forces.player.set_ammo_damage_modifier("tesla", game.forces.player.get_ammo_damage_modifier("tesla") + value)
    end,
    ["electric-shooting-speed"] = function(value)
        game.forces.player.set_gun_speed_modifier("electric", game.forces.player.get_gun_speed_modifier("electric") + value)
    end,
    ["trade-productivity"] = function(value)
        local new_prod = storage.trades.base_productivity + value
        if new_prod < 0 then
            lib.log_error("Tried to set a negative trade productivity")
            new_prod = 0
        end

        local prev = storage.trades.base_productivity
        storage.trades.base_productivity = new_prod

        if prev ~= new_prod then
            event_system.trigger "item-buff-changed-trade-productivity"
        end
    end,
    ["passive-coins"] = function(value)
        storage.item_buffs.passive_coins_rate = math.max(0, storage.item_buffs.passive_coins_rate + value)
    end,
    ["train-trading-capacity"] = function(value)
        storage.item_buffs.train_trading_capacity = math.max(0, storage.item_buffs.train_trading_capacity + value)
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
        apply_nonlinear_buff("cost_multiplier", value)
    end,
    ["unresearched-penalty-reduced"] = function(value)
        apply_nonlinear_buff("unresearched_penalty_multiplier", value)
    end,
    ["strongbox-loot"] = function(value)
        apply_nonlinear_buff("strongbox_loot", -value)
    end,

    ["recipe-productivity"] = function(recipe_name, value)
        if not recipe_name then
            log("nil recipe")
            return
        end
        if not prototypes.recipe[recipe_name] then
            log("unknown recipe: " .. recipe_name)
            return
        end
        local recipe = game.forces.player.recipes[recipe_name]
        local new_prod = recipe.productivity_bonus + value * 0.01
        if new_prod < 0 then
            lib.log_error("Tried to set a negative recipe productivity")
            new_prod = 0
        end
        recipe.productivity_bonus = new_prod
    end,
}



local function format_enhanced_items(enhanced_items)
    local str = "[font=heading-2][color=green]"
    for _item_name, levels in pairs(enhanced_items) do
        str = str .. " [img=item." .. _item_name .. "]+" .. levels
    end
    str = str .. "[.color][.font]"
    return str
end



function item_buffs.register_events()
    event_system.register("player-used-capsule", function(player, capsule_name)
        if capsule_name:sub(1, 23) ~= "hexadic-resonator-tier-" then return end

        local feature_name = "item-buff-enhancement"
        if not quests.is_feature_unlocked(feature_name) then
            local quests_to_unlock = quests.get_quests_which_unlock(feature_name)

            local quest_str = {""}
            if next(quests_to_unlock) then
                table.insert(quest_str, lib.color_localized_string({"quest-title." .. quests_to_unlock[1].name}, "cyan", "heading-2"))
            else
                table.insert(quest_str, lib.color_localized_string({"hextorio-gui.obfuscated-text"}, "black", "heading-2"))
            end

            player.print {"hextorio.feature-locked",
                lib.color_localized_string({"feature-name." .. feature_name}, "orange", "heading-2"),
                quest_str,
            }

            lib.safe_insert(player, {name = capsule_name, count = 1})
            return
        end

        local tier = capsule_name:sub(24)

        item_buffs.add_free_buffs(2 ^ (tier - 1))
    end)
end

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

    -- Level 0 means locked/nothing applied
    if level <= 0 then
        for i = 1, #modifiers do
            modifiers[i] = 0
        end
        return modifiers
    end

    -- Scale the modifiers by the level
    for i, v in ipairs(modifiers) do
        if type(v) == "number" then
            if storage.item_buffs.has_linear_effect_scaling[buff.type] then
                modifiers[i] = v + level_scalings[i] * (level - 1)
            else
                modifiers[i] = v * level_scalings[i] ^ (level - 1)
            end
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

                local idx = i
                if buff.type == "recipe-productivity" then
                    idx = modifiers[1]
                end

                local prev = t[idx] or 0
                t[idx] = prev + v

                -- This is just sending the difference in rounded values to the buff application while keeping track of the combined fractional values.
                modifiers[i] = item_buffs.rounded_buff_value(t[idx]) - item_buffs.rounded_buff_value(prev)
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
        local trigger_event = true
        local level
        if item_buffs.is_unlocked(item_name) then
            level = 1
        else
            trigger_event = false
            level = 0
        end
        item_buffs.set_item_buff_level(item_name, level, trigger_event)
    end
    return storage.item_buffs.levels[item_name]
end

---Set the level of the item's buff.  0 = locked, 1 = first level of unlocked buff, etc.
---Automatically triggers the unlock if the item is currently at level 0 (locked).
---@param item_name string
---@param level int
---@param trigger_event boolean|nil Whether to trigger the `item-buff-level-changed` event.  Defaults to `true` if not provided.
function item_buffs.set_item_buff_level(item_name, level, trigger_event)
    local prev_level = storage.item_buffs.levels[item_name]
    if prev_level == level or level < 0 then
        return
    end

    local dec = 0
    if prev_level == 0 and not item_buffs.gives_buff_of_type(item_name, "all-buffs-level") then
        dec = storage.item_buffs.level_bonus
        level = level + dec
    end

    if trigger_event == nil then trigger_event = true end

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
                -- For linear buffs, apply or remove incremental changes based on level difference
                if level > prev_level then
                    -- Apply incremental buffs for each level increase
                    for i = prev_level, level - 1 do
                        item_buffs.apply_buff_modifiers(item_buffs.get_incremental_buff(buff, i), 1, false)
                    end
                elseif level < prev_level then
                    -- Remove incremental buffs for each level decrease
                    for i = level, prev_level - 1 do
                        item_buffs.apply_buff_modifiers(item_buffs.get_incremental_buff(buff, i), 1, true)
                    end
                end
            end
        end
    end

    if trigger_event then
        event_system.trigger("item-buff-level-changed", item_name, prev_level, level)
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

function item_buffs.enhance_all_item_buffs(config)
    if storage.item_buffs.enhance_all.processing then
        return
    end

    local player = config.player

    local inv = lib.get_player_inventory(player)
    if not inv then
        lib.log_error("item_buffs.enhance_all_item_buffs: no player inventory found")
        return
    end

    item_buffs.fetch_settings()


    player.print({"hextorio.checking-for-enhancements"})

    storage.item_buffs.enhance_all.player = player
    storage.item_buffs.enhance_all.inventory = inv
    storage.item_buffs.enhance_all.item_names = item_buffs.get_buffable_items()
    storage.item_buffs.enhance_all.enhanced_items = {}
    storage.item_buffs.enhance_all.total_cost = coin_tiers.new()
    storage.item_buffs.enhance_all.processing = true
end

---Get the cheapest item to buff out of the given list of item names. Return the item name and its cost.
---@param item_names string[]
---@param budget_coin Coin|nil
---@return string|nil, Coin|nil
function item_buffs.get_cheapest_item_buff(item_names, budget_coin)
    local item_name
    local cost

    for _, _item_name in pairs(item_names) do
        local _cost = item_buffs.get_item_buff_cost(_item_name)
        if not budget_coin or coin_tiers.lt(_cost, budget_coin) then
            if not item_name or coin_tiers.lt(_cost, cost) then
                item_name = _item_name
                cost = _cost
            end
        end
    end

    return item_name, cost
end

---Get a list of item names that are ranked up to at least bronze and have available item buffs.
---@return string[]
function item_buffs.get_buffable_items()
    local item_names = {}
    for item_name, _ in pairs(storage.trades.discovered_items) do
        if item_ranks.get_item_rank(item_name) >= 2 and next(item_buffs.get_buffs(item_name)) then
            table.insert(item_names, item_name)
        end
    end
    return item_names
end

function item_buffs._enhance_all_item_buffs_tick()
    if not storage.item_buffs.enhance_all.processing then return end

    local player = storage.item_buffs.enhance_all.player
    local inv = storage.item_buffs.enhance_all.inventory
    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    local inv_coin = inventories.get_coin_from_inventory(inv, nil, is_piggy_bank_unlocked) -- Check each time because the player can modify the coins they have available to spend while this processes over time.
    local item_names = storage.item_buffs.enhance_all.item_names
    local enhanced_items = storage.item_buffs.enhance_all.enhanced_items

    -- Find the cheapest item buff
    local item_name, cost = item_buffs.get_cheapest_item_buff(item_names, inv_coin)

    -- If found, the process should enhance it and continue on the next tick
    if item_name and cost then
        storage.item_buffs.enhance_all.total_cost = coin_tiers.add(storage.item_buffs.enhance_all.total_cost, cost)
        enhanced_items[item_name] = (enhanced_items[item_name] or 0) + 1
        inventories.remove_coin_from_inventory(inv, cost, nil, is_piggy_bank_unlocked)

        item_buffs.set_item_buff_level(
            item_name,
            item_buffs.get_item_buff_level(item_name) + 1
        )

        return
    end

    -- Process is now finished
    storage.item_buffs.enhance_all.processing = false

    if next(enhanced_items) then
        local str = format_enhanced_items(enhanced_items)

        ---@diagnostic disable-next-line: cast-local-type
        str = {
            "",
            lib.color_localized_string({"hextorio.item-buffs-enhanced"}, "yellow", "heading-2"),
            str,
            "\n",
            {"hextorio-gui.cost", coin_tiers.coin_to_text(storage.item_buffs.enhance_all.total_cost)},
        }

        player.print(str)
    else
        player.print {"hextorio.none-enhanced"}
    end

    event_system.trigger("item-buffs-enhance-all-finished", player, storage.item_buffs.enhance_all.total_cost, enhanced_items)
end

---Queue up a number of cheapest item buffs to upgrade for free.
---@param amount int
function item_buffs.add_free_buffs(amount)
    storage.item_buffs.free_buffs_remaining = storage.item_buffs.free_buffs_remaining + amount
end

function item_buffs.process_free_buffs()
    if storage.item_buffs.free_buffs_remaining <= 0 then return end

    if not storage.item_buffs.free_buffs_list then
        storage.item_buffs.free_buffs_list = item_buffs.get_buffable_items()
    end

    if not storage.item_buffs.free_buffs_enhanced_items then
        storage.item_buffs.free_buffs_enhanced_items = {}
    end

    local item_name, _ = item_buffs.get_cheapest_item_buff(storage.item_buffs.free_buffs_list)
    if item_name then
        storage.item_buffs.free_buffs_enhanced_items[item_name] = (storage.item_buffs.free_buffs_enhanced_items[item_name] or 0) + 1
        item_buffs.set_item_buff_level(
            item_name,
            item_buffs.get_item_buff_level(item_name) + 1
        )
    else
        lib.log_error("item_buffs.process_free_buffs: No items able to be buffed")
    end

    storage.item_buffs.free_buffs_remaining = storage.item_buffs.free_buffs_remaining - 1
    if storage.item_buffs.free_buffs_remaining <= 0 then
        if next(storage.item_buffs.free_buffs_enhanced_items) then
            local str = format_enhanced_items(storage.item_buffs.free_buffs_enhanced_items)

            ---@diagnostic disable-next-line: cast-local-type
            str = {
                "",
                lib.color_localized_string({"hextorio.item-buffs-enhanced"}, "yellow", "heading-2"),
                str,
            }

            game.print(str)
        else
            -- TODO: maybe give the hexadic resonator back to the player
        end

        storage.item_buffs.free_buffs_list = nil
        storage.item_buffs.free_buffs_enhanced_items = nil
    end
end

---Recalculate all bonuses from zero.
---@param new_data table
function item_buffs.migrate_buff_changes(new_data)
    -- Store which items were enabled and their levels
    local items_to_restore = {}
    for item_name, _ in pairs(storage.item_buffs.enabled) do
        if item_buffs.is_enabled(item_name) then
            local level = item_buffs.get_item_buff_level(item_name)
            if level > 0 then
                items_to_restore[item_name] = level
            end
        end
    end

    -- Reset all force bonuses and reapply technology effects
    game.forces.player.reset_technology_effects()

    -- Reset custom storage values that aren't affected by technologies
    storage.trades.base_productivity = 0 -- THIS RESETS QUEST-GIVEN BONUSES
    storage.item_buffs.passive_coins_rate = 0
    storage.item_buffs.train_trading_capacity = 10

    -- Clear fractional trackers
    storage.item_buffs.fractional_bonuses = {}

    -- Reset nonlinear buffs
    storage.item_buffs.strongbox_loot = 1
    storage.item_buffs.cost_multiplier = 1
    storage.item_buffs.unresearched_penalty_multiplier = 1
    storage.item_buffs.level_bonus = 0

    -- Update metadata
    storage.item_buffs.show_as_linear = new_data.show_as_linear
    storage.item_buffs.is_fractional = new_data.is_fractional
    storage.item_buffs.has_description = new_data.has_description
    storage.item_buffs.is_nonlinear = new_data.is_nonlinear
    storage.item_buffs.has_linear_effect_scaling = new_data.has_linear_effect_scaling
    storage.item_buffs.item_buffs = new_data.item_buffs

    -- Re-apply all buffs with new parameters
    for item_name, level in pairs(items_to_restore) do
        local buffs = storage.item_buffs.item_buffs[item_name]
        if buffs then
            for _, buff in pairs(buffs) do
                item_buffs.apply_buff_modifiers(buff, level, false)
            end
        end
    end

    event_system.trigger "item-buff-data-migrated"
end



return item_buffs
