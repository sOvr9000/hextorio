
local lib = require "api.lib"
local axial       = require "api.axial"
local terrain     = require "api.terrain"
local item_values = require "api.item_values"
local sets        = require "api.sets"
local item_ranks  = require "api.item_ranks"
local coin_tiers  = require "api.coin_tiers"
local event_system= require "api.event_system"
local gameplay_statistics = require "api.gameplay_statistics"
local quests      = require "api.quests"
local hex_island  = require "api.hex_island"
local trade_loop_finder = require "api.trade_loop_finder"
local inventories       = require "api.inventories"
local hex_state_manager = require "api.hex_state_manager"
local hex_util          = require "api.hex_util"
local hex_sets          = require "api.hex_sets"



local trades = {}



---@alias TradeSide
---| "give" The left side
---| "receive" The right side

---@alias TradeItemSamplingParameters StringFilters
---@alias TradeInputMap {[string]: int[]}

---@class Trade
---@field id int Unique ID (serial number) given to this trade.
---@field surface_name string
---@field active boolean Whether this trade is currently allowed to be executed when possible.
---@field hex_core_state HexState|nil The hex core state to which this trade belongs.
---@field allowed_qualities string[] The current list of qualities allowed to be used by this trade.
---@field productivity number The base productivity of this trade to be used in calculating the productivity for each quality.
---@field current_prod_value StringAmounts Indexed by quality name, the current progress towards filling the productivity bar (red or purple).
---@field max_items_per_output number|nil The maximum number of items to be output by this trade, per output item type.
---@field is_interplanetary boolean Cached flag for quickly checking whether this trade contains an interplanetary item in either its inputs or outputs.
---@field has_coins_in_input boolean Cached flag for quickly checking whether this trade contains coins in its inputs.
---@field has_coins_in_output boolean Cached flag for quickly checking whether this trade contains coins in its outputs.
---@field input_items TradeItem[] List of item names and counts representing the inputs of the trade.
---@field output_items TradeItem[] List of item names and counts representing the outputs of the trade.

---@class TentativeTrade Similar to a Trade, but during the process of its generation and before state initialization. Particularly, output item counts are nil until determined by the generator.
---@field surface_name string
---@field input_items TentativeTradeItem[]
---@field output_items TentativeTradeItem[]

---@class TradeItem
---@field name string
---@field count int

---@class TentativeTradeItem
---@field name string
---@field count int|nil Can be nil until determined by the generator.

---@class TradeGenerationParameters
---@field target_efficiency number|nil The requested ratio of item values from outputs to inputs in the generated trade.
---@field target_efficiency_epsilon number|nil The allowed error in the actual ratio of items values from outputs to inputs in the generated trade. Set to 1 to request a perfect efficiency/ratio match. Set to a number close to but above 1.0 like 1.1 to allow for ratios close to the target efficiency/ratio.
---@field item_sampling_filters TradeItemSamplingParameters|nil The item names to forcefully include (by whitelist) or exclude (by blacklist) in the item name candidates for the random trade generator, allowing the generator to select from more or fewer items, where the blacklist enforces exclusion but the whitelist does not enforce inclusion.
---@field max_stacks_per_item number|nil The maximum number of stacks allowed per item in the generated trade.  For example, if this is 2, then item count for beacons would not exceed 2*20 = 40. Can be a non-integer.
---@field max_count_per_item int|nil The maximum amount of each item allowed in the generated trade.  This feels reasonable at around 100, preventing from (e.g.) having to feed an egregious amount of items for a small return.
---@field allow_nil_return boolean|nil Whether to allow a nil trade if the generator cannot solve the item counts from a given set of items and item count constraints. If the generator fails to approximate target_efficiency and allow_nil_return = false, then a trade with the closest possible ratio is returned. Defaults to true.

---@class TradeProductivityUpdateJob
---@field surface_id int The surface ID to update trades on
---@field current_flat_index int The current flat index in the flattened_surface_hexes array
---@field total_flat_indices int The total number of flat indices to process

---@class TradeCollectionJob
---@field player LuaPlayer The player that queued this job
---@field trade_ids int[] Array of trade IDs to collect
---@field current_index int Current index in the trade_ids array
---@field total_count int Total number of trades to collect
---@field collected_trades {[int]: Trade} Lookup table of collected trade objects
---@field filter TradeOverviewFilterSettings The filter settings to use after collection
---@field process_immediately boolean If true, process all trades in a single tick without progress events

---@class TradeFilteringJob
---@field player LuaPlayer The player that queued this job
---@field trades_lookup {[int]: Trade} Lookup table of trades to filter
---@field trade_ids int[] Array of trade IDs to filter
---@field current_index int Current index in the trade_ids array
---@field total_count int Total number of trades to filter
---@field filtered_trades {[int]: Trade} Lookup table of filtered trade objects
---@field filter TradeOverviewFilterSettings The filter settings to apply
---@field is_favorited {[int]: boolean} Lookup table of favorited status
---@field ready_to_complete boolean If true, will trigger completion event on next tick
---@field process_immediately boolean If true, process all trades in a single tick without progress events

---@class TradeSortingJob
---@field player LuaPlayer The player that queued this job
---@field filtered_trades {[int]: Trade} Lookup table of filtered trades to sort
---@field is_favorited {[int]: boolean} Lookup table of favorited status
---@field trade_ids int[] Array of trade IDs to process
---@field current_index int Current index in the trade_ids array
---@field total_count int Total number of trades to process
---@field filter TradeOverviewFilterSettings The filter settings (including max_trades and sorting)
---@field sorted_top_trades Trade[] Array of top N trades (bounded to max_trades), maintained in sorted order
---@field sort_keys {[int]: number} Cached sort keys for trades in sorted_top_trades
---@field min_sort_key number|nil Minimum sort key in sorted_top_trades (worst trade)
---@field max_sort_key number|nil Maximum sort key in sorted_top_trades (best trade)
---@field metrics {[int]: number}|nil Cached metrics (like distances, trade volumes, or trade productivities) for sorting
---@field process_immediately boolean If true, process all trades in a single tick without progress events

---@class TradeExportJob
---@field player LuaPlayer The player that queued this job
---@field trade_ids int[] Array of trade IDs to export
---@field current_index int Current index in the trade_ids array
---@field total_count int Total number of trades to export
---@field seen_items {[string]: {[string]: boolean}} Items seen per surface (surface_name -> item_name -> true)
---@field formatted_trades {[string]: table[]} Formatted trades per surface
---@field item_value_lookup {[string]: {[string]: number}} Item values per surface



function trades.register_events()
    local function discover_all(player, params, trigger_post)
        local items_list = {}
        for surface_name, vals in pairs(storage.item_values.values) do
            for item_name, _ in pairs(vals) do
                if not lib.is_coin(item_name) and lib.is_item(item_name) then
                    table.insert(items_list, item_name)
                end
            end
        end

        trades.discover_items(items_list)

        if trigger_post then
            event_system.trigger("post-discover-all-command", player, params)
        end
    end

    -- Automatically discover all items when ranking up all items.
    event_system.register("command-discover-all", function(player, params) discover_all(player, params, true) end)
    event_system.register("command-rank-up-all", function(player, params) discover_all(player, params, false) end)

    event_system.register("command-refresh-all-trades", function(player, params)
        trades.recalculate_researched_items()
        trades.fetch_base_trade_productivity_settings()
        trades.queue_productivity_update_job()
    end)

    event_system.register("item-buff-changed-trade-productivity", function() trades.queue_productivity_update_job() end)

    local function fetch_and_queue_update(surface_name)
        trades.fetch_base_trade_productivity_settings(surface_name)
        trades.queue_productivity_update_job(surface_name)
    end

    event_system.register("runtime-setting-changed-base-trade-prod-nauvis", function() fetch_and_queue_update "nauvis" end)
    event_system.register("runtime-setting-changed-base-trade-prod-vulcanus", function() fetch_and_queue_update "vulcanus" end)
    event_system.register("runtime-setting-changed-base-trade-prod-fulgora", function() fetch_and_queue_update "fulgora" end)
    event_system.register("runtime-setting-changed-base-trade-prod-gleba", function() fetch_and_queue_update "gleba" end)
    event_system.register("runtime-setting-changed-base-trade-prod-aquilo", function() fetch_and_queue_update "aquilo" end)

    event_system.register("runtime-setting-changed-trade-batching-threshold", function()
        storage.trades.batch_processing_threshold = lib.runtime_setting_value_as_int "trade-batching-threshold"
    end)

    event_system.register("runtime-setting-changed-trade-collection-batch-size", function()
        storage.trades.collection_batch_size = lib.runtime_setting_value_as_int "trade-collection-batch-size"
    end)

    event_system.register("runtime-setting-changed-trade-filtering-batch-size", function()
        storage.trades.filtering_batch_size = lib.runtime_setting_value_as_int "trade-filtering-batch-size"
    end)

    event_system.register("runtime-setting-changed-trade-sorting-batch-size", function()
        storage.trades.sorting_batch_size = lib.runtime_setting_value_as_int "trade-sorting-batch-size"
    end)

    event_system.register("runtime-setting-changed-base-trade-efficiency", function()
        storage.trades.base_trade_efficiency = lib.runtime_setting_value_as_number "base-trade-efficiency"
    end)

    event_system.register("entity-killed-entity", trades.on_entity_killed_entity)
end

function trades.init()
    for surface_name, surrounding_trades in pairs(storage.trades.surrounding_trades) do
        local island_hexes = hex_island.get_island_hex_set(surface_name)

        -- lib.log("found island hexes for " .. surface_name .. ": " .. serpent.line(island_hexes))

        -- Select land hexes close to spawn
        local range = 2 -- Adjacent hexes, or secondly adjacent
        local hexes_set, _ = hex_util.all_hexes_within_range({q=0, r=0}, range, island_hexes)
        hex_sets.remove(hexes_set, {q=0, r=0})

        local hexes_list = hex_sets.to_array(hexes_set)

        -- lib.log("found connected hexes from spawn: " .. serpent.line(hexes_list))

        if #hexes_list > 0 then
            for _, trade_items in pairs(surrounding_trades) do
                local input_names = trade_items[1]
                local output_names = trade_items[2]
                local params = {target_efficiency = storage.trades.base_trade_efficiency}
                local trade = trades.from_item_names(surface_name, input_names, output_names, params)
                if trade then
                    local pos = hexes_list[math.random(1, #hexes_list)]
                    trades.add_guaranteed_trade(trade, pos)
                    -- lib.log("Added guaranteed trade " .. lib.tostring_trade(trade) .. " in hex " .. serpent.line(pos))
                else
                    lib.log_error("trades.init: Failed to generate trade from item names: " .. serpent.line(input_names) .. " -> " .. serpent.line(output_names) .. " -- Is target_efficiency too high or low (see below)?\nparams = " .. serpent.block(params))
                end
            end
        else
            lib.log_error("trades.init: Could not find hexes near spawn to add guaranteed trades on " .. surface_name)
        end
    end
end

---Set a hex position to be guaranteed to contain a specific trade.
---@param trade Trade
---@param hex_pos HexPos
function trades.add_guaranteed_trade(trade, hex_pos)
    local surface_guaranteed_trades = storage.trades.guaranteed_trades[trade.surface_name]
    if not surface_guaranteed_trades then
        surface_guaranteed_trades = {}
        storage.trades.guaranteed_trades[trade.surface_name] = surface_guaranteed_trades
    end

    local Q = surface_guaranteed_trades[hex_pos.q]
    if not Q then
        Q = {}
        surface_guaranteed_trades[hex_pos.q] = Q
    end

    local guaranteed_trades = Q[hex_pos.r]
    if not guaranteed_trades then
        guaranteed_trades = {}
        Q[hex_pos.r] = guaranteed_trades
    end

    table.insert(guaranteed_trades, trade)
end

---Create a new trade object.
---@param input_items TradeItem[]
---@param output_items TradeItem[]
---@param surface_name string
---@return TentativeTrade
function trades.new(input_items, output_items, surface_name)
    ---@type TentativeTrade
    local trade = {
        surface_name = surface_name,
        input_items = table.deepcopy(input_items),
        output_items = table.deepcopy(output_items),
    }

    return trade
end

---Return a Trade object from a TentativeTrade object, initializing state.
---@param trade TentativeTrade
---@return Trade
function trades.initialize_trade_state(trade)
    storage.trades.trade_id_ctr = (storage.trades.trade_id_ctr or 0) + 1

    local input_items = trade.input_items
    local output_items = trade.output_items

    -- Item counts will be have been set by the generator.
    ---@cast input_items TradeItem[]
    ---@cast output_items TradeItem[]

    local is_interplanetary = false
    local has_coins_in_input = false
    for _, input_item in pairs(input_items) do
        if lib.is_coin(input_item.name) then
            has_coins_in_input = true
        end
        if item_values.is_item_interplanetary(trade.surface_name, input_item.name) then
            is_interplanetary = true
        end
    end

    local has_coins_in_output = false
    for _, output_item in pairs(output_items) do
        if lib.is_coin(output_item.name) then
            has_coins_in_output = true
            break
        end
        if item_values.is_item_interplanetary(trade.surface_name, output_item.name) then
            is_interplanetary = true
        end
    end

    ---@type Trade
    local new = {
        id = storage.trades.trade_id_ctr,
        surface_name = trade.surface_name,
        input_items = input_items,
        output_items = output_items,
        active = true,
        has_coins_in_input = has_coins_in_input,
        has_coins_in_output = has_coins_in_output,
        allowed_qualities = {"normal"},
        productivity = 0,
        current_prod_value = {},
        is_interplanetary = is_interplanetary,
    }

    trades.check_productivity(new)

    return new
end

---Generate a trade object from item names, using item values to determine best input and output counts and normalizing tiered coins to the lowest tier.  Can return nil if the given `params.target_efficiency` is impossible to achieve with the input and output item names while respecting item count constraints.
---@param surface_name string
---@param input_item_names string[]
---@param output_item_names string[]
---@param params TradeGenerationParameters|nil
---@return Trade|nil
function trades.from_item_names(surface_name, input_item_names, output_item_names, params)
    if not params then params = {} end
    trades.set_trade_generation_parameter_defaults(params)

    local surface = game.get_surface(surface_name)
    if not surface then
        lib.log_error("trades.from_item_names: Invalid surface name: " .. surface_name)
        return
    end

    if lib.is_space_platform(surface) then
        lib.log_error("trades.from_item_names: Attempting to create a trade for a space platform (illegal) with input_item_names = " .. serpent.line(input_item_names) .. ", output_item_names = " .. serpent.line(output_item_names))
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

    local max_value = 0
    for _, item_name in pairs(input_item_names) do
        max_value = math.max(max_value, item_values.get_item_value(surface_name, item_name))
    end
    for _, item_name in pairs(output_item_names) do
        max_value = math.max(max_value, item_values.get_item_value(surface_name, item_name))
    end

    local input_items = {}
    for _, item_name in pairs(input_item_names) do
        local input_item = {
            name = item_name,
        }
        table.insert(input_items, input_item)
    end

    local output_items = {}
    for _, item_name in pairs(output_item_names) do
        local output_item = {
            name = item_name,
            -- leave count unset for automatic calculation
        }
        table.insert(output_items, output_item)
    end

    local tentative = trades.new(input_items, output_items, surface_name)
    local solved = trades.generator_solve_item_counts(surface_name, tentative, params)

    if params.allow_nil_return and not solved then
        return
    end

    return trades.initialize_trade_state(tentative)
end

---Given a trade with undefined output item counts, attempt to set the output counts to the values which best preserve a value ratio of the given `params.target_efficiency`.  If the solver fails (returning false), item counts are left undefined.
---@param surface_name string
---@param trade TentativeTrade
---@param params TradeGenerationParameters|nil
---@return boolean solved Whether the target_efficiency could be approximated with item counts while respecting item count constraints.
function trades.generator_solve_item_counts(surface_name, trade, params)
    if not params then params = {} end
    trades.set_trade_generation_parameter_defaults(params)

    -- log("")
    -- log("")

    -- log("INIT ITEM COUNT SOLVER")
    -- log("inputs: " .. serpent.line(trade.input_items))
    -- log("outputs: " .. serpent.line(trade.output_items))
    -- log("params: " .. serpent.line(params))

    -- Convert coins to lowest tier
    for _, input_item in pairs(trade.input_items) do
        if lib.is_coin(input_item.name) then
            input_item.name = "hex-coin"
            break
        end
    end

    for _, output_item in pairs(trade.output_items) do
        if lib.is_coin(output_item.name) then
            output_item.name = "hex-coin"
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

    -- log("Initial item counts:")
    -- log("inputs: " .. serpent.line(trade.input_items))
    -- log("outputs: " .. serpent.line(trade.output_items))

    -- log("initial total_input_value = " .. (total_input_value * den) .. " (" .. den .. " * " .. total_input_value .. ")")
    -- log("initial total_output_value = " .. (total_output_value * den) .. " (" .. num .. " * " .. total_output_value .. ")")

    total_input_value = total_input_value * den
    total_output_value = total_output_value * num

    -- Scale up if total values are under one hex coin
    local min_total_value = item_values.get_item_value("nauvis", "hex-coin")
    if total_input_value < min_total_value or total_output_value < min_total_value then
        local scale = math.max(math.ceil(min_total_value / total_input_value), math.ceil(min_total_value / total_output_value))

        for _, input_item in pairs(trade.input_items) do
            input_item.count = input_item.count * scale
        end

        for _, output_item in pairs(trade.output_items) do
            output_item.count = output_item.count * scale
        end

        -- log("scaled up total_input_value = " .. total_input_value .. " by " .. scale .. "x to total_input_value = " .. (total_input_value * scale))
        -- log("scaled up total_output_value = " .. total_output_value .. " by " .. scale .. "x to total_output_value = " .. (total_output_value * scale))

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
    -- log("New input counts: " .. serpent.line(trade.input_items))
    -- log("Updating total_input_value = " .. total_input_value .. ": new_total_input_value = " .. new_total_input_value)
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
    -- log("New output counts: " .. serpent.line(trade.output_items))
    -- log("Updating total_output_value = " .. total_output_value .. ": new_total_output_value = " .. new_total_output_value)
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

    -- log("START SOLVER")
    -- log(serpent.line(working_inputs) .. " -> " .. serpent.line(working_outputs))
    -- log("target_ratio = " .. target_ratio .. " (sqrt of " .. params.target_efficiency .. ")")
    -- log("epsilon = " .. epsilon)
    -- log("epsilon_inv = " .. epsilon_inv)
    -- log("initial total_input_value = " .. total_input_value)
    -- log("initial total_output_value = " .. total_output_value)

    local solved = false
    local max_iterations = 100
    for iteration = 1, max_iterations do
        local current_efficiency = total_output_value / total_input_value

        local ratio = current_efficiency / params.target_efficiency
        if ratio <= epsilon and ratio >= epsilon_inv then
            -- log("finished after " .. iteration .. " iterations")
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

            -- log("side = " .. j)
            -- log("total_value = " .. total_value)
            -- log("other_total_value = " .. other_total_value)
            -- log("target_total_value = " .. target_total_value)

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
                -- log("set new target_total_value = " .. target_total_value)

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

                    -- log("scaled up from 1x")
                    break
                end
            end

            local perm = PERMUTATIONS[math.random(1, #PERMUTATIONS)]
            for _, cur_index in pairs(perm) do
                if cur_index <= #working_items then
                    local item = working_items[cur_index]
                    local item_value = item_vals[cur_index]
                    local stack_size = item_stack_sizes[cur_index]

                    -- log("cur item = " .. item.name .. ", count = " .. item.count)

                    local sum_of_other_values = total_value - item_value * item.count
                    -- log("sum of other values = " .. sum_of_other_values)

                    local new_count = math.max(1, math.floor(0.5 + (target_total_value - sum_of_other_values) / item_value))
                    -- log("new count = " .. new_count)

                    -- TODO: Don't repeatedly call lib.is_coin() here because it performs string operations (which are slow)
                    if not lib.is_coin(item.name) then
                        ---@diagnostic disable-next-line: cast-local-type
                        new_count = math.min(params.max_count_per_item, new_count)

                        if stack_size then
                            ---@diagnostic disable-next-line: cast-local-type
                            new_count = math.min(params.max_stacks_per_item * stack_size, new_count)
                        end
                    end

                    if new_count ~= item.count then
                        changed = true

                        if j == 1 then
                            total_input_value = total_value + (new_count - item.count) * item_value
                        else
                            total_output_value = total_value + (new_count - item.count) * item_value
                        end
                        item.count = new_count

                        break
                    end
                end
            end
        end

        -- log("current item counts: " .. serpent.line(working_inputs) .. " | " .. serpent.line(working_outputs))

        if not changed then
            solved = iteration < max_iterations
            -- log("terminated early after " .. iteration .. " iterations")
            -- log("solved = " .. tostring(solved))
            break
        end
    end

    -- log("finished iteration with final ratio: " .. total_output_value .. " / " .. total_input_value .. " = " .. (total_output_value / total_input_value))

    trade.input_items = working_inputs
    trade.output_items = working_outputs

    return solved
end

---Return the value of the trade's inputs on a given surface.
---@param surface_name string
---@param trade Trade
---@param quality string|nil
---@param quality_cost_mult number|nil
---@return number
function trades.get_input_value(surface_name, trade, quality, quality_cost_mult)
    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1
    local input_value = 0
    local quality_value_scale = lib.get_quality_value_scale(quality)
    for _, input_item in pairs(trade.input_items) do
        local value = item_values.get_item_value(surface_name, input_item.name) * input_item.count * quality_value_scale
        if lib.is_coin(input_item.name) then
            value = value * quality_cost_mult
        end
        input_value = input_value + value
    end
    return input_value
end

---Return the value of the trade's outputs on a given surface.
---@param surface_name string
---@param trade Trade
---@param quality string|nil
---@return number
function trades.get_output_value(surface_name, trade, quality)
    quality = quality or "normal"
    local output_value = 0
    local quality_value_scale = lib.get_quality_value_scale(quality)
    for _, output_item in pairs(trade.output_items) do
        output_value = output_value + item_values.get_item_value(surface_name, output_item.name) * output_item.count * quality_value_scale
    end
    return output_value
end

---Return the volume of the trade on a given surface.
---@param surface_name string
---@param trade Trade
---@return number
function trades.get_volume_of_trade(surface_name, trade)
    return trades.get_total_value_of_trade(surface_name, trade) * 0.5
end

---Return the ratio of values of the trade's outputs to its inputs, on a given surface.
---@param surface_name string
---@param trade Trade
---@return number
function trades.get_trade_value_ratio(surface_name, trade)
    return trades.get_output_value(surface_name, trade) / trades.get_input_value(surface_name, trade)
end

---Return the total value of the trade on a given surface.
---@param surface_name string
---@param trade Trade
---@param quality string|nil
---@param quality_cost_mult number|nil
---@return number
function trades.get_total_value_of_trade(surface_name, trade, quality, quality_cost_mult)
    return trades.get_input_value(surface_name, trade, quality, quality_cost_mult) + trades.get_output_value(surface_name, trade, quality)
end

---Return a human-readable string which represents the trade's total input and output values, including productivity bonuses if present.
---@param trade Trade
---@param quality string|nil
---@param quality_cost_mult number|nil
function trades.get_total_values_str(trade, quality, quality_cost_mult)
    local coin_value = item_values.get_item_value("nauvis", "hex-coin")
    local total_input_value = trades.get_input_value(trade.surface_name, trade, quality, quality_cost_mult) / coin_value
    local total_output_value = trades.get_output_value(trade.surface_name, trade, quality) / coin_value
    local str = {"",
        {"hextorio-gui.total-input-value", coin_tiers.base_coin_value_to_text(total_input_value)},
        "\n",
        {"hextorio-gui.total-output-value", coin_tiers.base_coin_value_to_text(total_output_value)},
    }
    local prod = trades.get_productivity(trade, quality)
    if prod ~= 0 then
        table.insert(str, "\n")
        table.insert(str, {"hextorio-gui.total-output-with-prod", coin_tiers.base_coin_value_to_text(trades.scale_value_with_productivity(total_output_value, prod))})
    end
    return str
end

---Return a human-readable string which summarizes the calculations for the trade's productivity bonus.
---@param trade Trade
---@param quality string|nil
function trades.get_productivity_bonus_str(trade, quality)
    if not quality then quality = "normal" end

    local prod = trades.get_productivity(trade, quality)
    local prod_mod = trades.get_productivity_modifier(quality)

    if not trades.has_any_productivity_modifiers(trade, quality) then
        return ""
    end

    local bonus_strs = {}

    for _, input_item in pairs(trade.input_items) do
        if item_ranks.is_item_rank_defined(input_item.name) then
            local rank = item_ranks.get_item_rank(input_item.name)
            if rank >= 2 then
                table.insert(bonus_strs, "[img=item." .. input_item.name .. "] [color=green]" .. lib.format_percentage(item_ranks.get_rank_bonus_effect(rank), 0, true, true) .. "[.color]")
            end
        end
    end
    for _, output_item in pairs(trade.output_items) do
        if item_ranks.is_item_rank_defined(output_item.name) then
            local rank = item_ranks.get_item_rank(output_item.name)
            if rank >= 2 then
                table.insert(bonus_strs, "[img=item." .. output_item.name .. "] [color=green]" .. lib.format_percentage(item_ranks.get_rank_bonus_effect(rank), 0, true, true) .. "[.color]")
            end
        end
    end
    for _, output_item in pairs(trade.output_items) do
        if not storage.trades.researched_items[output_item.name] then
            table.insert(bonus_strs, "[img=virtual-signal.signal-science-pack][img=item." .. output_item.name .. "] [color=red]" .. lib.format_percentage(-storage.trades.unresearched_penalty * storage.item_buffs.unresearched_penalty_multiplier, 0, true, true) .. "[.color]")
        end
    end

    if prod_mod ~= 0 then
        table.insert(bonus_strs, "[img=quality." .. quality .. "] [color=red]" .. lib.format_percentage(prod_mod, 0, true, true) .. "[.color]")
    end

    local color
    if prod >= 0 then
        color = "green"
    else
        color = "red"
    end

    local s = "\n" .. table.concat(bonus_strs, "\n")
    if #bonus_strs > 0 then
        s = s .. "\n"
    end

    local str = {"",
        lib.color_localized_string({"hextorio-gui.productivity-bonus"}, "purple", "heading-2"),
        s .. "[font=heading-2]= [color=" .. color .. "]" .. lib.format_percentage(prod, 0, true, true) .. "[.color][.font]",
    }

    if storage.trades.base_productivity ~= nil and math.abs(storage.trades.base_productivity) > 1e-12 then
        table.insert(str, 3, "\n")
        table.insert(str, 4, {"", lib.color_localized_string({"hextorio-gui.bonuses"}, "white", "default-semibold")})
        table.insert(str, 5, " [color=green]" .. lib.format_percentage(storage.trades.base_productivity, 0, true, true) .. "[.color]")
    end

    local planet_prod = lib.runtime_setting_value("base-trade-prod-" .. trade.surface_name)
    if planet_prod ~= 0 then
        color = "green"
        if planet_prod < 0 then
            color = "red"
        end

        table.insert(str, #str, "\n")
        table.insert(str, #str, "[planet=" .. trade.surface_name .. "] [color=" .. color .. "]" .. lib.format_percentage(planet_prod, 0, true, true) .. "[.color]")
    end

    if prod < 0 then
        table.insert(str, {"", "\n\n[img=utility.warning_icon] ", lib.color_localized_string({"hextorio-gui.negative-prod-meaning"}, "red")})
    end

    return str
end

---Get a coin object representing the trade's input items that are coins.
---@param trade Trade
---@param quality string|nil
---@param quality_cost_mult number|nil
---@return Coin
function trades.get_input_coins_of_trade(trade, quality, quality_cost_mult)
    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1
    local values = {}
    for _, input_item in pairs(trade.input_items) do
        if lib.is_coin(input_item.name) then
            values[input_item.name] = input_item.count
        end
    end
    local coin = coin_tiers.from_coin_values_by_name(values)
    local mult = lib.get_quality_value_scale(quality) * quality_cost_mult
    coin = coin_tiers.multiply(coin, mult)
    coin = coin_tiers.floor(coin)
    return coin
end

---Get a coin object representing the trade's output items that are coins.
---@param trade Trade
---@param quality string|nil
---@return Coin
function trades.get_output_coins_of_trade(trade, quality)
    quality = quality or "normal"
    local values = {}
    for _, output_item in pairs(trade.output_items) do
        if lib.is_coin(output_item.name) then
            values[output_item.name] = output_item.count
        end
    end
    local coin = coin_tiers.from_coin_values_by_name(values)
    coin = coin_tiers.multiply(coin, lib.get_quality_value_scale(quality))
    coin = coin_tiers.floor(coin)
    return coin
end

---Check how many batches of (how many times) a trade can occur given an input amount of items.
---@param input_items QualityItemCounts
---@param input_coin Coin
---@param trade Trade
---@param quality string|nil
---@param quality_cost_mult number|nil
---@param check_output_buffer boolean|nil Whether to prevent making this trade if its hex core's output buffer contains any amount of at least one of the output items.
---@param max_items_per_output int|nil
---@param max_output_batches int|nil Maximum number of output batches allowed, where an output batch is counted only if the trade is actually outputting items.
---@param inventory_output_size int|nil Current number of empty slots in the output inventory.
---@return number
function trades.get_num_batches_for_trade(input_items, input_coin, trade, quality, quality_cost_mult, check_output_buffer, max_items_per_output, max_output_batches, inventory_output_size)
    if not trade.active then return 0 end
    if check_output_buffer == nil then check_output_buffer = true end

    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    if check_output_buffer and trade.hex_core_state.output_buffer then
        -- Ensure that if the output buffer has any of the output items, it does not process.
        local buffer_quality = trade.hex_core_state.output_buffer[quality]
        if buffer_quality then
            for _, outp in pairs(trade.output_items) do
                if (buffer_quality[outp.name] or 0) > 0 then
                    return 0
                end
            end
        end
    end

    if not max_items_per_output then
        max_items_per_output = trade.max_items_per_output or 100000
    end
    if max_items_per_output < 1 then return 0 end -- Probably won't ever happen, but if it ever does, it's an optimization.

    local input_items_quality = input_items[quality]
    if not input_items_quality and coin_tiers.is_zero(input_coin) then return 0 end

    local num_batches = math.huge

    -- Initial calculation by comparing item counts in input inventory and trade inputs.
    if input_items_quality then
        for _, input_item in pairs(trade.input_items) do
            if not lib.is_coin(input_item.name) then
                local available = input_items_quality[input_item.name] or 0
                if available == 0 then return 0 end
                num_batches = math.min(math.floor(available / input_item.count), num_batches)
                if num_batches == 0 then return 0 end
            end
        end
    end

    -- Limit by number of coins in inventory and what the trade requires
    if trade.has_coins_in_input then
        local trade_coin = trades.get_input_coins_of_trade(trade, quality, quality_cost_mult)
        num_batches = math.min(math.floor(coin_tiers.divide_coins(input_coin, trade_coin)), num_batches)
    end
    if num_batches == 0 then return 0 end

    -- Limit by max output batches
    local total_prod
    if max_output_batches then
        max_output_batches = math.max(0, max_output_batches) -- Probably not needed, but doesn't hurt to have this.
        if max_output_batches == 0 then
            num_batches = 0
        else
            local for_max_batches = trades.get_num_batches_to_fill_productivity_bar(trade, max_output_batches, quality) or max_output_batches

            total_prod = trades.get_productivity(trade, quality)
            if total_prod > 0 then
                -- for_max_batches needs to be adjusted because total output batches is incremented by total input batches (when total prod is positive)
                for_max_batches = math.max(1, math.ceil((max_output_batches - for_max_batches) * total_prod / (1 + total_prod)))
                -- TODO: THIS CALCULATION IS NOT TESTED AND MIGHT CAUSE BUGS IF MAX_OUTPUT_BATCHES > 1
            end

            num_batches = math.min(for_max_batches, num_batches)
        end

        if num_batches == 0 then return 0 end
    end

    -- Further limit num_batches according to max_items_per_output
    local approximate_stacks_output = 0
    for _, output_item in pairs(trade.output_items) do
        if not lib.is_coin(output_item.name) then
            num_batches = math.min(math.floor(max_items_per_output / output_item.count), num_batches)
            if num_batches == 0 then return 0 end

            if inventory_output_size then
                local prot = prototypes["item"][output_item.name]
                if prot then
                    approximate_stacks_output = approximate_stacks_output + output_item.count / prot.stack_size -- Allow fractions in the sum
                end
            end
        end
    end

    -- Even further limit by total stacks of output if number of empty slots in output inventory is known
    if inventory_output_size and approximate_stacks_output > 0 then
        if not total_prod then
            total_prod = trades.get_productivity(trade, quality)
        end
        approximate_stacks_output = trades.scale_value_with_productivity(approximate_stacks_output, total_prod)
        num_batches = math.min(math.floor(inventory_output_size / approximate_stacks_output), num_batches)
    end

    return num_batches
end

---Trade items within an inventory, returning the total items removed, total items inserted, remaining items to insert if inventory was filled completely, the remaining coins in the inventory input inventory, and the newly added coins to the output inventory.
---@param inventory_input LuaInventory|LuaTrain
---@param inventory_output LuaInventory|LuaTrain
---@param trade Trade
---@param num_batches number
---@param quality string|nil
---@param quality_cost_mult number|nil
---@param input_items QualityItemCounts|nil The total amount of items in the input inventory. Calculated automatically if not provided.
---@param input_coin Coin|nil The total amount of coins in the input inventory. Calculated automatically if not provided.
---@param cargo_wagons LuaEntity[]|nil If either the input or output inventory is a LuaTrain, then these are the cargo wagons closest to the train stop where the train had stopped.
---@return QualityItemCounts|nil, QualityItemCounts|nil, QualityItemCounts|nil, Coin|nil, Coin|nil tuple total removed, total inserted, remaining items to insert (if inventory_output is full), remaining coins in inventory_input, coins added to inventory_output
function trades.trade_items(inventory_input, inventory_output, trade, num_batches, quality, quality_cost_mult, input_items, input_coin, cargo_wagons)
    if not trade.active or num_batches < 1 then
        return nil, nil, nil, nil, nil
    end

    local is_train_input = inventory_input.object_name == "LuaTrain"
    local is_train_output = inventory_output.object_name == "LuaTrain"

    -- TODO: Handle two flow statistics if input and output inventories are on different surfaces
    local flow_statistics = game.forces.player.get_item_production_statistics(trade.surface_name)

    if not input_items or not input_coin then
        if is_train_input then
            input_coin, input_items = inventories.get_coins_and_items_on_train(cargo_wagons or {}, storage.item_buffs.train_trading_capacity)
        else
            input_coin, input_items = trades.get_coins_and_items_of_inventory(inventory_input)
        end
    end

    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    local quality_items = input_items[quality]

    local total_removed = {} ---@type QualityItemCounts
    if quality_items then
        local quality_items_removed = {}
        total_removed[quality] = quality_items_removed
        for _, input_item in pairs(trade.input_items) do
            if not lib.is_coin(input_item.name) then
                local to_remove = math.min(input_item.count * num_batches, quality_items[input_item.name] or 0)
                if to_remove >= 1 then
                    local actually_removed
                    if is_train_input then
                        actually_removed = lib.remove_from_train(cargo_wagons or {}, {name = input_item.name, count = to_remove, quality = quality}, storage.item_buffs.train_trading_capacity)
                    else
                        actually_removed = inventory_input.remove {name = input_item.name, count = to_remove, quality = quality}
                    end

                    quality_items_removed[input_item.name] = (quality_items_removed[input_item.name] or 0) + actually_removed
                    trades.increment_total_sold(input_item.name, actually_removed)
                    flow_statistics.on_flow({name = input_item.name, quality = quality}, -actually_removed)
                end
            end
        end
    end

    local remaining_coin
    if trade.has_coins_in_input then
        local trade_coin = trades.get_input_coins_of_trade(trade, quality, quality_cost_mult)
        local coins_removed = coin_tiers.multiply(trade_coin, num_batches)
        remaining_coin = coin_tiers.subtract(input_coin, coins_removed)
        inventories.remove_coin_from_inventory(inventory_input, coins_removed, cargo_wagons)
        flow_statistics.on_flow("hex-coin", -coin_tiers.to_base_value(coins_removed))
    else
        remaining_coin = input_coin
    end

    local total_output_batches = num_batches + trades.increment_current_prod_value(trade, num_batches, quality)

    local coins_added
    if trade.has_coins_in_output and total_output_batches >= 1 then
        local trade_coin = trades.get_output_coins_of_trade(trade, quality)
        coins_added = coin_tiers.multiply(trade_coin, total_output_batches)
        inventories.add_coin_to_inventory(inventory_output, coins_added, cargo_wagons)
        flow_statistics.on_flow("hex-coin", coin_tiers.to_base_value(coins_added))
    else
        coins_added = coin_tiers.new()
    end

    local total_inserted = {} ---@type QualityItemCounts
    local remaining_to_insert = {}

    if total_output_batches >= 1 then
        local quality_items_inserted = {}
        total_inserted[quality] = quality_items_inserted
        for _, output_item in pairs(trade.output_items) do
            if not lib.is_coin(output_item.name) then
                local to_insert = output_item.count * total_output_batches

                local actually_inserted
                if is_train_output then
                    actually_inserted = lib.insert_into_train(cargo_wagons or {}, {name = output_item.name, count = math.min(1000000000, to_insert), quality = quality}, storage.item_buffs.train_trading_capacity)
                else
                    actually_inserted = inventory_output.insert {name = output_item.name, count = math.min(1000000000, to_insert), quality = quality}
                end

                quality_items_inserted[output_item.name] = (quality_items_inserted[output_item.name] or 0) + actually_inserted

                if actually_inserted < to_insert then
                    if not remaining_to_insert[quality] then remaining_to_insert[quality] = {} end
                    remaining_to_insert[quality][output_item.name] = (remaining_to_insert[quality][output_item.name] or 0) + to_insert - actually_inserted
                end

                trades.increment_total_bought(output_item.name, to_insert)
                flow_statistics.on_flow({name = output_item.name, quality = quality}, to_insert) -- Track entire stacks being inserted into both the output inventory and the buffer (remaining_to_insert).
            end
        end
    end

    event_system.trigger("trade-processed", trade, total_removed, total_inserted)
    return total_removed, total_inserted, remaining_to_insert, remaining_coin, coins_added
end

---Sample random item names for inputs and outputs of a trade based on a central value for each item.
---@param surface_name string
---@param volume number
---@param params TradeGenerationParameters|nil
---@param allow_interplanetary boolean|nil
---@param include_item string|nil An item name to be forcefully included in the returned input or output items.
---@return string[], string[]
function trades.random_trade_item_names(surface_name, volume, params, allow_interplanetary, include_item)
    if not params then params = {} end
    if allow_interplanetary == nil then allow_interplanetary = false end

    trades.set_trade_generation_parameter_defaults(params)

    local ratio
    if params.target_efficiency >= 1 then
        ratio = 10 * params.target_efficiency
    else
        ratio = 10 / params.target_efficiency
    end

    local possible_items = item_values.get_items_near_value(surface_name, volume, ratio, true, false, allow_interplanetary)

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
        lib.log_error("trades.random_trade_item_names: No items found near value " .. volume)
        return {}, {}
    end

    local set = sets.new()
    for i = 1, 6 do
        if #possible_items == 0 then break end
        local item_name = table.remove(possible_items, math.random(1, #possible_items))
        sets.add(set, item_name)
    end
    local trade_items = sets.to_array(set)

    if include_item and not set[include_item] then
        trade_items[math.random(1, #trade_items)] = include_item
    end

    if #trade_items == 0 then
        lib.log_error("trades.random_trade_item_names: Not enough items selected for trade")
        return {}, {}
    end

    local input_item_names = {}
    local output_item_names = {}
    local mod = math.random(0, 1) -- Controls whether inputs or outputs are selected first, removing bias from inputs having more items than outputs on average.
    for i = 1, #trade_items do
        if i % 2 == mod then
            table.insert(output_item_names, trade_items[i])
        else
            table.insert(input_item_names, trade_items[i])
        end
    end

    local num_inputs = math.random(1, 3)
    while #input_item_names > num_inputs do
        local idx = 1
        if input_item_names[1] == include_item then
            idx = idx + 1
        end
        if idx <= #input_item_names then
            table.remove(input_item_names, idx)
        else
            break
        end
    end

    local num_outputs = math.random(1, 3)
    while #output_item_names > num_outputs do
        local idx = 1
        if output_item_names[1] == include_item then
            idx = idx + 1
        end
        if idx <= #output_item_names then
            table.remove(output_item_names, idx)
        else
            break
        end
    end

    trades._check_coin_names_for_volume(input_item_names, volume)
    trades._check_coin_names_for_volume(output_item_names, volume)

    return input_item_names, output_item_names
end

---Create a new trade between a single item and a coin type.
---@param surface_name string
---@param item_name string
---@param target_efficiency number|nil Defaults to 1.0
---@return Trade
function trades.new_coin_trade(surface_name, item_name, target_efficiency)
    if target_efficiency == nil then
        target_efficiency = storage.trades.base_trade_efficiency
    end

    if math.random() < lib.runtime_setting_value "sell-trade-chance" then
        ---@diagnostic disable-next-line: return-type-mismatch
        return trades.from_item_names(surface_name, {item_name}, {"hex-coin"}, {target_efficiency = target_efficiency})
    end

    ---@diagnostic disable-next-line: return-type-mismatch
    return trades.from_item_names(surface_name, {"hex-coin"}, {item_name}, {target_efficiency = target_efficiency})

    -- Note: nil is impossible to be returned for coin trades, assuming target_efficiency isn't extremely large or small (which should never happen since the mod setting has min and max values)
end

---Generate a random trade on a given surface with a central value for input and output items.
---@param surface_name string
---@param volume number
---@param params TradeGenerationParameters
---@param allow_interplanetary boolean|nil
---@param include_item string|nil
---@return Trade|nil
function trades.random(surface_name, volume, params, allow_interplanetary, include_item)
    local input_item_names, output_item_names = trades.random_trade_item_names(surface_name, volume, params, allow_interplanetary, include_item)

    if not next(output_item_names) and not next(input_item_names) then
        lib.log("trades.random: Not enough items centered around the value " .. volume)
        return
    end

    local is_coin_trade = false
    if #input_item_names == 1 and not next(output_item_names) then
        -- Special case: Sell the item.
        table.insert(output_item_names, "hex-coin")
        is_coin_trade = true
    elseif #output_item_names == 1 and not next(input_item_names) then
        -- Special case: Buy the item.
        table.insert(input_item_names, "hex-coin")
        is_coin_trade = true
    end

    if not is_coin_trade and math.random() < lib.runtime_setting_value "coin-trade-chance" then
        local coin_type = "hex-coin"
        if volume > item_values.get_item_value(surface_name, "hexaprism-coin") then
            coin_type = "hexaprism-coin"
        elseif volume > item_values.get_item_value(surface_name, "meteor-coin") then
            coin_type = "meteor-coin"
        elseif volume > item_values.get_item_value(surface_name, "gravity-coin") then
            coin_type = "gravity-coin"
        end
        if math.random() < lib.runtime_setting_value "sell-trade-chance" then
            local idx = math.random(1, #output_item_names)
            if #output_item_names[idx] > 1 and output_item_names[idx] == include_item then
                idx = idx % #output_item_names + 1
            end
            if output_item_names[idx] ~= include_item then
                output_item_names[idx] = coin_type
            end
        else
            local idx = math.random(1, #input_item_names)
            if #input_item_names[idx] > 1 and input_item_names[idx] == include_item then
                idx = idx % #input_item_names + 1
            end
            if input_item_names[idx] ~= include_item then
                input_item_names[math.random(1, #input_item_names)] = coin_type
            end
        end
    end

    return trades.from_item_names(surface_name, input_item_names, output_item_names, params)
end

---Return whether the item is now discovered if it wasn't previously.
---@param item_name string
---@return boolean
function trades.mark_as_discovered(item_name)
    if not quests.is_feature_unlocked "catalog" then return false end
    if item_name:sub(-5) == "-coin" then return false end
    local already_discovered = trades.is_item_discovered(item_name)
    storage.trades.discovered_items[item_name] = true
    return not already_discovered
end

---Check whether the item is discovered.
---@param item_name string
---@return boolean
function trades.is_item_discovered(item_name)
    return storage.trades.discovered_items[item_name] == true
end

---Try to discover each item in the list, and return a list of the items which were newly discovered.
---@param items_list string[]
---@return string[]
function trades.discover_items(items_list)
    if not items_list then return {} end

    local new_discoveries = {}
    for _, item_name in pairs(items_list) do
        if trades.mark_as_discovered(item_name) then
            table.insert(new_discoveries, item_name)
        end
    end

    if next(new_discoveries) then
        local s = " "
        for i, item_name in ipairs(new_discoveries) do
            if i > 1 then
                s = s .. " "
            end
            s = s .. "[img=item." .. item_name .. "]"
        end
        lib.print_notification("item-ranked-up", lib.color_localized_string({"", {"hextorio.new-catalog-items"}, s}, "green", "heading-1"))
    end

    return new_discoveries
end

---Try to discover each item in each trade's inputs and outputs, and return a list of the items which were newly discovered in the given trades.
---@param trades_list Trade[]
---@return string[]
function trades.discover_items_in_trades(trades_list)
    if not trades_list then return {} end

    local items_list = {}
    for _, trade in pairs(trades_list) do
        for _, input in pairs(trade.input_items) do
            table.insert(items_list, input.name)
        end
        for _, output in pairs(trade.output_items) do
            table.insert(items_list, output.name)
        end
    end

    return trades.discover_items(items_list)
end

---Increment the total amount of an item traded.
---@param item_name string
---@param amount int
function trades._increment_total_traded(item_name, amount)
    if amount <= 0 then return end
    storage.trades.total_items_traded[item_name] = (storage.trades.total_items_traded[item_name] or 0) + amount
end

---Increment the total amount of an item sold (given to a hex core).
---@param item_name string
---@param amount int
function trades.increment_total_sold(item_name, amount)
    if amount <= 0 then return end
    local old_amount = storage.trades.total_items_sold[item_name] or 0
    storage.trades.total_items_sold[item_name] = (storage.trades.total_items_sold[item_name] or 0) + amount
    trades._increment_total_traded(item_name, amount)
    if old_amount == 0 and trades.get_total_bought(item_name) > 0 and item_ranks.get_item_rank(item_name) == 1 then
        item_ranks.progress_item_rank(item_name, 2)
    end
end

---Increment the total amount of an item bought (received from a hex core).
---@param item_name string
---@param amount int
function trades.increment_total_bought(item_name, amount)
    if amount <= 0 then return end
    local old_amount = storage.trades.total_items_bought[item_name] or 0
    storage.trades.total_items_bought[item_name] = (storage.trades.total_items_bought[item_name] or 0) + amount
    trades._increment_total_traded(item_name, amount)
    if old_amount == 0 and trades.get_total_sold(item_name) > 0 and item_ranks.get_item_rank(item_name) == 1 then
        item_ranks.progress_item_rank(item_name, 2)
    end
end

---Get the total number of an item traded (either bought or sold).
---@param item_name string
---@return integer
function trades.get_total_traded(item_name)
    return storage.trades.total_items_traded[item_name] or 0
end

---Get the total number of an item sold (given to a hex core).
---@param item_name string
---@return integer
function trades.get_total_sold(item_name)
    return storage.trades.total_items_sold[item_name] or 0
end

---Get the total number of an item bought (received from a hex core).
---@param item_name string
---@return integer
function trades.get_total_bought(item_name)
    return storage.trades.total_items_bought[item_name] or 0
end

---Return whether the given trade is currently enabled to be used in trading.
---@param trade Trade
---@return boolean
function trades.is_active(trade)
    return trade.active == true -- If somehow it is ever nil, it'll return false in that case.
end

---Set a trade to be active or inactive, returning whether the activity was really changed.
---@param trade Trade
---@param flag boolean|nil Defaults to `true`.
---@return boolean
function trades.set_trade_active(trade, flag)
    if flag == nil then flag = true end
    if flag == trade.active then return false end
    trade.active = flag
    return true
end

---Set a productivity bonus for a trade.
---@param trade Trade
---@param productivity number
function trades.set_productivity(trade, productivity)
    if math.abs(productivity) < 1e-12 then
        productivity = 0
    end
    trade.productivity = productivity
end

---Get a trade's productivity bonus, accounting for the modifier from quality.
---@param trade Trade
---@param quality string|nil
---@return number
function trades.get_productivity(trade, quality)
    return (trade.productivity or 0) + trades.get_productivity_modifier(quality or "normal")
end

---Increment a trade's productivity bonus.
---@param trade Trade
---@param amount number
function trades.increment_productivity(trade, amount)
    trades.set_productivity(trade, (trade.productivity or 0) + amount)
end

---Get the trade's current progress toward filling the productivity bar.
---@param trade Trade
---@param quality string|nil
---@return number
function trades.get_current_prod_value(trade, quality)
    return (trade.current_prod_value or {})[quality or "normal"] or 0
end

---Set a trade's current progress toward filling the productivity bar.
---@param trade Trade
---@param value number
---@param quality string|nil
function trades.set_current_prod_value(trade, value, quality)
    if quality == nil then quality = "normal" end
    if not trade.current_prod_value then
        trade.current_prod_value = {}
    end
    trade.current_prod_value[quality] = value
end

---Return how many input batches to the given trade are needed to increment its current productivity value just enough times to get `fill_times` more output batches.
---@param trade Trade
---@param fill_times int The number of times the productivity bar is to be filled.
---@param quality string
---@return int|nil num_batches How many batches of the trade are needed to fill the productivity bar `fill_times` times.  Is only nil if trade prod = 0 because that means the (nonexistent) productivity bar can never fill.
function trades.get_num_batches_to_fill_productivity_bar(trade, fill_times, quality)
    if fill_times < 1 then return 0 end

    local total_prod = trades.get_productivity(trade, quality)
    if total_prod == 0 then return end

    local current_prod_value = trades.get_current_prod_value(trade, quality)
    local remaining_prod_value = fill_times - current_prod_value

    local prod_increment = trades.get_productivity_increment(total_prod)
    return math.ceil(remaining_prod_value / prod_increment)
end

---Get the increment that is made to a trade's current productivity value (the red or purple progress bar) when it has `prod` trade productivity.
---@param prod number
---@return number
function trades.get_productivity_increment(prod)
    if prod < 0 then
        return 1 / (1 - prod)
    end
    return prod
end

---Increment a trade's current progress toward filling the productivity bar, returning how many times the bar has been filled.
---@param trade Trade
---@param num_batches int The number of times the trade was made.
---@param quality string
---@return int
function trades.increment_current_prod_value(trade, num_batches, quality)
    local total_prod = trades.get_productivity(trade, quality)
    local current_prod_value = trades.get_current_prod_value(trade, quality)

    local prod_inc = trades.get_productivity_increment(total_prod)
    local new_prod_value = current_prod_value + num_batches * prod_inc
    local rounded = math.floor(0.5 + new_prod_value)

    if math.abs(new_prod_value - rounded) < 1e-12 then
        -- This value came very close to a whole number, and likely a floating point rounding error is what threw it off.
        -- Snapping to the expected value like this keeps situations from happening where -500% prod results in having to make 7 trades instead of 6.
        new_prod_value = rounded
    end

    local f = math.floor(new_prod_value)
    trades.set_current_prod_value(trade, new_prod_value - f, quality)

    if total_prod < 0 then
        return f - num_batches
    end

    return f
end

---Get the current base productivity bonus for all trades.
---@param surface_name string
---@return number
function trades.get_base_trade_productivity_on_surface(surface_name)
    local base_prod = storage.trades.base_productivity or 0 -- Upgrades from quests.
    local planet_prod = storage.trades.base_trade_productivity[surface_name] or 0 -- Planet-wide buff/debuff
    return base_prod + planet_prod
end

---Return whether the given trade has any modifiers applying to it, even if the total is 0%.
---@param trade Trade
---@param quality string|nil
---@return boolean
function trades.has_any_productivity_modifiers(trade, quality)
    if trades.get_productivity(trade, quality) ~= 0 then return true end

    if storage.trades.base_productivity ~= nil and storage.trades.base_productivity ~= 0 then
        return true
    end

    for _, item in pairs(trade.input_items) do
        if lib.is_catalog_item(item.name) and item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)) ~= 0 then
            return true
        end
    end

    for _, item in pairs(trade.output_items) do
        if lib.is_catalog_item(item.name) and item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)) ~= 0 then
            return true
        end
        if not storage.trades.researched_items[item.name] then
            return true
        end
    end

    if storage.trades.base_trade_productivity[trade.surface_name] ~= 0 then
        return true
    end

    return false
end

---Return whether the given trade is receiving a productivity penalty for giving unresearched items.
---@param trade Trade
---@param is_mod_setting_enabled boolean|nil
---@return boolean
function trades.has_unresearched_penalty(trade, is_mod_setting_enabled)
    if is_mod_setting_enabled == nil then
        is_mod_setting_enabled = lib.runtime_setting_value "unresearched-penalty" > 0
    end

    if not is_mod_setting_enabled then return false end

    for _, item in pairs(trade.output_items) do
        if not storage.trades.researched_items[item.name] then
            return true
        end
    end

    return false
end

---Set the base productivity bonus for all trades.
---@param prod number
function trades.set_base_trade_productivity(prod)
    if math.abs(prod) < 1e-12 then
        prod = 0
    end
    storage.trades.base_productivity = prod
end

---Increment the current base productivity bonus for all trades.
---@param amount number
function trades.increment_base_trade_productivity(amount)
    trades.set_base_trade_productivity((storage.trades.base_productivity or 0) + amount)
end

---Recalculate the trade's productivity effect based on base productivity and its input and output item ranks.
---@param trade Trade
function trades.check_productivity(trade)
    local base_prod = trades.get_base_trade_productivity_on_surface(trade.surface_name)
    trades.set_productivity(trade, base_prod)

    for _, item in pairs(trade.input_items) do
        if lib.is_catalog_item(item.name) then
            trades.increment_productivity(trade, item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)))
        end
    end

    for _, item in pairs(trade.output_items) do
        if lib.is_catalog_item(item.name) then
            local penalty_prod = 0.0
            if not storage.trades.researched_items[item.name] then
                penalty_prod = storage.trades.unresearched_penalty * storage.item_buffs.unresearched_penalty_multiplier
            end
            trades.increment_productivity(trade, item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)) - penalty_prod)
        end
    end
end

---Replace nil values with default values in `params`, modifying the table in place.
---@param params TradeGenerationParameters
function trades.set_trade_generation_parameter_defaults(params)
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

---Queue a job to update trade productivities for a surface, or for all surfaces if surface is nil.
---@param surface SurfaceIdentification|nil If not provided, queues jobs for all existing surfaces.
function trades.queue_productivity_update_job(surface)
    if surface == nil then
        for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
            surface = game.get_surface(surface_id)
            if surface and not lib.is_space_platform(surface) then
                trades.queue_productivity_update_job(surface_id)
            end
        end
        return
    end

    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then return end

    if not storage.hex_grid.flattened_surface_hexes then return end

    local flattened_hexes = storage.hex_grid.flattened_surface_hexes[surface_id]
    if not flattened_hexes then return end

    if not storage.trades.productivity_update_jobs then
        storage.trades.productivity_update_jobs = {}
    end

    for i, job in ipairs(storage.trades.productivity_update_jobs) do
        if job.surface_id == surface_id then
            table.remove(storage.trades.productivity_update_jobs, i) -- Overwrite previous job if it exists.  Only one job needs to exist for this task.
        end
    end

    ---@type TradeProductivityUpdateJob
    local job = {
        surface_id = surface_id,
        current_flat_index = 1,
        total_flat_indices = #flattened_hexes,
    }

    table.insert(storage.trades.productivity_update_jobs, job)
end

---Process trade productivity update jobs. Processes up to 50 hex cores per tick.
function trades.process_trade_productivity_updates()
    local jobs = storage.trades.productivity_update_jobs or {}
    if #jobs == 0 then return end

    local batch_size = 400

    local job = jobs[1]

    local end_index = math.min(job.current_flat_index + batch_size - 1, job.total_flat_indices)
    local hex_states = hex_state_manager.get_hexes_from_flat_indices(job.surface_id, job.current_flat_index, end_index)

    for _, state in pairs(hex_states) do
        for _, trade_id in pairs(state.trades or {}) do
            local trade = trades.get_trade_from_id(trade_id)
            if trade then
                trades.check_productivity(trade)
            end
        end
    end

    job.current_flat_index = end_index + 1
    if job.current_flat_index > job.total_flat_indices then
        table.remove(jobs, 1)
    end
end

---Queue a job to collect trade objects from trade IDs for the trade overview.
---@param player LuaPlayer
---@param trade_ids_set {[int]: boolean} Set of trade IDs to collect
---@param filter table The filter settings to apply after collection
---@param process_immediately boolean If true, process all trades in a single tick without progress events
function trades.queue_trade_collection_job(player, trade_ids_set, filter, process_immediately)
    trades.cancel_trade_overview_jobs(player)

    local trade_ids = {}
    for trade_id, _ in pairs(trade_ids_set) do
        table.insert(trade_ids, trade_id)
    end

    ---@type TradeCollectionJob
    local job = {
        player = player,
        trade_ids = trade_ids,
        current_index = 1,
        total_count = #trade_ids,
        collected_trades = {},
        filter = filter,
        process_immediately = process_immediately,
    }

    if not storage.trades.trade_collection_jobs then
        storage.trades.trade_collection_jobs = {}
    end

    table.insert(storage.trades.trade_collection_jobs, job)
end

---Process trade collection jobs. Collects trade objects from IDs in batches.
function trades.process_trade_collection_jobs()
    local jobs = storage.trades.trade_collection_jobs or {}
    if #jobs == 0 then return end

    local batch_size = math.floor(storage.trades.collection_batch_size / #jobs)
    local lookup = trades.get_trades_lookup()

    for i = #jobs, 1, -1 do
        local job = jobs[i]

        if job.total_count == 0 then
            table.remove(jobs, i)
            event_system.trigger("trade-collection-complete", job.player, job.collected_trades, job.filter, job.process_immediately)
        else
            local end_index
            if job.process_immediately then
                end_index = job.total_count
            else
                end_index = math.min(job.current_index + batch_size - 1, job.total_count)
            end

            for idx = job.current_index, end_index do
                local trade_id = job.trade_ids[idx]
                local trade = lookup[trade_id]
                if trade then
                    job.collected_trades[trade_id] = trade
                end
            end

            job.current_index = end_index + 1
            local progress = end_index / job.total_count

            if not job.process_immediately then
                event_system.trigger("trade-collection-progress", job.player, progress, end_index, job.total_count)
            end

            if job.current_index > job.total_count then
                table.remove(jobs, i)
                event_system.trigger("trade-collection-complete", job.player, job.collected_trades, job.filter, job.process_immediately)
            end
        end
    end
end

---Queue a job to filter trades for the trade overview.
---@param player LuaPlayer
---@param trades_lookup {[int]: Trade}
---@param filter table The filter settings to apply
---@param process_immediately boolean If true, process all trades in a single tick without progress events
function trades.queue_trade_filtering_job(player, trades_lookup, filter, process_immediately)
    local trade_ids = {}
    for trade_id, _ in pairs(trades_lookup) do
        table.insert(trade_ids, trade_id)
    end

    ---@type TradeFilteringJob
    local job = {
        player = player,
        trades_lookup = trades_lookup,
        trade_ids = trade_ids,
        current_index = 1,
        total_count = #trade_ids,
        filtered_trades = {},
        filter = filter,
        is_favorited = {},
        ready_to_complete = false,
        process_immediately = process_immediately,
    }

    if not storage.trades.trade_filtering_jobs then
        storage.trades.trade_filtering_jobs = {}
    end

    table.insert(storage.trades.trade_filtering_jobs, job)
end

function trades.process_trade_filtering_jobs()
    local jobs = storage.trades.trade_filtering_jobs or {}
    if #jobs == 0 then return end

    local batch_size = math.floor(storage.trades.filtering_batch_size / #jobs)

    for i = #jobs, 1, -1 do
        local job = jobs[i]
        local player = job.player
        if job.total_count == 0 then
            table.remove(jobs, i)
            trades.queue_trade_sorting_job(job.player, job.filtered_trades, job.is_favorited, job.filter, job.process_immediately)
        else
            local filter = job.filter
            local end_index
            if job.process_immediately then
                end_index = job.total_count
            else
                end_index = math.min(job.current_index + batch_size - 1, job.total_count)
            end

            for idx = job.current_index, end_index do
                local trade_id = job.trade_ids[idx]
                local trade = job.trades_lookup[trade_id]
                if trade then
                    local should_filter = false

                    local state = trade.hex_core_state
                    if state then
                        if not state.hex_core or not state.hex_core.valid then
                            should_filter = true
                        elseif filter.show_claimed_only and not state.claimed then
                            should_filter = true
                        elseif filter.exclude_dungeons and state.is_dungeon then
                            should_filter = true
                        elseif filter.exclude_sinks_generators and (state.mode == "sink" or state.mode == "generator") then
                            should_filter = true
                        end
                    end
                    if not should_filter and filter.show_interplanetary_only and not trades.is_interplanetary_trade(trade) then
                        should_filter = true
                    end
                    if not should_filter and filter.exclude_favorited and trades.is_trade_favorited(player, trade) then
                        should_filter = true
                    end
                    if not should_filter and filter.planets and trade.surface_name then
                        if not filter.planets[trade.surface_name] then
                            should_filter = true
                        end
                    end
                    if not should_filter and filter.num_item_bounds then
                        local input_bounds = filter.num_item_bounds.inputs
                        if input_bounds then
                            local num_inputs = #trade.input_items
                            if num_inputs < (input_bounds.min or 1) or num_inputs > (input_bounds.max or math.huge) then
                                should_filter = true
                            end
                        end
                        local output_bounds = filter.num_item_bounds.outputs
                        if output_bounds then
                            local num_outputs = #trade.output_items
                            if num_outputs < (output_bounds.min or 1) or num_outputs > (output_bounds.max or math.huge) then
                                should_filter = true
                            end
                        end
                    end

                    if not should_filter then
                        job.filtered_trades[trade_id] = trade
                        job.is_favorited[trade_id] = trades.is_trade_favorited(player, trade)
                    end
                end
            end

            job.current_index = end_index + 1
            local progress = end_index / job.total_count

            if not job.process_immediately then
                event_system.trigger("trade-filtering-progress", job.player, progress, end_index, job.total_count)
            end

            if job.current_index > job.total_count then
                table.remove(jobs, i)
                trades.queue_trade_sorting_job(job.player, job.filtered_trades, job.is_favorited, job.filter, job.process_immediately)
            end
        end
    end
end

---Queue a job to sort/select top N trades for the trade overview.
---@param player LuaPlayer
---@param filtered_trades {[int]: Trade}
---@param is_favorited {[int]: boolean}
---@param filter table The filter settings to apply
---@param process_immediately boolean If true, process all trades in a single tick without progress events
function trades.queue_trade_sorting_job(player, filtered_trades, is_favorited, filter, process_immediately)
    local trade_ids = {}
    for trade_id, _ in pairs(filtered_trades) do
        table.insert(trade_ids, trade_id)
    end

    ---@type TradeSortingJob
    local job = {
        player = player,
        filtered_trades = filtered_trades,
        is_favorited = is_favorited,
        trade_ids = trade_ids,
        current_index = 1,
        total_count = #trade_ids,
        filter = filter,
        sorted_top_trades = {},
        sort_keys = {},
        min_sort_key = nil,
        max_sort_key = nil,
        process_immediately = process_immediately,
    }

    if not storage.trades.trade_sorting_jobs then
        storage.trades.trade_sorting_jobs = {}
    end

    table.insert(storage.trades.trade_sorting_jobs, job)
    if not process_immediately then
        event_system.trigger("trade-sorting-starting", player, #trade_ids)
    end
end

function trades.process_trade_sorting_jobs()
    local jobs = storage.trades.trade_sorting_jobs or {}
    if #jobs == 0 then return end

    local batch_size = math.floor(storage.trades.sorting_batch_size / #jobs)

    ---@param trade Trade
    ---@param sorting_method TradeOverviewSortingMethod
    ---@param metrics {[int]: number}
    ---@return number
    local function calculate_sort_key(trade, sorting_method, metrics)
        if sorting_method == "num-inputs" then
            return #trade.input_items
        elseif sorting_method == "num-outputs" then
            return #trade.output_items
        else
            return metrics[trade.id] or 0
        end
    end

    ---Binary search to find insertion index in sorted array, with favorites always first.
    ---@param sorted_array Trade[]
    ---@param sort_keys {[int]: number}
    ---@param is_favorited {[int]: boolean}
    ---@param new_sort_key number
    ---@param new_is_fav boolean
    ---@param ascending boolean
    ---@return number
    local function get_insertion_index(sorted_array, sort_keys, is_favorited, new_sort_key, new_is_fav, ascending)
        local low = 1
        local high = #sorted_array + 1

        while low < high do
            local mid = math.floor((low + high) / 2)
            local mid_trade_id = sorted_array[mid].id
            local mid_key = sort_keys[mid_trade_id]
            local mid_is_fav = is_favorited[mid_trade_id]

            local after

            -- Favorites always come first
            if new_is_fav and not mid_is_fav then
                after = false  -- before non-favorites
            elseif not new_is_fav and mid_is_fav then
                after = true   -- after favorites
            else
                -- Both favorited or both not favorited, compare by sort key
                if ascending then
                    after = mid_key < new_sort_key
                else
                    after = mid_key > new_sort_key
                end
            end

            if after then
                low = mid + 1
            else
                high = mid
            end
        end

        return low
    end

    for i = #jobs, 1, -1 do
        local job = jobs[i]
        local player = job.player
        local filter = job.filter

        local max_trades = filter.max_trades
        local end_index
        if job.process_immediately then
            end_index = job.total_count
        else
            end_index = math.min(job.current_index + batch_size - 1, job.total_count)
        end
        local ascending = filter.sorting.ascending == true
        local sorting_method = filter.sorting.method

        ---@param value number
        local function update_bounds(value)
            if job.min_sort_key == nil then
                job.min_sort_key = value
                job.max_sort_key = value
            else
                job.min_sort_key = math.min(job.min_sort_key, value)
                job.max_sort_key = math.max(job.max_sort_key, value)
            end
        end

        if job.total_count == 0 then
            -- Handle empty job (no trades to sort)
            table.remove(jobs, i)
            event_system.trigger("trade-sorting-complete", player, {}, {}, job.is_favorited, filter)
        else
            -- Pre-calculate data needed for sorting (only once at start)
            if not job.metrics and filter.sorting and filter.sorting.method then
                job.metrics = {}

                if filter.sorting.method == "distance-from-spawn" then
                    for trade_id, trade in pairs(job.filtered_trades) do
                        if trade.hex_core_state then
                            job.metrics[trade_id] = axial.distance(trade.hex_core_state.position, {q=0, r=0})
                        else
                            job.metrics[trade_id] = 0
                        end
                    end
                elseif filter.sorting.method == "distance-from-character" and player.character then
                    local transformation = terrain.get_surface_transformation(player.surface)
                    local char_pos = axial.get_hex_containing(player.character.position, transformation.scale, transformation.rotation)
                    for trade_id, trade in pairs(job.filtered_trades) do
                        if trade.hex_core_state then
                            job.metrics[trade_id] = axial.distance(trade.hex_core_state.position, char_pos)
                        else
                            job.metrics[trade_id] = 0
                        end
                    end
                elseif filter.sorting.method == "total-item-value" then
                    for trade_id, trade in pairs(job.filtered_trades) do
                        job.metrics[trade_id] = trades.get_volume_of_trade(trade.surface_name, trade)
                    end
                elseif filter.sorting.method == "productivity" then
                    for trade_id, trade in pairs(job.filtered_trades) do
                        job.metrics[trade_id] = trades.get_productivity(trade)
                    end
                end
            end

            for idx = job.current_index, end_index do
                local trade_id = job.trade_ids[idx]
                local trade = job.filtered_trades[trade_id]

                if trade then
                    local is_fav = job.is_favorited[trade_id]

                    local sort_key = 0
                    if sorting_method then
                        sort_key = calculate_sort_key(trade, sorting_method, job.metrics)
                    end

                    local current_count = #job.sorted_top_trades
                    if current_count < max_trades then
                        local insert_idx = get_insertion_index(job.sorted_top_trades, job.sort_keys, job.is_favorited, sort_key, is_fav, ascending)
                        table.insert(job.sorted_top_trades, insert_idx, trade)
                        job.sort_keys[trade_id] = sort_key

                        if not is_fav then
                            update_bounds(sort_key)
                        end
                    else
                        -- List is full, check if this trade should replace the worst one
                        -- Favorites always get inserted (displacing a non-favorite if needed)
                        local worst_trade = job.sorted_top_trades[#job.sorted_top_trades]
                        local worst_is_fav = job.is_favorited[worst_trade.id]

                        local insert = false
                        if is_fav and not worst_is_fav then
                            -- Favorite always displaces non-favorite
                            insert = true
                        elseif is_fav == worst_is_fav then
                            -- Both same favorite status, compare by sort key
                            local worst_key = job.sort_keys[worst_trade.id]
                            if ascending then
                                insert = sort_key < worst_key
                            else
                                insert = sort_key > worst_key
                            end
                        end

                        -- If new trade is non-favorite and worst is favorite, never insert
                        if insert then
                            -- Find insertion point
                            local insert_idx = get_insertion_index(job.sorted_top_trades, job.sort_keys, job.is_favorited, sort_key, is_fav, ascending)

                            -- Insert new trade
                            table.insert(job.sorted_top_trades, insert_idx, trade)
                            job.sort_keys[trade_id] = sort_key

                            -- Remove worst trade (always the last one)
                            local removed_trade = table.remove(job.sorted_top_trades)
                            job.sort_keys[removed_trade.id] = nil

                            if not is_fav and not worst_is_fav then
                                -- Recalculate bounds from the remaining non-favorites
                                job.min_sort_key = nil
                                job.max_sort_key = nil
                                for _, t in ipairs(job.sorted_top_trades) do
                                    if not job.is_favorited[t.id] then
                                        update_bounds(job.sort_keys[t.id])
                                    end
                                end
                            end
                        end
                    end
                end
            end

            job.current_index = end_index + 1
            local progress = end_index / job.total_count

            if not job.process_immediately then
                event_system.trigger("trade-sorting-progress", player, progress, end_index, job.total_count)
            end

            if job.current_index > job.total_count then
                local sorted_lookup = {}
                for _, trade in ipairs(job.sorted_top_trades) do
                    sorted_lookup[trade.id] = trade
                end

                table.remove(jobs, i)
                event_system.trigger("trade-sorting-complete", player, sorted_lookup, job.sorted_top_trades, job.is_favorited, filter)
            end
        end
    end
end

---Cancel all trade overview jobs for a player.
---@param player LuaPlayer
function trades.cancel_trade_overview_jobs(player)
    for i = #(storage.trades.trade_collection_jobs or {}), 1, -1 do
        if storage.trades.trade_collection_jobs[i].player == player then
            table.remove(storage.trades.trade_collection_jobs, i)
        end
    end
    for i = #(storage.trades.trade_filtering_jobs or {}), 1, -1 do
        if storage.trades.trade_filtering_jobs[i].player == player then
            table.remove(storage.trades.trade_filtering_jobs, i)
        end
    end
    for i = #(storage.trades.trade_sorting_jobs or {}), 1, -1 do
        if storage.trades.trade_sorting_jobs[i].player == player then
            table.remove(storage.trades.trade_sorting_jobs, i)
        end
    end
    for i = #(storage.trades.trade_export_jobs or {}), 1, -1 do
        if storage.trades.trade_export_jobs[i].player == player then
            table.remove(storage.trades.trade_export_jobs, i)
        end
    end

    -- Also cancel the existing GUI rendering job
    if storage.gui and storage.gui.trades_scroll_pane_update and storage.gui.trades_scroll_pane_update[player.name] then
        storage.gui.trades_scroll_pane_update[player.name].finished = true
    end

    -- Reset the GUI progress bars
    event_system.trigger("trade-overview-jobs-cancelled", player)
end

---Queue a job to export all trades to JSON.
---@param player LuaPlayer
function trades.queue_trade_export_job(player)
    local all_trades = trades.get_all_trades(true)
    local trade_ids = {}
    for _, trade in pairs(all_trades) do
        table.insert(trade_ids, trade.id)
    end

    ---@type TradeExportJob
    local job = {
        player = player,
        trade_ids = trade_ids,
        current_index = 1,
        total_count = #trade_ids,
        seen_items = {nauvis = {}, vulcanus = {}, fulgora = {}, gleba = {}, aquilo = {}},
        formatted_trades = {nauvis = {}, vulcanus = {}, fulgora = {}, gleba = {}, aquilo = {}},
        item_value_lookup = {nauvis = {}, vulcanus = {}, fulgora = {}, gleba = {}, aquilo = {}},
    }

    if not storage.trades.trade_export_jobs then
        storage.trades.trade_export_jobs = {}
    end

    for i = #storage.trades.trade_export_jobs, 1, -1 do
        if storage.trades.trade_export_jobs[i].player == player then
            table.remove(storage.trades.trade_export_jobs, i)
        end
    end

    table.insert(storage.trades.trade_export_jobs, job)
end

---Process trade export jobs. Exports trades to JSON in batches.
function trades.process_trade_export_jobs()
    local jobs = storage.trades.trade_export_jobs or {}
    if #jobs == 0 then return end

    local batch_size = 2000
    local lookup = trades.get_trades_lookup()

    for i = #jobs, 1, -1 do
        local job = jobs[i]

        local end_index = math.min(job.current_index + batch_size - 1, job.total_count)
        for idx = job.current_index, end_index do
            local trade_id = job.trade_ids[idx]
            local trade = lookup[trade_id]
            if trade then
                local transformation = terrain.get_surface_transformation(trade.surface_name)
                local hex_core = trade.hex_core_state.hex_core
                local quality = "normal"
                if hex_core and hex_core.valid then
                    quality = hex_core.quality.name
                end

                table.insert(job.formatted_trades[trade.surface_name], {
                    axial_pos = trade.hex_core_state.position,
                    rect_pos = axial.get_hex_center(trade.hex_core_state.position, transformation.scale, transformation.rotation),
                    inputs = trade.input_items,
                    outputs = trade.output_items,
                    claimed = trade.hex_core_state.claimed == true,
                    is_dungeon = trade.hex_core_state.is_dungeon == true or trade.hex_core_state.was_dungeon == true,
                    productivity = trades.get_productivity(trade),
                    is_interplanetary = trades.is_interplanetary_trade(trade),
                    mode = trade.hex_core_state.mode or "normal",
                    core_quality = quality,
                })

                local seen = job.seen_items[trade.surface_name]
                for _, input in pairs(trade.input_items) do
                    seen[input.name] = true
                end
                for _, output in pairs(trade.output_items) do
                    seen[output.name] = true
                end
            end
        end

        job.current_index = end_index + 1
        local progress = end_index / job.total_count

        event_system.trigger("trade-export-progress", job.player, progress, end_index, job.total_count)

        if job.current_index > job.total_count then
            table.remove(jobs, i)
            trades.finalize_trade_export(job)
        end
    end
end

---@param job TradeExportJob
function trades.finalize_trade_export(job)
    -- Compute item values
    local hex_coin_value_inv = 1 / item_values.get_item_value("nauvis", "hex-coin")
    for surface_name, item_names in pairs(job.seen_items) do
        for item_name, _ in pairs(item_names) do
            job.item_value_lookup[surface_name][item_name] = item_values.get_item_value(surface_name, item_name, true, "normal") * hex_coin_value_inv
        end
    end

    -- Remove empty surfaces
    for surface_name, trades_list in pairs(job.formatted_trades) do
        if not next(trades_list) then
            job.formatted_trades[surface_name] = nil
        end
    end

    for surface_name, values in pairs(job.item_value_lookup) do
        if not next(values) then
            job.item_value_lookup[surface_name] = nil
        end
    end

    local to_export = {
        trades = job.formatted_trades,
        item_values = job.item_value_lookup,
    }

    event_system.trigger("trade-export-complete", job.player, to_export)
end

-- ---Sample a random value for the central value of items in a trade on a given surface.
-- ---@param surface_name string
-- ---@param item_name string
-- ---@return number
-- function trades.get_random_volume_for_item(surface_name, item_name)
--     local volume = item_values.get_item_value(surface_name, item_name)
--     return volume * (3 + 7 * math.random())
-- end

---Verify that the trade data structures are valid.
function trades._check_tree_existence()
    if not storage.trades.tree then
        storage.trades.tree = {}
    end
    if not storage.trades.tree.by_input then
        storage.trades.tree.by_input = {}
    end
    if not storage.trades.tree.by_output then
        storage.trades.tree.by_output = {}
    end
    if not storage.trades.tree.by_surface then
        storage.trades.tree.by_surface = {}
    end
    if not storage.trades.tree.all_trades_lookup then
        storage.trades.tree.all_trades_lookup = {}
    end
    if not storage.trades.recoverable then
        storage.trades.recoverable = {}
    end
end

---Add a trade to the trade tree.
---@param trade Trade
function trades.add_trade_to_tree(trade)
    trades._check_tree_existence()
    for _, input in pairs(trade.input_items) do
        if not storage.trades.tree.by_input[input.name] then
            storage.trades.tree.by_input[input.name] = {}
        end
        storage.trades.tree.by_input[input.name][trade.id] = true
    end
    for _, output in pairs(trade.output_items) do
        if not storage.trades.tree.by_output[output.name] then
            storage.trades.tree.by_output[output.name] = {}
        end
        storage.trades.tree.by_output[output.name][trade.id] = true
    end

    local surface_trades = storage.trades.tree.by_surface[trade.surface_name]
    if not surface_trades then
        surface_trades = {}
        storage.trades.tree.by_surface[trade.surface_name] = surface_trades
    end
    surface_trades[trade.id] = true

    storage.trades.tree.all_trades_lookup[trade.id] = trade
end

---Remove a trade from the trade tree, allowing for recoverability.
---@param trade Trade
---@param recoverable boolean|nil
function trades.remove_trade_from_tree(trade, recoverable)
    if recoverable == nil then recoverable = true end
    trades._check_tree_existence()
    for _, input in pairs(trade.input_items) do
        if storage.trades.tree.by_input[input.name] then
            storage.trades.tree.by_input[input.name][trade.id] = nil
        end
    end
    for _, output in pairs(trade.output_items) do
        if storage.trades.tree.by_output[output.name] then
            storage.trades.tree.by_output[output.name][trade.id] = nil
        end
    end

    local surface_trades = storage.trades.tree.by_surface[trade.surface_name]
    if surface_trades then
        surface_trades[trade.id] = nil
    end

    if recoverable then
        storage.trades.recoverable[trade.id] = true
    else
        storage.trades.tree.all_trades_lookup[trade.id] = nil
    end
end

---Recover a trade that was previously removed from the trade tree.
---@param trade Trade
function trades.recover_trade(trade)
    trades._check_tree_existence()
    if not storage.trades.recoverable[trade.id] then return end
    trades.add_trade_to_tree(trade)
    storage.trades.recoverable[trade.id] = nil
end

---Return a lookup table, mapping trade ids to boolean (true) values, of all trades that consume the given item.
---@param item_name string
---@return {[int]: boolean}
function trades.get_trades_by_input(item_name)
    if not item_name then
        lib.log_error("trades.get_trades_by_input: item_name is nil")
        return {}
    end
    trades._check_tree_existence()
    return storage.trades.tree.by_input[item_name] or {}
end

---Return a lookup table, mapping trade ids to boolean (true) values, of all trades that produce the given item.
---@param item_name string
---@return {[int]: boolean}
function trades.get_trades_by_output(item_name)
    if not item_name then
        lib.log_error("trades.get_trades_by_output: item_name is nil")
        return {}
    end
    trades._check_tree_existence()
    return storage.trades.tree.by_output[item_name] or {}
end

---Return a lookup table, mapping trade ids to boolean (true) values, of all trades on the given surface.
---@param surface_name string
---@return {[int]: boolean}
function trades.get_trades_by_surface(surface_name)
    trades._check_tree_existence()
    return storage.trades.tree.by_surface[surface_name] or {}
end

---Return a lookup table, mapping trade ids to trade objects, of all trades in the current game.
---@return {[int]: Trade}
function trades.get_trades_lookup()
    trades._check_tree_existence()
    return storage.trades.tree.all_trades_lookup
end

---Return a normally indexed table of all trade objects in the current game, skipping over the trades that were deleted but recoverable if `only_existent` is true.
---@param only_existent boolean|nil
---@return Trade[]
function trades.get_all_trades(only_existent)
    if only_existent == nil then only_existent = true end
    trades._check_tree_existence()
    local all_trades = {}
    for trade_id, trade in pairs(trades.get_trades_lookup()) do
        if not only_existent or not storage.trades.recoverable[trade_id] then
            table.insert(all_trades, trade)
        end
    end
    return all_trades
end

---Return a normally indexed table of all ids of the trades that were deleted from hex cores and haven't yet been relocated via the gold star bonus effect.
---@return int[]
function trades.get_recoverable_trades()
    return sets.to_array(storage.trades.recoverable)
end

---Returns a normally indexed table of trade objects.
---@param trade_id_list int[]
---@return Trade[]
function trades.convert_trade_id_array_to_trade_array(trade_id_list)
    local _trades = {}
    local lookup = trades.get_trades_lookup()
    for _, trade_id in pairs(trade_id_list) do
        local trade = lookup[trade_id]
        if trade then
            table.insert(_trades, trade)
        else
            lib.log_error("trades.get_trades_from_ids: trade_id " .. trade_id .. " not found in lookup")
        end
    end
    return _trades
end

---Return a normally indexed table of trade objects.
---@param trades_lookup {[int]: boolean} A lookup table that maps trade ids to boolean (true) values.
---@return Trade[]
function trades.convert_boolean_lookup_to_array(trades_lookup)
    local _trades = {}
    local lookup = trades.get_trades_lookup()
    for trade_id, _ in pairs(trades_lookup) do
        local trade = lookup[trade_id]
        if trade then
            table.insert(_trades, trade)
        else
            lib.log_error("trades.get_trades_array_from_trades_lookup: trade_id " .. trade_id .. " not found in lookup")
        end
    end
    return _trades
end

---Convert a lookup table, which maps trade ids to boolean (true) values, to a lookup table which maps trade ids to trade objects.
---@param boolean_lookup {[int]: boolean}
---@return {[int]: Trade}
function trades.convert_boolean_lookup_to_trades_lookup(boolean_lookup)
    local trades_lookup = {}
    local lookup = trades.get_trades_lookup()
    for trade_id, _ in pairs(boolean_lookup) do
        local trade = lookup[trade_id]
        trades_lookup[trade_id] = trade
        if not trade then
            lib.log_error("trades.convert_boolean_lookup_to_trades_lookup: trade_id " .. trade_id .. " not found in lookup")
        end
    end
    return trades_lookup
end

---Convert a lookup table, which maps trade ids to trade objects, to a normally indexed table of trade objects.
---@param trades_lookup {[int]: Trade}
---@return Trade[]
function trades.convert_trades_lookup_to_array(trades_lookup)
    local trades_list = {}
    local n = 0
    for _, trade in pairs(trades_lookup) do
        n = n + 1
        trades_list[n] = trade
    end
    return trades_list
end

---Get a trade from its id.
---@param trade_id int
---@return Trade|nil
function trades.get_trade_from_id(trade_id)
    return trades.get_trades_lookup()[trade_id]
end

---Return whether the trade has a given item in its inputs.
---@param trade Trade
---@param item_name string
---@return boolean
function trades.has_item_as_input(trade, item_name)
    if lib.is_coin(item_name) then
        for _, input in pairs(trade.input_items) do
            if lib.is_coin(input.name) then
                return true
            end
        end
    else
        -- return storage.trades.tree.by_input[item_name] ~= nil and storage.trades.tree.by_input[item_name][trade.id] ~= nil
        for _, input in pairs(trade.input_items) do
            if input.name == item_name then
                return true
            end
        end
    end
    return false
end

---Return whether the trade has a given item in its outputs.
---@param trade Trade
---@param item_name string
---@return boolean
function trades.has_item_as_output(trade, item_name)
    if lib.is_coin(item_name) then
        for _, output in pairs(trade.output_items) do
            if lib.is_coin(output.name) then
                return true
            end
        end
    else
        -- return storage.trades.tree.by_output[item_name] ~= nil and storage.trades.tree.by_output[item_name][trade.id] ~= nil
        for _, output in pairs(trade.output_items) do
            if output.name == item_name then
                return true
            end
        end
    end
    return false
end

---Return whether the trade has a given item in either its inputs or outputs.
---@param trade Trade
---@param item_name string
---@return boolean
function trades.has_item(trade, item_name)
    return trades.has_item_as_input(trade, item_name) or trades.has_item_as_output(trade, item_name)
end

---Verify that the list of item names has the best coin tiers for display, given a central value for item values.
---@param list string[]
---@param volume number
function trades._check_coin_names_for_volume(list, volume)
    -- Convert coin names to correct tier for trade volume
    for i, item_name in ipairs(list) do
        if lib.is_coin(item_name) then
            list[i] = coin_tiers.get_name_of_tier(coin_tiers.get_tier_for_display(coin_tiers.from_base_value(volume / item_values.get_item_value("nauvis", "hex-coin"))))
        end
    end
end

---Get two lists from a trade object, one for the item names of the inputs, and the other for the outputs.
---@param trade Trade
---@return string[], string[]
function trades.get_input_output_item_names_of_trade(trade)
    local input_names = {}
    local output_names = {}
    for _, input in pairs(trade.input_items) do
        table.insert(input_names, input.name)
    end
    for _, output in pairs(trade.output_items) do
        table.insert(output_names, output.name)
    end
    return input_names, output_names
end

---Get the combined list of item names from a trade object, taken from both the inputs and outputs.
---@param trade Trade
---@return string[]
function trades.get_item_names_in_trade(trade)
    local item_names = {}
    for _, input in pairs(trade.input_items) do
        table.insert(item_names, input.name)
    end
    for _, output in pairs(trade.output_items) do
        table.insert(item_names, output.name)
    end
    return item_names
end

---Get the total amount of coins and items of an inventory.
---@param inv LuaInventory|LuaTrain
---@return Coin, QualityItemCounts
function trades.get_coins_and_items_of_inventory(inv)
    local input_coin_values = {}
    local all_items = inv.get_contents()
    local all_items_lookup = {}

    for _, stack in pairs(all_items) do
        local item_name = stack.name
        if lib.is_coin(item_name) then
            input_coin_values[item_name] = stack.count
        else
            local quality = stack.quality or "normal"
            local quality_table = all_items_lookup[quality]
            if not quality_table then
                quality_table = {}
                all_items_lookup[quality] = quality_table
            end
            quality_table[item_name] = stack.count
        end
    end

    local input_coin = coin_tiers.normalized(coin_tiers.from_coin_values_by_name(input_coin_values))
    return input_coin, all_items_lookup
end

---Process all trades from one inventory to another.
---@param surface_id int
---@param input_inv LuaInventory|LuaTrain
---@param output_inv LuaInventory|LuaTrain
---@param trade_ids int[]
---@param quality_cost_multipliers StringAmounts|nil
---@param check_output_buffer boolean|nil Whether to prevent making a trade if the trade's hex core's output buffer contains any amount of at least one of the trade's output items.
---@param max_items_per_output int|nil
---@param max_output_batches_per_trade int|nil How many output batches (successful outputs if negative productivity) are allowed per trade.
---@param cargo_wagons LuaEntity[]|nil If either the input or output inventory is a LuaTrain, then these are its cargo wagons closest to train stop.
---@return QualityItemCounts, QualityItemCounts, QualityItemCounts, table, table
function trades.process_trades_in_inventories(surface_id, input_inv, output_inv, trade_ids, quality_cost_multipliers, check_output_buffer, max_items_per_output, max_output_batches_per_trade, cargo_wagons)
    if check_output_buffer == nil then check_output_buffer = true end
    quality_cost_multipliers = quality_cost_multipliers or {}

    local is_output_train = output_inv.object_name == "LuaTrain"
    local is_input_train = input_inv.object_name == "LuaTrain"

    if is_input_train or is_output_train then
        if not cargo_wagons then
            lib.log_error("trades.process_trades_in_inventories: train inventories are involved but no cargo wagons were passed")
            return {}, {}, {}, coin_tiers.new(), coin_tiers.new()
        end
        ---@cast cargo_wagons LuaEntity[]
    end

    local input_coin, all_items_lookup
    if is_input_train then
        input_coin, all_items_lookup = inventories.get_coins_and_items_on_train(cargo_wagons, storage.item_buffs.train_trading_capacity)
    else
        input_coin, all_items_lookup = trades.get_coins_and_items_of_inventory(input_inv)
    end

    local initial_input_coin = coin_tiers.copy(input_coin)

    local _total_removed = {}
    local _total_inserted = {}
    local _remaining_to_insert = {}

    -- Use raw array for accumulation to avoid repeated normalization (performance optimization)
    local total_coins_added_values = coin_tiers.new_coin_values()

    -- Retrieve uniquely traded items and prod reqs tables
    local prod_reqs = storage.item_ranks.productivity_requirements
    local uniquely_traded_items = storage.trades.uniquely_traded_items
    if not uniquely_traded_items then
        uniquely_traded_items = {}
        storage.trades.uniquely_traded_items = uniquely_traded_items
    end
    local surface_uniquely_traded_items = uniquely_traded_items[surface_id]
    if not surface_uniquely_traded_items then
        surface_uniquely_traded_items = {}
        uniquely_traded_items[surface_id] = surface_uniquely_traded_items
    end

    local inventory_output_size
    if is_output_train then
        inventory_output_size = 0
        for i, wagon in ipairs(cargo_wagons) do
            if i > storage.item_buffs.train_trading_capacity then break end

            -- inventory_output_size = inventory_output_size + wagon.prototype.get_inventory_size(defines.inventory.cargo_wagon, wagon.quality)
            local inv = wagon.get_inventory(defines.inventory.cargo_wagon)
            if inv then
                inventory_output_size = inventory_output_size + inv.count_empty_stacks(true, false)
            end
        end
    else
        local hex_core = output_inv.entity_owner
        if hex_core and hex_core.valid then
            -- inventory_output_size = hex_core.prototype.get_inventory_size(defines.inventory.chest, hex_core.quality)
            local inv = hex_core.get_inventory(defines.inventory.chest)
            if inv then
                inventory_output_size = inv.count_empty_stacks(true, false)
            end
        end
    end

    local total_batches = 0
    for _, trade_id in pairs(trade_ids) do
        local trade = trades.get_trade_from_id(trade_id)

        if trade and trade.active then
            for _, quality in pairs(trade.allowed_qualities or {"normal"}) do
                local all_items_quality = all_items_lookup[quality] or {}
                local quality_cost_mult = quality_cost_multipliers[quality] or 1
                local num_batches = trades.get_num_batches_for_trade(all_items_lookup, input_coin, trade, quality, quality_cost_mult, check_output_buffer, max_items_per_output, max_output_batches_per_trade, inventory_output_size)

                if num_batches >= 1 then
                    local prod = trades.get_productivity(trade, quality)
                    local rounded_prod = math.floor(0.5 + prod * 1000) * 0.001 -- This is what's displayed in GUI, so even if the prod is slightly less than what's shown, allow the shown value to be used to conditionally rank up items (trade in precision for fewer confusing situations)

                    gameplay_statistics.increment("sell-item-of-quality", num_batches, quality)
                    total_batches = total_batches + num_batches

                    local total_removed, total_inserted, remaining_to_insert, remaining_coin, coins_added = trades.trade_items(input_inv, output_inv, trade, num_batches, quality, quality_cost_mult, all_items_lookup, input_coin, cargo_wagons)
                    if total_removed and total_inserted and remaining_to_insert and remaining_coin and coins_added then
                        input_coin = remaining_coin

                        -- Accumulate without normalization for performance
                        coin_tiers.accumulate(total_coins_added_values, coins_added)

                        if not _total_inserted[quality] then _total_inserted[quality] = {} end
                        for item_name, amount in pairs(total_inserted[quality] or {}) do
                            _total_inserted[quality][item_name] = (_total_inserted[quality][item_name] or 0) + amount
                            all_items_quality[item_name] = (all_items_quality[item_name] or 0) + amount
                            trades._handle_item_in_trade(surface_uniquely_traded_items, prod_reqs, item_name, "receive", rounded_prod)
                        end

                        if not _total_removed[quality] then _total_removed[quality] = {} end
                        for item_name, amount in pairs(total_removed[quality] or {}) do
                            _total_removed[quality][item_name] = (_total_removed[quality][item_name] or 0) + amount
                            all_items_quality[item_name] = math.max(0, (all_items_quality[item_name] or 0) - amount)
                            trades._handle_item_in_trade(surface_uniquely_traded_items, prod_reqs, item_name, "give", rounded_prod)
                        end

                        if not _remaining_to_insert[quality] then _remaining_to_insert[quality] = {} end
                        for item_name, amount in pairs(remaining_to_insert[quality] or {}) do
                            _remaining_to_insert[quality][item_name] = (_remaining_to_insert[quality][item_name] or 0) + amount
                            trades._handle_item_in_trade(surface_uniquely_traded_items, prod_reqs, item_name, "receive", rounded_prod)
                        end
                    end
                end
            end
        end
    end

    local total_coins_removed = coin_tiers.subtract(initial_input_coin, input_coin)

    gameplay_statistics.increment("make-trades", total_batches)

    -- Only NOW does it normalize, skipping all unnecessary normalizations mid-processing.
    local total_coins_added = coin_tiers.normalized(coin_tiers.new(total_coins_added_values))

    return _total_removed, _total_inserted, _remaining_to_insert, total_coins_removed, total_coins_added
end

---@param uniquely_traded_items {[string]: boolean}
---@param prod_reqs {[int]: number}
---@param item_name string
---@param trade_side TradeSide
---@param rounded_prod number
function trades._handle_item_in_trade(uniquely_traded_items, prod_reqs, item_name, trade_side, rounded_prod)
    if not uniquely_traded_items[item_name] then
        uniquely_traded_items[item_name] = true
        gameplay_statistics.increment "total-unique-items-traded"
    end

    local rank = item_ranks.get_item_rank(item_name)
    if rank ~= 2 and rank ~= 4 then return end

    if rounded_prod + 1e-9 >= prod_reqs[rank] and (trade_side == "receive" and rank == 2 or trade_side == "give" and rank == 4) then
        item_ranks.progress_item_rank(item_name, rank + 1)
    end
end

---Calculate the productivity modifier for a given quality.
---@param quality string
---@return number
function trades.get_productivity_modifier(quality)
    -- The results of this function can be cached, but that'd be slower than calculating it repeatedly,
    -- partly because the tier has to be determined, which is already cached and requires a string hash.
    local tier = lib.get_quality_tier(quality)
    if tier <= 1 then return 0 end
    return -0.35 - (tier - 2) * 0.2
end

---Get a value scaled by the productivity modifier, allowing for negative productivity modifiers.
---@param value number
---@param prod number
function trades.scale_value_with_productivity(value, prod)
    if prod < 0 then
        return value / (1 - prod)
    end
    return value * (1 + prod)
end

---Generate for each item the hex coordinates at which that item exists in `trades_per_item` interplanetary trades on the given surface.
---@param surface_name string
---@param trades_per_item int|nil
function trades.generate_interplanetary_trade_locations(surface_name, trades_per_item)
    if not trades_per_item then trades_per_item = 1 end

    if not storage.trades.interplanetary_trade_locations then
        storage.trades.interplanetary_trade_locations = {}
    end
    if not storage.trades.interplanetary_trade_locations[surface_name] then
        storage.trades.interplanetary_trade_locations[surface_name] = {}
    end

    local land_hexes = hex_island.get_land_hex_list(surface_name)
    local total_land_hexes = #land_hexes

    if total_land_hexes == 0 then
        -- Old saves won't have any interplanetary locations.
        return
    end

    local item_vals = item_values.get_interplanetary_item_values(surface_name, true, false, "normal")
    for item_name, _ in pairs(item_vals) do
        for i = 1, trades_per_item do
            local hex_pos = land_hexes[math.random(1, total_land_hexes)]
            if not storage.trades.interplanetary_trade_locations[surface_name][hex_pos.q] then
                storage.trades.interplanetary_trade_locations[surface_name][hex_pos.q] = {}
            end
            if not storage.trades.interplanetary_trade_locations[surface_name][hex_pos.q][hex_pos.r] then
                storage.trades.interplanetary_trade_locations[surface_name][hex_pos.q][hex_pos.r] = {}
            end
            storage.trades.interplanetary_trade_locations[surface_name][hex_pos.q][hex_pos.r][item_name] = true
            event_system.trigger("interplanetary-trade-generated", surface_name, item_name, hex_pos)
        end
    end
end

---Get the items that are traded at the given hex coordinates.
---@param surface_name string
---@param hex_pos HexPos
---@return StringSet
function trades.get_interplanetary_trade_items(surface_name, hex_pos)
    if not storage.trades.interplanetary_trade_locations then
        storage.trades.interplanetary_trade_locations = {}
    end
    local locations = storage.trades.interplanetary_trade_locations[surface_name]
    if not locations then return {} end
    if not locations[hex_pos.q] then return {} end
    return locations[hex_pos.q][hex_pos.r] or {}
end

---Get the list of hex coordinates at which the given item is traded in an interplanetary trade on the given surface.
---@param surface_name string
---@param item_name string
---@return HexPos[]
function trades.get_interplanetary_trade_locations_for_item(surface_name, item_name)
    if not storage.trades.interplanetary_trade_locations then
        storage.trades.interplanetary_trade_locations = {}
    end
    if not storage.trades.interplanetary_trade_locations[surface_name] then
        storage.trades.interplanetary_trade_locations[surface_name] = {}
    end

    local locations = {}
    for q, Q in pairs(storage.trades.interplanetary_trade_locations[surface_name]) do
        for r, R in pairs(Q) do
            if R[item_name] then
                table.insert(locations, {q=q, r=r})
            end
        end
    end

    return locations
end

---Return whether the given trade is interplanetary to its surface.
---@param trade Trade
---@return boolean
function trades.is_interplanetary_trade(trade)
    if trade.is_interplanetary ~= nil then return trade.is_interplanetary end

    local surface_name = trade.surface_name
    for _, input in pairs(trade.input_items) do
        if item_values.is_item_interplanetary(surface_name, input.name) then
            trade.is_interplanetary = true
            return true
        end
    end
    for _, output in pairs(trade.output_items) do
        if item_values.is_item_interplanetary(surface_name, output.name) then
            trade.is_interplanetary = true
            return true
        end
    end

    trade.is_interplanetary = false
    return false
end

---Set whether a trade is favorited for a player.
---@param player LuaPlayer
---@param trade Trade
---@param flag boolean|nil Defaults to true.
function trades.favorite_trade(player, trade, flag)
    if flag == nil then flag = true end

    local fav = storage.trades.favorites
    if not fav then
        fav = {}
        storage.trades.favorites = fav
    end

    local player_favs = fav[player.index]
    if not player_favs then
        player_favs = {}
        fav[player.index] = player_favs
    end

    local prev_val = player_favs[trade.id]
    if flag then
        player_favs[trade.id] = true
    else
        player_favs[trade.id] = nil
    end

    if player_favs[trade.id] ~= prev_val then
        event_system.trigger("player-favorited-trade", player, trade)
    end
end

---Return the set of trade IDs that are marked as favorited for a player.
---@param player LuaPlayer
---@return {[int]: boolean}
function trades.get_favorited_trades(player)
    local fav = storage.trades.favorites
    if not fav then
        fav = {}
        storage.trades.favorites = fav
    end

    local player_favs = fav[player.index]
    if not player_favs then
        player_favs = {}
        fav[player.index] = player_favs
    end

    return table.deepcopy(player_favs)
end

---Return whether a trade is favorited for a player.
---@param player LuaPlayer
---@param trade Trade
---@return boolean
function trades.is_trade_favorited(player, trade)
    local fav = storage.trades.favorites
    if not fav then
        fav = {}
        storage.trades.favorites = fav
    end

    local player_favs = fav[player.index]
    if not player_favs then
        return false
    end

    return player_favs[trade.id] == true
end

function trades.recalculate_researched_items()
    -- Determine which items are "researched"
    local researched_items = sets.new()
    for _, recipe in pairs(game.forces.player.recipes) do
        if not recipe.hidden and recipe.enabled then
            for _, product in pairs(recipe.products) do
                if product.type == "item" then
                    sets.add(researched_items, product.name)
                end
            end
        end
    end

    -- Add raw items to set
    researched_items = sets.union(researched_items, lib.get_raw_items())
    storage.trades.researched_items = researched_items
end

---@param surface_name string|nil
function trades.fetch_base_trade_productivity_settings(surface_name)
    if surface_name == nil then
        for _surface_name, _ in pairs(storage.item_values.values) do
            trades.fetch_base_trade_productivity_settings(_surface_name)
        end
        return
    end

    if not storage.trades.base_trade_productivity then
        storage.trades.base_trade_productivity = {}
    end

    local prod = lib.runtime_setting_value_as_number("base-trade-prod-" .. surface_name)
    storage.trades.base_trade_productivity[surface_name] = prod
end

function trades.fetch_base_trade_efficiency_settings()
    local eff = lib.runtime_setting_value_as_number "base-trade-efficiency"
    storage.trades.base_trade_efficiency = eff
end

---Return whether the heuristic upper bound for total number of trades on the selected planets exceeds the current batch processing threshold.
---@param filter TradeOverviewFilterSettings
---@return boolean
function trades.should_use_batch_processing(filter)
    local count = 0

    local threshold = storage.trades.batch_processing_threshold

    -- Repeated code because these heuristic validations need to be as FAST as possible, as they will always be executed in a single tick.
    if filter.input_items and filter.input_items[1] then
        -- Don't quite need to check for surface matching because item filtering vastly reduces the number of trades already.  So this is faster for that.
        for _ in pairs(trades.get_trades_by_input(filter.input_items[1])) do
            count = count + 1
            if count > threshold then return true end
        end
    elseif filter.output_items and filter.output_items[1] then
        for _ in pairs(trades.get_trades_by_input(filter.output_items[1])) do
            count = count + 1
            if count > threshold then return true end
        end
    else
        if filter.planets then
            for surface_name, allow in pairs(filter.planets) do
                if allow then
                    for _ in pairs(trades.get_trades_by_surface(surface_name)) do
                        count = count + 1
                        if count > threshold then return true end
                    end
                end
            end
        end
    end

    return false
end

function trades.migrate_old_data()
    if not storage.trades.base_trade_efficiency then
        trades.fetch_base_trade_efficiency_settings()
    end

    if not storage.trades.productivity_update_jobs then
        storage.trades.productivity_update_jobs = {}
        storage.trades.trade_collection_jobs = {}
        storage.trades.trade_filtering_jobs = {}
        storage.trades.trade_sorting_jobs = {}
        storage.trades.trade_export_jobs = {}
        storage.trades.researched_items = {}
        storage.trades.base_trade_productivity = {}

        local penalty = lib.runtime_setting_value "unresearched-penalty"
        ---@cast penalty number

        storage.trades.unresearched_penalty = penalty
        trades.recalculate_researched_items()
        trades.fetch_base_trade_productivity_settings()
    end
end

---@param entity_that_died LuaEntity
---@param entity_that_caused LuaEntity
---@param damage_type_prot LuaDamagePrototype|nil
function trades.on_entity_killed_entity(entity_that_died, entity_that_caused, damage_type_prot)
    if not damage_type_prot or damage_type_prot.name ~= "electric" or entity_that_caused.force.name ~= "player" then return end

    local transformation = terrain.get_surface_transformation(entity_that_died.surface)
    local hex_pos = axial.get_hex_containing(entity_that_died.position, transformation.scale, transformation.rotation)
    local hex_state = hex_state_manager.get_hex_state(entity_that_died.surface, hex_pos)
    if not hex_state or not hex_state.trades then return end

    local prod_req = storage.item_ranks.productivity_requirements[3]
    for _, trade_id in pairs(hex_state.trades) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            local prod = trades.get_productivity(trade, "normal") -- just assume normal quality even if it's not set on that
            local rounded_prod = math.floor(0.5000001 + prod * 100) / 100 + 1e-9 -- floating point rounding errors... -_-
            if rounded_prod >= prod_req then
                for _, item_name in pairs(trades.get_item_names_in_trade(trade)) do
                    local rank = item_ranks.get_item_rank(item_name)
                    if rank == 3 then
                        item_ranks.progress_item_rank(item_name, 4)
                    end
                end
            end
        end
    end
end



return trades
