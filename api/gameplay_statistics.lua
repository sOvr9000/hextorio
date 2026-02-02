
local event_system = require "api.event_system"

local gameplay_statistics = {}



---@alias GameplayStatisticType
---| "total-hexes-claimed"
---| "total-quests-completed"
---| "total-strongbox-level"
---| "net-coin-production"
---| "total-spawners-killed"
---| "tech-tree-completion"
---| "total-resources-depleted"
---| "total-dungeons-looted"
---| "total-item-buff-level"
---| "total-item-rank"
---| "science-per-hour"
---| "total-rockets-launched"



function gameplay_statistics.register_events()
    event_system.register("entity-killed-entity", gameplay_statistics.on_entity_killed_entity)
    event_system.register("research-completed", gameplay_statistics.on_research_completed)
    event_system.register("dungeon-looted", gameplay_statistics.on_dungeon_looted)
    event_system.register("item-buff-level-changed", gameplay_statistics.on_item_buff_level_changed)
    event_system.register("item-rank-up", gameplay_statistics.on_item_rank_up)
    event_system.register("rocket-launched", gameplay_statistics.on_rocket_launched)
end

---Get a gameplay statistic.
---@param key GameplayStatisticType
---@return int current_value
function gameplay_statistics.get(key)
    return ((storage.gameplay_statistics or {}).stats or {})[key] or 0
end

---Set a gameplay statistic.
---@param key GameplayStatisticType
---@param new_value int|nil
function gameplay_statistics.set(key, new_value)
    local stats_storage = storage.gameplay_statistics
    if not stats_storage then
        stats_storage = {stats = {}}
        storage.gameplay_statistics = stats_storage
    end

    local stats = stats_storage.stats
    if not stats then
        stats = {}
        stats_storage.stats = stats
    end

    local prev = stats[key] or 0
    if prev ~= new_value then
        stats[key] = new_value
        event_system.trigger("gameplay-statistic-changed", key, prev, new_value)
    end
end

---Increment a gameplay statistic.
---@param key GameplayStatisticType
---@param amount int|nil
function gameplay_statistics.increment(key, amount)
    if amount == 0 then return end
    gameplay_statistics.set(key, gameplay_statistics.get(key) + (amount or 1))
end

---@param entity_that_died LuaEntity
---@param entity_that_caused LuaEntity
---@param damage_type_prot LuaDamagePrototype|nil
function gameplay_statistics.on_entity_killed_entity(entity_that_died, entity_that_caused, damage_type_prot)
    if entity_that_died.type == "unit-spawner" and entity_that_caused.force == game.forces.player then
        gameplay_statistics.increment "total-spawners-killed"
    end
end

---@param tech LuaTechnology
function gameplay_statistics.on_research_completed(tech)
    gameplay_statistics.increment "tech-tree-completion"
end

---@param resource LuaEntity
function gameplay_statistics.on_resource_depleted(resource)
    gameplay_statistics.increment "total-resources-depleted"
end

---@param dungeon Dungeon
function gameplay_statistics.on_dungeon_looted(dungeon)
    gameplay_statistics.increment "total-dungeons-looted"
end

---@param item_name string
---@param prev_level int
---@param new_level int
function gameplay_statistics.on_item_buff_level_changed(item_name, prev_level, new_level)
    gameplay_statistics.increment("total-item-buff-level", new_level - prev_level)
end

---@param item_name string
function gameplay_statistics.on_item_rank_up(item_name)
    gameplay_statistics.increment "total-item-rank"
end

---@param rocket LuaEntity
---@param silo LuaEntity|nil
function gameplay_statistics.on_rocket_launched(rocket, silo)
    gameplay_statistics.increment "total-rockets-launched"
end



return gameplay_statistics
