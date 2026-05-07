
local lib               = require "api.lib"
local coin_tiers        = require "api.coin_tiers"
local trades            = require "api.trades"
local event_system      = require "api.event_system"
local spider_control    = require "api.spider_control"
local inventories       = require "api.inventories"

local spider_network = {}



---@alias TradertronMode "ranking"|"trading"
---@alias TradertronState "idle"|"pickup"|"dropoff"

---@class DeliveryRoute
---@field pickup_hex_pos HexPos Hex to pick up items/coins from.
---@field dropoff_hex_pos HexPos Hex to deliver items/coins to.
---@field trade_id int The trade being serviced by this delivery.
---@field items QualityItemCounts|nil Items committed to this delivery.
---@field coins Coin|nil Coins committed to this delivery.

---@class SpiderNetworkStorage
---@field spiders {[int]: {[int]: Tradertron}} Mapping for each surface ID of entity unit numbers to the Tradertron that is associated to that entity
---@field trade_ids_in_ranking_progress {[int]: int} Mapping of trade IDs to spider unit numbers currently ranking up items with that trade.

---@class Tradertron
---@field unit SpiderControlUnit
---@field mode TradertronMode
---@field current_state TradertronState
---@field route DeliveryRoute|nil Current delivery route, or nil if idle.



function spider_network.register_events()
    event_system.register("entity-becoming-invalid", spider_network.on_entity_becoming_invalid)
    event_system.register("active-hex-state-processed", spider_network.on_active_hex_state_processed)
    event_system.register("spider-reached-hex-state", spider_network.on_spider_reached_hex_state)

    event_system.register("player-built-entity", function(player, entity)
        spider_network.register_spider(entity)
    end)
end

---@return SpiderNetworkStorage
function spider_network._get_spider_network_storage()
    local sn_storage = storage.spider_network
    if not sn_storage then
        sn_storage = {}
        storage.spider_network = sn_storage
    end

    if not sn_storage.spiders then
        sn_storage.spiders = {}
    end

    return sn_storage
end

---@param surface_index int
---@return {[int]: Tradertron}
function spider_network.get_spider_storage_on_surface(surface_index)
    local sn_storage = spider_network._get_spider_network_storage()
    local spiders = sn_storage.spiders[surface_index]
    if not spiders then
        spiders = {}
        sn_storage.spiders[surface_index] = spiders
    end
    return spiders
end

---Register a SpiderVehicle type of entity to the spider network.
---@param entity LuaEntity
---@return Tradertron|nil
function spider_network.register_spider(entity)
    if not entity or not entity.valid then return end

    local unit = spider_control.register_spider(entity, true)
    if not unit then return end

    ---@type Tradertron
    local tradertron = {
        unit = unit,
        mode = "trading",
        current_state = "idle",
    }

    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    spiders[entity.unit_number] = tradertron

    return tradertron
end

---Unregister a Tradertron from the spider network.
---@param tradertron Tradertron
function spider_network.unregister_spider(tradertron)
    spider_network.clear_route(tradertron)

    local unit = tradertron.unit
    if not unit then return end

    local entity = unit.entity
    if not entity or not entity.valid then return end

    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    spiders[entity.unit_number] = nil
end

---@param state HexState
function spider_network.register_hex_state(state)
    if not state.claimed or not state.hex_core or not state.hex_core.valid then return end
    state.is_in_spider_network = true
end

---@param state HexState
function spider_network.unregister_hex_state(state)
    state.is_in_spider_network = nil
end

---Get a Tradertron from a SpiderVehicle entity if it's registered.
---@param entity LuaEntity
---@return Tradertron|nil
function spider_network.get_tradertron_from_entity(entity)
    if not entity or not entity.valid or entity.type ~= "spider-vehicle" then return end
    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    return spiders[entity.unit_number]
end

---@param state HexState
---@return boolean
function spider_network.is_hex_state_in_network(state)
    return state.is_in_spider_network == true
end

---Clear a Tradertron's current delivery route and set it to idle.
---@param tradertron Tradertron
function spider_network.clear_route(tradertron)
    tradertron.route = nil
    tradertron.current_state = "idle"
end

---Return the first idle, unrouted Tradertron from the given spiders table, or nil if none exists.
---@param spiders {[int]: Tradertron}
---@return Tradertron|nil
function spider_network.select_next_idle_spider(spiders)
    for _, tradertron in pairs(spiders) do
        if tradertron.current_state == "idle" and not tradertron.route then
            return tradertron
        end
    end
end

---Match items and coins available in a hex's output inventory to trades in the network that need them, dispatching idle spiders on delivery routes for each viable match.
---@param state HexState
---@param inv_coins Coin
---@param inv_items QualityItemCounts
function spider_network._process_available_deliveries(state, inv_coins, inv_items)
    local spiders = spider_network.get_spider_storage_on_surface(state.hex_core.surface_index)

    -- Item delivery: match available items to trade input needs.
    for quality, quality_items in pairs(inv_items) do
        for item_name, available in pairs(quality_items) do
            if available > 0 then
                local remaining = available
                for trade_id, _ in pairs(trades.get_trades_by_input(item_name)) do
                    if remaining <= 0 then break end
                    local trade = trades.get_trade_from_id(trade_id)
                    if trade and trade.active then
                        local input_count = trades.get_input_count(trade, item_name)
                        if input_count > 0 then
                            local deliver_amount = math.min(remaining, input_count)
                            local route_items = {[quality] = {[item_name] = deliver_amount}}
                            if spider_network._try_dispatch(spiders, state, trade_id, route_items, nil) then
                                remaining = remaining - deliver_amount
                                quality_items[item_name] = remaining
                            end
                        end
                    end
                end
            end
        end
    end

    -- Coin delivery: match available coins to trade coin-input needs.
    if not coin_tiers.is_zero(inv_coins) then
        for tier = 1, inv_coins.max_coin_tier do
            local tier_amount = math.floor(inv_coins.values[tier])
            if tier_amount > 0 then
                local coin_name = coin_tiers.get_name_of_tier(tier)
                for trade_id, _ in pairs(trades.get_trades_by_input(coin_name)) do
                    if tier_amount <= 0 then break end
                    local trade = trades.get_trade_from_id(trade_id)
                    if trade and trade.active then
                        local input_count = trades.get_input_count(trade, coin_name)
                        if input_count > 0 then
                            local deliver_amount = math.min(tier_amount, input_count)
                            local coin_values = coin_tiers.new_coin_values()
                            coin_values[tier] = deliver_amount
                            if spider_network._try_dispatch(spiders, state, trade_id, nil, coin_tiers.new(coin_values)) then
                                tier_amount = tier_amount - deliver_amount
                                inv_coins.values[tier] = tier_amount
                            end
                        end
                    end
                end
            end
        end
    end
end

---@param spiders {[int]: Tradertron}
---@param source_hex_state HexState
---@param trade_id int
---@param route_items QualityItemCounts|nil
---@param route_coins Coin|nil
---@return boolean
function spider_network._try_dispatch(spiders, source_hex_state, trade_id, route_items, route_coins)
    local trade = trades.get_trade_from_id(trade_id)
    if not trade or not trade.active or not trade.hex_core_state then return false end
    if not spider_network.is_hex_state_in_network(trade.hex_core_state) then return false end
    if trade.hex_core_state == source_hex_state then return false end

    local idle = spider_network.select_next_idle_spider(spiders)
    if not idle then return false end

    local route = {
        pickup_hex_pos = source_hex_state.position,
        dropoff_hex_pos = trade.hex_core_state.position,
        trade_id = trade_id,
        items = route_items,
        coins = route_coins,
    }

    idle.route = route
    idle.current_state = "pickup"
    spider_control.enqueue_pathfind_hex_move(idle.unit, route.pickup_hex_pos)

    return true
end

---Transfer a coin amount from a hex inventory to a spider entity's trunk, returning the actual coins moved.
---@param from_inv LuaInventory
---@param to_entity LuaEntity
---@param coin Coin
---@return Coin actual
function spider_network._transfer_coins_to_spider(from_inv, to_entity, coin)
    local actual_values = coin_tiers.new_coin_values()
    for tier = 1, coin.max_coin_tier do
        local amount = math.floor(coin.values[tier])
        if amount > 0 then
            local coin_name = coin_tiers.get_name_of_tier(tier)
            local inserted = to_entity.insert {name = coin_name, count = amount}
            if inserted > 0 then
                from_inv.remove {name = coin_name, count = inserted}
                actual_values[tier] = inserted
            end
        end
    end
    return coin_tiers.new(actual_values)
end

---Deposit all items from a spider entity's trunk inventory into a target inventory.
---@param from_entity LuaEntity
---@param to_inv LuaInventory
function spider_network._transfer_spider_trunk_to_inventory(from_entity, to_inv)
    local spider_inv = from_entity.get_inventory(defines.inventory.spider_trunk)
    if not spider_inv then return end
    for _, stack in pairs(spider_inv.get_contents()) do
        local inserted = to_inv.insert {name = stack.name, count = stack.count, quality = stack.quality}
        if inserted > 0 then
            spider_inv.remove {name = stack.name, count = inserted, quality = stack.quality}
        end
    end
end

---Pick up items/coins from the route's source hex and transition the spider to dropoff state.
---@param tradertron Tradertron
---@param state HexState
function spider_network._handle_pickup(tradertron, state)
    local route = tradertron.route
    if not route then
        tradertron.current_state = "idle"
        return
    end

    if state.position.q ~= route.pickup_hex_pos.q or state.position.r ~= route.pickup_hex_pos.r then
        spider_network.clear_route(tradertron)
        return
    end

    local entity = tradertron.unit.entity
    if not entity or not entity.valid then return end

    local inv = state.hex_core_output_inventory
    if inv and inv.valid then
        if route.items then
            for quality, quality_items in pairs(route.items) do
                for item_name, amount in pairs(quality_items) do
                    local actual = entity.insert {name = item_name, count = amount, quality = quality}
                    if actual > 0 then
                        inv.remove {name = item_name, count = actual, quality = quality}
                    end
                end
            end
        end

        if route.coins and not coin_tiers.is_zero(route.coins) then
            spider_network._transfer_coins_to_spider(inv, entity, route.coins)
        end
    end

    tradertron.current_state = "dropoff"
    spider_control.enqueue_pathfind_hex_move(tradertron.unit, route.dropoff_hex_pos)
end

---Deposit all carried items/coins into the route's target hex input inventory and return to idle.
---@param tradertron Tradertron
---@param state HexState
function spider_network._handle_dropoff(tradertron, state)
    local route = tradertron.route
    if not route then
        tradertron.current_state = "idle"
        return
    end

    if not state.trades then
        spider_network.clear_route(tradertron)
        return
    end

    local has_trade = false
    for _, tid in ipairs(state.trades) do
        if tid == route.trade_id then
            has_trade = true
            break
        end
    end

    if not has_trade then
        spider_network.clear_route(tradertron)
        return
    end

    local inv = state.hex_core_input_inventory
    if not inv or not inv.valid then return end

    local entity = tradertron.unit.entity
    if not entity or not entity.valid then return end

    spider_network._transfer_spider_trunk_to_inventory(entity, inv)
    spider_network.clear_route(tradertron)
end

---@param state HexState
function spider_network.on_active_hex_state_processed(state)
    if not spider_network.is_hex_state_in_network(state) then return end
    if not state.hex_core or not state.hex_core.valid then return end

    local output_inventory = state.hex_core_output_inventory
    if not output_inventory or not output_inventory.valid then return end

    local inv_coins, inv_items = inventories.get_coins_and_items_of_inventory(output_inventory)
    spider_network._process_available_deliveries(state, inv_coins, inv_items)
end

---@param entity LuaEntity
---@param state HexState
function spider_network.on_spider_reached_hex_state(entity, state)
    if entity.autopilot_destination then return end

    local tradertron = spider_network.get_tradertron_from_entity(entity)
    if not tradertron then return end

    local cur_state = tradertron.current_state
    if cur_state == "pickup" then
        spider_network._handle_pickup(tradertron, state)
    elseif cur_state == "dropoff" then
        spider_network._handle_dropoff(tradertron, state)
    end
end

---@param entity LuaEntity
function spider_network.on_entity_becoming_invalid(entity)
    if not entity.valid then return end
    if entity.type ~= "spider-vehicle" then return end

    local tradertron = spider_network.get_tradertron_from_entity(entity)
    if not tradertron then return end

    spider_network.unregister_spider(tradertron)
end



return spider_network
