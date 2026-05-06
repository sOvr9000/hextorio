
local lib               = require "api.lib"
local event_system      = require "api.event_system"
local spider_control    = require "api.spider_control"
local hex_state_manager = require "api.hex_state_manager"
local inventories       = require "api.inventories"

local spider_network = {}



---@alias TradertronMode "ranking"|"trading"
---@alias TradertronState "idle"|"pickup"|"dropoff"

---@class SpiderNetworkStorage
---@field spiders {[int]: {[int]: Tradertron}} Mapping for each surface ID of entity unit numbers to the Tradertron that is associated to that entity
---@field filtered_trade_ids {[int]: int} (TODO) Fetch using trades.queue_trade_filtering_job()
---@field trade_ids_in_ranking_progress {[int]: int} Mapping of trade IDs to spider unit numbers that are currently in progress of ranking up items with that trade.

---@class Tradertron
---@field unit SpiderControlUnit
---@field mode TradertronMode
---@field current_state TradertronState
---@field target_trade_id int|nil
---@field current_requested_coins Coin|nil
---@field current_requested_items QualityItemCounts|nil
---@field requested_coins Coin|nil
---@field requested_items QualityItemCounts|nil



function spider_network.register_events()
    event_system.register("entity-becoming-invalid", spider_network.on_entity_becoming_invalid)
    event_system.register("active-hex-state-processed", spider_network.on_active_hex_state_processed)
    event_system.register("spider-reached-hex-state", spider_network.on_spider_reached_hex_state)
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
    local unit = tradertron.unit
    if not unit then return end

    local entity = unit.entity
    if not entity or not entity.valid then return end

    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    spiders[entity.unit_number] = nil
end

---Get a Tradertron from a SpiderVehicle entity if it's registered.
---@param entity LuaEntity
---@return Tradertron|nil
function spider_network.get_tradertron_from_entity(entity)
    if not entity or not entity.valid or entity.type ~= "spider-vehicle" then return end
    local spiders = spider_network.get_spider_storage_on_surface(entity.surface_index)
    return spiders[entity.unit_number]
end

---@param hex_state HexState
---@return boolean
function spider_network.is_hex_state_in_network(hex_state)
    return hex_state.is_in_spider_network == true
end

---@param tradertron Tradertron
---@param inv_coins Coin
---@param inv_items QualityItemCounts
---@return QualityItemCounts matching, boolean success How many items matched, and whether any were matched at all.
function spider_network.get_matching_requested_items(tradertron, inv_coins, inv_items)
    local matched = {}
    local success = false

    for quality, requested_items in pairs(tradertron.requested_items) do
        local quality_items = inv_items[quality]
        if quality_items then
            for item_name, requested_amount in pairs(requested_items) do
                local amount = quality_items[item_name]
                if amount and amount >= 1 then
                    local match_amount = math.min(requested_amount, amount)
                    lib.add_item_to_quality_item_counts(matched, item_name, match_amount, quality)
                    success = true
                end
            end
        end
    end

    return matched, success
end

---@param tradertron Tradertron
---@param state HexState
---@param inv_coins Coin
---@param inv_items QualityItemCounts
function spider_network._process_spider_logic(tradertron, state, inv_coins, inv_items)
    local cur_state = tradertron.current_state
    if cur_state == "idle" then
        if not tradertron.unit.entity.autopilot_destination then
            local matching, success = spider_network.get_matching_requested_items(tradertron, inv_coins, inv_items)
            if success then
                spider_control.enqueue_pathfind_hex_move(tradertron.unit, state.position)
                tradertron.current_state = "pickup"

                lib.negate_quality_item_counts(matching)
                lib.add_quality_item_counts(inv_items, matching)
            end
        end
    end
end

---@param tradertron Tradertron
---@param state HexState
function spider_network._handle_spider_reached_hex_state(tradertron, state)
    local inv = state.hex_core_output_inventory
    if not inv or not inv.valid then return end

    local cur_state = tradertron.current_state

    if cur_state == "pickup" then
        local inv_coins, inv_items = inventories.get_coins_and_items_of_inventory(inv)
        local matched, success = spider_network.get_matching_requested_items(tradertron, inv_coins, inv_items)
        if not success then return end

        for quality, quality_matched in pairs(matched) do
            for item_name, amount in pairs(quality_matched) do
                hex_state_manager.add_to_requested_pickup(state, item_name, -amount, quality)
                local actual_inserted = tradertron.unit.entity.insert {name = item_name, count = amount}
                if actual_inserted > 0 then
                    inv.remove {name = item_name, count = actual_inserted}
                end
                lib.add_item_to_quality_item_counts(tradertron.requested_items, item_name, -actual_inserted, quality)
            end
        end

        tradertron.current_state = "idle"
    end
end

---@param state HexState
function spider_network.on_active_hex_state_processed(state)
    if not spider_network.is_hex_state_in_network(state) then return end
    if not state.hex_core or not state.hex_core.valid then return end

    local input_inventory = state.hex_core_input_inventory
    if not input_inventory or not input_inventory.valid then return end -- Shouldn't happen because hex state is active

    local inv_coins, inv_items = inventories.get_coins_and_items_of_inventory(input_inventory)

    local spiders = spider_network.get_spider_storage_on_surface(state.hex_core.surface_index)
    for _, tradertron in pairs(spiders) do
        spider_network._process_spider_logic(tradertron, state, inv_coins, inv_items)
    end
end

---@param entity LuaEntity
---@param state HexState
function spider_network.on_spider_reached_hex_state(entity, state)
    if entity.autopilot_destination then return end

    local tradertron = spider_network.get_tradertron_from_entity(entity)
    if not tradertron then return end

    spider_network._handle_spider_reached_hex_state(tradertron, state)
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
