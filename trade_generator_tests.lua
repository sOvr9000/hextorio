local lib = require "api.lib"
local trades = require "api.trades"
local item_values = require "api.item_values"
local trade_generator = require "api.trade_generator"
local coin_tiers = require "api.coin_tiers"
local trade_loop_finder = require "api.trade_loop_finder"
local inventories = require "api.inventories"
local event_system = require "api.event_system"

local trade_generator_tests = {}

local COMMAND_NAME = "trade-generator-tests"
local SAMPLE_COMMAND_NAME = "trade-generator-sample-distribution"
local SAMPLE_ALL_PRESETS_COMMAND_NAME = "trade-generator-sample-all-presets"
local SAMPLE_ALL_PRESETS_RANGE_COMMAND_NAME = "trade-generator-sample-all-presets-range"
local OUTPUT_FILE = "hextorio/trade_generator_tests.log"
local SAMPLE_OUTPUT_FILE_PREFIX = "hextorio/trade_distribution_sample_"
local SAMPLE_ALL_PRESETS_OUTPUT_FILE_PREFIX = "hextorio/trade_distribution_all_presets_"
local SAMPLE_ALL_PRESETS_RANGE_OUTPUT_FILE_PREFIX = "hextorio/trade_distribution_all_presets_range_"
local MAX_TICKS_PER_TEST = 5

-- API references (local docs):
-- - commands.add_command + CustomCommandData.parameter:
--   .reference/factorio-api-html/classes/LuaCommandProcessor.html
--   .reference/factorio-api-html/concepts/CustomCommandData.html
-- - helpers.write_file:
--   .reference/factorio-api-html/classes/LuaHelpers.html#write_file
-- - helpers.table_to_json:
--   .reference/factorio-api-html/classes/LuaHelpers.html#table_to_json
-- - LuaPlayer.print:
--   .reference/factorio-api-html/classes/LuaPlayer.html#print
-- - script.on_nth_tick + NthTickEventData.tick:
--   .reference/factorio-api-html/classes/LuaBootstrap.html#on_nth_tick
--   .reference/factorio-api-html/concepts/NthTickEventData.html

local function _emit(player, message)
    local line = "[TradeGeneratorTests] " .. message
    if player and player.valid then
        player.print(line)
    else
        game.print(line)
    end
    helpers.write_file(OUTPUT_FILE, line .. "\n", true)
end

local function _expect(condition, message)
    if not condition then
        error(message, 0)
    end
end

local function _contains_coin(names)
    for _, name in pairs(names or {}) do
        if lib.is_coin(name) then
            return true
        end
    end
    return false
end

local function _count_coins(names)
    local count = 0
    for _, name in pairs(names or {}) do
        if lib.is_coin(name) then
            count = count + 1
        end
    end
    return count
end

local function _contains_only_allowed_items(names, allowed_lookup)
    for _, name in pairs(names or {}) do
        if not lib.is_coin(name) and not allowed_lookup[name] then
            return false
        end
    end
    return true
end

local function _contains_name(names, target_name)
    for _, name in pairs(names or {}) do
        if name == target_name then
            return true
        end
    end
    return false
end

local function _to_name_array(items)
    local out = {}
    for i, item in pairs(items or {}) do
        out[i] = item.name
    end
    return out
end

local function _with_runtime_setting_overrides(overrides, fn)
    local old_value = lib.runtime_setting_value
    local old_number = lib.runtime_setting_value_as_number
    local old_int = lib.runtime_setting_value_as_int
    local old_boolean = lib.runtime_setting_value_as_boolean
    local old_string = lib.runtime_setting_value_as_string
    local old_color = lib.runtime_setting_value_as_color

    local function value(name)
        local override = overrides[name]
        if override ~= nil then
            return override
        end
        return old_value(name)
    end

    lib.runtime_setting_value = value
    lib.runtime_setting_value_as_number = function(name) return value(name) end
    lib.runtime_setting_value_as_int = function(name) return value(name) end
    lib.runtime_setting_value_as_boolean = function(name) return value(name) end
    lib.runtime_setting_value_as_string = function(name) return value(name) end
    lib.runtime_setting_value_as_color = function(name) return value(name) end

    local ok, result = xpcall(fn, debug.traceback)

    lib.runtime_setting_value = old_value
    lib.runtime_setting_value_as_number = old_number
    lib.runtime_setting_value_as_int = old_int
    lib.runtime_setting_value_as_boolean = old_boolean
    lib.runtime_setting_value_as_string = old_string
    lib.runtime_setting_value_as_color = old_color

    if not ok then error(result, 0) end
    return result
end

local function _with_runtime_number_overrides(overrides, fn)
    return _with_runtime_setting_overrides(overrides, fn)
end

local function _with_runtime_string_overrides(overrides, fn)
    return _with_runtime_setting_overrides(overrides, fn)
end

local function _with_trade_shape_weights(temp_weights, fn)
    local old_weights = storage.trades.trade_shape_weights
    local old_wc = storage.trades.trade_shape_weighted_choice
    local old_wc_by_group = storage.trades.trade_shape_weighted_choice_by_group
    storage.trades.trade_shape_weights = temp_weights
    storage.trades.trade_shape_weighted_choice = nil
    storage.trades.trade_shape_weighted_choice_by_group = nil

    local ok, result = xpcall(fn, debug.traceback)

    storage.trades.trade_shape_weights = old_weights
    storage.trades.trade_shape_weighted_choice = old_wc
    storage.trades.trade_shape_weighted_choice_by_group = old_wc_by_group

    if not ok then error(result, 0) end
    return result
end

local function _pick_non_coin_items(surface_name, count)
    local items = {}
    local values = ((storage.item_values or {}).values or {})[surface_name] or {}
    for name, _ in pairs(values) do
        if not lib.is_coin(name) then
            items[#items + 1] = name
            if #items >= count then
                return items
            end
        end
    end
    return items
end

local function _pick_non_coin_inventory_items(surface_name, count)
    local items = {}
    local values = ((storage.item_values or {}).values or {})[surface_name] or {}
    for name, _ in pairs(values) do
        if not lib.is_coin(name) and prototypes.item[name] then
            items[#items + 1] = name
            if #items >= count then
                return items
            end
        end
    end
    return items
end

local function _pick_volume(surface_name, fallback_item)
    local ok, value = pcall(item_values.get_item_value, surface_name, fallback_item)
    if ok and type(value) == "number" and value > 0 then
        return value
    end
    return (storage.item_values and storage.item_values.base_coin_value) or 10
end

local function _generate_random_tentative(surface_name, volume, params, include_item, attempts)
    attempts = attempts or 16
    for _ = 1, attempts do
        local tentative = trade_generator.generate_random(surface_name, {}, volume, params, true, include_item)
        if tentative then
            return tentative
        end
    end
    return nil
end

local function _generate_random_with_existing(surface_name, existing_trades, volume, params, include_item, attempts)
    attempts = attempts or 16
    for _ = 1, attempts do
        local tentative = trade_generator.generate_random(surface_name, existing_trades, volume, params, true, include_item)
        if tentative then
            return tentative
        end
    end
    return nil
end

local function _make_shape_only_weights(num_inputs, num_outputs)
    return {
        {num_inputs = num_inputs, num_outputs = num_outputs, weight = 1},
    }
end

local function _make_grouped_shape_only_weights(group_name, num_inputs, num_outputs)
    local out = {
        non_coin = {},
        coin_input = {},
        coin_output = {},
    }
    out[group_name] = _make_shape_only_weights(num_inputs, num_outputs)
    return out
end

local function _with_script_inventories(size_in, size_out, fn)
    local inv_in = game.create_inventory(size_in)
    local inv_out = game.create_inventory(size_out)
    local ok, result = xpcall(function()
        return fn(inv_in, inv_out)
    end, debug.traceback)

    if inv_in and inv_in.valid then inv_in.destroy() end
    if inv_out and inv_out.valid then inv_out.destroy() end

    if not ok then error(result, 0) end
    return result
end

local tests = {
    {
        id = "shape_validation_guard_regression",
        description = "Validates invalid shape config entries are rejected without replacing active trade-shape weights.",
        run = function(context)
            trade_generator.init()
            local complexity = lib.runtime_setting_value_as_string "trade-complexity"
            local lookup = storage.trades.trade_shape_weights_lookup
            _expect(type(lookup) == "table" and type(lookup[complexity]) == "table", "Missing trade-shape lookup for complexity: " .. tostring(complexity))

            local old_lookup_weights = lookup[complexity]
            local old_active_weights = storage.trades.trade_shape_weights
            local old_wc = storage.trades.trade_shape_weighted_choice
            local old_wc_by_group = storage.trades.trade_shape_weighted_choice_by_group

            lookup[complexity] = {
                non_coin = {
                    {num_inputs = 0, num_outputs = 1, weight = 1},   -- invalid: zero inputs in grouped mode
                    {num_inputs = 1, num_outputs = 1, weight = -1},  -- invalid: negative weight
                },
                coin_input = {},
                coin_output = {},
            }

            local ok, err = xpcall(function()
                trade_generator.init()
            end, debug.traceback)

            lookup[complexity] = old_lookup_weights
            storage.trades.trade_shape_weighted_choice = old_wc
            storage.trades.trade_shape_weighted_choice_by_group = old_wc_by_group

            _expect(ok, "trade_generator.init crashed on invalid shape config: " .. tostring(err))
            _expect(storage.trades.trade_shape_weights == old_active_weights, "Invalid shape config should not replace active trade-shape weights")
        end,
    },
    {
        id = "shape_validation_empty_effective_pool",
        description = "Validates grouped shape config with no positive-weight entries is rejected without replacing active trade-shape weights.",
        run = function(context)
            trade_generator.init()
            local complexity = lib.runtime_setting_value_as_string "trade-complexity"
            local lookup = storage.trades.trade_shape_weights_lookup
            _expect(type(lookup) == "table" and type(lookup[complexity]) == "table", "Missing trade-shape lookup for complexity: " .. tostring(complexity))

            local old_lookup_weights = lookup[complexity]
            local old_active_weights = storage.trades.trade_shape_weights
            local old_wc = storage.trades.trade_shape_weighted_choice
            local old_wc_by_group = storage.trades.trade_shape_weighted_choice_by_group

            lookup[complexity] = {
                non_coin = {{num_inputs = 1, num_outputs = 1, weight = 0}},
                coin_input = {{num_inputs = 1, num_outputs = 1, weight = 0}},
                coin_output = {{num_inputs = 1, num_outputs = 1, weight = 0}},
            }

            local ok, err = xpcall(function()
                trade_generator.init()
            end, debug.traceback)

            lookup[complexity] = old_lookup_weights
            storage.trades.trade_shape_weighted_choice = old_wc
            storage.trades.trade_shape_weighted_choice_by_group = old_wc_by_group

            _expect(ok, "trade_generator.init crashed on empty effective pool config: " .. tostring(err))
            _expect(storage.trades.trade_shape_weights == old_active_weights, "Empty effective pool config should not replace active trade-shape weights")
        end,
    },
    {
        id = "weights_placeholders_present",
        description = "Validates grouped archetype schema exists and shape entries are positive-count with non-negative weights.",
        run = function(context)
            local lookup = storage.trades.trade_shape_weights_lookup
            _expect(type(lookup) == "table", "Missing storage.trades.trade_shape_weights_lookup")

            for complexity, grouped in pairs(lookup) do
                _expect(type(grouped) == "table", "Invalid grouped shape lookup for " .. complexity)
                for _, group_name in ipairs({"non_coin", "coin_input", "coin_output"}) do
                    local weights = grouped[group_name]
                    _expect(type(weights) == "table", "Missing group '" .. group_name .. "' in " .. complexity)
                    local has_positive_weight = false
                    for _, shape in pairs(weights) do
                        _expect(shape.weight >= 0, "Negative weight found in " .. complexity .. "." .. group_name)
                        _expect(shape.num_inputs >= 1 and shape.num_inputs <= 3, "Invalid num_inputs in " .. complexity .. "." .. group_name)
                        _expect(shape.num_outputs >= 1 and shape.num_outputs <= 3, "Invalid num_outputs in " .. complexity .. "." .. group_name)
                        if shape.weight > 0 then
                            has_positive_weight = true
                        end
                    end
                    _expect(has_positive_weight, "Group '" .. group_name .. "' has no positive weights in " .. complexity)
                end
            end
        end,
    },
    {
        id = "weighted_choice_excludes_zero_weight_shapes",
        description = "Validates grouped weighted-choice caches only contain positive-count shapes.",
        run = function(context)
            local lookup = storage.trades.trade_shape_weights_lookup
            local volume = context.volume
            for complexity, grouped in pairs(lookup) do
                _with_trade_shape_weights(grouped, function()
                    _with_runtime_number_overrides({
                        ["coin-trade-chance"] = 0,
                        ["sell-trade-chance"] = 0.5,
                    }, function()
                        _generate_random_tentative(context.surface_name, volume, {allow_nil_return = true}, nil, 8)
                    end)

                    local by_group = storage.trades.trade_shape_weighted_choice_by_group
                    _expect(type(by_group) == "table", "No grouped weighted-choice cache generated for " .. complexity)

                    for _, group_name in ipairs({"non_coin", "coin_input", "coin_output"}) do
                        local has_positive_weight = false
                        for _, shape in pairs(grouped[group_name] or {}) do
                            if shape.weight > 0 then
                                has_positive_weight = true
                                break
                            end
                        end
                        if has_positive_weight then
                            local wc = by_group[group_name]
                            if wc then
                                _expect(wc.__total_weight and wc.__total_weight > 0, "Empty weighted choice for " .. complexity .. "." .. group_name)
                                for shape, _ in pairs(wc) do
                                    if shape ~= "__total_weight" then
                                        _expect(shape[1] > 0, "Found zero-input sampled shape in " .. complexity .. "." .. group_name)
                                        _expect(shape[2] > 0, "Found zero-output sampled shape in " .. complexity .. "." .. group_name)
                                    end
                                end
                            end
                        end
                    end
                end)
            end
        end,
    },
    {
        id = "from_item_names_rejects_both_empty",
        description = "Validates both-empty input/output trade generation is rejected.",
        run = function(context)
            local tentative = trade_generator.generate_from_item_names(context.surface_name, {}, {}, {allow_nil_return = false})
            _expect(tentative == nil, "Expected nil for both-empty input/output")
        end,
    },
    {
        id = "from_item_names_normalizes_single_empty_side",
        description = "Validates either empty side is normalized into a coin-side trade.",
        run = function(context)
            local item = context.sample_items[1]
            _expect(item ~= nil, "No sample item found for empty-side normalization test")

            local empty_input = trade_generator.generate_from_item_names(context.surface_name, {}, {item}, {allow_nil_return = false})
            _expect(empty_input ~= nil, "Expected generated trade when only input side is empty")
            _expect(#empty_input.input_items >= 1, "Expected at least one normalized input item")
            _expect(lib.is_coin(empty_input.input_items[1].name), "Expected normalized input to be a coin")
            _expect(_contains_name(_to_name_array(empty_input.output_items), item), "Expected output item to remain present")

            local empty_output = trade_generator.generate_from_item_names(context.surface_name, {item}, {}, {allow_nil_return = false})
            _expect(empty_output ~= nil, "Expected generated trade when only output side is empty")
            _expect(#empty_output.output_items >= 1, "Expected at least one normalized output item")
            _expect(lib.is_coin(empty_output.output_items[1].name), "Expected normalized output to be a coin")
            _expect(_contains_name(_to_name_array(empty_output.input_items), item), "Expected input item to remain present")
        end,
    },
    {
        id = "coin_routing_non_coin_path",
        description = "Validates non-coin path is selected when coin-trade-chance=0.",
        run = function(context)
            local grouped = {
                non_coin = _make_shape_only_weights(2, 2),
                coin_input = _make_shape_only_weights(2, 2),
                coin_output = _make_shape_only_weights(2, 2),
            }
            _with_trade_shape_weights(grouped, function()
                _with_runtime_number_overrides({
                    ["coin-trade-chance"] = 0,
                    ["sell-trade-chance"] = 0.5,
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, nil, 20)
                    _expect(tentative ~= nil, "Failed to generate random trade for non-coin routing test")
                    local input_names = _to_name_array(tentative.input_items)
                    local output_names = _to_name_array(tentative.output_items)
                    _expect(not _contains_coin(input_names), "Unexpected coin found in inputs when coin-trade-chance=0")
                    _expect(not _contains_coin(output_names), "Unexpected coin found in outputs when coin-trade-chance=0")
                end)
            end)
        end,
    },
    {
        id = "coin_routing_coin_input_path",
        description = "Validates coin-input path is selected when coin-trade-chance=1 and sell-trade-chance=0.",
        run = function(context)
            local grouped = _make_grouped_shape_only_weights("coin_input", 2, 2)
            _with_trade_shape_weights(grouped, function()
                _with_runtime_number_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 0,
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, nil, 12)
                    _expect(tentative ~= nil, "Failed to generate forced coin-input trade")
                    local input_names = _to_name_array(tentative.input_items)
                    local output_names = _to_name_array(tentative.output_items)
                    _expect(#input_names == 2, "Expected two input items for coin-input path")
                    _expect(_count_coins(input_names) == 1, "Expected exactly one input coin for coin-input path")
                    _expect(#output_names == 2, "Expected two output items for coin-input path")
                    _expect(_count_coins(output_names) == 0, "Did not expect output coin for coin-input path")
                end)
            end)
        end,
    },
    {
        id = "coin_routing_coin_output_path",
        description = "Validates coin-output path is selected when coin-trade-chance=1 and sell-trade-chance=1.",
        run = function(context)
            local grouped = _make_grouped_shape_only_weights("coin_output", 2, 2)
            _with_trade_shape_weights(grouped, function()
                _with_runtime_number_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 1,
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, nil, 12)
                    _expect(tentative ~= nil, "Failed to generate forced coin-output trade")
                    local input_names = _to_name_array(tentative.input_items)
                    local output_names = _to_name_array(tentative.output_items)
                    _expect(#output_names == 2, "Expected two output items for coin-output path")
                    _expect(_count_coins(output_names) == 1, "Expected exactly one output coin for coin-output path")
                    _expect(#input_names == 2, "Expected two input items for coin-output path")
                    _expect(_count_coins(input_names) == 0, "Did not expect input coin for coin-output path")
                end)
            end)
        end,
    },
    {
        id = "trade_limit_partition_build_validation",
        description = "Validates per-surface source/sink partitions build with non-empty groups and strict override assignment.",
        run = function(context)
            trade_generator.rebuild_trade_limit_partitions(context.surface_name)
            local partition = trade_generator.get_trade_limit_partition(context.surface_name)
            _expect(partition ~= nil, "Missing partition state")
            _expect(partition.valid == true, "Partition is invalid: " .. tostring(partition.error))
            _expect(#(partition.source_items or {}) > 0, "Expected non-empty source partition")
            _expect(#(partition.sink_items or {}) > 0, "Expected non-empty sink partition")

            for item_name, _ in pairs(partition.source_lookup or {}) do
                _expect(not (partition.sink_lookup or {})[item_name], "Item assigned to both source and sink: " .. item_name)
            end

            local overrides = ((storage.trades or {}).trade_limit_partition_overrides or {})[context.surface_name] or {}
            for _, item_name in ipairs(overrides.sources or {}) do
                if lib.is_item(item_name) and not lib.is_coin(item_name) and item_values.is_item_tradable(context.surface_name, item_name) then
                    _expect((partition.source_lookup or {})[item_name] == true, "Strict source override not applied: " .. item_name)
                end
            end
            for _, item_name in ipairs(overrides.sinks or {}) do
                if lib.is_item(item_name) and not lib.is_coin(item_name) and item_values.is_item_tradable(context.surface_name, item_name) then
                    _expect((partition.sink_lookup or {})[item_name] == true, "Strict sink override not applied: " .. item_name)
                end
            end
        end,
    },
    {
        id = "trade_limit_mode_behavior",
        description = "Validates off/one-to-one/all-coin-trades mode behavior for random coin trade partition filtering.",
        run = function(context)
            trade_generator.rebuild_trade_limit_partitions(context.surface_name)
            local partition = trade_generator.get_trade_limit_partition(context.surface_name)
            _expect(partition and partition.valid, "Expected a valid partition for mode behavior test")

            local nearby_items = item_values.get_items_near_value(context.surface_name, context.volume, 10, true, false, true)
            local nearby_lookup = {}
            for _, item_name in pairs(nearby_items or {}) do
                nearby_lookup[item_name] = true
            end

            local sink_candidates = {}
            for _, item_name in pairs(partition.sink_items or {}) do
                if nearby_lookup[item_name] then
                    sink_candidates[#sink_candidates + 1] = item_name
                end
                if #sink_candidates >= 3 then
                    break
                end
            end

            local sink_a = sink_candidates[1]
            local sink_b = sink_candidates[2]
            local sink_c = sink_candidates[3]
            _expect(sink_a and sink_b and sink_c, "Need at least three sink items for mode behavior test")

            local grouped_all_coin_input = _make_grouped_shape_only_weights("coin_input", 2, 1)
            _with_trade_shape_weights(grouped_all_coin_input, function()
                local params = {
                    allow_nil_return = true,
                    item_sampling_filters = {whitelist = {[sink_a] = true, [sink_b] = true}},
                }

                _with_runtime_setting_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 0,
                    ["coin-trade-limit-mode"] = "off",
                }, function()
                    local input_names, output_names = trade_generator.generate_item_names(context.surface_name, context.volume, params, true, nil)
                    _expect(#input_names > 0 and #output_names > 0, "Mode=off should not block sink-only candidate pool")
                end)

                _with_runtime_setting_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 0,
                    ["coin-trade-limit-mode"] = "all-coin-trades",
                }, function()
                    local input_names, output_names = trade_generator.generate_item_names(context.surface_name, context.volume, params, true, nil)
                    _expect(#input_names == 0 and #output_names == 0, "Mode=all-coin-trades should block sink-only candidate pool for coin_input")
                end)
            end)

            local grouped_one_to_one_gate = _make_grouped_shape_only_weights("coin_input", 2, 2)
            _with_trade_shape_weights(grouped_one_to_one_gate, function()
                local params = {
                    allow_nil_return = true,
                    item_sampling_filters = {whitelist = {[sink_a] = true, [sink_b] = true, [sink_c] = true}},
                }
                _with_runtime_setting_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 0,
                    ["coin-trade-limit-mode"] = "one-to-one-only",
                }, function()
                    local input_names, output_names = trade_generator.generate_item_names(context.surface_name, context.volume, params, true, nil)
                    _expect(#input_names > 0 and #output_names > 0, "Mode=one-to-one-only should not constrain coin_input when output has more than one item")
                end)
            end)
        end,
    },
    {
        id = "trade_limit_side_exclusivity",
        description = "Validates constrained sides use the configured source/sink partition under all-coin-trades mode.",
        run = function(context)
            trade_generator.rebuild_trade_limit_partitions(context.surface_name)
            local partition = trade_generator.get_trade_limit_partition(context.surface_name)
            _expect(partition and partition.valid, "Expected a valid partition for side exclusivity test")

            local grouped = {
                non_coin = {},
                coin_input = _make_shape_only_weights(2, 2),
                coin_output = _make_shape_only_weights(2, 2),
            }
            _with_trade_shape_weights(grouped, function()
                _with_runtime_setting_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 0,
                    ["coin-trade-limit-mode"] = "all-coin-trades",
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, nil, 20)
                    _expect(tentative ~= nil, "Failed to generate constrained coin_input trade")
                    local output_names = _to_name_array(tentative.output_items)
                    _expect(
                        _contains_only_allowed_items(output_names, partition.source_lookup or {}),
                        "coin_input constrained outputs included non-source item(s): " .. serpent.line(output_names)
                    )
                end)

                _with_runtime_setting_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 1,
                    ["coin-trade-limit-mode"] = "all-coin-trades",
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, nil, 20)
                    _expect(tentative ~= nil, "Failed to generate constrained coin_output trade")
                    local input_names = _to_name_array(tentative.input_items)
                    _expect(
                        _contains_only_allowed_items(input_names, partition.sink_lookup or {}),
                        "coin_output constrained inputs included non-sink item(s): " .. serpent.line(input_names)
                    )
                end)
            end)
        end,
    },
    {
        id = "trade_limit_partition_commands",
        description = "Validates trade-limit partition list/rebuild command events run and refresh partition state.",
        run = function(context)
            local before = trade_generator.get_trade_limit_partition(context.surface_name)
            _expect(before ~= nil, "Missing partition before command test")

            event_system.trigger("command-trade-limit-partitions", context.player, {"rebuild", context.surface_name})
            local after_rebuild = trade_generator.get_trade_limit_partition(context.surface_name)
            _expect(after_rebuild ~= nil, "Missing partition after rebuild command")
            _expect(after_rebuild.valid == true, "Rebuild command produced invalid partition: " .. tostring(after_rebuild.error))

            event_system.trigger("command-trade-limit-partitions", context.player, {"list", context.surface_name})
        end,
    },
    {
        id = "mixed_coin_item_archetype_generation",
        description = "Validates mixed coin+item archetypes generate correctly and preserve include_item in non-coin slots.",
        run = function(context)
            local include_item = context.sample_items[1]
            _expect(include_item ~= nil, "No sample item found for mixed coin archetype test")

            local grouped = {
                non_coin = {},
                coin_input = _make_shape_only_weights(3, 2),
                coin_output = _make_shape_only_weights(2, 3),
            }
            _with_trade_shape_weights(grouped, function()
                _with_runtime_number_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 0,
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, include_item, 20)
                    _expect(tentative ~= nil, "Failed to generate mixed coin-input trade")
                    local input_names = _to_name_array(tentative.input_items)
                    local output_names = _to_name_array(tentative.output_items)
                    _expect(#input_names == 3 and _count_coins(input_names) == 1, "Expected 3-input mixed trade with one input coin")
                    _expect(#output_names == 2 and _count_coins(output_names) == 0, "Expected non-coin outputs for mixed coin-input trade")
                    _expect(_contains_name(input_names, include_item) or _contains_name(output_names, include_item), "include_item missing in mixed coin-input trade")
                end)

                _with_runtime_number_overrides({
                    ["coin-trade-chance"] = 1,
                    ["sell-trade-chance"] = 1,
                }, function()
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, include_item, 20)
                    _expect(tentative ~= nil, "Failed to generate mixed coin-output trade")
                    local input_names = _to_name_array(tentative.input_items)
                    local output_names = _to_name_array(tentative.output_items)
                    _expect(#input_names == 2 and _count_coins(input_names) == 0, "Expected non-coin inputs for mixed coin-output trade")
                    _expect(#output_names == 3 and _count_coins(output_names) == 1, "Expected 3-output mixed trade with one output coin")
                    _expect(_contains_name(input_names, include_item) or _contains_name(output_names, include_item), "include_item missing in mixed coin-output trade")
                end)
            end)
        end,
    },
    {
        id = "trade_execution_regression",
        description = "Validates item-item, coin-item, and mixed coin+item trade execution updates inventories as expected.",
        run = function(context)
            local item_a = context.sample_items[1]
            local item_b = context.sample_items[2]
            _expect(item_a ~= nil and item_b ~= nil, "Need at least two non-coin items for trade execution regression test")

            _with_script_inventories(120, 120, function(inv_in, inv_out)
                local item_trade = trades.from_item_names(context.surface_name, {item_a}, {item_b}, {
                    target_efficiency = storage.trades.base_trade_efficiency,
                    allow_nil_return = false,
                })
                _expect(item_trade ~= nil, "Failed to generate item-item trade for execution regression")
                _expect(item_trade.has_items_in_input and item_trade.has_items_in_output, "Item-item trade flags are invalid")

                local item_in_name = item_trade.input_items[1].name
                local item_in_count = item_trade.input_items[1].count
                local item_out_name = item_trade.output_items[1].name
                local item_out_count = item_trade.output_items[1].count

                local inserted = inv_in.insert({name = item_in_name, count = item_in_count * 2, quality = "normal"})
                _expect(inserted >= item_in_count, "Failed to seed input inventory for item-item execution test")

                local before_in = inv_in.get_item_count(item_in_name)
                local before_out = inv_out.get_item_count(item_out_name)
                local removed, added = trades.trade_items(inv_in, inv_out, item_trade, 1, "normal", 1, nil, nil, nil)
                _expect(removed ~= nil and added ~= nil, "trade_items returned nil for item-item execution test")
                _expect(inv_in.get_item_count(item_in_name) == before_in - item_in_count, "Item-item input delta mismatch")
                _expect(inv_out.get_item_count(item_out_name) == before_out + item_out_count, "Item-item output delta mismatch")

                inv_in.clear()
                inv_out.clear()

                _with_runtime_number_overrides({
                    ["sell-trade-chance"] = 0,
                }, function()
                    local coin_trade = trades.new_coin_trade(context.surface_name, item_a, storage.trades.base_trade_efficiency)
                    _expect(coin_trade ~= nil, "Failed to generate coin-input trade for execution regression")
                    _expect(coin_trade.has_coins_in_input == true, "Expected coins in input for coin-input execution test")
                    _expect(coin_trade.has_items_in_output == true, "Expected items in output for coin-input execution test")

                    local trade_coin = trades.get_input_coins_of_trade(coin_trade, "normal", 1)
                    inventories.add_coin_to_inventory(inv_in, coin_tiers.multiply(trade_coin, 2), nil, false)

                    local out_name = coin_trade.output_items[1].name
                    local out_count = coin_trade.output_items[1].count
                    local before_coin = coin_tiers.to_base_value(inventories.get_coin_from_inventory(inv_in, nil, false))
                    local before_item = inv_out.get_item_count(out_name)

                    local removed_coin, added_coin = trades.trade_items(inv_in, inv_out, coin_trade, 1, "normal", 1, nil, nil, nil)
                    _expect(removed_coin ~= nil and added_coin ~= nil, "trade_items returned nil for coin-input execution test")

                    local after_coin = coin_tiers.to_base_value(inventories.get_coin_from_inventory(inv_in, nil, false))
                    _expect(after_coin < before_coin, "Coin-input execution did not consume coins")
                    _expect(inv_out.get_item_count(out_name) == before_item + out_count, "Coin-input execution item delta mismatch")
                end)

                inv_in.clear()
                inv_out.clear()

                local mixed_trade = trades.from_item_names(context.surface_name, {storage.coin_tiers.COIN_NAMES[1], item_a}, {item_b}, {
                    target_efficiency = storage.trades.base_trade_efficiency,
                    allow_nil_return = false,
                })
                _expect(mixed_trade ~= nil, "Failed to generate mixed coin+item trade for execution regression")
                _expect(mixed_trade.has_coins_in_input and mixed_trade.has_items_in_input, "Expected mixed input side with coin and item")

                local mixed_coin = trades.get_input_coins_of_trade(mixed_trade, "normal", 1)
                inventories.add_coin_to_inventory(inv_in, coin_tiers.multiply(mixed_coin, 2), nil, false)
                for _, input_item in ipairs(mixed_trade.input_items) do
                    if not lib.is_coin(input_item.name) then
                        inv_in.insert({name = input_item.name, count = input_item.count * 2, quality = "normal"})
                    end
                end

                local before_mixed_coin = coin_tiers.to_base_value(inventories.get_coin_from_inventory(inv_in, nil, false))
                local before_mixed_item = inv_in.get_item_count(item_a)
                local mixed_output_name = mixed_trade.output_items[1].name
                local mixed_output_count = mixed_trade.output_items[1].count
                local before_mixed_output = inv_out.get_item_count(mixed_output_name)

                local removed_mixed, added_mixed = trades.trade_items(inv_in, inv_out, mixed_trade, 1, "normal", 1, nil, nil, nil)
                _expect(removed_mixed ~= nil and added_mixed ~= nil, "trade_items returned nil for mixed execution test")

                local after_mixed_coin = coin_tiers.to_base_value(inventories.get_coin_from_inventory(inv_in, nil, false))
                _expect(after_mixed_coin < before_mixed_coin, "Mixed execution did not consume coins")
                _expect(inv_in.get_item_count(item_a) < before_mixed_item, "Mixed execution did not consume non-coin input item")
                _expect(inv_out.get_item_count(mixed_output_name) == before_mixed_output + mixed_output_count, "Mixed execution output delta mismatch")
            end)
        end,
    },
    {
        id = "cross_surface_generation_regression",
        description = "Validates trade generation and execution succeed on all non-platform surfaces with available item values.",
        run = function(context)
            local tested = 0
            for _, surface in pairs(game.surfaces) do
                if surface and surface.valid and not lib.is_space_platform(surface) then
                    local items = _pick_non_coin_inventory_items(surface.name, 2)
                    if #items >= 2 then
                        local trade = trades.from_item_names(surface.name, {items[1]}, {items[2]}, {
                            target_efficiency = storage.trades.base_trade_efficiency,
                            allow_nil_return = false,
                        })
                        _expect(trade ~= nil, "Failed to generate trade on surface " .. surface.name)

                        _with_script_inventories(120, 120, function(inv_in, inv_out)
                            local input_name = trade.input_items[1].name
                            local input_count = trade.input_items[1].count
                            local output_name = trade.output_items[1].name
                            local output_count = trade.output_items[1].count

                            local inserted = inv_in.insert({name = input_name, count = input_count * 2, quality = "normal"})
                            _expect(inserted >= input_count, "Failed to seed input inventory on surface " .. surface.name)

                            local before_in = inv_in.get_item_count(input_name)
                            local before_out = inv_out.get_item_count(output_name)
                            local removed, added = trades.trade_items(inv_in, inv_out, trade, 1, "normal", 1, nil, nil, nil)
                            _expect(removed ~= nil and added ~= nil, "trade_items returned nil on surface " .. surface.name)
                            _expect(inv_in.get_item_count(input_name) == before_in - input_count, "Input delta mismatch on surface " .. surface.name)
                            _expect(inv_out.get_item_count(output_name) == before_out + output_count, "Output delta mismatch on surface " .. surface.name)
                        end)

                        tested = tested + 1
                    end
                end
            end
            _expect(tested > 0, "No valid surfaces with sufficient inventory items were available for cross-surface execution test")
        end,
    },
    {
        id = "loop_avoidance_regression",
        description = "Validates generated trade does not introduce simple two-trade loops with existing simple trades.",
        run = function(context)
            local items = _pick_non_coin_items(context.surface_name, 3)
            _expect(#items >= 3, "Need at least 3 items for loop-avoidance regression test")

            local trade_a = trade_generator.generate_from_item_names(context.surface_name, {items[1]}, {items[2]}, {allow_nil_return = false})
            local trade_b = trade_generator.generate_from_item_names(context.surface_name, {items[2]}, {items[3]}, {allow_nil_return = false})
            _expect(trade_a ~= nil and trade_b ~= nil, "Failed to build baseline simple trades for loop-avoidance test")

            local existing = {trade_a, trade_b}
            _with_runtime_number_overrides({
                ["coin-trade-chance"] = 0,
                ["sell-trade-chance"] = 0.5,
            }, function()
                local tentative
                for _ = 1, 12 do
                    tentative = trade_generator.generate_random(context.surface_name, existing, context.volume, {allow_nil_return = true}, true, nil)
                    if tentative then break end
                end
                _expect(tentative ~= nil, "Failed to generate candidate trade for loop-avoidance test")
                existing[#existing + 1] = tentative
                local loops = trade_loop_finder.find_simple_loops(existing)
                _expect(not next(loops), "Simple loop detected after generating candidate trade")
            end)
        end,
    },
    {
        id = "loop_avoidance_empty_vs_full_consistency",
        description = "Validates loop-avoidance behavior is consistent for empty vs populated existing trade lists.",
        run = function(context)
            local items = _pick_non_coin_items(context.surface_name, 4)
            _expect(#items >= 4, "Need at least 4 items for empty-vs-full loop-avoidance consistency test")

            local trade_a = trade_generator.generate_from_item_names(context.surface_name, {items[1]}, {items[2]}, {allow_nil_return = false})
            local trade_b = trade_generator.generate_from_item_names(context.surface_name, {items[2]}, {items[3]}, {allow_nil_return = false})
            local trade_c = trade_generator.generate_from_item_names(context.surface_name, {items[3]}, {items[4]}, {allow_nil_return = false})
            _expect(trade_a ~= nil and trade_b ~= nil and trade_c ~= nil, "Failed to build baseline trades for consistency test")

            local full_existing = {trade_a, trade_b, trade_c}
            _expect(not next(trade_loop_finder.find_simple_loops(full_existing)), "Baseline populated existing list unexpectedly contains loops")

            _with_runtime_number_overrides({
                ["coin-trade-chance"] = 0,
                ["sell-trade-chance"] = 0.5,
            }, function()
                local empty_tentative = _generate_random_with_existing(context.surface_name, {}, context.volume, {allow_nil_return = true}, nil, 16)
                _expect(empty_tentative ~= nil, "Failed to generate trade with empty existing list")
                _expect(not next(trade_loop_finder.find_simple_loops({empty_tentative})), "Generated trade with empty existing list unexpectedly creates a simple loop")

                local full_tentative = _generate_random_with_existing(context.surface_name, full_existing, context.volume, {allow_nil_return = true}, nil, 16)
                if full_tentative then
                    local candidate = table.deepcopy(full_existing)
                    candidate[#candidate + 1] = full_tentative
                    _expect(not next(trade_loop_finder.find_simple_loops(candidate)), "Generated trade with populated existing list introduces a simple loop")
                else
                    -- Under tighter constraints a nil result is acceptable; consistency requirement is that no looping trade is returned.
                    _expect(not next(trade_loop_finder.find_simple_loops(full_existing)), "Populated existing list became looping after nil generation result")
                end
            end)
        end,
    },
    {
        id = "trade_batching_regression",
        description = "Validates get_num_batches_for_trade still returns feasible batches for item-item and coin trades.",
        run = function(context)
            local item_a = context.sample_items[1]
            local item_b = context.sample_items[2]
            _expect(item_a ~= nil and item_b ~= nil, "Need at least two items for batching regression test")

            local item_trade = trades.from_item_names(context.surface_name, {item_a}, {item_b}, {
                target_efficiency = storage.trades.base_trade_efficiency,
                allow_nil_return = false,
            })
            _expect(item_trade ~= nil, "Failed to generate item-item trade for batching test")

            local item_input_count = item_trade.input_items[1].count
            local input_items = {normal = {[item_a] = item_input_count * 3}}
            local no_coin = coin_tiers.new()
            local batches_item = trades.get_num_batches_for_trade(input_items, no_coin, item_trade, "normal", 1, false, nil, nil, nil)
            _expect(batches_item >= 1, "Expected at least one batch for item-item trade")

            _with_runtime_number_overrides({
                ["sell-trade-chance"] = 0,
            }, function()
                local coin_trade = trades.new_coin_trade(context.surface_name, item_a, storage.trades.base_trade_efficiency)
                _expect(coin_trade ~= nil, "Failed to generate coin trade for batching test")

                local trade_coin = trades.get_input_coins_of_trade(coin_trade, "normal", 1)
                local enough_coin = coin_tiers.multiply(trade_coin, 3)
                local batches_coin = trades.get_num_batches_for_trade({normal = {}}, enough_coin, coin_trade, "normal", 1, false, nil, nil, nil)
                _expect(batches_coin >= 1, "Expected at least one batch for coin-input trade")
            end)
        end,
    },
    {
        id = "existing_item_item_generation_regression",
        description = "Validates existing item-to-item trade generation and initialization still succeeds.",
        run = function(context)
            local item_a = context.sample_items[1]
            local item_b = context.sample_items[2]
            _expect(item_a ~= nil and item_b ~= nil, "Need at least two non-coin items for item-item regression test")

            local trade = trades.from_item_names(context.surface_name, {item_a}, {item_b}, {
                target_efficiency = storage.trades.base_trade_efficiency,
                allow_nil_return = false,
            })
            _expect(trade ~= nil, "Failed to generate baseline item-item trade")
            _expect(trade.has_items_in_input == true, "Expected non-coin input flag to remain true")
            _expect(trade.has_items_in_output == true, "Expected non-coin output flag to remain true")
        end,
    },
    {
        id = "batch_generation_stability",
        description = "Validates repeated random generation runs stably and yields successful trades in bulk.",
        run = function(context)
            _with_runtime_number_overrides({
                ["coin-trade-chance"] = 0.5,
                ["sell-trade-chance"] = 0.5,
            }, function()
                -- Performance note: this is intentionally a coarse stability sentinel, not a benchmark.
                -- Keep the current scale/threshold as-is to avoid over-optimizing test runtime behavior.
                local profiler = helpers.create_profiler(true)
                profiler.restart()

                local successes = 0
                for _ = 1, 60 do
                    local tentative = _generate_random_tentative(context.surface_name, context.volume, {allow_nil_return = true}, nil, 4)
                    if tentative then successes = successes + 1 end
                end

                profiler.stop()
                _expect(successes >= 20, "Too few successful generations in stability run: " .. successes .. "/60")
            end)
        end,
    },
}

local function _find_test(test_id)
    for _, test in ipairs(tests) do
        if test.id == test_id then
            return test
        end
    end
    return nil
end

local function _list_tests(player)
    _emit(player, "Available tests:")
    for _, test in ipairs(tests) do
        _emit(player, " - " .. test.id .. ": " .. test.description)
    end
end

local function _summarize_side(trade_items)
    local coin_count = 0
    local item_count = 0
    for _, item in pairs(trade_items or {}) do
        if item and item.name then
            if lib.is_coin(item.name) then
                coin_count = coin_count + 1
            else
                item_count = item_count + 1
            end
        end
    end

    if coin_count > 0 and item_count == 0 then
        return "coin"
    end
    if coin_count == 0 and item_count > 0 then
        return tostring(item_count)
    end
    if coin_count > 0 and item_count > 0 then
        return "coin+" .. tostring(item_count)
    end
    return "empty"
end

local function _get_trade_category(tentative_trade)
    local left = _summarize_side(tentative_trade and tentative_trade.input_items)
    local right = _summarize_side(tentative_trade and tentative_trade.output_items)
    return left .. "->" .. right
end

local function _build_probability_map(category_counts, total_count)
    local out = {}
    if total_count <= 0 then
        return out
    end
    for category, count in pairs(category_counts) do
        out[category] = count / total_count
    end
    return out
end

local function _distribution_error_l1(prev_probabilities, next_probabilities)
    local visited = {}
    local err = 0

    for category, p in pairs(next_probabilities) do
        err = err + math.abs(p - (prev_probabilities[category] or 0))
        visited[category] = true
    end
    for category, p in pairs(prev_probabilities) do
        if not visited[category] then
            err = err + math.abs(p)
        end
    end

    return err
end

---@class TradeGeneratorTestRun
---@field player_index uint|nil
---@field selected_tests table[]
---@field context table
---@field next_index int
---@field current {index:int, test:table, started_tick:uint, wait_until_tick:uint, state:table|nil, initialized:boolean}|nil
---@field passed int
---@field failed int
local active_run = nil ---@type TradeGeneratorTestRun|nil

---@class TradeDistributionSampleRun
---@field player_index uint|nil
---@field surface_name string
---@field volume number
---@field started_tick uint
---@field wait_until_tick uint
---@field tick_count int
---@field samples_per_tick int
---@field samples_attempted int
---@field generated_count int
---@field nil_count int
---@field category_counts table<string, int>
---@field previous_probabilities table<string, number>
---@field last_error_l1 number
---@field runtime_settings table
local active_sampling_run = nil ---@type TradeDistributionSampleRun|nil

---@class TradeAllPresetSamplingRun
---@field player_index uint|nil
---@field surface_name string
---@field volume number
---@field started_tick uint
---@field wait_until_tick uint
---@field phase string
---@field presets string[]
---@field current_index int
---@field ticks_in_preset int
---@field samples_per_tick int
---@field generated int
---@field nil_returns int
---@field counts table<string, int>
---@field expected_categories table<string, boolean>
---@field results table<string, table>
---@field runtime_settings table
---@field active_weights_lookup_name string
local active_all_preset_sampling_run = nil ---@type TradeAllPresetSamplingRun|nil

---@class TradeAllPresetRangeSamplingRun
---@field player_index uint|nil
---@field mode_label string
---@field surface_name string
---@field volume number
---@field started_tick uint
---@field wait_until_tick uint
---@field phase string
---@field presets string[]
---@field coin_trade_chance_values number[]
---@field sell_trade_chance number
---@field current_coin_index int
---@field current_preset_index int
---@field current_coin_trade_chance number
---@field ticks_in_case int
---@field samples_per_tick int
---@field generated int
---@field nil_returns int
---@field counts table<string, int>
---@field expected_categories table<string, boolean>
---@field results table<string, table>
---@field active_weights_lookup_name string
local active_all_preset_range_sampling_run = nil ---@type TradeAllPresetRangeSamplingRun|nil

local function _sanitize_label(label)
    local s = tostring(label or ""):lower()
    s = s:gsub("%s+", "-")
    s = s:gsub("[^%w%-_]", "")
    if s == "" then
        return "unlabeled"
    end
    return s
end

local function _build_shape_category_expectations(weights)
    local expected_categories = {}

    local function add_shape(shape, group_name)
        local function coin_side_label(non_coin_count)
            if non_coin_count <= 0 then
                return "coin"
            end
            return "coin+" .. tostring(non_coin_count)
        end

        local left
        local right
        if group_name == "coin_input" then
            left = coin_side_label(shape.num_inputs - 1)
            right = tostring(shape.num_outputs)
        elseif group_name == "coin_output" then
            left = tostring(shape.num_inputs)
            right = coin_side_label(shape.num_outputs - 1)
        else
            left = tostring(shape.num_inputs)
            right = tostring(shape.num_outputs)
        end
        expected_categories[left .. "->" .. right] = true
    end

    if type(weights) == "table" and (weights.non_coin or weights.coin_input or weights.coin_output) then
        for _, shape in pairs(weights.non_coin or {}) do
            if shape.weight > 0 then add_shape(shape, "non_coin") end
        end
        for _, shape in pairs(weights.coin_input or {}) do
            if shape.weight > 0 then add_shape(shape, "coin_input") end
        end
        for _, shape in pairs(weights.coin_output or {}) do
            if shape.weight > 0 then add_shape(shape, "coin_output") end
        end
    else
        for _, shape in pairs(weights or {}) do
            local left = shape.num_inputs == 0 and "coin" or tostring(shape.num_inputs)
            local right = shape.num_outputs == 0 and "coin" or tostring(shape.num_outputs)
            local key = left .. "->" .. right
            if shape.weight > 0 then expected_categories[key] = true end
        end
    end

    return expected_categories
end

---@return table lookup, string lookup_name
local function _get_active_shape_lookup_for_generator()
    local lookup_name = "trade_shape_weights_lookup"
    local lookup = storage.trades[lookup_name]
    return lookup, lookup_name
end

local function _build_context(player)
    local surface = game.get_surface("nauvis") or (player and player.surface) or game.surfaces[1]
    _expect(surface ~= nil, "No valid surface found for tests")

    local sample_items = _pick_non_coin_items(surface.name, 2)
    local sample_item = sample_items[1] or "iron-plate"
    local volume = _pick_volume(surface.name, sample_item)

    local context = {
        player = player,
        surface_name = surface.name,
        sample_items = sample_items,
        volume = volume,
        defer_ticks = function(num_ticks)
            local n = tonumber(num_ticks) or 1
            n = math.max(1, math.floor(n))
            return {wait_ticks = n}
        end,
    }
    context.defer = context.defer_ticks

    return context
end

local function _start_selected_tests(player, selected_tests)
    if active_run then
        _emit(player, "A test run is already active. Wait for it to complete before starting another run.")
        return
    end
    if active_sampling_run or active_all_preset_sampling_run or active_all_preset_range_sampling_run then
        _emit(player, "A sampling run is already active. Wait for it to complete before starting tests.")
        return
    end

    local context = _build_context(player)
    active_run = {
        player_index = player and player.index or nil,
        selected_tests = selected_tests,
        context = context,
        next_index = 1,
        current = nil,
        passed = 0,
        failed = 0,
    }

    _emit(player, "Running " .. #selected_tests .. " test(s) on surface '" .. context.surface_name .. "' with deferred per-tick execution")
end

local function _resolve_player(player_index)
    if not player_index then return nil end
    return game.get_player(player_index)
end

local function _safe_run_test_call(fn)
    return xpcall(fn, debug.traceback)
end

local function _start_distribution_sampling(player)
    if active_run then
        _emit(player, "A test run is active. Wait for it to finish before starting distribution sampling.")
        return
    end
    if active_all_preset_sampling_run then
        _emit(player, "An all-preset sampling run is active. Wait for it to finish before starting distribution sampling.")
        return
    end
    if active_all_preset_range_sampling_run then
        _emit(player, "An all-preset range sampling run is active. Wait for it to finish before starting distribution sampling.")
        return
    end
    if active_sampling_run then
        _emit(player, "A distribution sampling run is already active.")
        return
    end

    local context = _build_context(player)
    local runtime_settings = {
        coin_trade_chance = lib.runtime_setting_value_as_number("coin-trade-chance"),
        sell_trade_chance = lib.runtime_setting_value_as_number("sell-trade-chance"),
        trade_complexity = lib.runtime_setting_value_as_string("trade-complexity"),
    }

    active_sampling_run = {
        player_index = player and player.index or nil,
        surface_name = context.surface_name,
        volume = context.volume,
        started_tick = game.tick,
        wait_until_tick = game.tick,
        tick_count = 0,
        samples_per_tick = 5,
        samples_attempted = 0,
        generated_count = 0,
        nil_count = 0,
        category_counts = {},
        previous_probabilities = {},
        last_error_l1 = 0,
        runtime_settings = runtime_settings,
    }

    _emit(
        player,
        "Started distribution sampling: " .. active_sampling_run.samples_per_tick .. " trades/tick for "
            .. MAX_TICKS_PER_TEST
            .. " ticks on surface '"
            .. context.surface_name
            .. "'"
    )
end

local function _start_all_preset_sampling(player)
    if active_run then
        _emit(player, "A test run is active. Wait for it to finish before starting all-preset sampling.")
        return
    end
    if active_sampling_run then
        _emit(player, "A distribution sampling run is already active.")
        return
    end
    if active_all_preset_sampling_run then
        _emit(player, "An all-preset sampling run is already active.")
        return
    end
    if active_all_preset_range_sampling_run then
        _emit(player, "An all-preset range sampling run is already active.")
        return
    end
    local lookup, lookup_name = _get_active_shape_lookup_for_generator()
    if type(lookup) ~= "table" then
        _emit(player, "Cannot start all-preset sampling: active trade-shape lookup '" .. tostring(lookup_name) .. "' is missing")
        return
    end

    local presets = {"simple", "balanced", "complex"}
    for _, preset in ipairs(presets) do
        if type(lookup[preset]) ~= "table" then
            _emit(player, "Cannot start all-preset sampling: missing preset table '" .. preset .. "'")
            return
        end
    end

    local context = _build_context(player)
    active_all_preset_sampling_run = {
        player_index = player and player.index or nil,
        surface_name = context.surface_name,
        volume = context.volume,
        started_tick = game.tick,
        wait_until_tick = game.tick,
        phase = "start_preset",
        presets = presets,
        current_index = 1,
        ticks_in_preset = 0,
        samples_per_tick = 5,
        generated = 0,
        nil_returns = 0,
        counts = {},
        expected_categories = {},
        results = {},
        runtime_settings = {
            coin_trade_chance = lib.runtime_setting_value_as_number("coin-trade-chance"),
            sell_trade_chance = lib.runtime_setting_value_as_number("sell-trade-chance"),
        },
        active_weights_lookup_name = lookup_name,
    }

    _emit(
        player,
        "Started all-preset sampling: "
            .. active_all_preset_sampling_run.samples_per_tick
            .. " trades/tick, "
            .. MAX_TICKS_PER_TEST
            .. " ticks per preset (simple, balanced, complex)"
    )
end

local function _start_all_preset_range_sampling(player, mode_label)
    if active_run then
        _emit(player, "A test run is active. Wait for it to finish before starting all-preset range sampling.")
        return
    end
    if active_sampling_run then
        _emit(player, "A distribution sampling run is already active.")
        return
    end
    if active_all_preset_sampling_run then
        _emit(player, "An all-preset sampling run is already active.")
        return
    end
    if active_all_preset_range_sampling_run then
        _emit(player, "An all-preset range sampling run is already active.")
        return
    end
    local lookup, lookup_name = _get_active_shape_lookup_for_generator()
    if type(lookup) ~= "table" then
        _emit(player, "Cannot start all-preset range sampling: active trade-shape lookup '" .. tostring(lookup_name) .. "' is missing")
        return
    end

    local presets = {"simple", "balanced", "complex"}
    for _, preset in ipairs(presets) do
        if type(lookup[preset]) ~= "table" then
            _emit(player, "Cannot start all-preset range sampling: missing preset table '" .. preset .. "'")
            return
        end
    end

    local context = _build_context(player)
    local sanitized_mode_label = _sanitize_label(mode_label)
    if sanitized_mode_label == "unlabeled" then
        sanitized_mode_label = "current"
    end

    active_all_preset_range_sampling_run = {
        player_index = player and player.index or nil,
        mode_label = sanitized_mode_label,
        surface_name = context.surface_name,
        volume = context.volume,
        started_tick = game.tick,
        wait_until_tick = game.tick,
        phase = "start_case",
        presets = presets,
        coin_trade_chance_values = {0.2, 0.3, 0.5},
        sell_trade_chance = 0.5,
        current_coin_index = 1,
        current_preset_index = 1,
        ticks_in_case = 0,
        samples_per_tick = 5,
        generated = 0,
        nil_returns = 0,
        counts = {},
        expected_categories = {},
        results = {},
        active_weights_lookup_name = lookup_name,
    }

    _emit(
        player,
        "Started all-preset range sampling (mode='"
            .. sanitized_mode_label
            .. "'): coin-trade-chance in {0.20, 0.30, 0.50}, sell-trade-chance=0.50, "
            .. MAX_TICKS_PER_TEST
            .. " ticks per case"
    )
end

local function _finish_distribution_sampling(run, tick)
    local player = _resolve_player(run.player_index)
    local probabilities = _build_probability_map(run.category_counts, run.generated_count)
    local output = {
        metadata = {
            command = SAMPLE_COMMAND_NAME,
            started_tick = run.started_tick,
            finished_tick = tick,
            max_ticks = MAX_TICKS_PER_TEST,
            samples_per_tick = run.samples_per_tick,
            surface_name = run.surface_name,
            volume = run.volume,
            runtime_settings = run.runtime_settings,
            error_metric = "l1_probability_distance_vs_previous_tick",
        },
        totals = {
            ticks_sampled = run.tick_count,
            samples_attempted = run.samples_attempted,
            generated = run.generated_count,
            nil_returns = run.nil_count,
            final_error_l1_vs_previous_tick = run.last_error_l1,
        },
        category_counts = run.category_counts,
        category_distribution = probabilities,
    }

    local filename = SAMPLE_OUTPUT_FILE_PREFIX .. tostring(run.started_tick) .. ".json"
    helpers.write_file(filename, helpers.table_to_json(output), false)

    _emit(player, "Distribution sampling completed. JSON written to script-output/" .. filename)
end

local function _finish_all_preset_sampling(run, tick, failed_reason)
    local player = _resolve_player(run.player_index)
    local status = failed_reason and "failed" or "completed"

    -- Restore active weights to current runtime setting after this command.
    local ok_restore, restore_err = xpcall(function()
        trade_generator.init()
    end, debug.traceback)
    if not ok_restore then
        failed_reason = (failed_reason or "Unknown failure") .. " | restore error: " .. tostring(restore_err)
        status = "failed"
    end

    local output = {
        metadata = {
            command = SAMPLE_ALL_PRESETS_COMMAND_NAME,
            status = status,
            started_tick = run.started_tick,
            finished_tick = tick,
            max_ticks_per_preset = MAX_TICKS_PER_TEST,
            samples_per_tick = run.samples_per_tick,
            surface_name = run.surface_name,
            volume = run.volume,
            runtime_settings = run.runtime_settings,
            active_weights_lookup_name = run.active_weights_lookup_name,
            presets = run.presets,
            failure_reason = failed_reason,
        },
        preset_results = run.results,
    }

    local filename = SAMPLE_ALL_PRESETS_OUTPUT_FILE_PREFIX .. tostring(run.started_tick) .. ".json"
    helpers.write_file(filename, helpers.table_to_json(output), false)

    if failed_reason then
        _emit(player, "All-preset sampling failed: " .. failed_reason)
    else
        _emit(player, "All-preset sampling completed successfully.")
    end
    _emit(player, "All-preset sampling JSON written to script-output/" .. filename)
end

local function _finish_all_preset_range_sampling(run, tick, failed_reason)
    local player = _resolve_player(run.player_index)
    local status = failed_reason and "failed" or "completed"

    local ok_restore, restore_err = xpcall(function()
        trade_generator.init()
    end, debug.traceback)
    if not ok_restore then
        failed_reason = (failed_reason or "Unknown failure") .. " | restore error: " .. tostring(restore_err)
        status = "failed"
    end

    local output = {
        metadata = {
            command = SAMPLE_ALL_PRESETS_RANGE_COMMAND_NAME,
            status = status,
            mode_label = run.mode_label,
            active_weights_lookup_name = run.active_weights_lookup_name,
            started_tick = run.started_tick,
            finished_tick = tick,
            max_ticks_per_case = MAX_TICKS_PER_TEST,
            samples_per_tick = run.samples_per_tick,
            surface_name = run.surface_name,
            volume = run.volume,
            coin_trade_chance_values = run.coin_trade_chance_values,
            sell_trade_chance = run.sell_trade_chance,
            presets = run.presets,
            failure_reason = failed_reason,
        },
        sweep_results = run.results,
    }

    local filename = SAMPLE_ALL_PRESETS_RANGE_OUTPUT_FILE_PREFIX
        .. run.mode_label
        .. "_"
        .. tostring(run.started_tick)
        .. ".json"
    helpers.write_file(filename, helpers.table_to_json(output), false)

    if failed_reason then
        _emit(player, "All-preset range sampling failed: " .. failed_reason)
    else
        _emit(player, "All-preset range sampling completed successfully.")
    end
    _emit(player, "All-preset range sampling JSON written to script-output/" .. filename)
end

local function _begin_all_preset_phase(run)
    local complexity = run.presets[run.current_index]
    if not complexity then
        return false, "No complexity preset for index " .. tostring(run.current_index)
    end

    _with_runtime_string_overrides({
        ["trade-complexity"] = complexity,
    }, function()
        trade_generator.init()
    end)

    local lookup = storage.trades[run.active_weights_lookup_name]
    if type(lookup) ~= "table" then
        return false, "Active trade-shape lookup '" .. tostring(run.active_weights_lookup_name) .. "' missing at runtime"
    end
    local expected_weights = lookup[complexity]
    if type(expected_weights) ~= "table" then
        return false, "Missing expected weights for complexity '" .. complexity .. "' in '" .. tostring(run.active_weights_lookup_name) .. "'"
    end
    if storage.trades.trade_shape_weights ~= expected_weights then
        return false, "trade_generator.init did not apply '" .. complexity .. "' preset"
    end
    if storage.trades.trade_shape_weighted_choice_by_group ~= nil then
        return false, "Expected grouped weighted-choice cache reset when initializing '" .. complexity .. "' preset"
    end

    run.expected_categories = _build_shape_category_expectations(expected_weights)
    run.ticks_in_preset = 0
    run.generated = 0
    run.nil_returns = 0
    run.counts = {}
    run.phase = "sample_preset"
    return true, nil
end

local function _begin_all_preset_range_case(run)
    local coin_trade_chance = run.coin_trade_chance_values[run.current_coin_index]
    local complexity = run.presets[run.current_preset_index]
    if coin_trade_chance == nil or complexity == nil then
        return false, "Invalid range sampling index state"
    end

    _with_runtime_setting_overrides({
        ["trade-complexity"] = complexity,
    }, function()
        trade_generator.init()
    end)

    local lookup = storage.trades[run.active_weights_lookup_name]
    if type(lookup) ~= "table" then
        return false, "Active trade-shape lookup '" .. tostring(run.active_weights_lookup_name) .. "' missing at runtime"
    end
    local expected_weights = lookup[complexity]
    if type(expected_weights) ~= "table" then
        return false, "Missing expected weights for complexity '" .. complexity .. "' in '" .. tostring(run.active_weights_lookup_name) .. "'"
    end
    if storage.trades.trade_shape_weights ~= expected_weights then
        return false, "trade_generator.init did not apply '" .. complexity .. "' preset"
    end
    if storage.trades.trade_shape_weighted_choice_by_group ~= nil then
        return false, "Expected grouped weighted-choice cache reset when initializing '" .. complexity .. "' preset"
    end

    run.expected_categories = _build_shape_category_expectations(expected_weights)
    run.ticks_in_case = 0
    run.generated = 0
    run.nil_returns = 0
    run.counts = {}
    run.phase = "sample_case"

    -- Keep currently sampled values in one place for the tick sampler.
    run.current_coin_trade_chance = coin_trade_chance
    return true, nil
end

---@param current {test:table, state:table|nil, initialized:boolean}
---@param context table
---@return boolean ok, any result_or_error
local function _run_current_test_step(current, context)
    local test = current.test

    -- Deferred test protocol (no coroutines):
    --   optional test.init(context) -> state table
    --   required test.run_tick(context, state) for multi-tick tests
    --   return nil or {done=true} to finish; return {wait_ticks=N} to continue later
    if test.run_tick then
        if not current.initialized then
            current.initialized = true
            if test.init then
                local ok_init, state_or_err = _safe_run_test_call(function()
                    return test.init(context)
                end)
                if not ok_init then
                    return false, state_or_err
                end
                current.state = state_or_err
            else
                current.state = {}
            end
        end

        return _safe_run_test_call(function()
            return test.run_tick(context, current.state)
        end)
    end

    -- Backward-compatible synchronous test path.
    if current.initialized then
        return true, {done = true}
    end

    current.initialized = true
    return _safe_run_test_call(function()
        test.run(context)
        return {done = true}
    end)
end

function trade_generator_tests.on_tick(event)
    local tick = event.tick
    if not active_run and not active_sampling_run and not active_all_preset_sampling_run and not active_all_preset_range_sampling_run then
        return
    end

    if active_run then
        local run = active_run
        local player = _resolve_player(run.player_index)

        if not run.current then
            if run.next_index > #run.selected_tests then
                _emit(player, "Completed. Passed=" .. run.passed .. " Failed=" .. run.failed .. " Total=" .. #run.selected_tests)
                active_run = nil
            else
                local index = run.next_index
                local test = run.selected_tests[index]
                run.next_index = index + 1

                _emit(player, "[" .. index .. "/" .. #run.selected_tests .. "] " .. test.id .. " - " .. test.description)

                run.current = {
                    index = index,
                    test = test,
                    started_tick = tick,
                    wait_until_tick = tick,
                    state = nil,
                    initialized = false,
                }
            end
        end

        if not active_run then
            return
        end

        local current = run.current
        if current then
    local timeout_ticks = (current.test and current.test.timeout_ticks) or MAX_TICKS_PER_TEST
    if tick - current.started_tick > timeout_ticks then
        run.failed = run.failed + 1
        _emit(player, "FAIL: " .. current.test.id .. " :: timed out after " .. timeout_ticks .. " ticks")
        run.current = nil
            elseif tick >= current.wait_until_tick then
                local ok, yielded = _run_current_test_step(current, run.context)
                if not ok then
                    run.failed = run.failed + 1
                    _emit(player, "FAIL: " .. current.test.id .. " :: " .. tostring(yielded))
                    run.current = nil
                else
                    local wait_ticks = 0
                    local is_done = true
                    if type(yielded) == "table" then
                        if yielded.wait_ticks ~= nil then
                            wait_ticks = math.max(1, math.floor(tonumber(yielded.wait_ticks) or 1))
                            is_done = false
                        elseif yielded.done ~= nil then
                            is_done = yielded.done ~= false
                        end
                    end

                    if is_done then
                        run.passed = run.passed + 1
                        _emit(player, "PASS: " .. current.test.id)
                        run.current = nil
                    else
                        current.wait_until_tick = tick + wait_ticks
                    end
                end
            end
        end
    end

    if active_sampling_run then
        local run = active_sampling_run
        if tick >= run.wait_until_tick then
            run.tick_count = run.tick_count + 1

            for _ = 1, run.samples_per_tick do
                run.samples_attempted = run.samples_attempted + 1
                local tentative_trade = trade_generator.generate_random(run.surface_name, {}, run.volume, {allow_nil_return = true}, true, nil)
                if tentative_trade then
                    run.generated_count = run.generated_count + 1
                    local category = _get_trade_category(tentative_trade)
                    run.category_counts[category] = (run.category_counts[category] or 0) + 1
                else
                    run.nil_count = run.nil_count + 1
                end
            end

            local current_probabilities = _build_probability_map(run.category_counts, run.generated_count)
            local err = _distribution_error_l1(run.previous_probabilities, current_probabilities)
            run.last_error_l1 = err
            run.previous_probabilities = current_probabilities

            if run.tick_count >= MAX_TICKS_PER_TEST then
                _finish_distribution_sampling(run, tick)
                active_sampling_run = nil
            else
                run.wait_until_tick = tick + 1
            end
        end
    end

    if active_all_preset_sampling_run then
        local run = active_all_preset_sampling_run
        if tick < run.wait_until_tick then
            return
        end

        if run.current_index > #run.presets then
            _finish_all_preset_sampling(run, tick, nil)
            active_all_preset_sampling_run = nil
            return
        end

        if run.phase == "start_preset" then
            local ok, err = _begin_all_preset_phase(run)
            if not ok then
                _finish_all_preset_sampling(run, tick, err)
                active_all_preset_sampling_run = nil
                return
            end

            local complexity = run.presets[run.current_index]
            local player = _resolve_player(run.player_index)
            _emit(player, "Sampling preset '" .. complexity .. "' for " .. MAX_TICKS_PER_TEST .. " ticks")
            run.wait_until_tick = tick + 1
            return
        end

        _with_runtime_number_overrides({
            ["coin-trade-chance"] = run.runtime_settings.coin_trade_chance,
            ["sell-trade-chance"] = run.runtime_settings.sell_trade_chance,
        }, function()
            for _ = 1, run.samples_per_tick do
                local tentative = trade_generator.generate_random(run.surface_name, {}, run.volume, {allow_nil_return = true}, true, nil)
                if tentative then
                    local category = _get_trade_category(tentative)
                    run.counts[category] = (run.counts[category] or 0) + 1
                    run.generated = run.generated + 1
                else
                    run.nil_returns = run.nil_returns + 1
                end
            end
        end)

        run.ticks_in_preset = run.ticks_in_preset + 1
        if run.ticks_in_preset < MAX_TICKS_PER_TEST then
            run.wait_until_tick = tick + 1
            return
        end

        local complexity = run.presets[run.current_index]
        if run.generated <= 0 then
            _finish_all_preset_sampling(run, tick, "No trades were generated while sampling preset '" .. complexity .. "'")
            active_all_preset_sampling_run = nil
            return
        end
        run.results[complexity] = {
            trade_complexity_source = complexity,
            ticks_sampled = run.ticks_in_preset,
            generated = run.generated,
            nil_returns = run.nil_returns,
            category_counts = table.deepcopy(run.counts),
            category_distribution = _build_probability_map(run.counts, run.generated),
        }

        run.current_index = run.current_index + 1
        run.phase = "start_preset"
        run.wait_until_tick = tick + 1
    end

    if active_all_preset_range_sampling_run then
        local run = active_all_preset_range_sampling_run
        if tick < run.wait_until_tick then
            return
        end

        if run.current_coin_index > #run.coin_trade_chance_values then
            _finish_all_preset_range_sampling(run, tick, nil)
            active_all_preset_range_sampling_run = nil
            return
        end

        if run.phase == "start_case" then
            local ok, err = _begin_all_preset_range_case(run)
            if not ok then
                _finish_all_preset_range_sampling(run, tick, err)
                active_all_preset_range_sampling_run = nil
                return
            end

            local complexity = run.presets[run.current_preset_index]
            local player = _resolve_player(run.player_index)
            _emit(
                player,
                "Range sampling case: coin-trade-chance="
                    .. string.format("%.2f", run.current_coin_trade_chance)
                    .. ", complexity='"
                    .. complexity
                    .. "' for "
                    .. MAX_TICKS_PER_TEST
                    .. " ticks"
            )
            run.wait_until_tick = tick + 1
            return
        end

        _with_runtime_setting_overrides({
            ["coin-trade-chance"] = run.current_coin_trade_chance,
            ["sell-trade-chance"] = run.sell_trade_chance,
        }, function()
            for _ = 1, run.samples_per_tick do
                local tentative = trade_generator.generate_random(run.surface_name, {}, run.volume, {allow_nil_return = true}, true, nil)
                if tentative then
                    local category = _get_trade_category(tentative)
                    run.counts[category] = (run.counts[category] or 0) + 1
                    run.generated = run.generated + 1
                else
                    run.nil_returns = run.nil_returns + 1
                end
            end
        end)

        run.ticks_in_case = run.ticks_in_case + 1
        if run.ticks_in_case < MAX_TICKS_PER_TEST then
            run.wait_until_tick = tick + 1
            return
        end

        local complexity = run.presets[run.current_preset_index]
        if run.generated <= 0 then
            _finish_all_preset_range_sampling(run, tick, "No trades were generated for coin-trade-chance=" .. tostring(run.current_coin_trade_chance) .. ", complexity='" .. complexity .. "'")
            active_all_preset_range_sampling_run = nil
            return
        end
        local coin_category_count = 0
        for category, count in pairs(run.counts) do
            if string.find(category, "coin", 1, true) then
                coin_category_count = coin_category_count + count
            end
        end

        if run.current_coin_trade_chance == 0.2 then
            local player = _resolve_player(run.player_index)
            _emit(
                player,
                "Override parity probe @0.20 for complexity '"
                    .. complexity
                    .. "': coin_category_count="
                    .. tostring(coin_category_count)
            )
        end

        if run.current_coin_trade_chance == 0.2 and coin_category_count <= 0 then
            _finish_all_preset_range_sampling(run, tick, "Override parity check failed: expected coin categories at coin-trade-chance=0.20 for complexity '" .. complexity .. "'")
            active_all_preset_range_sampling_run = nil
            return
        end

        local coin_key = string.format("%.2f", run.current_coin_trade_chance)
        run.results[coin_key] = run.results[coin_key] or {}
        run.results[coin_key][complexity] = {
            trade_complexity_source = complexity,
            ticks_sampled = run.ticks_in_case,
            generated = run.generated,
            nil_returns = run.nil_returns,
            coin_category_count = coin_category_count,
            category_counts = table.deepcopy(run.counts),
            category_distribution = _build_probability_map(run.counts, run.generated),
        }

        if run.current_preset_index < #run.presets then
            run.current_preset_index = run.current_preset_index + 1
        else
            run.current_preset_index = 1
            run.current_coin_index = run.current_coin_index + 1
        end
        run.phase = "start_case"
        run.wait_until_tick = tick + 1
    end

end

function trade_generator_tests.register_commands()
    script.on_nth_tick(1, trade_generator_tests.on_tick)

    commands.remove_command(COMMAND_NAME)
    commands.add_command(
        COMMAND_NAME,
        "/trade-generator-tests [all|list|<test-id>] - Runs trade generator validation tests.",
        function(cmd)
            local player = cmd.player_index and game.get_player(cmd.player_index) or nil
            local arg = cmd.parameter and cmd.parameter:match("^%s*(.-)%s*$") or ""

            if arg == "" or arg == "all" then
                _start_selected_tests(player, tests)
                return
            end

            if arg == "list" then
                _list_tests(player)
                return
            end

            local test = _find_test(arg)
            if not test then
                _emit(player, "Unknown test id: '" .. arg .. "'")
                _list_tests(player)
                return
            end

            _start_selected_tests(player, {test})
        end
    )

    commands.remove_command(SAMPLE_COMMAND_NAME)
    commands.add_command(
        SAMPLE_COMMAND_NAME,
        "/trade-generator-sample-distribution - Samples trades per tick for MAX_TICKS_PER_TEST and exports category distribution JSON to script-output.",
        function(cmd)
            local player = cmd.player_index and game.get_player(cmd.player_index) or nil
            _start_distribution_sampling(player)
        end
    )

    commands.remove_command(SAMPLE_ALL_PRESETS_COMMAND_NAME)
    commands.add_command(
        SAMPLE_ALL_PRESETS_COMMAND_NAME,
        "/trade-generator-sample-all-presets - Samples simple/balanced/complex presets sequentially with MAX_TICKS_PER_TEST budgets and exports JSON.",
        function(cmd)
            local player = cmd.player_index and game.get_player(cmd.player_index) or nil
            _start_all_preset_sampling(player)
        end
    )

    commands.remove_command(SAMPLE_ALL_PRESETS_RANGE_COMMAND_NAME)
    commands.add_command(
        SAMPLE_ALL_PRESETS_RANGE_COMMAND_NAME,
        "/trade-generator-sample-all-presets-range [mode-label] - Sweeps coin-trade-chance (0.20, 0.30, 0.50) across simple/balanced/complex and exports one JSON matrix.",
        function(cmd)
            local player = cmd.player_index and game.get_player(cmd.player_index) or nil
            local mode_label = cmd.parameter and cmd.parameter:match("^%s*(.-)%s*$") or ""
            _start_all_preset_range_sampling(player, mode_label)
        end
    )

end

return trade_generator_tests
