local lib = require "api.lib"
local sets = require "api.sets"
local item_values = require "api.item_values"
local trade_loop_finder = require "api.trade_loop_finder"
local weighted_choice = require "api.weighted_choice"

-- DEPRECATED: Legacy snapshot of `main` trade generation behavior.
-- This module is temporary and exists only for sampling/comparison.
local legacy = {}

local RANDOM_TRADE_ATTEMPTS = 10

---@param params TradeGenerationParameters
local function set_trade_generation_parameter_defaults_legacy(params)
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

---@return int num_inputs, int num_outputs
local function get_trade_shape_legacy_main()
    local trade_shape_wc = storage.trades.trade_shape_weighted_choice
    if not trade_shape_wc then
        local weights = storage.trades.trade_shape_weights
        if not weights then
            lib.log_error("trade_generator_legacy_main.get_trade_shape_legacy_main: No weights set for trade shape sampling")
            return 1, 1
        end

        local item_list = {}
        for _, shape_item in pairs(weights) do
            item_list[#item_list + 1] = {
                item = {shape_item.num_inputs, shape_item.num_outputs},
                weight = shape_item.weight,
            }
        end

        trade_shape_wc = weighted_choice.from_list(item_list)
        if not trade_shape_wc then
            lib.log_error("trade_generator_legacy_main.get_trade_shape_legacy_main: Failed to create weighted choice")
            return 1, 1
        end

        storage.trades.trade_shape_weighted_choice = trade_shape_wc
    end

    local item = weighted_choice.choice(trade_shape_wc)
    if not item then
        return 1, 1
    end
    return item[1], item[2]
end

---@param surface_name string
---@param volume number
---@param params TradeGenerationParameters|nil
---@param allow_untradable boolean|nil
---@param include_item string|nil
---@return string[], string[]
local function generate_item_names_legacy_main(surface_name, volume, params, allow_untradable, include_item)
    if allow_untradable == nil then allow_untradable = false end
    if not params then params = {} end
    set_trade_generation_parameter_defaults_legacy(params)

    local ratio
    if params.target_efficiency >= 1 then
        ratio = 10 * params.target_efficiency
    else
        ratio = 10 / params.target_efficiency
    end

    local possible_items = item_values.get_items_near_value(surface_name, volume, ratio, true, false, allow_untradable)

    if params.item_sampling_filters.whitelist then
        possible_items = lib.filter_whitelist(possible_items, function(item_name)
            return params.item_sampling_filters.whitelist[item_name]
        end)
    end

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
    for _ = 1, 6 do
        if #possible_items == 0 then break end
        local item_name = table.remove(possible_items, math.random(1, #possible_items))
        sets.add(set, item_name)
    end

    local trade_items = sets.to_array(set)
    if #trade_items < 2 then
        lib.log_error("trade_generator.generate_item_names: Not enough items selected for trade")
        return {}, {}
    end

    local num_inputs, num_outputs = get_trade_shape_legacy_main()
    local total_items = num_inputs + num_outputs

    if include_item then
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

-- DEPRECATED: Legacy snapshot of `main` implementation.
---@param surface_name string
---@param input_item_names string[]
---@param output_item_names string[]
---@param params TradeGenerationParameters|nil
---@param solve_item_counts_fn fun(surface_name:string, trade:table, params:TradeGenerationParameters|nil):boolean
---@return TentativeTrade|nil
function legacy.generate_from_item_names(surface_name, input_item_names, output_item_names, params, solve_item_counts_fn)
    if not params then params = {} end
    set_trade_generation_parameter_defaults_legacy(params)

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

    local coin_name = storage.coin_tiers.COIN_NAMES[1]
    for i = 1, #input_item_names do
        if lib.is_coin(input_item_names[i]) then
            input_item_names[i] = coin_name
        end
    end
    for i = 1, #output_item_names do
        if lib.is_coin(output_item_names[i]) then
            output_item_names[i] = coin_name
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

    local tentative = {
        surface_name = surface_name,
        input_items = input_items,
        output_items = output_items,
    }

    local solved = solve_item_counts_fn(surface_name, tentative, params)
    if not solved and params.allow_nil_return then
        return nil
    end

    return tentative
end

-- DEPRECATED: Legacy snapshot of `main` implementation.
---@param surface_name string
---@param existing_trades Trade[]
---@param volume number
---@param params TradeGenerationParameters|nil
---@param allow_untradable boolean|nil
---@param include_item string|nil
---@param solve_item_counts_fn fun(surface_name:string, trade:table, params:TradeGenerationParameters|nil):boolean
---@return TentativeTrade|nil
function legacy.generate_random(surface_name, existing_trades, volume, params, allow_untradable, include_item, solve_item_counts_fn)
    if not params then
        params = {}
    else
        params = table.deepcopy(params)
    end
    set_trade_generation_parameter_defaults_legacy(params)

    local candidate_trades = table.deepcopy(existing_trades)
    local slot = #candidate_trades + 1

    local coin_type = storage.coin_tiers.COIN_NAMES[1]

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

    for _ = 1, RANDOM_TRADE_ATTEMPTS do
        local input_item_names, output_item_names = generate_item_names_legacy_main(surface_name, volume, params, allow_untradable, include_item)

        if not next(output_item_names) or not next(input_item_names) then
            lib.log("trade_generator.generate_random: Not enough items centered around the value " .. volume)
            return
        end

        local is_coin_trade = false
        if #input_item_names == 1 and not next(output_item_names) then
            table.insert(output_item_names, coin_type)
            is_coin_trade = true
        elseif #output_item_names == 1 and not next(input_item_names) then
            table.insert(input_item_names, coin_type)
            is_coin_trade = true
        end

        if not is_coin_trade and math.random() < lib.runtime_setting_value "coin-trade-chance" then
            if math.random() < lib.runtime_setting_value "sell-trade-chance" then
                local i = math.random(1, #output_item_names)
                if #output_item_names[i] > 1 and output_item_names[i] == include_item then
                    i = i % #output_item_names + 1
                end
                if output_item_names[i] ~= include_item then
                    output_item_names[i] = coin_type
                end
            else
                local i = math.random(1, #input_item_names)
                if #input_item_names[i] > 1 and input_item_names[i] == include_item then
                    i = i % #input_item_names + 1
                end
                if input_item_names[i] ~= include_item then
                    input_item_names[math.random(1, #input_item_names)] = coin_type
                end
            end
        end

        local tentative = legacy.generate_from_item_names(
            surface_name,
            input_item_names,
            output_item_names,
            params,
            solve_item_counts_fn
        )
        if tentative then
            candidate_trades[slot] = tentative
            if not next(trade_loop_finder.find_simple_loops(candidate_trades)) then
                return tentative
            end
        end
    end

    lib.log_error("trade_generator.generate_random: A trade failed to generate within " .. RANDOM_TRADE_ATTEMPTS .. " attempts.")
end

return legacy
