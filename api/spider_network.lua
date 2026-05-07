
local lib               = require "api.lib"
local coin_tiers        = require "api.coin_tiers"
local trades            = require "api.trades"
local event_system      = require "api.event_system"
local spider_control    = require "api.spider_control"
local inventories       = require "api.inventories"
local axial             = require "api.axial"
local hex_state_manager = require "api.hex_state_manager"
local terrain           = require "api.terrain"

local spider_network = {}



---@alias TradertronMode "ranking"|"trading"
---@alias TradertronState "idle"|"pickup"|"dropoff"
---@alias SpiderNetworkOrder PickupOrder|DropoffOrder

---@class SpiderNetworkStorage
---@field spiders {[int]: {[int]: Tradertron}} Mapping for each surface ID of entity unit numbers to the Tradertron that is associated to that entity
---@field trade_ids_in_ranking_progress {[int]: int} Mapping of trade IDs to spider unit numbers currently ranking up items with that trade.
---@field orders SpiderNetworkOrder[]

---@class PickupOrder
---@field hex_pos HexPos
---@field items QualityItemCounts|nil
---@field coin Coin|nil
---@field priority number

---@class DropoffOrder
---@field hex_pos HexPos
---@field all_items boolean|nil If true, drop off entire inventory instead of specified amounts.
---@field items QualityItemCounts|nil
---@field coin Coin|nil
---@field priority number

---@class Tradertron
---@field unit SpiderControlUnit
---@field mode TradertronMode
---@field pickup_order PickupOrder|nil Current pickup order
---@field dropoff_order DropoffOrder|nil Current dropoff order



function spider_network.register_events()
    event_system.register("entity-becoming-invalid", spider_network.on_entity_becoming_invalid)
    event_system.register("active-hex-state-processed", spider_network.on_active_hex_state_processed)
    event_system.register("spider-reached-hex-state", spider_network.on_spider_reached_hex_state)
    event_system.register("player-started-driving-spider-control-vehicle", spider_network.on_player_started_driving_spider_control_vehicle)
    event_system.register("player-commanded-spider-control-vehicle", spider_network.on_player_commanded_spider_control_vehicle)

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

    if not sn_storage.orders then
        sn_storage.orders = {}
    end

    if not sn_storage.trade_ids_in_ranking_progress then
        sn_storage.trade_ids_in_ranking_progress = {}
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

---Clear a Tradertron's current orders, putting it in an idle state.
---@param tradertron Tradertron
function spider_network.clear_orders(tradertron)
    tradertron.pickup_order = nil
    tradertron.dropoff_order = nil

    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if entity and entity.valid then
        entity.autopilot_destination = nil
    end
end

---Return the first idle Tradertron that is closest to a given hex position.
---@param surface_index int
---@param hex_pos HexPos|nil If not provided, 
---@return Tradertron|nil
function spider_network.select_next_idle_spider(surface_index, hex_pos)
    local hex_center
    if hex_pos then
        local transformation = terrain.get_surface_transformation(surface_index)
        hex_center = axial.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
    end

    local closest_spider, closest_dist
    for _, tradertron in pairs(spider_network.get_spider_storage_on_surface(surface_index)) do
        if tradertron.unit and tradertron.unit.entity and tradertron.unit.entity.valid and not tradertron.pickup_order and not tradertron.dropoff_order then
            if not hex_pos then
                return tradertron
            end

            local dist = lib.square_distance(tradertron.unit.entity.position, hex_center)
            if not closest_dist or dist < closest_dist then
                closest_dist = dist
                closest_spider = tradertron
            end
        end
    end

    return closest_spider
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

    local order = {
        hex_pos = state.position,
        items = quality_item_counts,
        coin = coin,
        priority = priority,
    }

    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.orders[#sn_storage.orders+1] = order
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

    -- Generally, all_items should be true for tradertrons in trading mode, and false/nil for tradertrons in ranking mode

    local order = {
        hex_pos = state.position,
        all_items = all_items,
        items = quality_item_counts,
        coin = coin,
        priority = priority,
    }

    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.orders[#sn_storage.orders+1] = order
end

---@param tradertron Tradertron
function spider_network._handle_pickup(tradertron)
    local order = tradertron.pickup_order
    if not order then return end

    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if not entity or not entity.valid then return end

    local hex_pos = order.hex_pos
    local state = hex_state_manager.get_hex_state(entity.surface_index, hex_pos)
    if not state or not state.claimed then return end

    local hex_core_inv = state.hex_core_output_inventory
    if not hex_core_inv or not hex_core_inv.valid then return end

    local spider_inv = entity.get_inventory(defines.inventory.spider_trunk)
    if not spider_inv or not spider_inv.valid then return end

    inventories.transfer_coins_and_items(hex_core_inv, nil, spider_inv, nil, order.coin, order.items)
end

---@param tradertron Tradertron
function spider_network._handle_dropoff(tradertron)
    local order = tradertron.pickup_order
    if not order then return end

    local entity = spider_network.get_entity_from_tradertron(tradertron)
    if not entity or not entity.valid then return end

    local hex_pos = order.hex_pos
    local state = hex_state_manager.get_hex_state(entity.surface_index, hex_pos)
    if not state or not state.claimed then return end

    local hex_core_inv = state.hex_core_output_inventory
    if not hex_core_inv or not hex_core_inv.valid then return end

    local spider_inv = entity.get_inventory(defines.inventory.spider_trunk)
    if not spider_inv or not spider_inv.valid then return end

    inventories.transfer_coins_and_items(spider_inv, nil, hex_core_inv, nil, order.coin, order.items)
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

    if tradertron.pickup_order and axial.equals(tradertron.pickup_order.hex_pos, hex_pos) then
        spider_network._handle_pickup(tradertron)
    end

    if tradertron.dropoff_order and axial.equals(tradertron.dropoff_order.hex_pos, hex_pos) then
        spider_network._handle_dropoff(tradertron)
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
function spider_network.on_player_started_driving_spider_control_vehicle(player, vehicle)
    local tradertron = spider_network.get_tradertron_from_entity(vehicle)
    if not tradertron then return end
    spider_network.unregister_spider(tradertron)
end

function spider_network.on_player_commanded_spider_control_vehicle(player, vehicle)
    local tradertron = spider_network.get_tradertron_from_entity(vehicle)
    if not tradertron then return end
    spider_network.unregister_spider(tradertron)
end



return spider_network
