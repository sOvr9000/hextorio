
local lib               = require "api.lib"
local coin_tiers        = require "api.coin_tiers"
local trades            = require "api.trades"
local event_system      = require "api.event_system"
local spider_control    = require "api.spider_control"
local inventories       = require "api.inventories"
local axial             = require "api.axial"
local hex_state_manager = require "api.hex_state_manager"
local hex_sets          = require "api.hex_sets"

local spider_network = {}



local MAX_ORDER_LIFETIME = 3600 -- one minute
local ORDER_GENERATOR_WORK_PER_TICK = 64
-- Rank 4 requires "trade recovery" which is too complex to source via spider network.
local RANK_UP_FILTER = {[2] = true, [3] = true, [5] = true}



---@alias TradertronMode "ranking"|"trading"
---@alias SpiderNetworkOrderType "pickup"|"dropoff"
---@alias SpiderNetworkOrder PickupOrder|DropoffOrder
---@alias OrderGeneratorState "accumulating"|"calculating"
---@alias OrderGeneratorPhase "snapshot-spiders"|"planning"
---@alias PickupPlanPhase "scanning"|"placing-orders"

---@class SpiderNetworkStorage
---@field enabled boolean Whether the spider network should do its processing.
---@field supported_entity_names StringSet
---@field spiders {[int]: {[int]: Tradertron}} Mapping for each surface ID of entity unit numbers to the Tradertron that is associated to that entity
---@field spider_list LuaEntity[] List of entities that are Tradertrons.
---@field orders_iterated_per_tick int
---@field cur_spider_list_idx int
---@field cur_order_idx int
---@field best_dispatch SpiderDispatch|nil
---@field orders SpiderNetworkOrder[]
---@field orders_set table Set of orders currently in the orders array, keyed by order reference for O(1) existence checks.
---@field order_generator OrderGenerator
---@field active_trade_deliveries {[int]: boolean} Set of trade IDs for which a dropoff order is currently pending or in flight. Prevents generating duplicate pickup+dropoff sets for the same trade.
---@field hex_positions_in_network {[int]: HexSet} Mapping of surface indices to hex positions currently in the spider network.

---@class OrderGenerator
---@field state OrderGeneratorState
---@field accumulation_started_at_cycle_boundary boolean Whether rank-up accumulation started at a hex-pool cycle boundary.
---@field trade_ids_that_rank_up {[int]: boolean} Set of trade IDs for which at least one item can rank up.
---@field calculation_trade_ids {[int]: boolean}|nil Frozen trade IDs being processed during the calculation state.
---@field calculation_trade_id_cursor int|nil Cursor for iterating calculation_trade_ids.
---@field calculation_phase OrderGeneratorPhase|nil Sub-state used while calculating.
---@field spider_scan_idx int|nil Cursor for rebuilding spider_items and spider_coins incrementally.
---@field active_pickup_plan PickupPlan|nil Active pickup planning job.
---@field spider_items {[string]: {[string]: {[string]: int}}} Items currently in any spider's inventory, surface name -> quality -> item name -> count. Rebuilt each cycle to prevent creating pickups for items already in transit.
---@field spider_coins {[string]: Coin} Coins currently in any spider's inventory, by surface name.

---@class PickupPlan
---@field trade_id int
---@field rank_ups int
---@field surface_index int
---@field destination_hex_pos HexPos
---@field quality string
---@field priority number
---@field phase PickupPlanPhase
---@field remaining_items {[string]: int}
---@field remaining_coin_base_value number
---@field pickup_hexes {[int]: {[int]: {items: {[string]: int}|nil, coin: Coin|nil}}}
---@field scan_q int|nil
---@field scan_r int|nil
---@field order_q int|nil
---@field order_r int|nil
---@field already_have_items QualityItemCounts|nil
---@field already_have_coins_bv number|nil
---@field placed_any_order boolean|nil

---@class PickupOrder
---@field type SpiderNetworkOrderType
---@field tick_created int
---@field surface_index int
---@field hex_pos HexPos
---@field map_position MapPosition
---@field items QualityItemCounts|nil
---@field coin Coin|nil
---@field priority number
---@field trade_id int|nil Trade this order is gathering for; used to cancel paired orders.

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
---@field trade_id int|nil Trade this order is delivering for; used to clear active_trade_deliveries on completion.

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
    event_system.register("spider-network-hex-state-processed", spider_network.on_spider_network_hex_state_processed)
    event_system.register("hex-pool-cycle-completed", spider_network.on_hex_pool_cycle_completed)
    event_system.register("spider-reached-hex-state", spider_network.on_spider_reached_hex_state)
    event_system.register("player-entered-spider-control-vehicle", spider_network.on_player_entered_spider_control_vehicle)
    event_system.register("player-commanded-spiders", spider_network.on_player_commanded_spiders)
    event_system.register("entity-built", spider_network.on_entity_built)
    event_system.register("trade-processed", spider_network.on_trade_processed)
    event_system.register("feature-unlocked", spider_network.on_feature_unlocked)
end

---@return SpiderNetworkStorage
function spider_network._get_spider_network_storage()
    local sn_storage = storage.spider_network
    if not sn_storage then
        sn_storage = {}
        storage.spider_network = sn_storage
    end

    if sn_storage.enabled == nil then
        sn_storage.enabled = false
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

    if not sn_storage.orders_set then
        sn_storage.orders_set = {}
        for _, order in pairs(sn_storage.orders) do
            sn_storage.orders_set[order] = true
        end
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

    if not sn_storage.order_generator then
        sn_storage.order_generator = {
            state = "accumulating",
            accumulation_started_at_cycle_boundary = false,
            trade_ids_that_rank_up = {},
        }
    end

    local gen = sn_storage.order_generator
    if not gen.state then gen.state = "accumulating" end
    if gen.accumulation_started_at_cycle_boundary == nil then
        gen.accumulation_started_at_cycle_boundary = false
    end
    if not gen.trade_ids_that_rank_up then gen.trade_ids_that_rank_up = {} end
    if not gen.spider_items then gen.spider_items = {} end
    if not gen.spider_coins then gen.spider_coins = {} end

    if not sn_storage.active_trade_deliveries then
        sn_storage.active_trade_deliveries = {}
    end

    if not sn_storage.hex_positions_in_network then
        sn_storage.hex_positions_in_network = {}
    end

    if not sn_storage.supported_entity_names then
        sn_storage.supported_entity_names = {
            ["sentient-spider"] = true,
        }
    end

    return sn_storage
end

---@param sn_storage SpiderNetworkStorage
---@param surface_index int
---@return HexSet
function spider_network._get_network_hex_set_on_surface(sn_storage, surface_index)
    local hex_set = sn_storage.hex_positions_in_network[surface_index]
    if not hex_set then
        hex_set = {}
        sn_storage.hex_positions_in_network[surface_index] = hex_set
    end
    return hex_set
end

---@param sn_storage SpiderNetworkStorage
---@param state HexState
function spider_network._add_network_hex_position(sn_storage, state)
    local hex_set = spider_network._get_network_hex_set_on_surface(sn_storage, state.surface_index)
    hex_sets.add(hex_set, state.position)
end

---@param sn_storage SpiderNetworkStorage
---@param state HexState
function spider_network._remove_network_hex_position(sn_storage, state)
    local hex_set = spider_network._get_network_hex_set_on_surface(sn_storage, state.surface_index)
    hex_sets.remove(hex_set, state.position)
end

---Return whether an entity of a certain name is able to be added to the spider network, e.g. "sentient-spider".
---@param entity_name string
---@return boolean
function spider_network.is_entity_name_supported(entity_name)
    local sn_storage = spider_network._get_spider_network_storage()
    return sn_storage.supported_entity_names[entity_name] == true
end

---Enable or disable the spider network processing.
---@param flag boolean
function spider_network.set_enabled(flag)
    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.enabled = flag
end

---Whether the spider network is currently enabled.
---@return boolean
function spider_network.is_enabled()
    local sn_storage = spider_network._get_spider_network_storage()
    return sn_storage.enabled
end

---Update per-hex pending order tracking when an order is added or removed.
---@param order SpiderNetworkOrder
---@param add boolean True to mark items as pending, false to clear them.
function spider_network._update_order_position_tracking(order, add)
    local items = order.items
    local coin = order.coin
    if not items and not coin then return end

    local state = hex_state_manager.get_hex_state(order.surface_index, order.hex_pos, false)
    if not state then return end

    local order_type = order.type
    local tracking = state.spider_network_pending_orders

    if add then
        if not tracking then
            tracking = {pickup = {}, dropoff = {}}
            state.spider_network_pending_orders = tracking
        end
        if not tracking[order_type] then
            tracking[order_type] = {}
        end
    else
        if not tracking then return end
    end

    local type_set = tracking[order_type]
    if not type_set then return end

    if items then
        for _, counts in pairs(items) do
            for item_name in pairs(counts) do
                type_set[item_name] = add or nil
            end
        end
    end
    if coin then
        type_set["__coin__"] = add or nil
    end

    if not add then
        local pickup = tracking.pickup
        local dropoff = tracking.dropoff
        if (not pickup or not next(pickup)) and (not dropoff or not next(dropoff)) then
            state.spider_network_pending_orders = nil
        end
    end
end

function spider_network._process_spiders()
    local sn_storage = spider_network._get_spider_network_storage()
    if not sn_storage.enabled then return end

    spider_network._process_order_generator(sn_storage)

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
                if best_score and order
                    and not cur_tradertron.order
                    and (not best_dispatch or best_score > best_dispatch.score)
                    and sn_storage.orders_set[order]
                then
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

    local success = spider_control.enqueue_pathfind_hex_move(tradertron.unit, order.hex_pos)
    if not success then return end

    tradertron.order = order
    spider_network._update_color(tradertron)
    spider_network._remove_order(order)
end

---@param tradertron Tradertron
function spider_network._update_color(tradertron)
    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if not entity or not entity.valid then return end

    local order = tradertron.order
    if not order then
        entity.color = {0, 0, 0}
    elseif order.type == "pickup" then
        entity.color = {1, 0, 0.25}
    elseif order.type == "dropoff" then
        entity.color = {0, 0.75, 1}
    end
end

---Reset a spider's color back to the default.
---@param tradertron Tradertron
function spider_network.reset_color(tradertron)
    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if not entity or not entity.valid then return end
    entity.color = {1, 0.5, 0, 0.5}
end

---@param tradertron Tradertron
---@param order SpiderNetworkOrder
---@param order_idx int
---@return boolean popped Whether the order was popped from the orders list, e.g. when the order is too old to fulfill.
function spider_network._process_order_for_spider(tradertron, order, order_idx)
    if order.tick_created + MAX_ORDER_LIFETIME < game.tick then
        spider_network._update_order_position_tracking(order, false)
        local sn_storage = spider_network._get_spider_network_storage()
        if order.trade_id then
            sn_storage.active_trade_deliveries[order.trade_id] = nil
        end
        spider_network._remove_order(order)
        return true
    end

    local score = spider_network.compute_tradertron_score_for_order(tradertron, order)
    if not score then return false end

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
                for item_name, count in pairs(counts) do
                    total_item_count = total_item_count + count
                    if spider_counts then
                        local spider_count = spider_counts[item_name]
                        if spider_count and spider_count > 0 then
                            matching_count = matching_count + math.min(spider_count, count)
                        end
                    end
                end
            end

            if total_item_count > 0 then
                matching_ratio = matching_count / total_item_count
            end
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
    if not entity or not entity.valid or not spider_network.is_entity_name_supported(entity.name) then return end

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

    spider_network._update_color(tradertron)

    game.print({"hextorio.spider-network-spiders-added", entity.gps_tag})

    return tradertron
end

---Unregister a Tradertron from the spider network.
---@param tradertron Tradertron
---@param clear_autopilot boolean
function spider_network.unregister_spider(tradertron, clear_autopilot)
    spider_network.clear_orders(tradertron, false, clear_autopilot)

    local unit = tradertron.unit
    if not unit then return end

    local entity = unit.entity
    if not entity or not entity.valid then return end

    local sn_storage = spider_network._get_spider_network_storage()
    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    spiders[entity.unit_number] = nil

    spider_network.reset_color(tradertron)

    local idx = lib.table_index(sn_storage.spider_list, entity)
    if idx then
        table.remove(sn_storage.spider_list, idx)
    end

    game.print({"hextorio.spider-network-spiders-removed", entity.gps_tag})
end

---@param state HexState
function spider_network.register_hex_state(state)
    if not state.claimed or not state.hex_core or not state.hex_core.valid then return end
    local sn_storage = spider_network._get_spider_network_storage()
    state.is_in_spider_network = true
    spider_network._add_network_hex_position(sn_storage, state)
    spider_network._update_hex_availability(state)
end

---@param state HexState
function spider_network.unregister_hex_state(state)
    local sn_storage = spider_network._get_spider_network_storage()
    state.is_in_spider_network = nil
    state.spider_network_available_items = nil
    state.spider_network_available_coin = nil
    spider_network._remove_network_hex_position(sn_storage, state)
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

---Return whether any dropoff order for the given trade ID is currently in the queue or assigned to a spider.
---Used to decide whether active_trade_deliveries should be cleared and whether followup dropoffs are needed.
---@param trade_id int
---@return boolean
function spider_network.trade_has_pending_or_active_dropoff(trade_id)
    local sn_storage = spider_network._get_spider_network_storage()
    for _, order in pairs(sn_storage.orders) do
        if order.trade_id == trade_id and order.type == "dropoff" then return true end
    end
    for _, entity in pairs(sn_storage.spider_list) do
        if entity and entity.valid then
            local tradertron = spider_network.get_tradertron_from_entity(entity)
            if tradertron and tradertron.order
                and tradertron.order.trade_id == trade_id
                and tradertron.order.type == "dropoff" then
                return true
            end
        end
    end
    return false
end

---Clear a Tradertron's current orders, forcing it to come to a stop.
---@param tradertron Tradertron
---@param discard_order boolean Whether to discard the order from the spider.  If false, the order is sent back to the network.
---@param clear_autopilot boolean
function spider_network.clear_orders(tradertron, discard_order, clear_autopilot)
    if clear_autopilot then
        local entity = spider_network.get_entity_from_tradertron(tradertron)
        if entity and entity.valid then
            entity.autopilot_destination = nil
        end
    end

    local order = tradertron.order
    if not order then return end

    tradertron.order = nil
    spider_network._update_color(tradertron)

    if discard_order then
        spider_network._update_order_position_tracking(order, false)
        local sn_storage = spider_network._get_spider_network_storage()
        if order.trade_id and order.type == "dropoff"
            and not spider_network.trade_has_pending_or_active_dropoff(order.trade_id) then
            sn_storage.active_trade_deliveries[order.trade_id] = nil
        end
    else
        spider_network._add_order(order)
    end
end

---@param order SpiderNetworkOrder
function spider_network._add_order(order)
    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.orders[#sn_storage.orders+1] = order
    sn_storage.orders_set[order] = true
    spider_network._update_order_position_tracking(order, true)
end

---@param order SpiderNetworkOrder
function spider_network._remove_order(order)
    local sn_storage = spider_network._get_spider_network_storage()

    local idx = lib.table_index(sn_storage.orders, order)
    if idx then
        table.remove(sn_storage.orders, idx)
    else
        lib.log_error("spider_network._remove_order: Order not found in orders list: " .. serpent.line(order) .. "\n" .. serpent.block(sn_storage.orders))
    end
    sn_storage.orders_set[order] = nil
end

---Add a pickup order to the spider network.
---@param state HexState
---@param coin Coin|nil
---@param quality_item_counts QualityItemCounts|nil
---@param priority number|nil
---@param trade_id int|nil Trade ID for which this order is gathering.
function spider_network.create_pickup_order(state, coin, quality_item_counts, priority, trade_id)
    if not coin and not quality_item_counts then return end
    if not spider_network.is_hex_state_in_network(state) then return end
    if not priority then priority = 1 end

    local hex_core = state.hex_core
    if not hex_core or not hex_core.valid then return end

    local order = table.deepcopy {
        type = "pickup",
        tick_created = game.tick,
        surface_index = hex_core.surface_index,
        hex_pos = state.position,
        map_position = hex_core.position,
        items = quality_item_counts,
        coin = coin,
        priority = priority,
        trade_id = trade_id,
    }

    spider_network._add_order(order)
end

---Add a dropoff order to the spider network.
---
---Generally, `all_items` should be true when deliveries are meant to boost trading loop throughput, and false when making one-off trades to rank up items.
---@param state HexState
---@param coin Coin|nil
---@param quality_item_counts QualityItemCounts|nil
---@param all_items boolean|nil Whether to deposit all items from the spider's inventory on arrival.
---@param priority number|nil
---@param trade_id int|nil Trade this order is delivering for; used to clear active_trade_deliveries on completion.
function spider_network.create_dropoff_order(state, coin, quality_item_counts, all_items, priority, trade_id)
    if not coin and not quality_item_counts then return end
    if not spider_network.is_hex_state_in_network(state) then return end
    if not priority then priority = 1 end
    if all_items == false then all_items = nil end

    local hex_core = state.hex_core
    if not hex_core or not hex_core.valid then return end

    local order = table.deepcopy {
        type = "dropoff",
        tick_created = game.tick,
        surface_index = hex_core.surface_index,
        hex_pos = state.position,
        map_position = hex_core.position,
        all_items = all_items,
        items = quality_item_counts,
        coin = coin,
        priority = priority,
        trade_id = trade_id,
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
        spider_network._update_hex_availability(state)
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

    spider_network.clear_orders(tradertron, true, true)

    if order.type == "dropoff" and order.trade_id then
        ---@cast order DropoffOrder
        spider_network._check_trade_delivery_followup(order, state)
    end
end

---After a trade-linked dropoff completes, check whether the trade hex now holds all required inputs.
---If items are still missing and no other dropoff for this trade is in flight, create a new dropoff
---for the remainder so another spider (possibly already carrying those items) can deliver them.
---@param completed_order DropoffOrder
---@param state HexState
function spider_network._check_trade_delivery_followup(completed_order, state)
    local trade = trades.get_trade_from_id(completed_order.trade_id)
    if not trade then return end

    local inv = state.hex_core_input_inventory
    if not inv or not inv.valid then return end

    local inv_coin, inv_items = inventories.get_coins_and_items_of_inventory(inv)
    local quality = (trade.allowed_qualities and trade.allowed_qualities[1]) or "normal"

    local remaining_items = {}
    for _, item in pairs(trade.input_items) do
        local item_name = item.name
        if not lib.is_coin(item_name) then
            local still_need = item.count
            local inv_quality_items = inv_items[quality]
            if inv_quality_items then
                still_need = still_need - (inv_quality_items[item_name] or 0)
            end
            if still_need > 0 then
                if not remaining_items[quality] then remaining_items[quality] = {} end
                remaining_items[quality][item_name] = still_need
            end
        end
    end

    local remaining_coin
    local required_coin = trades.get_input_coins_of_trade(trade, quality)
    if coin_tiers.gt(required_coin, inv_coin) then
        remaining_coin = coin_tiers.subtract(required_coin, inv_coin)
    end

    if not next(remaining_items) and not remaining_coin then return end
    if spider_network.trade_has_pending_or_active_dropoff(completed_order.trade_id) then return end

    spider_network.create_dropoff_order(
        state,
        remaining_coin,
        next(remaining_items) and remaining_items or nil,
        nil,
        completed_order.priority,
        completed_order.trade_id
    )

    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.active_trade_deliveries[completed_order.trade_id] = true
end

---Return whether a pending order of the given type exists at the given hex.
---If item_name is provided, checks specifically for that item; otherwise checks for any item.
---@param order_type SpiderNetworkOrderType
---@param state HexState
---@param item_name string|nil
---@return boolean
function spider_network.has_pending_order(order_type, state, item_name)
    local tracking = state.spider_network_pending_orders
    if not tracking then return false end
    local type_set = tracking[order_type]
    if not type_set then return false end
    return item_name and type_set[item_name] == true or next(type_set) ~= nil
end

---Return whether any item in a QualityItemCounts set has a pending order of the given type at the given hex.
---@param order_type SpiderNetworkOrderType
---@param state HexState
---@param quality_item_counts QualityItemCounts
---@return boolean
function spider_network.any_item_has_pending_order(order_type, state, quality_item_counts)
    for _, counts in pairs(quality_item_counts) do
        for item_name in pairs(counts) do
            if spider_network.has_pending_order(order_type, state, item_name) then
                return true
            end
        end
    end
    return false
end

---@param hex_set table
---@param q_cursor int|nil
---@param r_cursor int|nil
---@return int|nil q
---@return int|nil r
function spider_network._next_hex_set_position(hex_set, q_cursor, r_cursor)
    local q = q_cursor
    local Q = q and hex_set[q]
    if Q then
        local r = r_cursor
        if r and not Q[r] then r = nil end
        local next_r = next(Q, r)
        if next_r then return q, next_r end
    end

    if q and not hex_set[q] then q = nil end
    local next_q = next(hex_set, q)
    while next_q do
        local next_Q = hex_set[next_q]
        local next_r = next_Q and next(next_Q)
        if next_r then return next_q, next_r end
        next_q = next(hex_set, next_q)
    end
end

---@param plan PickupPlan
---@return boolean
function spider_network._pickup_plan_is_satisfied(plan)
    if plan.remaining_coin_base_value > 0 then return false end
    if next(plan.remaining_items) then return false end
    return true
end

---@param plan PickupPlan
---@return boolean
function spider_network._pickup_plan_has_pickups(plan)
    return next(plan.pickup_hexes) ~= nil
end

---@param plan PickupPlan
---@param q int
---@param r int
---@return table
function spider_network._get_pickup_plan_hex(plan, q, r)
    local Q = plan.pickup_hexes[q]
    if not Q then
        Q = {}
        plan.pickup_hexes[q] = Q
    end

    local entry = Q[r]
    if not entry then
        entry = {}
        Q[r] = entry
    end

    return entry
end

---@param plan PickupPlan
---@param state HexState
function spider_network._scan_hex_for_pickup_plan(plan, state)
    local q = state.position.q
    local r = state.position.r
    local quality_items = state.spider_network_available_items and state.spider_network_available_items[plan.quality]

    if quality_items then
        for item_name, needed in pairs(plan.remaining_items) do
            if needed > 0 and not spider_network.has_pending_order("pickup", state, item_name) then
                local count = quality_items[item_name] or 0
                local take = math.min(count, needed)
                if take > 0 then
                    local entry = spider_network._get_pickup_plan_hex(plan, q, r)
                    if not entry.items then entry.items = {} end
                    entry.items[item_name] = (entry.items[item_name] or 0) + take
                    local remaining = needed - take
                    plan.remaining_items[item_name] = remaining > 0 and remaining or nil
                end
            end
        end
    end

    if plan.remaining_coin_base_value <= 0 then return end
    if spider_network.has_pending_order("pickup", state, "__coin__") then return end

    local coin = state.spider_network_available_coin
    local available_bv = coin and coin_tiers.to_base_value(coin) or 0
    if available_bv <= 0 then return end

    local take_bv = math.min(available_bv, plan.remaining_coin_base_value)
    local entry = spider_network._get_pickup_plan_hex(plan, q, r)
    entry.coin = coin_tiers.from_base_value(take_bv)
    plan.remaining_coin_base_value = plan.remaining_coin_base_value - take_bv
end

---@param sn_storage SpiderNetworkStorage
---@param plan PickupPlan
---@param work_limit int
---@return int work_done
---@return boolean done
function spider_network._process_pickup_plan_scan(sn_storage, plan, work_limit)
    local hex_set = sn_storage.hex_positions_in_network[plan.surface_index] or {}
    local work_done = 0

    while work_done < work_limit do
        if spider_network._pickup_plan_is_satisfied(plan) then return work_done, true end

        local q, r = spider_network._next_hex_set_position(hex_set, plan.scan_q, plan.scan_r)
        if not q or not r then return work_done, true end

        plan.scan_q = q
        plan.scan_r = r
        work_done = work_done + 1

        local state = hex_state_manager.get_hex_state(plan.surface_index, {q = q, r = r}, false)
        if state and spider_network.is_hex_state_in_network(state) then
            spider_network._scan_hex_for_pickup_plan(plan, state)
        end
    end

    return work_done, false
end

---Start an incremental pickup plan for a ranking trade.
---@param sn_storage SpiderNetworkStorage
---@param trade_id int
---@return PickupPlan|nil
function spider_network._start_pickup_plan(sn_storage, trade_id)
    if sn_storage.active_trade_deliveries[trade_id] then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade or not trade.active then return end
    local rank_ups = trades.count_item_rank_ups(trade, RANK_UP_FILTER)
    if rank_ups == 0 then return end

    if not trade.hex_state_flat_index then return end
    local surface = game.get_surface(trade.surface_name)
    if not surface then return end

    local surface_index = surface.index
    local state = hex_state_manager.get_hex_from_flat_index(surface_index, trade.hex_state_flat_index)
    if not state or not spider_network.is_hex_state_in_network(state) then return end

    local quality = (trade.allowed_qualities and trade.allowed_qualities[1]) or "normal"
    local generator = sn_storage.order_generator
    local surface_name = trade.surface_name
    local quality_spider = generator.spider_items[surface_name] and generator.spider_items[surface_name][quality]

    local remaining_items = {}
    for _, item in pairs(trade.input_items) do
        if not lib.is_coin(item.name) then
            local in_spiders = quality_spider and (quality_spider[item.name] or 0) or 0
            local needed = item.count - in_spiders
            if needed > 0 then
                remaining_items[item.name] = (remaining_items[item.name] or 0) + needed
            end
        end
    end

    local remaining_coin_base_value = 0
    local required_coin = trades.get_input_coins_of_trade(trade, quality)
    if required_coin then
        local spider_coin_bv = generator.spider_coins[surface_name]
            and coin_tiers.to_base_value(generator.spider_coins[surface_name]) or 0
        remaining_coin_base_value = coin_tiers.to_base_value(required_coin) - spider_coin_bv
        if remaining_coin_base_value < 0 then remaining_coin_base_value = 0 end
    end

    if not next(remaining_items) and remaining_coin_base_value == 0 then return end

    ---@type PickupPlan
    return {
        trade_id = trade_id,
        rank_ups = rank_ups,
        surface_index = surface_index,
        destination_hex_pos = {q = state.position.q, r = state.position.r},
        quality = quality,
        priority = 1 + rank_ups,
        phase = "scanning",
        remaining_items = remaining_items,
        remaining_coin_base_value = remaining_coin_base_value,
        pickup_hexes = {},
    }
end

---@param sn_storage SpiderNetworkStorage
---@param plan PickupPlan
---@return boolean
function spider_network._prepare_pickup_plan_order_placement(sn_storage, plan)
    if sn_storage.active_trade_deliveries[plan.trade_id] then return false end

    local trade = trades.get_trade_from_id(plan.trade_id)
    if not trade or not trade.active then return false end
    if trades.count_item_rank_ups(trade, RANK_UP_FILTER) == 0 then return false end

    local state = hex_state_manager.get_hex_state(plan.surface_index, plan.destination_hex_pos, false)
    if not state or not spider_network.is_hex_state_in_network(state) then return false end

    local already_have_items = {}
    local already_have_coins_bv = 0
    local inv = state.hex_core_input_inventory
    if inv and inv.valid then
        local inv_coin, inv_items = inventories.get_coins_and_items_of_inventory(inv)
        already_have_items = inv_items
        already_have_coins_bv = coin_tiers.to_base_value(inv_coin)
    end

    plan.already_have_items = already_have_items
    plan.already_have_coins_bv = already_have_coins_bv
    plan.phase = "placing-orders"
    sn_storage.active_trade_deliveries[plan.trade_id] = true
    return true
end

---@param sn_storage SpiderNetworkStorage
---@param plan PickupPlan
---@param work_limit int
---@return int work_done
---@return boolean done
function spider_network._process_pickup_plan_order_placement(sn_storage, plan, work_limit)
    local trade = trades.get_trade_from_id(plan.trade_id)
    if not trade or not trade.active or trades.count_item_rank_ups(trade, RANK_UP_FILTER) == 0 then
        sn_storage.active_trade_deliveries[plan.trade_id] = nil
        return 0, true
    end
    if not sn_storage.active_trade_deliveries[plan.trade_id] then return 0, true end

    local destination_state = hex_state_manager.get_hex_state(plan.surface_index, plan.destination_hex_pos, false)
    if not destination_state or not spider_network.is_hex_state_in_network(destination_state) then
        sn_storage.active_trade_deliveries[plan.trade_id] = nil
        return 0, true
    end

    local work_done = 0
    while work_done < work_limit do
        local q, r = spider_network._next_hex_set_position(plan.pickup_hexes, plan.order_q, plan.order_r)
        if not q or not r then
            if not plan.placed_any_order then
                sn_storage.active_trade_deliveries[plan.trade_id] = nil
            end
            return work_done, true
        end

        plan.order_q = q
        plan.order_r = r
        work_done = work_done + 1

        local pickup_data = plan.pickup_hexes[q][r]
        local pickup_state = hex_state_manager.get_hex_state(plan.surface_index, {q = q, r = r}, false)
        if pickup_state then
            local qic = pickup_data.items and {[plan.quality] = pickup_data.items} or nil
            local coin = pickup_data.coin
            local pickup_qic = (qic and not spider_network.any_item_has_pending_order("pickup", pickup_state, qic)) and qic or nil
            local pickup_coin = (coin and not spider_network.has_pending_order("pickup", pickup_state, "__coin__")) and coin or nil
            if pickup_qic or pickup_coin then
                spider_network.create_pickup_order(pickup_state, pickup_coin, pickup_qic, plan.priority, plan.trade_id)
                plan.placed_any_order = true

                local dropoff_qic = nil
                if pickup_qic and plan.already_have_items then
                    dropoff_qic = table.deepcopy(pickup_qic)
                    lib.subtract_quality_item_counts(dropoff_qic, plan.already_have_items)
                    lib.subtract_quality_item_counts(plan.already_have_items, pickup_qic)
                    if not next(dropoff_qic) then dropoff_qic = nil end
                end

                local dropoff_coin = nil
                if pickup_coin and plan.already_have_coins_bv then
                    local coin_bv = coin_tiers.to_base_value(pickup_coin)
                    local need_bv = math.max(0, coin_bv - plan.already_have_coins_bv)
                    plan.already_have_coins_bv = math.max(0, plan.already_have_coins_bv - coin_bv)
                    if need_bv > 0 then
                        dropoff_coin = coin_tiers.from_base_value(need_bv)
                    end
                end

                if dropoff_qic or dropoff_coin then
                    spider_network.create_dropoff_order(destination_state, dropoff_coin, dropoff_qic, false, plan.priority, plan.trade_id)
                    plan.placed_any_order = true
                end
            end
        end
    end

    return work_done, false
end

---Cancel all queued and in-flight orders associated with a given trade ID.
---Clears position tracking and active_trade_deliveries for the trade.
---@param trade_id int
function spider_network.cancel_orders_for_trade(trade_id)
    local sn_storage = spider_network._get_spider_network_storage()
    local orders = sn_storage.orders

    for i = #orders, 1, -1 do
        local order = orders[i]
        if order and order.trade_id == trade_id then
            spider_network._update_order_position_tracking(order, false)
            sn_storage.orders_set[order] = nil
            table.remove(orders, i)
        end
    end

    for _, entity in pairs(sn_storage.spider_list) do
        if entity and entity.valid then
            local tradertron = spider_network.get_tradertron_from_entity(entity)
            if tradertron and tradertron.order and tradertron.order.trade_id == trade_id then
                spider_network.clear_orders(tradertron, true, true)
            end
        end
    end

    sn_storage.active_trade_deliveries[trade_id] = nil
end

---Update a hex state's cached spider-network availability from its output inventory.
---@param state HexState
function spider_network._update_hex_availability(state)
    state.spider_network_available_items = nil
    state.spider_network_available_coin = nil

    local output_inv = state.hex_core_output_inventory
    if not output_inv or not output_inv.valid then return end

    local inv_coin, inv_items = inventories.get_coins_and_items_of_inventory(output_inv)
    if not coin_tiers.is_zero(inv_coin) then
        state.spider_network_available_coin = inv_coin
    end

    if not next(inv_items) then return end

    state.spider_network_available_items = inv_items
end

---Add an entity name to the set of names that can be added to the spider network.
---@param entity_name string
function spider_network.register_supported_entity_name(entity_name)
    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.supported_entity_names[entity_name] = true
end

---Remove an entity name from the set of names that can be added to the spider network.
---@param entity_name string
function spider_network.unregister_supported_entity_name(entity_name)
    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.supported_entity_names[entity_name] = nil

    for i = #sn_storage.spider_list, 1, -1 do
        local spider = sn_storage.spider_list[i]
        if spider and spider.valid then
            if spider.name == entity_name then
                local tradertron = spider_network.get_tradertron_from_entity(spider)
                if tradertron then
                    spider_network.unregister_spider(tradertron, true)
                end
            end
        end
    end
end

---@param generator OrderGenerator
function spider_network._finish_order_generator_calculation(generator)
    generator.state = "accumulating"
    generator.accumulation_started_at_cycle_boundary = false
    generator.calculation_trade_ids = nil
    generator.calculation_trade_id_cursor = nil
    generator.calculation_phase = nil
    generator.spider_scan_idx = nil
    generator.active_pickup_plan = nil
end

---@param generator OrderGenerator
function spider_network._begin_order_generator_calculation(generator)
    generator.state = "calculating"
    generator.accumulation_started_at_cycle_boundary = false
    generator.calculation_trade_ids = generator.trade_ids_that_rank_up
    generator.trade_ids_that_rank_up = {}
    generator.calculation_trade_id_cursor = nil
    generator.calculation_phase = "snapshot-spiders"
    generator.spider_scan_idx = 1
    generator.active_pickup_plan = nil
    generator.spider_items = {}
    generator.spider_coins = {}
end

---@param sn_storage SpiderNetworkStorage
---@param generator OrderGenerator
---@param work_limit int
---@return int work_done
function spider_network._process_order_generator_spider_snapshot(sn_storage, generator, work_limit)
    local spider_list = sn_storage.spider_list
    local idx = generator.spider_scan_idx or 1
    local work_done = 0

    while work_done < work_limit and idx <= #spider_list do
        local entity = spider_list[idx]
        idx = idx + 1
        work_done = work_done + 1

        if entity and entity.valid then
            local inv = entity.get_inventory(defines.inventory.spider_trunk)
            if inv and inv.valid then
                local inv_coin, inv_items = inventories.get_coins_and_items_of_inventory(inv)
                local surface_name = entity.surface.name
                for quality, counts in pairs(inv_items) do
                    if not generator.spider_items[surface_name] then generator.spider_items[surface_name] = {} end
                    if not generator.spider_items[surface_name][quality] then generator.spider_items[surface_name][quality] = {} end
                    local q_map = generator.spider_items[surface_name][quality]
                    for item_name, count in pairs(counts) do
                        q_map[item_name] = (q_map[item_name] or 0) + count
                    end
                end
                if coin_tiers.to_base_value(inv_coin) > 0 then
                    generator.spider_coins[surface_name] = generator.spider_coins[surface_name]
                        and coin_tiers.add(generator.spider_coins[surface_name], inv_coin) or inv_coin
                end
            end
        end
    end

    generator.spider_scan_idx = idx
    if idx > #spider_list then
        generator.spider_scan_idx = nil
        generator.calculation_phase = "planning"
    end

    return work_done
end

---@param generator OrderGenerator
---@return int|nil trade_id
function spider_network._next_order_generator_trade(generator)
    local trade_ids = generator.calculation_trade_ids
    if not trade_ids then return end

    local trade_id = next(trade_ids, generator.calculation_trade_id_cursor)
    generator.calculation_trade_id_cursor = trade_id
    return trade_id
end

---@param sn_storage SpiderNetworkStorage
---@param generator OrderGenerator
---@param work_limit int
---@return int work_done
function spider_network._process_order_generator_planning(sn_storage, generator, work_limit)
    local work_done = 0

    while work_done < work_limit do
        local plan = generator.active_pickup_plan
        if not plan then
            local trade_id = spider_network._next_order_generator_trade(generator)
            if not trade_id then
                spider_network._finish_order_generator_calculation(generator)
                return work_done
            end

            generator.active_pickup_plan = spider_network._start_pickup_plan(sn_storage, trade_id)
            work_done = work_done + 1
            plan = generator.active_pickup_plan
        end

        if plan and plan.phase == "scanning" and work_done < work_limit then
            local scan_work, done = spider_network._process_pickup_plan_scan(sn_storage, plan, work_limit - work_done)
            work_done = work_done + scan_work
            if done then
                if spider_network._pickup_plan_is_satisfied(plan)
                    and spider_network._pickup_plan_has_pickups(plan)
                    and spider_network._prepare_pickup_plan_order_placement(sn_storage, plan)
                then
                    plan = generator.active_pickup_plan
                else
                    generator.active_pickup_plan = nil
                    plan = nil
                end
            end
        end

        if plan and plan.phase == "placing-orders" and work_done < work_limit then
            local placement_work, done = spider_network._process_pickup_plan_order_placement(sn_storage, plan, work_limit - work_done)
            work_done = work_done + placement_work
            if done then
                generator.active_pickup_plan = nil
            end
        end

        if work_done == 0 then
            work_done = 1
        end
    end

    return work_done
end

---@param sn_storage SpiderNetworkStorage
function spider_network._process_order_generator(sn_storage)
    local generator = sn_storage.order_generator
    if generator.state ~= "calculating" then return end

    local work_remaining = ORDER_GENERATOR_WORK_PER_TICK
    if generator.calculation_phase == "snapshot-spiders" then
        local work_done = spider_network._process_order_generator_spider_snapshot(sn_storage, generator, work_remaining)
        work_remaining = work_remaining - work_done
        if generator.calculation_phase == "snapshot-spiders" or work_remaining <= 0 then return end
    end

    if generator.calculation_phase == "planning" then
        spider_network._process_order_generator_planning(sn_storage, generator, work_remaining)
    end
end

---Scan a network hex's inventory and trades for the order generator.
---Fires for all spider network hexes regardless of active status, so rank-up trades are
---detected even when a hex has no items yet and is waiting for its first delivery.
---@param state HexState
function spider_network.on_spider_network_hex_state_processed(state)
    local sn_storage = spider_network._get_spider_network_storage()
    if not sn_storage.enabled then return end
    if not state.hex_core or not state.hex_core.valid then return end

    local generator = sn_storage.order_generator

    spider_network._add_network_hex_position(sn_storage, state)
    spider_network._update_hex_availability(state)
    if generator.state ~= "accumulating" then return end
    if not generator.accumulation_started_at_cycle_boundary then return end
    if not state.trades then return end

    for _, trade_id in pairs(state.trades) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade and trade.active then
            local rank_ups = trades.count_item_rank_ups(trade, RANK_UP_FILTER)
            if rank_ups > 0 then
                generator.trade_ids_that_rank_up[trade_id] = true
            end
        end
    end
end

function spider_network.on_hex_pool_cycle_completed()
    local sn_storage = spider_network._get_spider_network_storage()
    if not sn_storage.enabled then return end

    local generator = sn_storage.order_generator
    if generator.state ~= "accumulating" then return end

    if not generator.accumulation_started_at_cycle_boundary then
        generator.trade_ids_that_rank_up = {}
        generator.accumulation_started_at_cycle_boundary = true
        return
    end

    if next(generator.trade_ids_that_rank_up) then
        spider_network._begin_order_generator_calculation(generator)
    else
        generator.trade_ids_that_rank_up = {}
    end
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

    spider_network.unregister_spider(tradertron, false)
end

---@param player LuaPlayer
---@param vehicle LuaEntity
function spider_network.on_player_entered_spider_control_vehicle(player, vehicle)
    local tradertron = spider_network.get_tradertron_from_entity(vehicle)
    if not tradertron then return end
    spider_network.unregister_spider(tradertron, true)
end

---@param entity LuaEntity
function spider_network.on_entity_built(entity)
    local sn_storage = spider_network._get_spider_network_storage()
    if not sn_storage.enabled then return end

    spider_network.register_spider(entity)
end

---@param player LuaPlayer
---@param spiders LuaEntity[]
function spider_network.on_player_commanded_spiders(player, spiders)
    local sn_storage = spider_network._get_spider_network_storage()
    if not sn_storage.enabled then return end

    for _, spider in pairs(spiders) do
        local tradertron = spider_network.get_tradertron_from_entity(spider)
        if tradertron then
            spider_network.unregister_spider(tradertron, false)
        else
            if spider.type == "spider-vehicle" then
                local target = spider.follow_target
                if target and target.name == "hex-core" then
                    spider_network.register_spider(spider)
                end
            end
        end
    end
end

---@param trade Trade
---@param total_removed QualityItemCounts
---@param total_inserted QualityItemCounts
function spider_network.on_trade_processed(trade, total_removed, total_inserted)
    local sn_storage = spider_network._get_spider_network_storage()
    if not sn_storage.enabled then return end
    if not sn_storage.active_trade_deliveries[trade.id] then return end
    if trades.count_item_rank_ups(trade, RANK_UP_FILTER) > 0 then return end

    spider_network.cancel_orders_for_trade(trade.id)
end

---@param feature_name FeatureName
function spider_network.on_feature_unlocked(feature_name)
    if feature_name ~= "spider-network" then return end
    spider_network.set_enabled(true)
end



return spider_network
