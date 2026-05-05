
local spider_control = require "api.spider_control"
local event_system   = require "api.event_system"

local spider_network = {}



---@class SpiderNetworkStorage
---@field spiders {[int]: Tradertron} Mapping of entity unit numbers to the Tradertron that is associated to that entity

---@class Tradertron
---@field unit SpiderControlUnit



function spider_network.register_events()
    event_system.register("entity-becoming-invalid", spider_network.on_entity_becoming_invalid)
end

---@return SpiderNetworkStorage
function spider_network._get_spider_network_storage()
    local sn_storage = storage.spider_network
    if not sn_storage then
        sn_storage = {}
        storage.spider_network = sn_storage
    end

    if not sn_storage.tradertrons then
        sn_storage.tradertrons = {}
    end

    return sn_storage
end

---Register a SpiderVehicle type of entity to the spider network.
---@param entity LuaEntity
---@return Tradertron|nil
function spider_network.register_spider(entity)
    if not entity or not entity.valid then return end

    local unit = spider_control.register_spider(entity, true)
    if not unit then return end

    local tradertron = {
        unit = unit,
    }

    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.spiders[entity.unit_number] = tradertron

    return tradertron
end

---Unregister a Tradertron from the spider network.
---@param tradertron Tradertron
function spider_network.unregister_spider(tradertron)
    local unit = tradertron.unit
    if not unit then return end

    local entity = unit.entity
    if not entity or not entity.valid then return end

    local sn_storage = spider_network._get_spider_network_storage()
    sn_storage.spiders[entity.unit_number] = nil
end

---Get a Tradertron from a SpiderVehicle entity if it's registered.
---@param entity LuaEntity
---@return Tradertron|nil
function spider_network.get_tradertron_from_entity(entity)
    if not entity or not entity.valid or entity.type ~= "spider-vehicle" then return end
    local sn_storage = spider_network._get_spider_network_storage()
    return sn_storage.spiders[entity.unit_number]
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
