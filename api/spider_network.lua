
local lib               = require "api.lib"
local coin_tiers        = require "api.coin_tiers"
local trades            = require "api.trades"
local event_system      = require "api.event_system"
local spider_control    = require "api.spider_control"
local inventories       = require "api.inventories"
local axial             = require "api.axial"
local hex_state_manager = require "api.hex_state_manager"

local spider_network = {}



local MAX_ORDER_LIFETIME = 3600 -- one minute



---@alias TradertronMode "ranking"|"trading"
---@alias SpiderNetworkOrderType "pickup"|"dropoff"
---@alias SpiderNetworkOrder PickupOrder|DropoffOrder

---@class SpiderNetworkStorage
---@field spiders {[int]: {[int]: Tradertron}} Mapping for each surface ID of entity unit numbers to the Tradertron that is associated to that entity
---@field spider_list LuaEntity[] List of entities that are Tradertrons.
---@field trade_ids_in_ranking_progress {[int]: int} Mapping of trade IDs to spider unit numbers currently ranking up items with that trade.
---@field orders_iterated_per_tick int
---@field cur_spider_list_idx int
---@field cur_order_idx int
---@field best_dispatch SpiderDispatch|nil
---@field orders SpiderNetworkOrder[]

---@class PickupOrder
---@field type SpiderNetworkOrderType
---@field tick_created int
---@field surface_index int
---@field hex_pos HexPos
---@field map_position MapPosition
---@field items QualityItemCounts|nil
---@field coin Coin|nil
---@field priority number

---@class DropoffOrder
---@field type SpiderNetworkOrderType
---@field tick_created int
---@field surface_index int
---@field hex_pos HexPos
---@field map_position MapPosition
---@field all_items boolean|nil If true, drop off entire inventory instead of specified amounts.
---@field items QualityItemCounts|nil
---@field coin Coin|nil
---@field priority number

---@class SpiderDispatch
---@field tradertron Tradertron
---@field order SpiderNetworkOrder
---@field score number

---@class Tradertron
---@field unit SpiderControlUnit
---@field mode TradertronMode
---@field order SpiderNetworkOrder|nil Current order to complete
---@field best_score number|nil
---@field best_order SpiderNetworkOrder|nil
---@field best_order_idx int|nil



function spider_network.register_events()
    event_system.register("entity-becoming-invalid", spider_network.on_entity_becoming_invalid)
    event_system.register("active-hex-state-processed", spider_network.on_active_hex_state_processed)
    event_system.register("spider-reached-hex-state", spider_network.on_spider_reached_hex_state)
    event_system.register("player-entered-spider-control-vehicle", spider_network.on_player_entered_spider_control_vehicle)
    event_system.register("player-commanded-spiders", spider_network.on_player_commanded_spiders)

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

    if not sn_storage.spider_list then
        sn_storage.spider_list = {}
    end

    if not sn_storage.orders then
        sn_storage.orders = {}
    end

    if not sn_storage.trade_ids_in_ranking_progress then
        sn_storage.trade_ids_in_ranking_progress = {}
    end

    if not sn_storage.orders_iterated_per_tick then
        sn_storage.orders_iterated_per_tick = 24 -- TODO: make this a runtime setting
    end

    if not sn_storage.cur_spider_list_idx then
        sn_storage.cur_spider_list_idx = 0
    end

    if not sn_storage.cur_order_idx then
        sn_storage.cur_order_idx = 0
    end

    return sn_storage
end

function spider_network._process_spiders()
    local sn_storage = spider_network._get_spider_network_storage()
    local spider_list = sn_storage.spider_list
    local orders = sn_storage.orders
    if #orders == 0 then return end

    local num_spiders = #spider_list
    if num_spiders == 0 then return end

    local orders_iterated_per_tick = sn_storage.orders_iterated_per_tick
    local cur_spider_list_idx = sn_storage.cur_spider_list_idx
    local cur_order_idx = sn_storage.cur_order_idx

    local cur_order, cur_tradertron

    for _ = 1, orders_iterated_per_tick do
        -- Orders may be removed during this loop, so recount each time.
        local num_orders = #orders

        if num_orders == 0 then
            cur_order_idx = 0
        else
            cur_order_idx = 1 + cur_order_idx % num_orders
        end

        if cur_order_idx == 1 then
            if num_spiders == 0 then
                cur_spider_list_idx = 0
            else
                cur_spider_list_idx = 1 + cur_spider_list_idx % num_spiders
            end

            -- Orders have been fully iterated for previous tradertron
            if cur_tradertron then
                local best_dispatch = sn_storage.best_dispatch
                local best_score = cur_tradertron.best_score
                local order = cur_tradertron.best_order
                if best_score and order and (not best_dispatch or best_score > best_dispatch.score) then
                    sn_storage.best_dispatch = {
                        tradertron = cur_tradertron,
                        order = order,
                        score = best_score,
                    }
                end

                -- Start iteration for next tradertron
                spider_network._clear_order_tracking(cur_tradertron)
                cur_tradertron = nil
            end
        end

        if not cur_tradertron then
            cur_tradertron = spider_network.get_tradertron_from_entity(spider_list[cur_spider_list_idx])
        end

        cur_order = orders[cur_order_idx]
        if cur_order and cur_tradertron and not cur_tradertron.order then
            local popped = spider_network._process_order_for_spider(cur_tradertron, cur_order, cur_order_idx)
            if popped then
                -- The order was popped, so decrement the counter so that no orders get skipped.
                cur_order_idx = cur_order_idx - 1
            end
        end
    end

    sn_storage.cur_spider_list_idx = cur_spider_list_idx
    sn_storage.cur_order_idx = cur_order_idx

    local best_dispatch = sn_storage.best_dispatch
    if best_dispatch then
        spider_network.dispatch(best_dispatch)
        sn_storage.best_dispatch = nil
    end
end

---@param tradertron Tradertron
function spider_network._clear_order_tracking(tradertron)
    tradertron.best_score = nil
    tradertron.best_order = nil
    tradertron.best_order_idx = nil
end

---Dispatch a Tradertron.
---@param dispatch SpiderDispatch
function spider_network.dispatch(dispatch)
    local tradertron = dispatch.tradertron
    local order = dispatch.order

    tradertron.order = order
    spider_network._remove_order(order)
    spider_control.enqueue_pathfind_hex_move(tradertron.unit, order.hex_pos)
end

---@param tradertron Tradertron
---@param order SpiderNetworkOrder
---@param order_idx int
---@return boolean popped Whether the order was popped from the orders list.
function spider_network._process_order_for_spider(tradertron, order, order_idx)
    local score = spider_network.compute_tradertron_score_for_order(tradertron, order)
    if not score then return false end

    if order.tick_created + MAX_ORDER_LIFETIME < game.tick then
        local sn_storage = spider_network._get_spider_network_storage()
        table.remove(sn_storage.orders, order_idx)
        return true
    end

    local best_score = tradertron.best_score
    if best_score and score <= best_score then return false end

    tradertron.best_score = score
    tradertron.best_order_idx = order_idx
    tradertron.best_order = order

    return false
end

---Return how well-suited a Tradertron is for fulfilling some order.
---Returns nil when the order and tradertron are not on the same surface,
---or when the tradertron cannot fulfill any part of the order.
---
---Nil return is essentially a score of -math.huge with the implication that
---the tradertron should never attempt to fulfill this order.
---@param tradertron Tradertron
---@param order SpiderNetworkOrder
---@return number|nil
function spider_network.compute_tradertron_score_for_order(tradertron, order)
    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if not entity or not entity.valid or entity.surface_index ~= order.surface_index then return end

    local inv = entity.get_inventory(defines.inventory.spider_trunk)
    if not inv or not inv.valid then return end

    local matching_ratio
    if order.type == "pickup" then
        -- Heuristic: count number of empty slots, and check item stack sizes vs counts
        local num_empty_slots = inv.count_empty_stacks(false, false)
        if num_empty_slots == 0 then
            matching_ratio = 0
        else
            if order.items then
                local needed_slots = 0
                for _, counts in pairs(order.items) do
                    for item_name, count in pairs(counts) do
                        needed_slots = needed_slots + math.ceil(count / lib.get_stack_size(item_name))
                    end
                end
                matching_ratio = num_empty_slots / needed_slots
            else
                matching_ratio = 1 -- it's only coins, so heuristically assume for now that they can all fit in the spider inventory
            end
        end
    else
        -- Compute how many items the tradertron is holding that's needed by the order.
        local inv_coin, inv_items = inventories.get_coins_and_items_of_inventory(inv)
        if order.items then
            local matching_count = 0
            local total_item_count = 0

            for quality, counts in pairs(order.items) do
                local spider_counts = inv_items[quality]
                if spider_counts then
                    for item_name, count in pairs(counts) do
                        total_item_count = total_item_count + count
                        local spider_count = spider_counts[item_name]
                        if spider_count and spider_count > 0 then
                            matching_count = matching_count + math.min(spider_count, count)
                        end
                    end
                end
            end

            matching_ratio = matching_count / total_item_count
        end

        if order.coin then
            local inv_base_value = coin_tiers.to_base_value(inv_coin)
            local order_base_value = coin_tiers.to_base_value(order.coin)
            local ratio = math.min(1, inv_base_value / order_base_value)

            if matching_ratio then
                matching_ratio = (matching_ratio + ratio) * 0.5
            else
                matching_ratio = ratio
            end
        end

        if not matching_ratio then
            matching_ratio = 0
        end
    end

    if matching_ratio <= 0 then return end

    local age_factor = 0.01 * (game.tick - order.tick_created)
    local distance_factor = 0.001 * lib.square_distance(entity.position, order.map_position)

    return order.priority * matching_ratio * (1 + age_factor) / (1 + distance_factor)
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

    local unit = spider_control.register_spider(entity, false)
    if not unit then return end

    ---@type Tradertron
    local tradertron = {
        unit = unit,
        mode = "trading",
    }

    local sn_storage = spider_network._get_spider_network_storage()
    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    spiders[entity.unit_number] = tradertron
    sn_storage.spider_list[#sn_storage.spider_list+1] = entity

    return tradertron
end

---Unregister a Tradertron from the spider network.
---@param tradertron Tradertron
function spider_network.unregister_spider(tradertron)
    spider_network.clear_orders(tradertron, false)

    local unit = tradertron.unit
    if not unit then return end

    local entity = unit.entity
    if not entity or not entity.valid then return end

    local sn_storage = spider_network._get_spider_network_storage()
    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    spiders[entity.unit_number] = nil

    local idx = lib.table_index(sn_storage.spider_list, entity)
    if idx then
        table.remove(sn_storage.spider_list, idx)
    end
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
---@param entity LuaEntity|nil
---@return Tradertron|nil
function spider_network.get_tradertron_from_entity(entity)
    if not entity or not entity.valid or entity.type ~= "spider-vehicle" then return end
    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    return spiders[entity.unit_number]
end

---Get a SpiderVehicle entity from a Tradertron if its valid.
---@param tradertron Tradertron
---@return LuaEntity|nil
function spider_network.get_entity_from_tradertron(tradertron)
    local unit = tradertron.unit
    if not unit then return end

    local entity = unit.entity
    if not entity or not entity.valid or entity.type ~= "spider-vehicle" then return end

    return entity
end

---@param state HexState
---@return boolean
function spider_network.is_hex_state_in_network(state)
    return state.is_in_spider_network == true
end

---Clear a Tradertron's current orders, forcing it to come to a stop.
---@param tradertron Tradertron
---@param discard_order boolean Whether to discard the order from the spider.  If false, the order is sent back to the network.
function spider_network.clear_orders(tradertron, discard_order)
    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if entity and entity.valid then
        entity.autopilot_destination = nil
    end
    local order = tradertron.order
    if order then
        tradertron.order = nil
        if not discard_order then
            spider_network._add_order(order)
        end
    end
end

---@param order SpiderNetworkOrder
function spider_network._add_order(order)
    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.orders[#sn_storage.orders+1] = order
end

---@param order SpiderNetworkOrder
function spider_network._remove_order(order)
    local sn_storage = spider_network._get_spider_network_storage()

    local idx = lib.table_index(sn_storage.orders, order)
    if idx then
        log("removing order:\n" .. serpent.block(order) .. "\nfrom:\n" .. serpent.block(sn_storage.orders) .. "\nresult of removal:\n" .. serpent.block(sn_storage.orders))
        table.remove(sn_storage.orders, idx)
    else
        lib.log_error("spider_network._remove_order: Order not found in orders list: " .. serpent.line(order) .. "\n" .. serpent.block(sn_storage.orders))
    end
end

---Add a pickup order to the spider network.
---@param state HexState
---@param coin Coin|nil
---@param quality_item_counts QualityItemCounts|nil
---@param priority number|nil
function spider_network.create_pickup_order(state, coin, quality_item_counts, priority)
    if not coin and not quality_item_counts then return end
    if not spider_network.is_hex_state_in_network(state) then return end
    if not priority then priority = 1 end

    local hex_core = state.hex_core
    if not hex_core or not hex_core.valid then return end

    local order = {
        type = "pickup",
        tick_created = game.tick,
        surface_index = hex_core.surface_index,
        hex_pos = state.position,
        map_position = hex_core.position,
        items = quality_item_counts,
        coin = coin,
        priority = priority,
    }

    spider_network._add_order(order)
end

---Add a dropoff order to the spider network.
---@param state HexState
---@param coin Coin|nil
---@param quality_item_counts QualityItemCounts|nil
---@param all_items boolean|nil Whether to deposit all items from the spider's inventory on arrival.
---@param priority number|nil
function spider_network.create_dropoff_order(state, coin, quality_item_counts, all_items, priority)
    if not coin and not quality_item_counts then return end
    if not spider_network.is_hex_state_in_network(state) then return end
    if not priority then priority = 1 end
    if all_items == false then all_items = nil end

    local hex_core = state.hex_core
    if not hex_core or not hex_core.valid then return end

    -- Generally, all_items should be true for tradertrons in trading mode, and false/nil for tradertrons in ranking mode

    local order = {
        type = "dropoff",
        tick_created = game.tick,
        surface_index = hex_core.surface_index,
        hex_pos = state.position,
        map_position = hex_core.position,
        all_items = all_items,
        items = quality_item_counts,
        coin = coin,
        priority = priority,
    }

    spider_network._add_order(order)
end

---@param tradertron Tradertron
function spider_network.handle_order(tradertron)
    local order = tradertron.order
    if not order then return end
    if not order.coin and not order.items then return end

    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if not entity or not entity.valid then return end

    local hex_pos = order.hex_pos
    local state = hex_state_manager.get_hex_state(entity.surface_index, hex_pos)
    if not state or not state.claimed or not state.hex_core or not state.hex_core.valid then return end

    local hex_core_inv
    if order.type == "pickup" then
        hex_core_inv = state.hex_core_output_inventory
    else
        hex_core_inv = state.hex_core_input_inventory
    end
    if not hex_core_inv or not hex_core_inv.valid then return end

    local spider_inv = entity.get_inventory(defines.inventory.spider_trunk)
    if not spider_inv or not spider_inv.valid then return end

    if order.type == "pickup" then
        inventories.transfer_coins_and_items(hex_core_inv, nil, spider_inv, nil, order.coin, order.items)
    else
        local coin, items
        if order.all_items then
            coin, items = inventories.get_coins_and_items_of_inventory(spider_inv)
        else
            coin = order.coin
            items = order.items
        end
        inventories.transfer_coins_and_items(spider_inv, nil, hex_core_inv, nil, coin, items)
    end

    spider_network.clear_orders(tradertron, true)
end

---@param state HexState
function spider_network.on_active_hex_state_processed(state)
    if not spider_network.is_hex_state_in_network(state) then return end
    if not state.hex_core or not state.hex_core.valid then return end

    local output_inventory = state.hex_core_output_inventory
    if not output_inventory or not output_inventory.valid then return end

    local inv_coins, inv_items = inventories.get_coins_and_items_of_inventory(output_inventory)
    -- TODO
end

---@param entity LuaEntity
---@param state HexState
function spider_network.on_spider_reached_hex_state(entity, state)
    if entity.autopilot_destination then return end

    local tradertron = spider_network.get_tradertron_from_entity(entity)
    if not tradertron then return end

    local hex_pos = state.position
    if tradertron.order and axial.equals(tradertron.order.hex_pos, hex_pos) then
        spider_network.handle_order(tradertron)
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

---@param player LuaPlayer
---@param vehicle LuaEntity
function spider_network.on_player_entered_spider_control_vehicle(player, vehicle)
    local tradertron = spider_network.get_tradertron_from_entity(vehicle)
    if not tradertron then return end
    spider_network.unregister_spider(tradertron)
end

---@param player LuaPlayer
---@param spiders LuaEntity[]
function spider_network.on_player_commanded_spiders(player, spiders)
    for _, spider in pairs(spiders) do
        local tradertron = spider_network.get_tradertron_from_entity(spider)
        if not tradertron then return end
        spider_network.unregister_spider(tradertron)
    end
end



return spider_network
