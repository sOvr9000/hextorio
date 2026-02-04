local event_system  = require "api.event_system"
local lib           = require "api.lib"
local quests        = require("api.quests")
local hex_grid = require("api.hex_grid")
local train_trading = {}



---@class TrainTradingStorage
---@field allow_two_headed_trains boolean Whether to allow or disallow two-headed trains in trading.



function train_trading.register_events()
    script.on_event(defines.events.on_train_changed_state, function(event)
        local train = event.train
        local train_stop = train.station
        if not train_stop or not train_stop.valid then return end

        local old_state = event.old_state
        local new_state = train.state

        if old_state == defines.train_state.arrive_station and new_state == defines.train_state.wait_station then
            train_trading.on_train_arrived_at_stop(train, train_stop)
        end
    end)

    -- event_system.register("train-traded-items", train_trading.on_train_traded_items)

    event_system.register("runtime-setting-changed-allow-two-headed-trains", function()
        storage.train_trading.allow_two_headed_trains = lib.runtime_setting_value_as_boolean "allow-two-headed-trains"
    end)
end

function train_trading.init()
    ---@type TrainTradingStorage
    storage.train_trading = {
        allow_two_headed_trains = lib.runtime_setting_value_as_boolean "allow-two-headed-trains"
    }
end

---@param train LuaTrain
---@param train_stop LuaEntity
function train_trading.on_train_arrived_at_stop(train, train_stop)
    if not storage.train_trading.allow_two_headed_trains and lib.is_train_two_headed(train) then return end
    if not quests.is_feature_unlocked "locomotive-trading" then return end

    local state = hex_grid.get_closest_hex_state(train_stop.position, train_stop.surface)
    if not state then return end
    if not state.allow_locomotive_trading then return end

    local inventory_output
    if state.send_outputs_to_cargo_wagons then
        inventory_output = train
    else
        inventory_output = state.hex_core_output_inventory
    end

    hex_grid.process_hex_core_trades(state, train, inventory_output, train_stop)
end

-- ---@param train LuaTrain
-- ---@param total_items_inserted QualityItemCounts
-- ---@param total_items_removed QualityItemCounts
-- ---@param total_coins_inserted Coin
-- ---@param total_coins_removed Coin
-- function train_trading.on_train_traded_items(train, total_items_inserted, total_items_removed, total_coins_inserted, total_coins_removed)

-- end



return train_trading
