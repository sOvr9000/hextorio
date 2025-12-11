local event_system = require "api.event_system"

local train_trading = {}



---@class TrainTradingStorage



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
end

function train_trading.init()
    ---@type TrainTradingStorage
    storage.train_trading = {}
end

---@param train LuaTrain
---@param train_stop LuaEntity
function train_trading.on_train_arrived_at_stop(train, train_stop)
    event_system.trigger("train-arrived-at-stop", train, train_stop)
end

-- ---@param train LuaTrain
-- ---@param total_items_inserted QualityItemCounts
-- ---@param total_items_removed QualityItemCounts
-- ---@param total_coins_inserted Coin
-- ---@param total_coins_removed Coin
-- function train_trading.on_train_traded_items(train, total_items_inserted, total_items_removed, total_coins_inserted, total_coins_removed)

-- end



return train_trading
