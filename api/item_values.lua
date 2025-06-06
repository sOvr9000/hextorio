
local lib = require "api.lib"
local item_ranks = require "api.item_ranks"

local item_values = {}



function item_values.init()
    storage.item_values.recipe_tree = lib.get_recipe_tree()
    storage.item_values.recipe_graph = lib.get_recipe_graph(storage.item_values.recipe_tree)
    log(serpent.block(storage.item_values.recipe_tree))

    -- Log spoilable items.
    -- local spoilable = {}
    -- for _, item_name in pairs(storage.item_values.recipe_graph.all_items) do
    --     if lib.is_spoilable(item_name) then
    --         table.insert(spoilable, item_name)
    --     end
    -- end
    -- log(serpent.block(spoilable))
end

function item_values.get_item_value(surface_name, item_name, allow_interplanetary, quality_name)
    if not surface_name then
        lib.log_error("item_values.get_item_value: surface_name is nil, defaulting to 1")
        return 1
    end
    if not item_name then
        lib.log_error("item_values.get_item_value: item_name is nil, defaulting to 1")
        return 1
    end
    if type(surface_name) ~= "string" then
        lib.log_error("item_values.get_item_value: surface_name is not a string, received type: " .. type(surface_name))
        return 1
    end
    if type(item_name) ~= "string" then
        lib.log_error("item_values.get_item_value: item_name is not a string, received type: " .. type(item_name))
        return 1
    end

    if allow_interplanetary == nil then
        allow_interplanetary = true
    end

    if not quality_name then
        quality_name = "normal"
    end
    local quality_mult = lib.get_quality_value_scale(quality_name)

    local surface_vals = item_values.get_item_values_for_surface(surface_name)
    if not surface_vals then
        lib.log_error("item_values.get_item_value: No item values for surface " .. surface_name .. ", defaulting to 1")
        return 1
    end

    local val = surface_vals[item_name]
    if not val then
        if lib.is_coin(item_name) then
            surface_vals["hex-coin"] = 10
            surface_vals["gravity-coin"] = surface_vals["hex-coin"] * 100000
            surface_vals["meteor-coin"] = surface_vals["gravity-coin"] * 100000
            surface_vals["hexaprism-coin"] = surface_vals["meteor-coin"] * 100000 -- TODO: these valuse are too large for floating point precision, so coin_tiers will have to replace it eventually
            return surface_vals[item_name] * quality_mult
        end
        if allow_interplanetary then
            val = item_values.get_interplanetary_item_value(surface_name, item_name)
        else
            lib.log("item_values.get_item_value: Unknown item value for " .. item_name .. " on surface " .. surface_name .. ", defaulting to 1")
            val = 1
        end
    end

    if val then
        if not lib.is_coin(item_name) then
            val = val * (storage.item_values.value_multipliers[surface_name] or 1)
        end
    else
        lib.log("item_values.get_item_value: Could not find interplanetary value for " .. item_name .. " on surface " .. surface_name .. ", defaulting to 1")
        val = 1
    end

    return val * quality_mult
end

-- Get the value of an item for any surface.
-- The returned value is a large multiple of the minimum value of the item across all surfaces.
function item_values.get_interplanetary_item_value(surface_name, item_name)
    if storage.item_values.interplanetary_values[item_name] then
        return storage.item_values.interplanetary_values[item_name]
    end

    local min_value = math.huge
    local min_surface_name
    for _surface_name, surface_vals in pairs(storage.item_values.values) do
        local val = surface_vals[item_name]
        if val then
            val = val * (storage.item_values.value_multipliers[_surface_name] or 1)
            if val < min_value then
                min_value = val
                min_surface_name = _surface_name
            end
        end
    end

    if not min_surface_name then
        lib.log_error("item_values.get_interplanetary_item_value: No item value found for item " .. item_name .. ", defaulting to 1")
        return 1
    end

    local mult
    if surface_name == "aquilo" then
        mult = lib.runtime_setting_value "interplanetary-mult-aquilo"
    else
        mult = lib.runtime_setting_value "interplanetary-mult"
    end

    storage.item_values.interplanetary_values[item_name] = min_value * mult
    return storage.item_values.interplanetary_values[item_name]
end

function item_values.has_item_value(surface_name, item_name)
    if not surface_name then
        lib.log_error("item_values.has_item_value: surface_name is nil")
        return false
    end
    if not item_name then
        lib.log_error("item_values.has_item_value: item_name is nil")
        return false
    end
    local surface_vals = item_values.get_item_values_for_surface(surface_name)
    if not surface_vals then
        lib.log_error("item_values.has_item_value: No item values for surface " .. surface_name)
        return false
    end
    return surface_vals[item_name] ~= nil
end

---@param surface_name string
---@param items_only boolean|nil
---@param allow_coins boolean|nil
---@param quality string|nil
---@return {[string]: number}
function item_values.get_interplanetary_item_values(surface_name, items_only, allow_coins, quality)
    if items_only == nil then items_only = false end
    if allow_coins == nil then allow_coins = false end
    if not quality then quality = "normal" end

    local surface_vals = storage.item_values.values[surface_name]
    if not surface_vals then
        lib.log_error("item_values.get_interplanetary_item_values: No values found for surface " .. surface_name)
        return {}
    end
    local values = {}
    for _surface_name, _ in pairs(storage.item_values.values) do
        if _surface_name ~= surface_name then
            for _, name in pairs(item_values.get_items_sorted_by_value(_surface_name, items_only, allow_coins)) do
                if not surface_vals[name] then
                    values[name] = item_values.get_item_value(surface_name, name, true, quality)
                end
            end
        end
    end

    return values
end

function item_values.is_item_interplanetary(surface_name, item_name)
    return not item_values.has_item_value(surface_name, item_name)
end

function item_values.get_item_sell_value_bonus_from_rank(surface_name, item_name, rank_tier)
    local bonus_effect = item_ranks.get_rank_bonus_effect(rank_tier)
    local value = item_values.get_item_value(surface_name, item_name)
    return value * bonus_effect
end

function item_values.get_item_buy_value_bonus_from_rank(surface_name, item_name, rank_tier)
    local bonus_effect = item_ranks.get_rank_bonus_effect(rank_tier)
    local value = item_values.get_item_value(surface_name, item_name)
    return value / (1 + bonus_effect) - value
end

function item_values.get_boosted_item_value(surface_name, item_name, rank_tier)
    return item_values.get_item_value(surface_name, item_name) + item_values.get_item_value_bonus_from_rank(surface_name, item_name, rank_tier)
end

function item_values.get_item_values_for_surface(surface_name)
    if not surface_name then
        lib.log_error("item_values.get_item_values_for_surface: surface_name is nil")
        return
    end
    local surface_vals = storage.item_values.values[surface_name]
    if not surface_vals then
        lib.log_error("item_values.get_item_values_for_surface: No item values for surface " .. surface_name)
        return
    end
    return surface_vals
end

function item_values.get_expanded_item_values_for_surface(surface_name)
    if not surface_name then
        lib.log_error("item_values.get_expanded_item_values_for_surface: surface_name is nil")
        return
    end
    if not storage.item_values.expanded_values then
        storage.item_values.expanded_values = {}
    end
    local surface_vals = storage.item_values.expanded_values[surface_name]
    if surface_vals then
        return surface_vals
    end
    surface_vals = table.deepcopy(item_values.get_item_values_for_surface(surface_name)) or {}
    for _, _surface_vals in pairs(storage.item_values.values) do
        for item_name, _ in pairs(_surface_vals) do
            if not surface_vals[item_name] then
                surface_vals[item_name] = item_values.get_item_value(surface_name, item_name, true)
            end
        end
    end
    storage.item_values.expanded_values[surface_name] = surface_vals
    return surface_vals
end

function item_values.get_items_sorted_by_value(surface_name, items_only, allow_coins, allow_spoilable)
    if allow_coins == nil then
        allow_coins = true
    end
    if allow_spoilable == nil then
        allow_spoilable = true
    end
    local surface_vals = item_values.get_item_values_for_surface(surface_name)
    if not surface_vals then
        lib.log_error("item_values.get_items_sorted_by_value: No item values for surface " .. surface_name .. ", defaulting to empty table")
        return {}
    end
    local sorted_items = {}
    for item_name, _ in pairs(surface_vals) do
        if not items_only or prototypes.item[item_name] then
            if (allow_coins or not lib.is_coin(item_name)) and (allow_spoilable or not lib.is_spoilable(item_name)) then
                table.insert(sorted_items, item_name)
            end
        end
    end
    table.sort(sorted_items, function(a, b) return item_values.get_item_value(surface_name, a) < item_values.get_item_value(surface_name, b) end)
    return sorted_items
end

-- Return a list of item names whose values are within a ratio range of a center value
function item_values.get_items_near_value(surface_name, center_value, max_ratio, items_only, allow_coins, allow_interplanetary)
    if allow_interplanetary == nil then allow_interplanetary = false end
    if allow_coins == nil then allow_coins = true end

    local surface_vals
    if allow_interplanetary then
        surface_vals = item_values.get_expanded_item_values_for_surface(surface_name)
    else
        surface_vals = item_values.get_item_values_for_surface(surface_name)
    end

    if not surface_vals then
        lib.log_error("item_values.get_items_near_value: No item values for surface " .. surface_name .. ", defaulting to empty table")
        return {}
    end

    local item_names = {}
    local lower_bound = center_value / max_ratio
    local upper_bound = center_value * max_ratio

    for item_name, _ in pairs(surface_vals) do
        local value = item_values.get_item_value(surface_name, item_name) -- Ensure that multipliers apply
        if value <= upper_bound and value >= lower_bound and (not items_only or lib.is_item(item_name)) and (allow_coins or not lib.is_coin(item_name)) then
            table.insert(item_names, item_name)
        end
    end
    return item_names
end

-- Recalculate all item values based on their previous base of exponentiation and a new base of exponentiation
function item_values.adjust_exponential_base(old_base, new_base)
    -- TODO
end

function item_values.is_item_for_surface(item_name, surface_name)
    if not surface_name then
        return true
    end
    -- local surface_items = storage.item_values.recipe_graph.items_per_surface_lookup[surface_name]
    local surface_items = storage.trades.allowed_items_lookup[surface_name]
    if not surface_items then
        return false
    end
    return surface_items[item_name]
end



return item_values
