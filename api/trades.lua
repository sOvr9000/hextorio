
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
        for surface_id, _ in pairs(game.surfaces) do
            local surface = game.get_surface(surface_id)
            if surface and surface.name ~= "space-platform" and surface.name ~= "hextorio-temp" then
                local items_sorted_by_value = item_values.get_items_sorted_by_value(player.surface.name, true)
                for _, item_name in pairs(items_sorted_by_value) do
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
function trades.get_input_value(surface_name, trade)
    local input_value = 0
    for _, input_item in pairs(trade.input_items) do
        input_value = input_value + item_values.get_item_value(surface_name, input_item.name) * input_item.count
    end
    return input_value
end

-- Return the value of the trade's outputs
function trades.get_output_value(surface_name, trade)
    local output_value = 0
    for _, output_item in pairs(trade.output_items) do
        output_value = output_value + item_values.get_item_value(surface_name, output_item.name) * output_item.count
    end
    return output_value
end

function trades.get_volume_of_trade(surface_name, trade)
    return (trades.get_input_value(surface_name, trade) + trades.get_output_value(surface_name, trade)) * 0.5
end

-- Return the ratio of values of the trade's outputs to its inputs
function trades.get_trade_value_ratio(surface_name, trade)
    return trades.get_output_value(surface_name, trade) / trades.get_input_value(surface_name, trade)
end

function trades.get_total_values_str(trade)
    local coin_value = item_values.get_item_value("nauvis", "hex-coin")
    local total_input_value = trades.get_input_value(trade.surface_name, trade) / coin_value
    local total_output_value = trades.get_output_value(trade.surface_name, trade) / coin_value
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

function trades.get_input_coins_from_inventory_trade(inventory, trade)
    local inventory_coin, trade_coin
    for _, input_item in pairs(trade.input_items) do
        if lib.is_coin(input_item.name) then
            inventory_coin = coin_tiers.get_coin_from_inventory(inventory)
            local coins = {["hex-coin"] = 0, ["gravity-coin"] = 0, ["meteor-coin"] = 0, ["hexaprism-coin"] = 0}
            for _, _input_item in pairs(trade.input_items) do
                if lib.is_coin(_input_item.name) then
                    coins[_input_item.name] = _input_item.count
                end
            end
            trade_coin = coin_tiers.new(coins)
            break
        end
    end

    return inventory_coin, trade_coin
end

function trades.get_output_coins_from_inventory_trade(inventory, trade)
    local inventory_coin, trade_coin
    for _, output_item in pairs(trade.output_items) do
        if lib.is_coin(output_item.name) then
            inventory_coin = coin_tiers.get_coin_from_inventory(inventory)
            local coins = {["hex-coin"] = 0, ["gravity-coin"] = 0, ["meteor-coin"] = 0, ["hexaprism-coin"] = 0}
            for _, _output_item in pairs(trade.output_items) do
                if lib.is_coin(_output_item.name) then
                    coins[_output_item.name] = _output_item.count
                end
            end
            trade_coin = coin_tiers.new(coins)
            break
        end
    end

    return inventory_coin, trade_coin
end

-- Check whether a trade can occur at least once within an inventory
function trades.can_trade_items(inventory, trade)
    if not trade.active then return false end

    for _, input_item in pairs(trade.input_items) do
        if not lib.is_coin(input_item.name) then
            local count = inventory.get_item_count(input_item.name)
            if count < input_item.count then
                return false
            end
        end
    end

    local inventory_coin, trade_coin = trades.get_input_coins_from_inventory_trade(inventory, trade)
    if inventory_coin and trade_coin then
        if coin_tiers.lt(inventory_coin, trade_coin) then
            return false
        end
    end

    return true
end

-- Check how many batches of (how many times) a trade can occur within an inventory
function trades.get_num_batches_for_trade(input_inventory, output_inventory, trade)
    if not trade.active then return 0 end

    local num_batches = math.huge
    for _, input_item in pairs(trade.input_items) do
        if not lib.is_coin(input_item.name) then
            local count = input_inventory.get_item_count(input_item.name)
            local num = math.floor(count / input_item.count)
            num_batches = math.min(num, num_batches)
        end
    end

    local inventory_coin, trade_coin = trades.get_input_coins_from_inventory_trade(input_inventory, trade)
    if inventory_coin and trade_coin then
        num_batches = math.min(math.floor(coin_tiers.divide_coins(inventory_coin, trade_coin)), num_batches)
    end

    -- Further limit num batches by available space in output inventory, accounting for potentially high productivity
    local prod = trades.get_productivity(trade)
    for _, output_item in pairs(trade.output_items) do
        if not lib.is_coin(output_item.name) then
            local count = output_inventory.get_insertable_count(output_item.name)
            local num = math.floor(count / (3 * output_item.count * (1 + prod))) -- divide by 3 to overestimate the needed room for other output items
            num_batches = math.min(num, num_batches)
        end
    end

    return num_batches
end

-- Trade items within an inventory
function trades.trade_items(inventory_input, inventory_output, trade, num_batches)
    if not trade.active then return {}, {} end
    if num_batches <= 0 then return {}, {} end

    local total_removed = {}
    for _, input_item in pairs(trade.input_items) do
        if not lib.is_coin(input_item.name) then
            local to_remove = math.min(input_item.count * num_batches, inventory_input.get_item_count(input_item.name))
            inventory_input.remove {name = input_item.name, count = to_remove}
            total_removed[input_item.name] = (total_removed[input_item.name] or 0) + to_remove
            trades.increment_total_sold(input_item.name, to_remove)
        end
    end

    local _, trade_coin = trades.get_input_coins_from_inventory_trade(inventory_input, trade)
    if trade_coin then
        coin_tiers.remove_coin_from_inventory(inventory_input, coin_tiers.multiply(trade_coin, num_batches))
    end

    local total_inserted = {}
    _, trade_coin = trades.get_output_coins_from_inventory_trade(inventory_input, trade)
    local function insert_output(_num_batches)
        for _, output_item in pairs(trade.output_items) do
            if not lib.is_coin(output_item.name) then
                local to_insert = output_item.count * _num_batches
                inventory_output.insert {name = output_item.name, count = to_insert}
                total_inserted[output_item.name] = (total_inserted[output_item.name] or 0) + to_insert
                trades.increment_total_bought(output_item.name, to_insert)
            end
        end

        if trade_coin then
            coin_tiers.add_coin_to_inventory(inventory_input, coin_tiers.multiply(trade_coin, _num_batches))
        end
    end

    local total_output_batches = num_batches + trades.increment_current_prod_value(trade, num_batches)
    insert_output(total_output_batches)

    event_system.trigger("trade-processed", trade)

    return total_removed, total_inserted
end

function trades.random_trade_item_names(surface_name, volume, params)
    if not params then params = {} end
    local possible_items = item_values.get_items_near_value(surface_name, volume, 10, true, false)

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
    local input_item_names, output_item_names = trades.random_trade_item_names(surface_name, volume)

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
    -- lib.log(serpent.block(all_items))
    for _, input in pairs(all_items) do
        if type(input) ~= "table" then return false end
        if not input.name then return false end
        if type(input.name) ~= "string" then return false end
        if not input.count then return false end
        if type(input.count) ~= "number" then return false end
        if input.count <= 0 then return false end
        if not item_values.has_item_value(trade.surface_name, input.name) then return false end
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
    local random_volume = volume * (3 + 7 * math.random())
    return random_volume
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
        table.insert(storage.trades.tree.by_input[input.name], trade.id)
    end
    for _, output in pairs(trade.output_items) do
        if not storage.trades.tree.by_output[output.name] then
            storage.trades.tree.by_output[output.name] = {}
        end
        table.insert(storage.trades.tree.by_output[output.name], trade.id)
    end
    storage.trades.tree.all_trades_lookup[trade.id] = trade
end

function trades.remove_trade_from_tree(trade)
    if not trade then
        lib.log_error("trades.remove_trade_from_tree: trade is nil")
        return
    end
    trades._check_tree_existence()
    -- TODO: These subtrees should probably also index by trade object so that looping can be avoided; it's a potential optimization for the future
    for _, input in pairs(trade.input_items) do
        if storage.trades.tree.by_input[input.name] then
            local _trades = storage.trades.tree.by_input[input.name]
            for i = #_trades, 1, -1 do
                if _trades[i] == trade.id then
                    table.remove(_trades, i)
                end
            end
        end
    end
    for _, output in pairs(trade.output_items) do
        if storage.trades.tree.by_output[output.name] then
            local _trades = storage.trades.tree.by_output[output.name]
            for i = #_trades, 1, -1 do
                if _trades[i] == trade.id then
                    table.remove(_trades, i)
                end
            end
        end
    end
    storage.trades.tree.all_trades_lookup[trade.id] = nil
end

function trades.get_trades_by_input(item_name)
    if not item_name then
        lib.log_error("trades.get_trades_by_input: item_name is nil")
        return {}
    end
    trades._check_tree_existence()
    return storage.trades.tree.by_input[item_name] or {}
end

function trades.get_trades_by_output(item_name)
    if not item_name then
        lib.log_error("trades.get_trades_by_output: item_name is nil")
        return {}
    end
    trades._check_tree_existence()
    return storage.trades.tree.by_output[item_name] or {}
end

function trades.get_trades_lookup()
    trades._check_tree_existence()
    return storage.trades.tree.all_trades_lookup
end

function trades.get_all_trades()
    local all_trades = {}
    for _, trade in pairs(trades.get_trades_lookup()) do
        table.insert(all_trades, trade)
    end
    return all_trades
end

function trades.get_trades_from_ids(trade_id_list)
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

function trades.get_coin_name_for_trade_volume(trade_volume)
    if type(trade_volume) == "number" then
        if trade_volume < 10000000000 then -- use hex coin up to 10000x gravity coin's worth of hex coins
            return "hex-coin"
        elseif trade_volume < 1000000000000000 then -- use hex coin up to 10000x meteor coin's worth of gravity coins
            return "gravity-coin"
        elseif trade_volume < 100000000000000000000 then -- use hex coin up to 10000x heaxaprism coin's worth of gravity coins
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

function trades.get_item_names_from_trade(trade)
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



return trades
