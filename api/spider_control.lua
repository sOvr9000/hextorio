
local lib = require "api.lib"
local axial = require "api.axial"
local terrain = require "api.terrain"
local event_system = require "api.event_system"
local hex_state_manager = require "api.hex_state_manager"
local hex_pathfinding   = require "api.hex_pathfinding"
local hex_island        = require "api.hex_island"

local spider_control = {}



---@class SpiderControlStorage
---@field spiders {[int]: SpiderControlUnit} Mapping of entity unit numbers to the SpiderControlUnit that is associated to that entity

---@class SpiderControlUnit
---@field entity LuaEntity
---@field allow_manual_driving boolean



function spider_control.register_events()
    event_system.register("entity-becoming-invalid", spider_control.on_entity_becoming_invalid)
    event_system.register("player-driving-state-changed", spider_control.on_player_driving_state_changed)
    event_system.register("player-commanded-spiders", spider_control.on_player_commanded_spiders)
    event_system.register("spider-reached-patrol-point", spider_control.on_spider_reached_patrol_point)
end

---@return SpiderControlStorage
function spider_control._get_spider_control_storage()
    local sc_storage = storage.spider_control
    if not sc_storage then
        sc_storage = {}
        storage.spider_control = sc_storage
    end

    if not sc_storage.spiders then
        sc_storage.spiders = {}
    end

    return sc_storage
end

---@param entity LuaEntity
---@param allow_manual_driving boolean
---@return SpiderControlUnit|nil
function spider_control.register_spider(entity, allow_manual_driving)
    if not entity.valid then
        lib.log_error("spider_control.register_spider: entity is invalid")
        return
    end

    if entity.type ~= "spider-vehicle" then
        lib.log_error("spider_control.register_spider: entity is not a spider-vehicle type")
        return
    end

    if not allow_manual_driving and entity.get_driver() then return end

    local unit = {
        entity = entity,
        allow_manual_driving = allow_manual_driving,
    }

    local sc_storage = spider_control._get_spider_control_storage()
    sc_storage.spiders[entity.unit_number] = unit

    return unit
end

---@param entity LuaEntity
---@return int|nil
function spider_control.get_spider_control_unit_id_from_entity(entity)
    local sc_storage = storage.spider_control
    if not sc_storage then return end

    if entity.valid then
        return entity.unit_number
    else
        for id, unit in pairs(sc_storage.spiders) do
            if unit.entity and unit.entity and unit.entity == entity then
                return id
            end
        end
    end
end

---@param unit SpiderControlUnit
function spider_control.unregister_spider(unit)
    local sc_storage = spider_control._get_spider_control_storage()
    local entity = unit.entity

    local id = spider_control.get_spider_control_unit_id_from_entity(entity)
    if not id then
        lib.log_error("spider_control.unregister_spider: Failed to unregister spider control unit with entity " .. tostring(entity))
        return
    end

    sc_storage.spiders[id] = nil

    if unit.entity.valid then
        unit.entity.autopilot_destination = nil
    end
end

---@param unit SpiderControlUnit
---@return boolean
function spider_control.verify_unit_valid(unit)
    local entity = unit.entity
    if not entity or not entity.valid then
        lib.log_error("spider_control.verify_unit_valid: Spider control unit has missing or invalid entity; removing from system.")
        spider_control.unregister_spider(unit)
        return false
    end
    return true
end

---@param entity LuaEntity
---@return boolean
function spider_control.is_registered(entity)
    local id = spider_control.get_spider_control_unit_id_from_entity(entity)
    if not id then return false end
    return true
end

---@param entity LuaEntity
---@return SpiderControlUnit|nil
function spider_control.get_unit_from_entity(entity)
    local id = spider_control.get_spider_control_unit_id_from_entity(entity)
    if not id then return end
    local sc_storage = spider_control._get_spider_control_storage()
    return sc_storage.spiders[id]
end

---@param unit SpiderControlUnit
---@param to_positions MapPosition[]
function spider_control.enqueue_move(unit, to_positions)
    if not spider_control.verify_unit_valid(unit) then return end

    local entity = unit.entity
    for _, pos in pairs(to_positions) do
        entity.add_autopilot_destination(pos)
    end
end

---@param unit SpiderControlUnit
---@param to_hex_positions HexPos[]
function spider_control.enqueue_hex_move(unit, to_hex_positions)
    if not spider_control.verify_unit_valid(unit) then return end

    local entity = unit.entity
    local surface = entity.surface
    local transformation = terrain.get_surface_transformation(surface.index)

    local to_positions = {}
    for i, hex_pos in pairs(to_hex_positions) do
        to_positions[i] = axial.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
    end

    spider_control.enqueue_move(unit, to_positions)
end

---Add patrol points to the spider's autopilot by pathfinding from its current position to the destination hex.
---@param unit SpiderControlUnit
---@param to_hex_pos HexPos
---@return boolean success
function spider_control.enqueue_pathfind_hex_move(unit, to_hex_pos)
    local entity = unit.entity
    if not entity or not entity.valid then return false end

    local surface = entity.surface
    local state = hex_state_manager.get_hex_state_containing(surface, entity.position)
    if not state then return false end

    local cur_hex_pos = state.position

    local island = hex_island.get_island_hex_set(surface.name)
    local to_hex_positions = hex_pathfinding.find_path(island, cur_hex_pos, to_hex_pos)

    if not to_hex_positions then
        return false
    end

    spider_control.enqueue_hex_move(unit, to_hex_positions)
    return true
end

---@param entity LuaEntity
function spider_control.on_entity_becoming_invalid(entity)
    if not entity.valid then return end
    if entity.type ~= "spider-vehicle" then return end

    local unit = spider_control.get_unit_from_entity(entity)
    if not unit then return end

    spider_control.unregister_spider(unit)
end

---@param player LuaPlayer
---@param vehicle LuaEntity|nil
function spider_control.on_player_driving_state_changed(player, vehicle)
    if not vehicle or not vehicle.valid or not player.driving then return end

    local unit = spider_control.get_unit_from_entity(vehicle)
    if unit then
        if unit.allow_manual_driving then
            event_system.trigger("player-entered-spider-control-vehicle", player, vehicle)
        else
            player.driving = false
        end
    end
end

---@param player LuaPlayer
---@param spiders LuaEntity[]
function spider_control.on_player_commanded_spiders(player, spiders)
    for _, spider in pairs(spiders) do
        local unit = spider_control.get_unit_from_entity(spider)
        if unit then
            spider_control.unregister_spider(unit)
        end
    end
end

---@param entity LuaEntity
function spider_control.on_spider_reached_patrol_point(entity)
    local state = hex_state_manager.get_hex_state_containing(entity.surface, entity.position)
    if not state then return end

    event_system.trigger("spider-reached-hex-state", entity, state)
end



return spider_control
