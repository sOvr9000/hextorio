
-- Special weighted choice objects for loot tables, factoring in surface-specific item values and qualities to generate item weights.

local lib = require "api.lib"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local event_system= require "api.event_system"

local loot_tables = {}



---@class LootItem
---@field item_name string The name of the item
---@field quality_tier int The quality tier (1=normal, 2=uncommon, 3=rare, 4=epic, 5=legendary, 6=hextreme)

---@class LootItemWithCount
---@field loot_item LootItem The item and its quality tier
---@field count int The quantity of this item

---@class LootTable
---@field wc WeightedChoice Weighted choice object for random item selection based on item values
---@field loot LootItem[] Array of loot items that can be sampled from this table



function loot_tables.register_events()
    event_system.register("item-values-recalculated", loot_tables.init)
end

---Initialize loot tables.
function loot_tables.init()
    storage.loot_tables = {
        surface_loot_tables = {},
    }

    for surface_name, _ in pairs(storage.item_values.values) do
        local item_names = item_values.get_items_sorted_by_value(surface_name, true, true, false, false)
        storage.loot_tables.surface_loot_tables[surface_name] = {
            dungeon = loot_tables.new(surface_name, item_names, 1, 6)
        }
    end
end



---Get a loot table for a surface.
---@param surface_name string
---@param loot_table_name string
---@return LootTable|nil
function loot_tables.get_loot_table(surface_name, loot_table_name)
    local lookup = storage.loot_tables.surface_loot_tables[surface_name]
    if not lookup then
        lib.log_error("loot_tables.get_loot_table: No loot table found for surface " .. surface_name)
        return
    end
    local loot_table = lookup[loot_table_name]
    if not loot_table then
        lib.log_error("loot_tables.get_loot_table: No loot table found with name " .. loot_table_name .. " on surface " .. surface_name)
    end
    return loot_table
end

---Create a new loot table from a list of item names on a surface.
---@param surface_name string
---@param item_names string[]
---@param min_quality_tier int
---@param max_quality_tier int
---@return LootTable
function loot_tables.new(surface_name, item_names, min_quality_tier, max_quality_tier)
    local loot_table = {loot = {}}
    local weights = {}

    local index = 0
    for _, item_name in pairs(item_names) do
        for quality_tier = min_quality_tier, max_quality_tier do
            index = index + 1
            local item_value = item_values.get_item_value(surface_name, item_name, true, lib.get_quality_at_tier(quality_tier))
            weights[index] = 1 / item_value
            loot_table.loot[index] = {item_name = item_name, quality_tier = quality_tier}
        end
    end
    loot_table.wc = weighted_choice.new(weights)

    return loot_table
end

---Sample `n` items from a loot table.
---@param loot_table LootTable
---@param n int
---@return LootItem[]
function loot_tables.sample(loot_table, n)
    local loot_items = {}
    for i = 1, n do
        local idx = weighted_choice.choice(loot_table.wc)
        loot_items[i] = loot_table.loot[idx]
    end
    return table.deepcopy(loot_items)
end

---Sample items until a total value is reached.
---@param loot_table LootTable
---@param surface_name string
---@param expected_num_samples int The expected length of the returned list. The length varies randomly.
---@param total_value number
---@param amount_scaling number
---@return LootItemWithCount[]
function loot_tables.sample_until_total_value(loot_table, surface_name, expected_num_samples, max_num_samples, total_value, amount_scaling)
    if not next(loot_table.loot) then
        lib.log_error("loot_tables.sample_until_total_value: loot table is empty")
        return {}
    end

    local value_per_sample = total_value / (expected_num_samples * amount_scaling)
    local remaining_value = total_value

    local loot_items = {}
    for index = 1, max_num_samples do
        if remaining_value <= 0 then break end

        local idx = weighted_choice.choice(loot_table.wc)
        local item = loot_table.loot[idx]
        local stack_size = lib.get_stack_size(item.item_name)
        local item_value = item_values.get_item_value(surface_name, item.item_name, true, lib.get_quality_at_tier(item.quality_tier))
        local count = math.min(stack_size, math.max(1, math.floor(0.5 + amount_scaling * value_per_sample / item_value)))
        local total_item_value = item_value * count

        loot_items[index] = {loot_item = item, count = count}
        remaining_value = remaining_value - total_item_value
    end

    return table.deepcopy(loot_items)
end

---Add a positive bias to give rarer items more weight, or a negative bias to give more common items more weight, returning a new loot table with the applied bias.
---@param loot_table LootTable
---@param bias number
---@return LootTable
function loot_tables.add_bias(loot_table, bias)
    return {
        loot = table.deepcopy(loot_table.loot),
        wc = weighted_choice.add_global_bias(loot_table.wc, bias)
    }
end

---Remove items from a loot table based on minimum and maximum value.
---@param loot_table LootTable
---@param min_value number
---@param max_value number
---@return LootTable
function loot_tables.clip_items_by_value(loot_table, surface_name, min_value, max_value)
    local new_loot = {}
    local new_weights = {}
    local idx = 0
    for i, item in ipairs(loot_table.loot) do
        local item_value = item_values.get_item_value(surface_name, item.item_name, true, lib.get_quality_at_tier(item.quality_tier))
        if item_value >= min_value and item_value <= max_value then
            idx = idx + 1
            new_loot[idx] = item
            new_weights[idx] = loot_table.wc[i]
        end
    end

    return {
        loot = new_loot,
        wc = weighted_choice.new(new_weights)
    }
end


return loot_tables
