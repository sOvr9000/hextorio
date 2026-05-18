
local lib = require "api.lib"
local sets = require "api.sets"
local item_values = require "api.item_values"
local trade_loop_finder = require "api.trade_loop_finder"
local weighted_choice = require "api.weighted_choice"
local event_system = require "api.event_system"
local trade_generator_legacy_main = require "api.trade_generator_legacy_main"
local data_trades = require "data.trades"

local trade_generator = {}

local RANDOM_TRADE_ATTEMPTS = 10 -- Number of attempts to make when generating a random trade before giving up and returning nil.
-- DEPRECATED toggle: temporary mode switch for legacy-main sampling only.
-- Intended to be removed after comparison/sampling work is complete.
local DEFAULT_GENERATOR_MODE = "current" -- "current" | "legacy-main"
-- local DEFAULT_GENERATOR_MODE = "legacy-main" -- "current" | "legacy-main"
local generator_mode = DEFAULT_GENERATOR_MODE
local TRADE_SHAPE_LOOKUP_STORAGE_REVISION = 3

local function refresh_trade_shape_lookup_storage(force_refresh)
    if not storage or not storage.trades then return end

    if not force_refresh and storage.trades.trade_shape_lookup_storage_revision == TRADE_SHAPE_LOOKUP_STORAGE_REVISION then
        return
    end

    storage.trades.trade_shape_weights_lookup = table.deepcopy(data_trades.trade_shape_weights_lookup)
    storage.trades.deprecated_trade_shape_weights_lookup_main = table.deepcopy(data_trades.deprecated_trade_shape_weights_lookup_main)
    storage.trades.trade_shape_lookup_storage_revision = TRADE_SHAPE_LOOKUP_STORAGE_REVISION
end

---@return table weights_lookup, string lookup_name
local function get_active_weights_lookup()
    local lookup_name = "trade_shape_weights_lookup"
    local weights_lookup = storage.trades.trade_shape_weights_lookup

    if generator_mode == "legacy-main" then
        if not storage.trades.deprecated_trade_shape_weights_lookup_main then
            lib.log_error("trade_generator: deprecated legacy lookup missing in storage while mode='legacy-main'")
            return nil, "deprecated_trade_shape_weights_lookup_main"
        end
        lookup_name = "deprecated_trade_shape_weights_lookup_main"
        weights_lookup = storage.trades.deprecated_trade_shape_weights_lookup_main
    end

    return weights_lookup, lookup_name
end

---Read-only helper for diagnostics and sampling harness metadata.
---@return "current"|"legacy-main"
function trade_generator.get_generator_mode()
    return generator_mode
end

---Read-only helper for diagnostics and sampling harness metadata.
---@return "trade_shape_weights_lookup"|"deprecated_trade_shape_weights_lookup_main"
function trade_generator.get_active_weights_lookup_name()
    local _, lookup_name = get_active_weights_lookup()
    return lookup_name
end

---DEPRECATED testing helper for temporary sampling workflows.
---This mutates runtime generator mode and should not be used by gameplay logic.
---@param mode "current"|"legacy-main"
---@return boolean ok, string|nil error_message
function trade_generator.set_generator_mode_for_testing(mode)
    if mode ~= "current" and mode ~= "legacy-main" then
        return false, "Invalid mode: " .. tostring(mode)
    end
    generator_mode = mode
    if storage and storage.trades then
        storage.trades.trade_shape_weighted_choice = nil
        storage.trades.trade_shape_weighted_choice_by_group = nil
    end
    return true, nil
end

---@class TentativeTrade Similar to a Trade, but during the process of its generation and before state initialization. Particularly, output item counts are nil until determined by the generator.
---@field surface_name string
---@field input_items TentativeTradeItem[]
---@field output_items TentativeTradeItem[]

---@class TentativeTradeItem
---@field name string
---@field count int|nil Can be nil until determined by the generator.

---@class TradeGenerationParameters
---@field target_efficiency number|nil The requested ratio of item values from outputs to inputs in the generated trade.
---@field target_efficiency_epsilon number|nil The allowed error in the actual ratio of items values from outputs to inputs in the generated trade. Set to 1 to request a perfect efficiency/ratio match. Set to a number close to but above 1.0 like 1.1 to allow for ratios close to the target efficiency/ratio.
---@field item_sampling_filters StringFilters|nil The item names to forcefully include (by whitelist) or exclude (by blacklist) in the item name candidates for the random trade generator, allowing the generator to select from more or fewer items.
---@field max_stacks_per_item number|nil The maximum number of stacks allowed per item in the generated trade.  For example, if this is 2, then item count for beacons would not exceed 2*20 = 40. Can be a non-integer.
---@field max_count_per_item int|nil The maximum amount of each item allowed in the generated trade.  This feels reasonable at around 100, preventing from (e.g.) having to feed an egregious amount of items for a small return.
---@field allow_nil_return boolean|nil Whether to allow a nil trade if the generator cannot solve the item counts from a given set of items and item count constraints.  If false and the generator fails to approximate target_efficiency, then the item counts with the closest possible ratio given the other constraints are used. Defaults to true.

---@class TradeShapeWeightedItem
---@field num_inputs int
---@field num_outputs int
---@field weight number Weight of this shape. Set to 0 to disable shape selection.

---@class TradeShapeWeightsByArchetype
---@field non_coin TradeShapeWeightedItem[]|nil
---@field coin_input TradeShapeWeightedItem[]|nil
---@field coin_output TradeShapeWeightedItem[]|nil

---Replace undefined parameters with default values, modifying the table in place.
---@param params TradeGenerationParameters
local function set_trade_generation_parameter_defaults(params)
    if not params.target_efficiency then
        params.target_efficiency = 1
    end

    if not params.target_efficiency_epsilon then
        params.target_efficiency_epsilon = 1.05
    end

    if not params.item_sampling_filters then
        params.item_sampling_filters = {}
    end

    if not params.max_stacks_per_item then
        params.max_stacks_per_item = 5
    end

    if not params.max_count_per_item then
        params.max_count_per_item = 100
    end

    if params.allow_nil_return == nil then
        params.allow_nil_return = true
    end
end

---@param weights TradeShapeWeightedItem[]
---@return boolean
local function validate_flat_weights(weights)
    if type(weights) ~= "table" then
        return false
    end

    local has_positive_weight = false
    for _, obj in pairs(weights) do
        if
               type(obj.num_inputs) ~= "number"
            or type(obj.num_outputs) ~= "number"
            or type(obj.weight) ~= "number"
            or math.floor(obj.num_inputs) ~= obj.num_inputs
            or math.floor(obj.num_outputs) ~= obj.num_outputs
            or obj.num_inputs < 0
            or obj.num_inputs > 3
            or obj.num_outputs < 0
            or obj.num_outputs > 3
            or (obj.num_inputs == 0 and obj.num_outputs == 0)
            or obj.weight < 0
        then
            return false
        end
        if obj.weight > 0 then
            has_positive_weight = true
        end
    end

    return has_positive_weight
end

---@param weights TradeShapeWeightedItem[]
---@return boolean
local function validate_group_weights(weights)
    if type(weights) ~= "table" then
        return false
    end

    for _, obj in pairs(weights) do
        if
               type(obj.num_inputs) ~= "number"
            or type(obj.num_outputs) ~= "number"
            or type(obj.weight) ~= "number"
            or math.floor(obj.num_inputs) ~= obj.num_inputs
            or math.floor(obj.num_outputs) ~= obj.num_outputs
            or obj.num_inputs < 1
            or obj.num_inputs > 3
            or obj.num_outputs < 1
            or obj.num_outputs > 3
            or obj.weight < 0
        then
            return false
        end
    end

    return true
end

---@param grouped_weights TradeShapeWeightsByArchetype
---@return boolean
local function validate_grouped_trade_shape_distribution(grouped_weights)
    if type(grouped_weights) ~= "table" then
        return false
    end

    local groups = {"non_coin", "coin_input", "coin_output"}
    local has_any_positive_group = false

    for _, group_name in ipairs(groups) do
        local weights = grouped_weights[group_name]
        if weights ~= nil then
            if not validate_group_weights(weights) then
                return false
            end

            local has_group_positive_weight = false
            for _, obj in pairs(weights) do
                if obj.weight > 0 then
                    has_group_positive_weight = true
                    break
                end
            end

            if has_group_positive_weight then
                has_any_positive_group = true
            end
        end
    end

    return has_any_positive_group
end

---@param weights TradeShapeWeightedItem[]
local function set_trade_shape_distribution_legacy(weights)
    if not validate_flat_weights(weights) then
        lib.log_error("trade_generator.set_trade_shape_distribution_legacy: Invalid weights received:\n" .. serpent.block(weights))
        return
    end

    lib.log("New legacy weights set for trade shapes: " .. serpent.block(weights))
    storage.trades.trade_shape_weights = weights
    storage.trades.trade_shape_weighted_choice = nil
    storage.trades.trade_shape_weighted_choice_by_group = nil
end

---@param grouped_weights TradeShapeWeightsByArchetype
local function set_trade_shape_distribution_current(grouped_weights)
    if not validate_grouped_trade_shape_distribution(grouped_weights) then
        lib.log_error("trade_generator.set_trade_shape_distribution_current: Invalid grouped weights received:\n" .. serpent.block(grouped_weights))
        return
    end

    lib.log("New current grouped weights set for trade shapes: " .. serpent.block(grouped_weights))
    storage.trades.trade_shape_weights = grouped_weights
    storage.trades.trade_shape_weighted_choice_by_group = nil
    storage.trades.trade_shape_weighted_choice = nil
end

---@param group_name "non_coin"|"coin_input"|"coin_output"
---@return int num_inputs, int num_outputs
local function get_trade_shape_for_group_current(group_name)
    local grouped_weights = storage.trades.trade_shape_weights
    if type(grouped_weights) ~= "table" then
        lib.log_error("trade_generator.get_trade_shape_for_group_current: No grouped weights set")
        return 1, 1
    end

    local group_weights = grouped_weights[group_name]
    if type(group_weights) ~= "table" then
        lib.log_error("trade_generator.get_trade_shape_for_group_current: Missing group '" .. tostring(group_name) .. "'")
        return 1, 1
    end

    local by_group = storage.trades.trade_shape_weighted_choice_by_group
    if type(by_group) ~= "table" then
        by_group = {}
        storage.trades.trade_shape_weighted_choice_by_group = by_group
    end

    local trade_shape_wc = by_group[group_name]
    if not trade_shape_wc then
        local item_list = {}
        for _, shape_item in pairs(group_weights) do
            if shape_item.weight > 0 then
                item_list[#item_list + 1] = {
                    item = {shape_item.num_inputs, shape_item.num_outputs},
                    weight = shape_item.weight,
                }
            end
        end

        trade_shape_wc = weighted_choice.from_list(item_list)
        if not trade_shape_wc then
            lib.log_error("trade_generator.get_trade_shape_for_group_current: Failed to create weighted choice for group '" .. tostring(group_name) .. "'")
            return 1, 1
        end

        by_group[group_name] = trade_shape_wc
    end

    local item = weighted_choice.choice(trade_shape_wc)
    if not item then
        return 1, 1
    end

    return item[1], item[2]
end

---@return "non_coin"|"coin_input"|"coin_output"
local function choose_trade_archetype_current()
    local grouped_weights = storage.trades.trade_shape_weights
    local function has_positive_weight_group(group_name)
        local group = type(grouped_weights) == "table" and grouped_weights[group_name] or nil
        if type(group) ~= "table" then
            return false
        end
        for _, obj in pairs(group) do
            if obj.weight > 0 then
                return true
            end
        end
        return false
    end

    local has_non_coin = has_positive_weight_group("non_coin")
    local has_coin_input = has_positive_weight_group("coin_input")
    local has_coin_output = has_positive_weight_group("coin_output")

    local is_coin_trade = math.random() < lib.runtime_setting_value_as_number "coin-trade-chance"
    if is_coin_trade and (has_coin_input or has_coin_output) then
        local prefer_output = math.random() < lib.runtime_setting_value_as_number "sell-trade-chance"
        if prefer_output and has_coin_output then
            return "coin_output"
        end
        if (not prefer_output) and has_coin_input then
            return "coin_input"
        end
        if has_coin_input then
            return "coin_input"
        end
        return "coin_output"
    end

    if has_non_coin then
        return "non_coin"
    end
    if has_coin_input then
        return "coin_input"
    end
    return "coin_output"
end

---Sample random item names for inputs and outputs of a trade based on a central item value. Can generate coin trades
---@param surface_name string
---@param volume number The central item value.
---@param archetype "non_coin"|"coin_input"|"coin_output"
---@param params TradeGenerationParameters|nil
---@param allow_untradable boolean|nil Whether to include items that are initially untradable on the given surface. Defaults to false.
---@param include_item string|nil An item name to be forcefully included in the returned input or output items.
---@return string[], string[]
local function generate_item_names_for_trade(surface_name, volume, archetype, params, allow_untradable, include_item)
    if allow_untradable == nil then allow_untradable = false end
    if not params then params = {} end
    set_trade_generation_parameter_defaults(params)

    local ratio
    if params.target_efficiency >= 1 then
        ratio = 10 * params.target_efficiency
    else
        ratio = 10 / params.target_efficiency
    end

    local possible_items = item_values.get_items_near_value(surface_name, volume, ratio, true, false, allow_untradable)

    -- Apply whitelist filter
    if params.item_sampling_filters.whitelist then
        possible_items = lib.filter_whitelist(possible_items, function(item_name)
            return params.item_sampling_filters.whitelist[item_name]
        end)
    end

    -- Apply blacklist filter
    if params.item_sampling_filters.blacklist then
        possible_items = lib.filter_blacklist(possible_items, function(item_name)
            return params.item_sampling_filters.blacklist[item_name]
        end)
    end

    if #possible_items == 0 then
        lib.log_error("trade_generator.generate_item_names: No items found near value " .. volume)
        return {}, {}
    end

    local set = sets.new()
    if include_item then
        sets.add(set, include_item)
    end
    for i = 1, 6 do
        if #possible_items == 0 then break end
        local item_name = table.remove(possible_items, math.random(1, #possible_items))
        sets.add(set, item_name)
    end

    local num_inputs, num_outputs = get_trade_shape_for_group_current(archetype)
    local has_coin_input = archetype == "coin_input"
    local has_coin_output = archetype == "coin_output"

    local num_non_coin_inputs = has_coin_input and math.max(0, num_inputs - 1) or num_inputs
    local num_non_coin_outputs = has_coin_output and math.max(0, num_outputs - 1) or num_outputs
    local total_non_coin_items = num_non_coin_inputs + num_non_coin_outputs

    local trade_items = sets.to_array(set)
    if #trade_items < total_non_coin_items then
        lib.log_error(
            "trade_generator.generate_item_names: Not enough items selected for trade shape "
                .. num_inputs
                .. "-"
                .. num_outputs
                .. " archetype='"
                .. archetype
                .. "'; selected="
                .. #trade_items
                .. ", required="
                .. total_non_coin_items
        )
        return {}, {}
    end

    if include_item then
        -- Keep include_item in the non-coin slots so forced coin placement never replaces it.
        local idx_old = lib.table_index(trade_items, include_item)
        local idx_new = math.random(1, total_non_coin_items)
        trade_items[idx_new], trade_items[idx_old] = trade_items[idx_old], trade_items[idx_new]
    end

    local input_item_names = {}
    local output_item_names = {}
    local i = 1
    local input_offset = 0
    local output_offset = 0
    if has_coin_input then
        input_item_names[1] = storage.coin_tiers.COIN_NAMES[1]
        input_offset = 1
    end
    if has_coin_output then
        output_item_names[1] = storage.coin_tiers.COIN_NAMES[1]
        output_offset = 1
    end

    for k = 1, num_non_coin_inputs do
        input_item_names[k + input_offset] = trade_items[i]
        i = i + 1
    end
    for k = 1, num_non_coin_outputs do
        output_item_names[k + output_offset] = trade_items[i]
        i = i + 1
    end

    return input_item_names, output_item_names
end

--- 

function trade_generator.register_events()
    event_system.register("runtime-setting-changed-base-trade-efficiency", function()
        storage.trades.base_trade_efficiency = lib.runtime_setting_value_as_number "base-trade-efficiency"
    end)
    event_system.register("runtime-setting-changed-trade-complexity", function()
        trade_generator.init()
    end)
end

function trade_generator.init()
    refresh_trade_shape_lookup_storage(false)

    local complexity = lib.runtime_setting_value_as_string "trade-complexity"
    local weights_lookup, lookup_name = get_active_weights_lookup()
    if type(weights_lookup) ~= "table" then
        lib.log_error("trade_generator.init: Missing active weights lookup '" .. tostring(lookup_name) .. "'")
        return
    end

    local weights = weights_lookup[complexity]
    if type(weights) ~= "table" then
        lib.log_error("trade_generator.init: Missing complexity '" .. tostring(complexity) .. "' in lookup '" .. tostring(lookup_name) .. "'")
        return
    end

    if generator_mode == "legacy-main" then
        set_trade_shape_distribution_legacy(weights)
    else
        set_trade_shape_distribution_current(weights)
    end
end

---Generate a trade between select items and solve for the item counts, returning a TentativeTrade object ready for initialization as a complete Trade object.
---
---Returns nil if the item names and params.target_efficiency do not allow for a valid solution.
---@param surface_name string
---@param input_item_names string[]
---@param output_item_names string[]
---@param params TradeGenerationParameters|nil
---@return TentativeTrade|nil
local function generate_from_item_names_current(surface_name, input_item_names, output_item_names, params)
    if not params then params = {} end
    set_trade_generation_parameter_defaults(params)

    local surface = game.get_surface(surface_name)
    if not surface then
        lib.log_error("trade_generator.generate_from_item_names: Invalid surface name: " .. surface_name)
        return
    end

    if lib.is_space_platform(surface) then
        lib.log_error("trade_generator.generate_from_item_names: Attempting to create a trade for a space platform (illegal) with input_item_names = " .. serpent.line(input_item_names) .. ", output_item_names = " .. serpent.line(output_item_names))
    end

    -- TODO: this code does not match the expected types for the function. Should remove. 
    if type(input_item_names) == "string" then
        input_item_names = {input_item_names}
    end
    if type(output_item_names) == "string" then
        output_item_names = {output_item_names}
    end

    local function is_empty(t) return type(t) ~= "table" or not next(t) end
    local is_input_empty = is_empty(input_item_names)
    local is_output_empty = is_empty(output_item_names)
    if is_input_empty and is_output_empty then
        lib.log_error("trade_generator.generate_from_item_names: Empty input and output item names received, with input_item_names = " .. serpent.line(input_item_names) .. ", output_item_names = " .. serpent.line(output_item_names))
        return
    end
    if is_input_empty then input_item_names = {storage.coin_tiers.COIN_NAMES[1]} end
    if is_output_empty then output_item_names = {storage.coin_tiers.COIN_NAMES[1]} end

    for i = 1, #input_item_names do
        if lib.is_coin(input_item_names[i]) then
            input_item_names[i] = storage.coin_tiers.COIN_NAMES[1]
        end
    end
    for i = 1, #output_item_names do
        if lib.is_coin(output_item_names[i]) then
            output_item_names[i] = storage.coin_tiers.COIN_NAMES[1]
        end
    end

    local input_items = {}
    for i, name in ipairs(input_item_names) do
        input_items[i] = {name = name}
    end
    local output_items = {}
    for i, name in ipairs(output_item_names) do
        output_items[i] = {name = name}
    end

    ---@type TentativeTrade
    local tentative = {
        surface_name = surface_name,
        input_items = input_items,
        output_items = output_items,
    }

    local solved = trade_generator.solve_item_counts(surface_name, tentative, params)
    if not solved and params.allow_nil_return then
        return nil
    end

    return tentative
end

---Generate a random trade for a hex by sampling item names near a given value, retrying until the result creates no simple two-trade loops with existing hex trades.
---
---Returns nil if a loop-free trade cannot be generated within the attempt limit.
---@param surface_name string
---@param existing_trades Trade[] The trades already belonging to the hex, used for loop detection.
---@param volume number The central item value for item name sampling.
---@param params TradeGenerationParameters|nil
---@param allow_untradable boolean|nil Whether to include items that are initially untradable on the given surface. Defaults to false.
---@param include_item string|nil An item name to be forcefully included in the trade.
---@return TentativeTrade|nil
local function generate_random_current(surface_name, existing_trades, volume, params, allow_untradable, include_item)
    params = params and table.deepcopy(params) or {}
    set_trade_generation_parameter_defaults(params)

    ---@type (Trade|TentativeTrade)[]
    local candidate_trades = table.deepcopy(existing_trades)
    local slot = #candidate_trades + 1

    -- Blacklist input items in existing trades (making the spider network order fulfillment less finicky)
    -- Two trades in a hex core can still have overlapping inputs if the guaranteed trades around the spawn hex happen to be like that.
    if not params.item_sampling_filters.blacklist then
        params.item_sampling_filters.blacklist = {}
    end
    for _, trade in pairs(candidate_trades) do
        for _, input_item in pairs(trade.input_items) do
            params.item_sampling_filters.blacklist[input_item.name] = true
        end
    end

    for _ = 1, RANDOM_TRADE_ATTEMPTS do
        local archetype = choose_trade_archetype_current()
        local input_item_names, output_item_names = generate_item_names_for_trade(surface_name, volume, archetype, params, allow_untradable, include_item)

        local tentative = generate_from_item_names_current(surface_name, input_item_names, output_item_names, params)

        if tentative then
            candidate_trades[slot] = tentative
            if not next(trade_loop_finder.find_simple_loops(candidate_trades)) then
                return tentative
            end
        end
    end

    lib.log_error("trade_generator.generate_random: A trade failed to generate within " .. RANDOM_TRADE_ATTEMPTS .. " attempts.")
end

function trade_generator.generate_from_item_names(surface_name, input_item_names, output_item_names, params)
    if generator_mode == "legacy-main" then
        return trade_generator_legacy_main.generate_from_item_names(
            surface_name,
            input_item_names,
            output_item_names,
            params,
            trade_generator.solve_item_counts
        )
    end

    return generate_from_item_names_current(surface_name, input_item_names, output_item_names, params)
end

function trade_generator.generate_random(surface_name, existing_trades, volume, params, allow_untradable, include_item)
    if generator_mode == "legacy-main" then
        return trade_generator_legacy_main.generate_random(
            surface_name,
            existing_trades,
            volume,
            params,
            allow_untradable,
            include_item,
            trade_generator.solve_item_counts
        )
    end

    return generate_random_current(surface_name, existing_trades, volume, params, allow_untradable, include_item)
end

---Given a trade with undefined item counts, attempt to set the counts to the values which best preserve the specified input-to-output value ratio (`params.target_efficiency`).
---@param surface_name string
---@param trade TentativeTrade
---@param params TradeGenerationParameters|nil
---@return boolean solved Whether `params.target_efficiency` could be approximated with item counts while respecting item count constraints.
function trade_generator.solve_item_counts(surface_name, trade, params)
    if not params then params = {} end
    set_trade_generation_parameter_defaults(params)

    -- Convert coins to lowest tier
    local coin_name = storage.coin_tiers.COIN_NAMES[1]
    for _, input_item in pairs(trade.input_items) do
        if lib.is_coin(input_item.name) then
            input_item.name = coin_name
            break
        end
    end

    for _, output_item in pairs(trade.output_items) do
        if lib.is_coin(output_item.name) then
            output_item.name = coin_name
            break
        end
    end

    -- Obtain numerator/denominator for target efficiency
    -- TODO: cache the result for reuse when the target efficiency is known to be unchanged
    local max_num_den = 50
    local num, den = lib.get_rational_approximation(params.target_efficiency, 1.04, max_num_den, max_num_den)

    -- Apply upscale to num : den ratio
    -- This helps break monotony in item counts, tending to frequently settle around 1
    local max_scale = math.min(8, math.floor(max_num_den / math.max(num, den)))

    -- Ensure that the upscale does not exceed item count constraints (mainly stack counts)
    for _, input_item in pairs(trade.input_items) do
        if not lib.is_coin(input_item.name) then
            max_scale = math.min(max_scale, math.floor(params.max_count_per_item / den))

            local stack_size = (prototypes.item[input_item.name] or {}).stack_size
            if stack_size then
                max_scale = math.min(max_scale, math.floor(stack_size * params.max_stacks_per_item / den))
            end
        end
    end

    for _, output_item in pairs(trade.output_items) do
        if not lib.is_coin(output_item.name) then
            max_scale = math.min(max_scale, math.floor(params.max_count_per_item / num))

            local stack_size = (prototypes.item[output_item.name] or {}).stack_size
            if stack_size then
                max_scale = math.min(max_scale, math.floor(stack_size * params.max_stacks_per_item / num))
            end
        end
    end

    max_scale = math.max(1, max_scale) -- Just in case it becomes zero.

    local num_den_upscale = math.random(1, max_scale)
    num = num * num_den_upscale
    den = den * num_den_upscale

    -- Initialize item counts based on num / den, and create lookup tables for item values (better performance), and fetch item stack sizes
    local total_input_value = 0
    local input_item_values = {}
    local input_stack_sizes = {}
    for i, input_item in ipairs(trade.input_items) do
        local val = item_values.get_item_value(surface_name, input_item.name)
        total_input_value = total_input_value + val
        input_item_values[i] = val
        input_item.count = den

        local prot = prototypes.item[input_item.name]
        if prot then
            input_stack_sizes[i] = prot.stack_size
        end
    end

    local total_output_value = 0
    local output_item_values = {}
    local output_stack_sizes = {}
    for i, output_item in ipairs(trade.output_items) do
        local val = item_values.get_item_value(surface_name, output_item.name)
        total_output_value = total_output_value + val
        output_item_values[i] = val
        output_item.count = num

        local prot = prototypes.item[output_item.name]
        if prot then
            output_stack_sizes[i] = prot.stack_size
        end
    end

    total_input_value = total_input_value * den
    total_output_value = total_output_value * num

    -- Scale up if total values are under one hex coin
    local min_total_value = storage.item_values.base_coin_value or 10
    if total_input_value < min_total_value or total_output_value < min_total_value then
        local scale = math.max(math.ceil(min_total_value / total_input_value), math.ceil(min_total_value / total_output_value))

        for _, input_item in pairs(trade.input_items) do
            input_item.count = input_item.count * scale
        end

        for _, output_item in pairs(trade.output_items) do
            output_item.count = output_item.count * scale
        end

        total_input_value = total_input_value * scale
        total_output_value = total_output_value * scale
    end

    -- Increment lower-valued items, decrement higher-valued items, with some randomness
    local randomness = 0.125 -- How much to vary the item counts from the initial num : den counts
    local new_total_input_value = 0
    for i, input_item in ipairs(trade.input_items) do
        local item_value = input_item_values[i]
        local value_contribution = item_value * input_item.count / total_input_value

        -- Apply random offset to contribution
        value_contribution = math.min(1, value_contribution * (math.random() * 0.4 + 0.8))

        local new_count = input_item.count
        if value_contribution > 0.5 then
            new_count = new_count * (1 - randomness + 2 * randomness * value_contribution)
        else
            new_count = new_count / (1 + randomness - 2 * randomness * value_contribution)
        end
        new_count = math.max(1, math.floor(0.5 + new_count))

        new_total_input_value = new_total_input_value + new_count * item_value
        input_item.count = new_count
    end
    total_input_value = new_total_input_value

    local new_total_output_value = 0
    for i, output_item in ipairs(trade.output_items) do
        local item_value = output_item_values[i]
        local value_contribution = item_value * output_item.count / total_output_value

        -- Apply random offset to contribution
        value_contribution = math.min(1, value_contribution * (math.random() * 0.4 + 0.8))

        local new_count = output_item.count
        if value_contribution > 0.5 then
            new_count = new_count * (1 - randomness + 2 * randomness * value_contribution)
        else
            new_count = new_count / (1 + randomness - 2 * randomness * value_contribution)
        end
        new_count = math.max(1, math.floor(0.5 + new_count))

        new_total_output_value = new_total_output_value + new_count * item_value
        output_item.count = new_count
    end
    total_output_value = new_total_output_value

    -- Special case: One of the sides of the trade consists of only coins (then this is a fast, exact calculation).
    if #trade.input_items == 1 and trade.input_items[1].name == storage.coin_tiers.COIN_NAMES[1] then
        -- Normally +0.5 to round, but this is +random() so that it chooses the closer value more often but sometimes the farther value to add variation.
        trade.input_items[1].count = math.max(1, math.floor(math.random() + total_output_value / (params.target_efficiency * input_item_values[1])))
        return true
    elseif #trade.output_items == 1 and trade.output_items[1].name == storage.coin_tiers.COIN_NAMES[1] then
        trade.output_items[1].count = math.max(1, math.floor(math.random() + total_input_value * params.target_efficiency / output_item_values[1]))
        return true
    end

    -- For varying how item counts are traversed so that found solutions can be more varied.
    local PERMUTATIONS = {
        {1, 2, 3},
        {1, 3, 2},
        {2, 1, 3},
        {2, 3, 1},
        {3, 1, 2},
        {3, 2, 1},
    }

    -- Start iterative search
    -- Make small adjustments to each input or output count if it better approximates target efficiency
    local working_inputs = table.deepcopy(trade.input_items)
    local working_outputs = table.deepcopy(trade.output_items)
    local target_ratio = math.sqrt(params.target_efficiency)
    local epsilon = params.target_efficiency_epsilon
    local epsilon_inv = 1 / epsilon

    local solved = false
    local max_iterations = 100
    for iteration = 1, max_iterations do
        local current_efficiency = total_output_value / total_input_value

        local ratio = current_efficiency / params.target_efficiency
        if ratio <= epsilon and ratio >= epsilon_inv then
            solved = true
            break
        end

        local geo_mean = math.sqrt(total_input_value * total_output_value)
        local target_total_input_value = geo_mean / target_ratio
        local target_total_output_value = geo_mean * target_ratio

        local changed = false
        for j, t in ipairs {
            {working_inputs, input_item_values, input_stack_sizes, total_input_value, target_total_input_value, working_outputs, target_total_output_value},
            {working_outputs, output_item_values, output_stack_sizes, total_output_value, target_total_output_value, working_inputs, target_total_input_value},
        } do
            local working_items = t[1]
            local other_working_items = t[6]
            local item_vals = t[2]
            local item_stack_sizes = t[3]
            local total_value = t[4]
            local target_total_value = t[5]
            local other_total_value = t[7]

            local is_other_side_minimal = true
            for _, item in pairs(other_working_items) do
                if item.count > 1 then
                    is_other_side_minimal = false
                    break
                end
            end

            if is_other_side_minimal then
                if j == 1 then
                    target_total_value = other_total_value / params.target_efficiency
                else
                    target_total_value = other_total_value * params.target_efficiency
                end

                local cur_ratio = total_output_value / total_input_value
                if (cur_ratio <= epsilon and cur_ratio >= epsilon_inv) or math.random() < 0.666667 then
                    -- This final scaling can help escape local minima typically found with when it gets stuck at 1x of anything
                    local scale = math.random(2, 3)

                    for _, item in pairs(working_items) do
                        item.count = item.count * scale
                    end
                    for _, item in pairs(other_working_items) do
                        item.count = item.count * scale
                    end

                    total_input_value = total_input_value * scale
                    total_output_value = total_output_value * scale

                    changed = true
                    break
                end
            end

            local perm = PERMUTATIONS[math.random(1, #PERMUTATIONS)]
            for _, cur_index in pairs(perm) do
                if cur_index <= #working_items then
                    local item = working_items[cur_index]
                    local item_value = item_vals[cur_index]
                    local stack_size = item_stack_sizes[cur_index]

                    local sum_of_other_values = total_value - item_value * item.count
                    local new_count = math.max(1, math.floor(0.5 + (target_total_value - sum_of_other_values) / item_value))

                    if not lib.is_coin(item.name) then
                        new_count = math.min(params.max_count_per_item or 100, new_count)
                        if stack_size then
                            new_count = math.min(params.max_stacks_per_item * stack_size, new_count)
                        end
                    end

                    if new_count ~= item.count then
                        if j == 1 then
                            total_input_value = total_value + (new_count - item.count) * item_value
                        else
                            total_output_value = total_value + (new_count - item.count) * item_value
                        end

                        item.count = new_count

                        changed = true
                        break
                    end
                end
            end
        end

        if not changed then
            solved = iteration < max_iterations
            break
        end
    end

    trade.input_items = working_inputs
    trade.output_items = working_outputs

    return solved
end

return trade_generator
