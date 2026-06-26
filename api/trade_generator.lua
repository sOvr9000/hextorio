
local lib = require "api.lib"
local sets = require "api.sets"
local item_values = require "api.item_values"
local trade_loop_finder = require "api.trade_loop_finder"
local weighted_choice = require "api.weighted_choice"
local event_system = require "api.event_system"

local trade_generator = {}



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
---@field scale_target_efficiency_by_items boolean|nil Whether to automatically multiply target_efficiency by `1 + setting_value * total_items`, where `total_items` is the total number of unique item types in the trade, and `setting_value` is the value of the setting `"hextorio-trade-efficiency-per-item"`.  If the setting value is negative, the target_efficiency is instead divided by `1 - setting_value * total_items`.

---@class TradeShapeWeightedItem
---@field num_inputs int
---@field num_outputs int
---@field weight number



function trade_generator.register_events()
    event_system.register("runtime-setting-changed-base-trade-efficiency", function()
        storage.trades.base_trade_efficiency = lib.runtime_setting_value_as_number "base-trade-efficiency"
    end)

    event_system.register("runtime-setting-changed-trade-efficiency-per-item", function()
        storage.trades.trade_efficiency_per_item = lib.runtime_setting_value_as_number "trade-efficiency-per-item"
    end)
end

function trade_generator.init()
    local complexity = lib.runtime_setting_value_as_string "trade-complexity"
    local weights = storage.trades.trade_shape_weights_lookup[complexity]
    trade_generator.set_trade_shape_distribution(weights)
end

---Generate a trade between select items and solve for the item counts, returning a TentativeTrade object ready for initialization as a complete Trade object.
---
---Returns nil if the item names and params.target_efficiency do not allow for a valid solution.
---@param surface_name string
---@param input_item_names string[]
---@param output_item_names string[]
---@param params TradeGenerationParameters|nil
---@return TentativeTrade|nil
function trade_generator.generate_from_item_names(surface_name, input_item_names, output_item_names, params)
    if not params then params = {} end
    trade_generator.set_trade_generation_parameter_defaults(params)

    local surface = game.get_surface(surface_name)
    if not surface then
        lib.log_error("trade_generator.generate_from_item_names: Invalid surface name: " .. surface_name)
        return
    end

    if lib.is_space_platform(surface) then
        lib.log_error("trade_generator.generate_from_item_names: Attempting to create a trade for a space platform (illegal) with input_item_names = " .. serpent.line(input_item_names) .. ", output_item_names = " .. serpent.line(output_item_names))
    end

    if type(input_item_names) == "string" then
        input_item_names = {input_item_names}
    end
    if type(output_item_names) == "string" then
        output_item_names = {output_item_names}
    end

    for i = 1, #input_item_names do
        if lib.is_coin(input_item_names[i]) then
            input_item_names[i] = "hex-coin"
        end
    end
    for i = 1, #output_item_names do
        if lib.is_coin(output_item_names[i]) then
            output_item_names[i] = "hex-coin"
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
function trade_generator.generate_random(surface_name, existing_trades, volume, params, allow_untradable, include_item)
    if not params then
        params = {}
    else
        params = table.deepcopy(params)
    end
    trade_generator.set_trade_generation_parameter_defaults(params)

    ---@type (Trade|TentativeTrade)[]
    local candidate_trades = table.deepcopy(existing_trades)
    local slot = #candidate_trades + 1

    local coin_type = storage.coin_tiers.COIN_NAMES[1]

    -- Blacklist input items in existing trades (making the spider network order fulfillment less finicky)
    -- Two trades in a hex core can still have overlapping inputs if the guaranteed trades around the spawn hex happen to be like that.
    local blacklist = params.item_sampling_filters.blacklist
    if not blacklist then
        blacklist = {}
        params.item_sampling_filters.blacklist = blacklist
    end
    for _, trade in pairs(candidate_trades) do
        for _, input_item in pairs(trade.input_items) do
            blacklist[input_item.name] = true
        end
    end

    local coin_trade_chance = lib.runtime_setting_value "coin-trade-chance"
    local sell_trade_chance = lib.runtime_setting_value "sell-trade-chance"

    local attempts = 10
    for _ = 1, attempts do
        local input_item_names, output_item_names = trade_generator.generate_item_names(surface_name, volume, params, allow_untradable, include_item)

        local is_coin_trade = false
        if not next(output_item_names) then
            table.insert(output_item_names, coin_type)
            is_coin_trade = true
        elseif not next(input_item_names) then
            table.insert(input_item_names, coin_type)
            is_coin_trade = true
        end

        if not next(output_item_names) or not next(input_item_names) then
            lib.log_error("trade_generator.generate_random: No items exist around the value " .. volume)
            return
        end

        if not is_coin_trade and math.random() < coin_trade_chance then
            if math.random() < sell_trade_chance then
                local i = math.random(1, #output_item_names)
                if #output_item_names > 1 and output_item_names[i] == include_item then
                    i = i % #output_item_names + 1
                end
                if output_item_names[i] ~= include_item then
                    output_item_names[i] = coin_type
                end
            else
                local i = math.random(1, #input_item_names)
                if #input_item_names > 1 and input_item_names[i] == include_item then
                    i = i % #input_item_names + 1
                end
                if input_item_names[i] ~= include_item then
                    input_item_names[math.random(1, #input_item_names)] = coin_type
                end
            end
        end

        local tentative = trade_generator.generate_from_item_names(surface_name, input_item_names, output_item_names, params)
        if tentative then
            candidate_trades[slot] = tentative
            if not next(trade_loop_finder.find_simple_loops(candidate_trades)) then
                return tentative
            end
        end
    end

    lib.log_error("trade_generator.generate_random: A trade failed to generate within " .. attempts .. " attempts.")
end

---Replace undefined parameters with default values, modifying the table in place.
---@param params TradeGenerationParameters
function trade_generator.set_trade_generation_parameter_defaults(params)
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

    if params.scale_target_efficiency_by_items == nil then
        params.scale_target_efficiency_by_items = true
    end
end

---Get the current value of the setting "Trade Efficiency Per Item".
---@return number
function trade_generator.get_trade_efficiency_per_item()
    local eff = storage.trades.trade_efficiency_per_item
    if not eff then
        eff = lib.runtime_setting_value_as_number "trade-efficiency-per-item"
        storage.trades.trade_efficiency_per_item = eff
    end
    return eff
end

---Multiply trade efficiency by a factor based on the total number of unique items in a trade, modifying the table in place.
---@param params TradeGenerationParameters
---@param total_items int
function trade_generator.scale_trade_efficiency_by_total_items(params, total_items)
    local setting_value = trade_generator.get_trade_efficiency_per_item()

    -- Apply a multiplier only at three items or more.
    local mult = setting_value * (total_items - 2)

    params.target_efficiency = lib.apply_multiplier(params.target_efficiency, mult)
end

---Sample random item names for inputs and outputs of a trade based on a central item value.
---@param surface_name string
---@param volume number The central item value.
---@param params TradeGenerationParameters|nil
---@param allow_untradable boolean|nil Whether to include items that are initially untradable on the given surface. Defaults to false.
---@param include_item string|nil An item name to be forcefully included in the returned input or output items.
---@return string[], string[]
function trade_generator.generate_item_names(surface_name, volume, params, allow_untradable, include_item)
    if allow_untradable == nil then allow_untradable = false end

    if not params then
        params = {}
    else
        params = table.deepcopy(params)
    end

    local num_inputs, num_outputs = trade_generator._generate_random_trade_shape()
    local total_items = num_inputs + num_outputs

    trade_generator.set_trade_generation_parameter_defaults(params)

    if params.scale_target_efficiency_by_items then
        trade_generator.scale_trade_efficiency_by_total_items(params, total_items)
    end

    local input_to_output_value_ratio
    if params.target_efficiency >= 1 then
        input_to_output_value_ratio = 10 * params.target_efficiency
    else
        input_to_output_value_ratio = 10 / params.target_efficiency
    end

    local possible_items = item_values.get_items_near_value(surface_name, volume, input_to_output_value_ratio, true, false, allow_untradable)

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

    local trade_items = sets.to_array(set)
    if #trade_items < 2 then
        lib.log_error("trade_generator.generate_item_names: Not enough items selected for trade")
        return {}, {}
    end

    if include_item then
        -- Bring include_item to front indices that'll be used for populating input and output item lists.
        local idx_old = lib.table_index(trade_items, include_item)
        local idx_new = math.random(1, total_items)
        trade_items[idx_new], trade_items[idx_old] = trade_items[idx_old], trade_items[idx_new]
    end

    local input_item_names = {}
    local output_item_names = {}
    for i = 1, total_items do
        if i <= num_inputs then
            input_item_names[i] = trade_items[i]
        else
            output_item_names[i - num_inputs] = trade_items[i]
        end
    end

    return input_item_names, output_item_names
end

---Given a trade with undefined item counts, attempt to set the counts to the values which best preserve the specified input-to-output value ratio (`params.target_efficiency`).
---@param surface_name string
---@param trade TentativeTrade
---@param params TradeGenerationParameters|nil
---@return boolean solved Whether `params.target_efficiency` could be approximated with item counts while respecting item count constraints.
function trade_generator.solve_item_counts(surface_name, trade, params)
    if not params then
        params = {}
    else
        params = table.deepcopy(params)
    end

    trade_generator.set_trade_generation_parameter_defaults(params)

    if params.scale_target_efficiency_by_items then
        local total_items = #trade.input_items + #trade.output_items
        trade_generator.scale_trade_efficiency_by_total_items(params, total_items)
    end

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
    if #trade.input_items == 1 and trade.input_items[1].name == "hex-coin" then
        -- Normally +0.5 to round, but this is +random() so that it chooses the closer value more often but sometimes the farther value to add variation.
        trade.input_items[1].count = math.max(1, math.floor(math.random() + total_output_value / (params.target_efficiency * input_item_values[1])))
        return true
    elseif #trade.output_items == 1 and trade.output_items[1].name == "hex-coin" then
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

---Set the distribution of trade shapes during procedural generation.
---
---For example, this makes 25% of all trades be 1-1, and the rest 3-2:
---```
---local weights = {
---  {num_inputs = 1, num_outputs = 1, weight = 1},
---  {num_inputs = 3, num_outputs = 2, weight = 3},
---}
---trade_generator.set_trade_shape_distribution(weights)
---```
---@param weights TradeShapeWeightedItem[]
function trade_generator.set_trade_shape_distribution(weights)
    if type(weights) ~= "table" then
        lib.log_error("trade_generator.set_trade_shape_distribution: Invalid weights received: " .. tostring(weights))
        return
    end

    for _, obj in pairs(weights) do
        if
            -- TODO: maybe put type checking into a lib function or something, like lib.is_int()
               type(obj.num_inputs) ~= "number"
            or type(obj.num_outputs) ~= "number"
            or type(obj.weight) ~= "number"
            or math.floor(obj.num_inputs) ~= obj.num_inputs
            or math.floor(obj.num_outputs) ~= obj.num_outputs
            or obj.num_inputs < 1
            or obj.num_inputs > 3
            or obj.num_outputs < 1
            or obj.num_outputs > 3
            or obj.weight <= 0
        then
            lib.log_error("trade_generator.set_trade_shape_distribution: Invalid weights received:\n" .. serpent.block(weights))
            return
        end
    end

    lib.log("New weights set for trade shapes: " .. serpent.block(weights))

    storage.trades.trade_shape_weights = weights
    storage.trades.trade_shape_weighted_choice = nil
end

---Get the distribution currently used for sampling trade shapes during procedural generation.
---@return TradeShapeWeightedItem[]|nil
function trade_generator.get_trade_shape_distribution()
    return storage.trades.trade_shape_weights
end

---@return WeightedChoice|nil
function trade_generator.get_trade_shape_weighted_choice()
    local trade_shape_wc = storage.trades.trade_shape_weighted_choice

    if not trade_shape_wc then
        local weights = trade_generator.get_trade_shape_distribution()
        if not weights then
            lib.log_error("trade_generator._get_trade_shape_weighted_choice: No weights set for trade shape sampling")
            return
        end

        local wc = trade_generator._build_trade_shape_weighted_choice(weights)
        if not wc then
            lib.log_error("trade_generator._get_trade_shape_weighted_choice: Failed to create a weighted choice for trades given weights:\n" .. serpent.block(weights))
            return
        end

        trade_shape_wc = wc
        storage.trades.trade_shape_weighted_choice = trade_shape_wc
    end

    return trade_shape_wc
end

---@return int num_inputs, int num_outputs
function trade_generator._generate_random_trade_shape()
    local trade_shape_wc = trade_generator.get_trade_shape_weighted_choice()
    if not trade_shape_wc then
        return 1, 1
    end

    local item = weighted_choice.choice(trade_shape_wc)
    return item[1], item[2]
end

---@param weights TradeShapeWeightedItem[]
---@return WeightedChoice|nil
function trade_generator._build_trade_shape_weighted_choice(weights)
    local item_list = {}

    for _, shape_item in pairs(weights) do
        item_list[#item_list+1] = {
            item = {shape_item.num_inputs, shape_item.num_outputs},
            weight = shape_item.weight,
        }
    end

    return weighted_choice.from_list(item_list)
end



return trade_generator
