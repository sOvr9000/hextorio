
local lib = require "api.lib"
local item_ranks = require "api.item_ranks"
local event_system = require "api.event_system"
local coin_tiers   = require "api.coin_tiers"
local sets         = require "api.sets"

local item_values = {}



function item_values.register_events()
    event_system.register("command-set-item-value", function(player, params)
        local surface_name = params[1]
        local item_name = params[2]
        local value = params[3]

        if lib.is_coin(item_name) then
            player.print {"hextorio.command-cannot-modify-coin-value"}
            return
        end

        if value <= 0 then
            player.print {"hextorio.command-invalid-item-value"}
            return
        end

        if not storage.SUPPORTED_PLANETS[surface_name] then
            player.print {"hextorio.command-invalid-surface"}
            return
        end

        storage.item_values.raw_values[surface_name] = storage.item_values.raw_values[surface_name] or {}
        storage.item_values.raw_values[surface_name][item_name] = value * (storage.item_values.base_coin_value or 10)

        player.print {"hextorio.new-raw-value-set", lib.get_rich_text(item_name), lib.get_rich_text(surface_name), coin_tiers.coin_to_text(coin_tiers.from_base_value(value), false, 4)}
    end)

    event_system.register("command-get-item-value", function(player, params)
        local surface_name = params[1]
        local item_name = params[2]
        local quality = params[3] or "normal"

        if not storage.item_values.values[surface_name] then
            player.print {"hextorio.command-invalid-surface"}
            return
        end

        if not item_values.has_item_value("nauvis", item_name, true) then
            player.print {"hextorio.no-value-found", item_name}
            return
        end

        local value = item_values.get_item_value(surface_name, item_name, true, quality) / (storage.item_values.base_coin_value or 10)
        local source = (storage.item_values.sources and storage.item_values.sources[surface_name] or {})[item_name]

        local str = {"",
            {"hextorio.get-item-value-result", lib.get_rich_text(item_name), lib.get_rich_text(surface_name), coin_tiers.coin_to_text(coin_tiers.from_base_value(value), false, 4)},
            "\n",
            lib.get_item_value_source_string(source)
        }

        player.print(str)
    end)

    event_system.register("command-remove-item-value", function(player, params)
        local surface_name = params[1]
        local item_name = params[2]

        if lib.is_coin(item_name) then return end

        if surface_name and not storage.SUPPORTED_PLANETS[surface_name] then
            player.print {"hextorio.command-invalid-surface"}
            return
        end

        local surface_names
        if not surface_name then
            surface_names = sets.to_array(storage.SUPPORTED_PLANETS)
        else
            surface_names = {surface_name}
        end

        local has_raw = false
        for _, sn in pairs(surface_names) do
            if (storage.item_values.raw_values[sn] or {})[item_name] then has_raw = true; break end
        end

        if not has_raw and not item_values.has_item_value("nauvis", item_name, true) then
            player.print {"hextorio.no-value-found", item_name}
            return
        end

        for _, _surface_name in pairs(surface_names) do
            storage.item_values.values[_surface_name][item_name] = nil
            if storage.item_values.raw_values[_surface_name] then
                storage.item_values.raw_values[_surface_name][item_name] = nil
            end
        end

        if #surface_names == 1 then
            player.print {"hextorio.removed-value", lib.get_rich_text(item_name), lib.get_rich_text(surface_names[1])}
        else
            player.print {"hextorio.removed-all-values", item_name}
        end
    end)

    event_system.register("command-export-item-values", function(player, params)
        local sources = storage.item_values.sources or {}

        local function filter_coins(planet_table)
            local filtered = {}
            for item_name, v in pairs(planet_table) do
                if not lib.is_coin(item_name) then
                    filtered[item_name] = v
                end
            end
            return filtered
        end

        local filtered_values = {}
        local filtered_sources = {}
        for planet, planet_vals in pairs(storage.item_values.values) do
            filtered_values[planet] = filter_coins(planet_vals)
            if sources[planet] then
                filtered_sources[planet] = filter_coins(sources[planet])
            end
        end

        local recipe_tree = lib.get_recipe_tree()
        local used_recipes = {}
        for _, planet_sources in pairs(filtered_sources) do
            for _, source in pairs(planet_sources) do
                if source.type == "recipe" and source.recipe_name and recipe_tree[source.recipe_name] then
                    used_recipes[source.recipe_name] = recipe_tree[source.recipe_name]
                end
            end
        end

        local export_data = {
            version = 2,
            values = filtered_values,
            sources = filtered_sources,
            recipes = used_recipes,
        }

        local json = helpers.table_to_json(export_data)
        local str = helpers.encode_string(json)

        local filename = "all-item-values-encoded-json.txt"
        helpers.write_file(filename, str, false, player.index)
        player.print {"hextorio.item-values-exported", "Factorio/script-output/" .. filename}
    end)

    event_system.register("command-import-item-values", function(player, params)
        local str = params[1]

        local json = helpers.decode_string(str)
        if not json then
            player.print {"hextorio.command-invalid-encoded-string"}
            return
        end

        local t = helpers.json_to_table(json)
        if not t or type(t) ~= "table" then
            player.print {"hextorio.command-invalid-encoded-string"}
            return
        end

        -- Unwrap versioned exports
        if t.version and t.version >= 2 then
            t = t.values
            if not t or type(t) ~= "table" then
                player.print {"hextorio.command-invalid-encoded-string"}
                return
            end
        end

        -- Verify integrity
        if not t.nauvis or not t.vulcanus or not t.fulgora or not t.gleba or not t.aquilo then
            player.print {"hextorio.command-not-enough-planets"}
        end

        local errored = false

        for surface_name, values in pairs(t) do
            if surface_name ~= "nauvis" and surface_name ~= "vulcanus" and surface_name ~= "fulgora" and surface_name ~= "gleba" and surface_name ~= "aquilo" then
                lib.log("Removing item values entry: " .. surface_name .. "\nOnly Space Age planets (lower case) are accepted.")
                t[surface_name] = nil
            else
                for item_name, value in pairs(values) do
                    if type(item_name) ~= "string" then
                        errored = true
                        lib.log("Invalid data type for item name on " .. surface_name .. ": " .. type(item_name))
                        values[item_name] = nil
                    elseif type(value) ~= "number" then
                        errored = true
                        lib.log("Invalid data type for value of \"" .. item_name .. "\" on " .. surface_name .. ": " .. type(item_name))
                        values[item_name] = nil
                    elseif value <= 0 then
                        errored = true
                        lib.log("Zero or nonnegative item value for \"" .. item_name .. "\" on " .. surface_name .. " is unallowed: " .. value)
                        values[item_name] = nil
                    elseif not prototypes.item[item_name] and not prototypes.fluid[item_name] then
                        errored = true
                        lib.log("Item/fluid of name \"" .. item_name .. "\" on " .. surface_name .. " has no item or fluid prototype.")
                        values[item_name] = nil
                    end
                end
            end
        end

        item_values.set_item_values(t)

        event_system.trigger("post-import-item-values-command", player, params)

        if errored then
            player.print {"hextorio.command-some-item-values-invalid"}
        else
            player.print {"hextorio.item-values-imported"}
        end
    end)

    event_system.register("item-values-recalculated", function()
        storage.item_values.awaiting_solver = nil
    end)
end

---Automatically calculate item values for coins on a given surface.
---@param surface_vals {[string]: number}
function item_values.init_coin_values(surface_vals)
    local base_coin_name = storage.coin_tiers.COIN_NAMES[1] -- Should always be "hex-coin", but for algorithmic correctness, this is used.
    surface_vals[base_coin_name] = 10
    local coin_val = surface_vals[base_coin_name]
    for i = 2, #storage.coin_tiers.COIN_NAMES do
        local coin_name = storage.coin_tiers.COIN_NAMES[i]
        coin_val = coin_val * storage.coin_tiers.TIER_SCALING
        surface_vals[coin_name] = coin_val
    end
end

---Return whether the values have been calculated at least once.
---@return boolean
function item_values.is_ready()
    return storage.item_values.awaiting_solver == nil
end

---Get the value of an item on a given surface.
---@param surface_name string
---@param item_name string
---@param allow_interplanetary boolean|nil
---@param quality_name string|nil
---@return integer
function item_values.get_item_value(surface_name, item_name, allow_interplanetary, quality_name)
    if not storage.SUPPORTED_PLANETS[surface_name] then
        lib.log_error("item_values.get_item_value: surface not supported: " .. surface_name .. ", defaulting to 1")
        return 1
    end

    if not quality_name then
        quality_name = "normal"
    end
    local quality_mult = lib.get_quality_value_scale(quality_name)

    local surface_vals = item_values.get_item_values_for_surface(surface_name, true)
    if not surface_vals then
        lib.log_error("item_values.get_item_value: No item values for surface " .. surface_name .. ", defaulting to 1")
        return 1
    end

    local val = surface_vals[item_name]
    if not val then
        if lib.is_coin(item_name) then
            item_values.init_coin_values(surface_vals)
            return surface_vals[item_name] * quality_mult
        end
        lib.log_error("item_values.get_item_value: Unknown item value for " .. item_name .. " on surface " .. surface_name .. ", defaulting to 1")
        val = 1
    end

    return val * quality_mult
end

---Get the lowest value of an item across all surfaces.
---@param item_name string
---@return number|nil
function item_values.get_minimal_item_value(item_name)
    local min_vals = storage.item_values.minimal_values
    if not min_vals then
        if storage.item_values.awaiting_solver then
            lib.log_error("item_values.get_minimal_item_value: Cannot calculate minimal item values until item value solver finishes")
            return
        end

        -- Need to compute min values for all items
        min_vals = {}
        for _, surface_vals in pairs(storage.item_values.values) do
            for _item_name, val in pairs(surface_vals) do
                min_vals[_item_name] = math.min(min_vals[_item_name] or val, val)
            end
        end
        storage.item_values.minimal_values = min_vals
    end

    local min_val = min_vals[item_name]
    if not min_val then
        lib.log_error("item_values.get_minimal_item_value: No item value found for " .. item_name .. " on any surface")
        return
    end

    return min_val
end

---Return whether an item has a defined value on the given surface.  If allow_interplanetary, check all surfaces for a value (use surface_name="nauvis" as a dummy value).
---@param surface_name string
---@param item_name string
---@param allow_untradable boolean|nil Defaults to true
---@return boolean
function item_values.has_item_value(surface_name, item_name, allow_untradable)
    if not lib.is_vanilla_planet_name(surface_name) then
        return false
    end

    local surface_vals = item_values.get_item_values_for_surface(surface_name)
    if not surface_vals then
        lib.log_error("item_values.has_item_value: No item values for surface " .. surface_name)
        return false
    end

    if allow_untradable == nil then allow_untradable = true end

    if not allow_untradable then
        if not item_values.is_item_tradable(surface_name, item_name) then
            return false
        end
    else
        local min_val = item_values.get_minimal_item_value(item_name)
        if min_val and min_val > 0 then
            return true
        end
    end


    return false
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
    if not storage.item_values.is_tradable or not storage.item_values.is_tradable[surface_name] then
        return values
    end

    local tradable = storage.item_values.is_tradable[surface_name]
    for _surface_name, _surface_vals in pairs(storage.item_values.values) do
        if _surface_name ~= surface_name then
            for item_name, _ in pairs(_surface_vals) do
                if not tradable[item_name] and not values[item_name] then
                    values[item_name] = item_values.get_item_value(surface_name, item_name, true, quality)
                end
            end
        end
    end

    return values
end

---Return whether an item on a surface can only be obtained by importing an item from some other surface.
---@param surface_name string
---@param item_name string
---@return boolean
function item_values.is_item_interplanetary(surface_name, item_name)
    local ip = storage.item_values.is_interplanetary
    if not ip then return false end
    local surface_ip = ip[surface_name]
    return surface_ip ~= nil and surface_ip[item_name] == true
end

---Return whether an item can be traded on a surface. An item is tradable if it's
---locally produceable, or if no planet can produce it from local raws and this
---planet has a recipe for it.
---@param surface_name string
---@param item_name string
---@return boolean
function item_values.is_item_tradable(surface_name, item_name)
    local t = storage.item_values.is_tradable
    if not t then return false end
    local surface_t = t[surface_name]
    return surface_t ~= nil and surface_t[item_name] == true
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

---Return the mapping of all items to their values for a given surface.
---@param surface_name string
---@param allow_interplanetary boolean|nil Defaults to true
---@return {[string]: number}|nil
function item_values.get_item_values_for_surface(surface_name, allow_interplanetary)
    if not surface_name then
        lib.log_error("item_values.get_item_values_for_surface: surface_name is nil")
        return
    end

    local surface_vals = storage.item_values.values[surface_name]
    if not surface_vals then
        lib.log_error("item_values.get_item_values_for_surface: No item values for surface " .. surface_name)
        return
    end

    if allow_interplanetary == nil then allow_interplanetary = true end

    if not allow_interplanetary then
        local local_items_storage = storage.item_values.local_items
        if not local_items_storage then
            local_items_storage = {}
            storage.item_values.local_items = local_items_storage
        end

        local surface_local_items = local_items_storage[surface_name]
        if not surface_local_items then
            -- Filter out interplanetary items
            surface_local_items = {}
            for item_name, value in pairs(surface_vals) do
                if not item_values.is_item_interplanetary(surface_name, item_name) then
                    surface_local_items[item_name] = value
                end
            end
            local_items_storage[surface_name] = surface_local_items
        end

        return surface_local_items
    end

    return surface_vals
end

---Get a list of item names sorted by their values on a given surface.
---@param surface_name string
---@param items_only boolean|nil Defaults to false
---@param tradable_only boolean|nil Defaults to false
---@param allow_coins boolean|nil Defaults to true
---@param allow_spoilable boolean|nil Defaults to true
---@return string[]
function item_values.get_items_sorted_by_value(surface_name, items_only, tradable_only, allow_coins, allow_spoilable)
    if not lib.is_vanilla_planet_name(surface_name) then
        lib.log_error("item_values.get_items_sorted_by_value: surface not supported: " .. surface_name)
        return {}
    end

    if allow_coins == nil then
        allow_coins = true
    end
    if allow_spoilable == nil then
        allow_spoilable = true
    end

    local surface_vals
    if tradable_only then
        surface_vals = item_values.get_tradable_items(surface_name)
    else
        surface_vals = item_values.get_item_values_for_surface(surface_name, false)
    end
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
    -- log("sorted item values on " .. surface_name .. " (tradable only = " .. tostring(tradable_only) .. "):\n" .. serpent.block(sorted_items))

    return sorted_items
end

---Return a list of item names whose values are within a ratio range of a center value
---@param surface_name string
---@param center_value number
---@param max_ratio number
---@param items_only boolean|nil Defaults to false
---@param allow_coins boolean|nil Defaults to true
---@param allow_interplanetary boolean|nil Defaults to true
---@return string[]
function item_values.get_items_near_value(surface_name, center_value, max_ratio, items_only, allow_coins, allow_interplanetary)
    if not lib.is_vanilla_planet_name(surface_name) then
        lib.log_error("item_values.get_items_near_value: surface not supported: " .. surface_name)
        return {}
    end

    if allow_interplanetary == nil then allow_interplanetary = true end
    if allow_coins == nil then allow_coins = true end

    local surface_vals = item_values.get_item_values_for_surface(surface_name, allow_interplanetary)

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

---Return the set of all tradable items on a surface.
---@param surface_name string
---@return {[string]: boolean}
function item_values.get_tradable_items(surface_name)
    local tradable_storage = storage.item_values.tradable_items
    if not tradable_storage then
        tradable_storage = {}
        storage.item_values.tradable_items = tradable_storage
    end

    local surface_tradable_items = tradable_storage[surface_name]
    if not surface_tradable_items then
        surface_tradable_items = {}
        for item_name, flag in pairs((storage.item_values.is_tradable or {})[surface_name] or {}) do
            if flag then
                surface_tradable_items[item_name] = true
            end
        end
        tradable_storage[surface_name] = surface_tradable_items
    end

    return surface_tradable_items
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

---Set all item values to the given data.
---@param new_item_values {[string]: {[string]: number}}
function item_values.set_item_values(new_item_values)
    storage.item_values.values = new_item_values
    storage.item_values.minimal_values = nil
end

function item_values.migrate_old_data()
    item_values.init()
end



return item_values
