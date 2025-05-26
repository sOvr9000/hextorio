
local lib = require "api.lib"
local item_values = require "api.item_values"
local sets        = require "api.sets"
local item_ranks  = require "api.item_ranks"
local coin_tiers  = require "api.coin_tiers"
local event_system= require "api.event_system"
local quests      = require "api.quests"

require "util" -- for table.deepcopy

local trades = {}



function trades.register_events()
    event_system.register_callback("command-discover-all", function(player, params)
        local items_list = {}
        for surface_name, vals in pairs(storage.item_values.values) do
            for item_name, _ in pairs(vals) do
                if not lib.is_coin(item_name) and lib.is_item(item_name) then
                    table.insert(items_list, item_name)
                end
            end
        end
        trades.discover_items(items_list)
        event_system.trigger("post-discover-all-command", player, params)
    end)
end

function trades.new(input_items, output_items, surface_name)
    if not input_items or not output_items then
        lib.log_error("trade has no input items or no output items")
    end
    if not surface_name then
        lib.log_error("trade has no specified surface name")
    end
    storage.trades.trade_id_ctr = (storage.trades.trade_id_ctr or 0) + 1
    local trade = {
        id = storage.trades.trade_id_ctr,
        input_items = {},
        output_items = {},
        surface_name = surface_name,
        active = true,
    }
    for _, input_item in pairs(input_items) do
        table.insert(trade.input_items, {
            name = input_item.name,
            count = input_item.count,
        })
    end
    for _, output_item in pairs(output_items) do
        table.insert(trade.output_items, {
            name = output_item.name,
            count = output_item.count,
        })
    end
    trades.check_productivity(trade)
    return trade
end

-- Return a deep copy of a single trade
function trades.copy_trade(trade)
    return table.deepcopy(trade)
end

function trades.from_item_names(surface_name, input_item_names, output_item_names, params)
    if not params then
        params = {}
    end

    if type(input_item_names) == "string" then
        input_item_names = {input_item_names}
    end
    if type(output_item_names) == "string" then
        output_item_names = {output_item_names}
    end

    local max_value = 0
    for _, item_name in pairs(input_item_names) do
        max_value = math.max(max_value, item_values.get_item_value(surface_name, item_name))
    end
    for _, item_name in pairs(output_item_names) do
        max_value = math.max(max_value, item_values.get_item_value(surface_name, item_name))
    end

    local value_budget = (3 + math.random() * 7) * max_value
    local value_per_input = value_budget / #input_item_names

    local input_items = {}
    for _, item_name in pairs(input_item_names) do
        local value = item_values.get_item_value(surface_name, item_name)
        local mean_count = value_per_input / value
        local count = math.max(1, math.floor(0.5 + mean_count * (0.75 + 0.5 * math.random())))
        local input_item = {
            name = item_name,
            count = count,
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

    local trade = trades.new(input_items, output_items, surface_name)
    trades.determine_best_output_counts(surface_name, trade, params)
    return trade
end

-- Given a trade with set input items and counts and set output items but unset output counts, set the remaining unset output counts to the values which best preserve a value ratio of 1:1.
function trades.determine_best_output_counts(surface_name, trade, params)
    if not params then params = {} end
    trades._try_set_output_counts(surface_name, trade, params)
end

function trades._try_set_output_counts(surface_name, trade, params)
    if not params.target_efficiency then
        params.target_efficiency = 1
    end

    local total_input_value = trades.get_input_value(surface_name, trade) * params.target_efficiency
    local output_items_value = {}

    -- Initialize with values and minimal counts
    for i, output_item in ipairs(trade.output_items) do
        output_items_value[i] = item_values.get_item_value(surface_name, output_item.name)
        output_item.count = output_item.count or 1  -- Initialize with count 1 if not set
    end

    -- Handle single output item case specially
    if #trade.output_items == 1 then
        local output_item = trade.output_items[1]
        local item_value = output_items_value[1]
        output_item.count = math.max(1, math.floor((total_input_value / item_value) + 0.5))
        return
    end

    -- Initial distribution based on proportional values
    local total_output_value_per_item = 0
    for i = 1, #output_items_value do
        total_output_value_per_item = total_output_value_per_item + output_items_value[i]
    end

    for i, output_item in ipairs(trade.output_items) do
        local proportion = output_items_value[i] / total_output_value_per_item
        local target_value = total_input_value * proportion
        local target_count = target_value / output_items_value[i]
        output_item.count = math.max(1, math.floor(target_count + 0.5))
    end

    -- Hill climbing optimization to get closer to target ratio
    local iterations = 0
    local max_iterations = 50
    local best_error = math.abs(trades.get_trade_value_ratio(surface_name, trade) - 1)

    while iterations < max_iterations and best_error > 0.01 do
        iterations = iterations + 1
        local improved = false

        -- For each output item, try incrementing and decrementing
        for i, output_item in ipairs(trade.output_items) do
            -- Try incrementing
            output_item.count = output_item.count + 1
            local new_ratio = trades.get_trade_value_ratio(surface_name, trade)
            local new_error = math.abs(new_ratio - params.target_efficiency)

            if new_error < best_error then
                best_error = new_error
                improved = true
            else
                -- Revert increment
                output_item.count = output_item.count - 1

                -- Try decrementing if count > 1
                if output_item.count > 1 then
                    output_item.count = output_item.count - 1
                    new_ratio = trades.get_trade_value_ratio(surface_name, trade)
                    new_error = math.abs(new_ratio - params.target_efficiency)

                    if new_error < best_error then
                        best_error = new_error
                        improved = true
                    else
                        -- Revert decrement
                        output_item.count = output_item.count + 1
                    end
                end
            end
        end

        -- Exit if no improvements in this iteration
        if not improved then break end
    end
end

-- Return the value of the trade's inputs
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

-- Return the value of the trade's outputs
function trades.get_output_value(surface_name, trade, quality)
    quality = quality or "normal"
    local output_value = 0
    local quality_value_scale = lib.get_quality_value_scale(quality)
    for _, output_item in pairs(trade.output_items) do
        output_value = output_value + item_values.get_item_value(surface_name, output_item.name) * output_item.count * quality_value_scale
    end
    return output_value
end

function trades.get_volume_of_trade(surface_name, trade)
    return trades.get_total_value_of_trade(surface_name, trade) * 0.5
end

-- Return the ratio of values of the trade's outputs to its inputs
function trades.get_trade_value_ratio(surface_name, trade)
    return trades.get_output_value(surface_name, trade) / trades.get_input_value(surface_name, trade)
end

function trades.get_total_value_of_trade(surface_name, trade, quality, quality_cost_mult)
    return trades.get_input_value(surface_name, trade, quality, quality_cost_mult) + trades.get_output_value(surface_name, trade, quality)
end

function trades.get_total_values_str(trade, quality, quality_cost_mult)
    local coin_value = item_values.get_item_value("nauvis", "hex-coin")
    local total_input_value = trades.get_input_value(trade.surface_name, trade, quality, quality_cost_mult) / coin_value
    local total_output_value = trades.get_output_value(trade.surface_name, trade, quality) / coin_value
    return {"",
        {"hextorio-gui.total-input-value", coin_tiers.coin_to_text(total_input_value)},
        "\n",
        {"hextorio-gui.total-output-value", coin_tiers.coin_to_text(total_output_value)},
    }
end

function trades.get_productivity_bonus_str(trade)
    local prod = trades.get_productivity(trade)
    if prod == 0 then
        return ""
    end

    local bonus_strs = {}

    for _, input_item in pairs(trade.input_items) do
        if item_ranks.is_item_rank_defined(input_item.name) then
            local rank = item_ranks.get_item_rank(input_item.name)
            if rank >= 2 then
                table.insert(bonus_strs, "[img=item." .. input_item.name .. "] +[color=green]" .. lib.format_percentage(item_ranks.get_rank_bonus_effect(rank), 0, false) .. "%[.color]")
            end
        end
    end
    for _, output_item in pairs(trade.output_items) do
        if item_ranks.is_item_rank_defined(output_item.name) then
            local rank = item_ranks.get_item_rank(output_item.name)
            if rank >= 2 then
                table.insert(bonus_strs, "[img=item." .. output_item.name .. "] +[color=green]" .. lib.format_percentage(item_ranks.get_rank_bonus_effect(rank), 0, false) .. "%[.color]")
            end
        end
    end

    local str = {"",
        lib.color_localized_string({"hextorio-gui.productivity-bonus"}, "purple", "heading-2"),
        "\n" .. table.concat(bonus_strs, "\n") .. "\n[font=heading-2]=[color=green]" .. lib.format_percentage(prod, 0, false) .. "%[.color][.font]",
    }

    if trades.get_base_trade_productivity() > 0 then
        table.insert(str, 3, "\n")
        table.insert(str, 4, lib.color_localized_string({"hextorio-gui.quest-reward"}, "white", "heading-2"))
        table.insert(str, 5, " +[color=green]" .. lib.format_percentage(trades.get_base_trade_productivity(), 0, false) .. "%[.color]")
    end

    return str
end

function trades.get_input_coins_of_trade(trade, quality, quality_cost_mult)
    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1
    local values = {}
    for _, input_item in pairs(trade.input_items) do
        if lib.is_coin(input_item.name) then
            values[input_item.name] = input_item.count
        end
    end
    local coin = coin_tiers.new(values)
    local mult = lib.get_quality_value_scale(quality) * quality_cost_mult
    coin = coin_tiers.multiply(coin, mult)
    return coin
end

function trades.get_output_coins_of_trade(trade, quality)
    quality = quality or "normal"
    local values = {}
    for _, output_item in pairs(trade.output_items) do
        if lib.is_coin(output_item.name) then
            values[output_item.name] = output_item.count
        end
    end
    local coin = coin_tiers.new(values)
    coin = coin_tiers.multiply(coin, lib.get_quality_value_scale(quality))
    return coin
end

-- Check how many batches of (how many times) a trade can occur within an inventory
function trades.get_num_batches_for_trade(input_items, input_coin, trade, quality, quality_cost_mult, max_items_per_output)
    if not trade.active then return 0 end

    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    if not max_items_per_output then
        max_items_per_output = trade.max_items_per_output or 1000
        if max_items_per_output == 0 then return 0 end -- Probably won't ever happen, but if it ever does, it's an optimization.
    end

    local num_batches = math.huge
    for _, input_item in pairs(trade.input_items) do
        if not lib.is_coin(input_item.name) then
            num_batches = math.min(math.floor(((input_items[quality] or {})[input_item.name] or 0) / input_item.count), num_batches)
            if num_batches == 0 then return 0 end
        end
    end

    -- Further limit num_batches according to max_items_per_output
    for _, output_item in pairs(trade.output_items) do
        if not lib.is_coin(output_item.name) then
            num_batches = math.min(math.floor(max_items_per_output / output_item.count), num_batches)
            if num_batches == 0 then return 0 end
        end
    end

    local trade_coin = trades.get_input_coins_of_trade(trade, quality, quality_cost_mult)
    if not coin_tiers.is_zero(trade_coin) then
        num_batches = math.min(math.floor(coin_tiers.divide_coins(input_coin, trade_coin)), num_batches)
    end

    return num_batches
end

-- Trade items within an inventory
function trades.trade_items(inventory_input, inventory_output, trade, num_batches, quality, quality_cost_mult, input_items, input_coin)
    if not trade.active then return {}, {}, {}, input_coin end
    if num_batches <= 0 then return {}, {}, {}, input_coin end

    -- TODO: Handle two flow statistics if input and output inventories are on different surfaces
    local flow_statistics = game.forces.player.get_item_production_statistics(trade.surface_name)

    if not input_items or not input_coin then
        input_coin, input_items = trades.get_coins_and_items_of_inventory(inventory_input)
    end

    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    local total_removed = {}
    for _, input_item in pairs(trade.input_items) do
        if not lib.is_coin(input_item.name) then
            local to_remove = math.min(input_item.count * num_batches, input_items[quality][input_item.name] or 0)
            if to_remove > 0 then
                local actually_removed = inventory_input.remove {name = input_item.name, count = to_remove, quality = quality}
                if not total_removed[quality] then total_removed[quality] = {} end
                total_removed[quality][input_item.name] = (total_removed[quality][input_item.name] or 0) + actually_removed
                trades.increment_total_sold(input_item.name, actually_removed)
                flow_statistics.on_flow({name = input_item.name, quality = quality}, -actually_removed)
            end
        end
    end

    local trade_coin = trades.get_input_coins_of_trade(trade, quality, quality_cost_mult)
    local coins_removed = coin_tiers.multiply(trade_coin, num_batches)
    local remaining_coin = coin_tiers.subtract(input_coin, coins_removed)
    coin_tiers.remove_coin_from_inventory(inventory_input, coins_removed)
    flow_statistics.on_flow("hex-coin", -coin_tiers.to_base_value(coins_removed))

    local total_inserted = {}
    local remaining_to_insert = {}
    trade_coin = trades.get_output_coins_of_trade(trade, quality)
    local total_output_batches = num_batches + trades.increment_current_prod_value(trade, num_batches)
    for _, output_item in pairs(trade.output_items) do
        if not lib.is_coin(output_item.name) then
            local to_insert = output_item.count * total_output_batches
            local actually_inserted = inventory_output.insert {name = output_item.name, count = math.min(1000000000, to_insert), quality = quality}
            if not total_inserted[quality] then total_inserted[quality] = {} end
            total_inserted[quality][output_item.name] = (total_inserted[quality][output_item.name] or 0) + actually_inserted
            if actually_inserted < to_insert then
                if not remaining_to_insert[quality] then remaining_to_insert[quality] = {} end
                remaining_to_insert[quality][output_item.name] = (remaining_to_insert[quality][output_item.name] or 0) + to_insert - actually_inserted
            end
            trades.increment_total_bought(output_item.name, to_insert)
            flow_statistics.on_flow({name = output_item.name, quality = quality}, to_insert) -- Track entire stacks being inserted into both the output inventory and the buffer (remaining_to_insert).
        end
    end

    local coins_added = coin_tiers.multiply(trade_coin, total_output_batches)
    coin_tiers.add_coin_to_inventory(inventory_input, coins_added)
    flow_statistics.on_flow("hex-coin", coin_tiers.to_base_value(coins_added))

    event_system.trigger("trade-processed", trade)
    return total_removed, total_inserted, remaining_to_insert, remaining_coin
end

function trades.random_trade_item_names(surface_name, volume, params, allow_interplanetary)
    if not params then params = {} end
    if allow_interplanetary == nil then allow_interplanetary = false end

    local ratio = 10
    if surface_name == "aquilo" then
        ratio = 100
    end

    local possible_items = item_values.get_items_near_value(surface_name, volume, ratio, true, false, allow_interplanetary)

    -- Apply whitelist filter
    if params.whitelist then
        possible_items = lib.filter_whitelist(possible_items, function(item_name)
            return params.whitelist[item_name]
        end)
    end

    -- Apply blacklist filter
    if params.blacklist then
        possible_items = lib.filter_blacklist(possible_items, function(item_name)
            return params.blacklist[item_name]
        end)
    end

    if #possible_items < 2 then
        lib.log_error("trades.random_trade_item_names: Not enough items found near value " .. volume .. "; found: " .. serpent.line(possible_items))
        return
    end

    local set = sets.new()
    for i = 1, 6 do
        if #possible_items == 0 then break end
        local item_name = table.remove(possible_items, math.random(1, #possible_items))
        sets.add(set, item_name)
    end
    local trade_items = sets.to_array(set)

    if #trade_items < 2 then
        lib.log_error("trades.random_trade_item_names: Not enough items selected for trade")
        return
    end

    local input_item_names = {}
    local output_item_names = {}
    for i = 1, #trade_items do
        if i % 2 == 0 then
            table.insert(output_item_names, trade_items[i])
        else
            table.insert(input_item_names, trade_items[i])
        end
    end

    local num_inputs = math.random(1, 3)
    while #input_item_names > num_inputs do
        table.remove(input_item_names, 1)
    end

    local num_outputs = math.random(1, 3)
    while #output_item_names > num_outputs do
        table.remove(output_item_names, 1)
    end

    trades._check_coin_names_for_volume(input_item_names, volume)
    trades._check_coin_names_for_volume(output_item_names, volume)

    return input_item_names, output_item_names
end

-- Generate a random trade
function trades.random(surface_name, volume)
    local input_item_names, output_item_names = trades.random_trade_item_names(surface_name, volume, nil, surface_name == "aquilo")

    if not input_item_names or not output_item_names then
        lib.log("trades.random: Not enough items centered around the value " .. volume)
        return
    end

    if math.random() < lib.runtime_setting_value "coin-trade-chance" then
        local coin_type = "hex-coin"
        if volume > item_values.get_item_value(surface_name, "hexaprism-coin") then
            coin_type = "hexaprism-coin"
        elseif volume > item_values.get_item_value(surface_name, "meteor-coin") then
            coin_type = "meteor-coin"
        elseif volume > item_values.get_item_value(surface_name, "gravity-coin") then
            coin_type = "gravity-coin"
        end
        if math.random() < lib.runtime_setting_value "sell-trade-chance" then
            output_item_names[math.random(1, #output_item_names)] = coin_type
        else
            input_item_names[math.random(1, #input_item_names)] = coin_type
        end
    end

    return trades.from_item_names(surface_name, input_item_names, output_item_names)
end

function trades.is_trade_valid(trade)
    if not trade then return false end
    if not trade.id then return false end
    if not trade.input_items then return false end
    if not trade.output_items then return false end
    if not trade.surface_name then return false end
    if type(trade.surface_name) ~= "string" then return false end
    if type(trade.input_items) ~= "table" then return false end
    if type(trade.output_items) ~= "table" then return false end
    local all_items = table.pack(table.unpack(trade.input_items), table.unpack(trade.output_items))
    all_items.n = nil -- weird thing from Lua idk
    for _, item in pairs(all_items) do
        if type(item) ~= "table" then return false end
        if not item.name then return false end
        if type(item.name) ~= "string" then return false end
        if not item.count then return false end
        if type(item.count) ~= "number" then return false end
        if item.count <= 0 then return false end

        -- This does not need to be checked since items are allowed to have interplanetary values.
        -- if not item_values.has_item_value(trade.surface_name, item.name) then return false end
    end
    return true
end

-- Return whether the item is now discovered if it wasn't previously.
function trades.mark_as_discovered(item_name)
    if not quests.is_feature_unlocked "catalog" then return false end
    if item_name:sub(-5) == "-coin" then return false end
    local already_discovered = trades.is_item_discovered(item_name)
    storage.trades.discovered_items[item_name] = true
    return not already_discovered
end

function trades.is_item_discovered(item_name)
    return storage.trades.discovered_items[item_name] == true
end

-- Return a list of the item names which were newly discovered.
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
        game.print({"", {"hextorio.new-catalog-items"}, s})
    end

    return new_discoveries
end

-- Return a list of the item names which were newly discovered in the given trades.
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

function trades._increment_total_traded(item_name, amount)
    if amount <= 0 then return end
    storage.trades.total_items_traded[item_name] = (storage.trades.total_items_traded[item_name] or 0) + amount
end

function trades.increment_total_sold(item_name, amount)
    if amount <= 0 then return end
    local old_amount = storage.trades.total_items_sold[item_name] or 0
    storage.trades.total_items_sold[item_name] = (storage.trades.total_items_sold[item_name] or 0) + amount
    trades._increment_total_traded(item_name, amount)
    if old_amount == 0 and trades.get_total_bought(item_name) > 0 and item_ranks.get_item_rank(item_name) == 1 then
        item_ranks.progress_item_rank(item_name, 2)
    end
end

function trades.increment_total_bought(item_name, amount)
    if amount <= 0 then return end
    local old_amount = storage.trades.total_items_bought[item_name] or 0
    storage.trades.total_items_bought[item_name] = (storage.trades.total_items_bought[item_name] or 0) + amount
    trades._increment_total_traded(item_name, amount)
    if old_amount == 0 and trades.get_total_sold(item_name) > 0 and item_ranks.get_item_rank(item_name) == 1 then
        item_ranks.progress_item_rank(item_name, 2)
    end
end

function trades.get_total_traded(item_name)
    return storage.trades.total_items_traded[item_name] or 0
end

function trades.get_total_sold(item_name)
    return storage.trades.total_items_sold[item_name] or 0
end

function trades.get_total_bought(item_name)
    return storage.trades.total_items_bought[item_name] or 0
end

function trades.set_trade_active(trade, flag)
    if flag == trade.active then return false end
    trade.active = flag
    return true
end

function trades.set_productivity(trade, productivity)
    trade.productivity = productivity
end

function trades.get_productivity(trade)
    return trade.productivity or 0
end

function trades.increment_productivity(trade, productivity)
    trade.productivity = (trade.productivity or 0) + productivity
end

function trades.get_current_prod_value(trade)
    return trade.current_prod_value or 0
end

function trades.set_current_prod_value(trade, value)
    trade.current_prod_value = value
end

function trades.increment_current_prod_value(trade, times)
    trade.current_prod_value = (trade.current_prod_value or 0) + trades.get_productivity(trade) * (times or 1)
    local prod_amount = math.floor(trade.current_prod_value)
    trade.current_prod_value = trade.current_prod_value - prod_amount
    return prod_amount
end

function trades.get_base_trade_productivity()
    return storage.trades.base_productivity or 0
end

function trades.set_base_trade_productivity(prod)
    storage.trades.base_productivity = prod
end

function trades.increment_base_trade_productivity(prod)
    storage.trades.base_productivity = (storage.trades.base_productivity or 0) + prod
end

---Verify that the trade's productivity effect is correctly calculated from base productivity and its input and output item ranks.
---@param trade table
function trades.check_productivity(trade)
    trades.set_productivity(trade, trades.get_base_trade_productivity())
    for j, item in ipairs(trade.input_items) do
        if lib.is_catalog_item(item.name) then
            trades.increment_productivity(trade, item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)))
        end
    end
    for j, item in ipairs(trade.output_items) do
        if lib.is_catalog_item(item.name) then
            trades.increment_productivity(trade, item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)))
        end
    end
end

function trades.get_random_volume_for_item(surface_name, item_name)
    local volume = item_values.get_item_value(surface_name, item_name)
    if surface_name == "aquilo" then
        return volume * (3 + 97 * math.random())
    end
    return volume * (3 + 7 * math.random())
end

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
    if not storage.trades.tree.all_trades_lookup then
        storage.trades.tree.all_trades_lookup = {}
    end
    if not storage.trades.recoverable then
        storage.trades.recoverable = {}
    end
end

function trades.add_trade_to_tree(trade)
    if not trade then
        lib.log_error("trades.add_trade_to_tree: trade is nil")
        return
    end
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
    storage.trades.tree.all_trades_lookup[trade.id] = trade
end

function trades.remove_trade_from_tree(trade, recoverable)
    if recoverable == nil then recoverable = true end
    if not trade then
        lib.log_error("trades.remove_trade_from_tree: trade is nil")
        return
    end
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
    if recoverable then
        storage.trades.recoverable[trade.id] = true
    else
        storage.trades.tree.all_trades_lookup[trade.id] = nil
    end
end

function trades.recover_trade(trade)
    if not trade then
        lib.log_error("trades.recover_trade: trade is nil")
        return
    end
    trades._check_tree_existence()
    if not storage.trades.recoverable[trade.id] then return end
    trades.add_trade_to_tree(trade)
    storage.trades.recoverable[trade.id] = nil
end

---Returns a lookup table, mapping trade ids to boolean (true) values, of all trades that consume the given item.
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

---Returns a lookup table, mapping trade ids to boolean (true) values, of all trades that produce the given item.
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

---Returns a lookup table, mapping trade ids to trade objects, of all trades in the current game.
---@return {[int]: table}
function trades.get_trades_lookup()
    trades._check_tree_existence()
    return storage.trades.tree.all_trades_lookup
end

---Returns a normally indexed table of all trade objects in the current game, skipping over the trades that were deleted but recoverable if only_existent is true.
---@param only_existent boolean
---@return {[int]: table}
function trades.get_all_trades(only_existent)
    if only_existent == nil then only_existent = true end
    local all_trades = {}
    for trade_id, trade in pairs(trades.get_trades_lookup()) do
        if not only_existent or not storage.tree.recoverable[trade_id] then
            table.insert(all_trades, trade)
        end
    end
    return all_trades
end

---Returns a normally indexed table of all ids of the trades that were deleted from hex cores and haven't yet been relocated via the gold star bonus effect.
---@return {[int]: int}
function trades.get_recoverable_trades()
    return sets.to_array(storage.trades.recoverable)
end

---Expects a normally indexed table of trade ids.
---Returns a normally indexed table of trade objects.
---@param trade_id_list {[int]: int}
---@return {[int]: table}
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

---Expects a lookup table that maps trade ids to boolean (true) values.
---Returns a normally indexed table of trade objects.
---@param trades_lookup {[int]: boolean}
---@return {[int]: table}
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

---Converts a lookup table, which maps trade ids to boolean (true) values, to a lookup table which maps trade ids to trade objects.
---@param boolean_lookup {[int]: boolean}
---@return {[int]: table}
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

---Converts a lookup table, which maps trade ids to trade objects, to a normally indexed table of trade objects.
---@param trades_lookup {[int]: table}
---@return {[int]: table}
function trades.convert_trades_lookup_to_array(trades_lookup)
    local _trades = {}
    for _, trade in pairs(trades_lookup) do
        table.insert(_trades, trade)
    end
    return _trades
end

---@param trade_id int|table
---@return table|nil
function trades.get_trade_from_id(trade_id)
    if type(trade_id) == "table" and trades.is_trade_valid(trade_id) then return trade_id end
    if type(trade_id) ~= "number" then
        lib.log_error("trades.get_trade_from_id: trade_id is not a number, received type: " .. type(trade_id))
        -- if type(trade_id) == "table" then
        --     lib.log(serpent.block(trade_id))
        -- end
        return
    end
    return trades.get_trades_lookup()[trade_id]
end

function trades.has_item_as_input(trade, item_name)
    if not trade then
        lib.log_error("trades.has_item_as_input: trade is nil")
        return false
    end
    if not item_name then
        lib.log_error("trades.has_item_as_input: item_name is nil")
        return true
    end
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

function trades.has_item_as_output(trade, item_name)
    if not trade then
        lib.log_error("trades.has_item_as_output: trade is nil")
        return false
    end
    if not item_name then
        lib.log_error("trades.has_item_as_output: item_name is nil")
        return true
    end
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

function trades.has_item(trade, item_name)
    return trades.has_item_as_input(trade, item_name) or trades.has_item_as_output(trade, item_name)
end

function trades.get_coin_name_for_trade_volume(trade_volume)
    if type(trade_volume) == "number" then
        if trade_volume < 1000000000 then -- use hex coin up to 1000x gravity coin's worth of hex coins
            return "hex-coin"
        elseif trade_volume < 100000000000000 then -- use hex coin up to 1000x meteor coin's worth of gravity coins
            return "gravity-coin"
        elseif trade_volume < 10000000000000000000 then -- use hex coin up to 1000x heaxaprism coin's worth of gravity coins
            return "meteor-coin"
        else
            return "hexaprism-coin"
        end
    else
        -- TODO: trade_volume is a coin_tier object
    end
end

function trades._check_coin_names_for_volume(list, volume)
    -- Convert coin names to correct tier for trade volume
    for i, item_name in ipairs(list) do
        if lib.is_coin(item_name) then
            list[i] = trades.get_coin_name_for_trade_volume(volume)
        end
    end
end

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

function trades.get_coins_and_items_of_inventory(inv)
    local input_coin_values = {}
    local all_items = inv.get_contents()
    local all_items_lookup = {}
    for _, stack in pairs(all_items) do
        if lib.is_coin(stack.name) then
            input_coin_values[stack.name] = stack.count
        else
            local quality = stack.quality or "normal"
            if not all_items_lookup[quality] then
                all_items_lookup[quality] = {}
            end
            all_items_lookup[quality][stack.name] = stack.count
        end
    end
    local input_coin = coin_tiers.normalized(coin_tiers.new(input_coin_values))
    return input_coin, all_items_lookup
end

---Process all trades from one inventory to another.
---@param surface_name string
---@param input_inv LuaInventory
---@param output_inv LuaInventory
---@param trade_ids {[int]: int}
---@param quality_cost_multipliers {[string]: number} | nil
---@param max_items_per_output int | nil
---@return {[string]: int}, {[string]: int}, {[string]: int}
function trades.process_trades_in_inventories(surface_name, input_inv, output_inv, trade_ids, quality_cost_multipliers, max_items_per_output)
    -- Check if trades can occur
    local total_items = input_inv.get_item_count()
    if total_items == 0 then return {}, {}, {} end

    quality_cost_multipliers = quality_cost_multipliers or {}

    local input_coin, all_items_lookup = trades.get_coins_and_items_of_inventory(input_inv)

    local _total_removed = {}
    local _total_inserted = {}
    local _remaining_to_insert = {}
    for _, trade_id in pairs(trade_ids) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            for _, quality in pairs(trade.allowed_qualities or {"normal"}) do
                local quality_cost_mult = quality_cost_multipliers[quality] or 1
                local num_batches = trades.get_num_batches_for_trade(all_items_lookup, input_coin, trade, quality, quality_cost_mult, max_items_per_output)
                if num_batches > 0 then
                    local total_removed, total_inserted, remaining_to_insert, remaining_coin = trades.trade_items(input_inv, output_inv, trade, num_batches, quality, quality_cost_mult, all_items_lookup, input_coin)
                    input_coin = remaining_coin
                    if not _total_removed[quality] then _total_removed[quality] = {} end
                    for item_name, amount in pairs(total_removed[quality] or {}) do
                        _total_removed[quality][item_name] = (_total_removed[quality][item_name] or 0) + amount
                    end
                    if not _total_inserted[quality] then _total_inserted[quality] = {} end
                    for item_name, amount in pairs(total_inserted[quality] or {}) do
                        _total_inserted[quality][item_name] = (_total_inserted[quality][item_name] or 0) + amount
                    end
                    if not _remaining_to_insert[quality] then _remaining_to_insert[quality] = {} end
                    for item_name, amount in pairs(remaining_to_insert[quality] or {}) do
                        _remaining_to_insert[quality][item_name] = (_remaining_to_insert[quality][item_name] or 0) + amount
                    end
                end
            end
        end
    end

    trades._postprocess_items_traded(surface_name, _total_removed, "sold")
    trades._postprocess_items_traded(surface_name, _total_inserted, "bought")
    return _total_removed, _total_inserted, _remaining_to_insert
end

function trades._postprocess_items_traded(surface_name, total_traded, trade_type)
    local process_again = {}
    for quality, item_names in pairs(total_traded) do
        local tier = lib.get_quality_tier(quality)
        if tier >= 3 and trade_type == "sold" then
            -- The loop below can be removed or optimized if item names are tracked separately for this rank-up condition check.
            for item_name, count in pairs(item_names) do
                local rank = item_ranks.get_item_rank(item_name)
                if rank == 2 then
                    -- A bronze rank item was sold at rare+ quality.
                    item_ranks.rank_up(item_name)
                    if not process_again[quality] then
                        process_again[quality] = {}
                    end
                    process_again[quality][item_name] = count
                end
            end
        elseif tier >= 4 then -- can be trade type can be either
            -- The loop below can be removed or optimized if item names are tracked separately for this rank-up condition check.
            for item_name, _ in pairs(item_names) do
                if not item_values.has_item_value(surface_name, item_name) then
                    local rank = item_ranks.get_item_rank(item_name)
                    if rank == 3 then
                        -- A silver rank item was sold at epic+ quality on a planet where it cannot be naturally produced.
                        item_ranks.rank_up(item_name)
                    end
                end
            end
        end
    end
    if next(process_again) then
        trades._postprocess_items_traded(surface_name, process_again, "sold")
        trades._postprocess_items_traded(surface_name, process_again, "bought")
    end
end



return trades
