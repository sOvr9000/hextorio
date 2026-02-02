
local event_system = require "api.event_system"
local lib = require "api.lib"
local entity_util  = require "api.entity_util"

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
---| "claimed-hexes-on"
---| "items-at-rank"
---| "total-item-rank"
---| "visit-planet"
---| "cover-ores-on"
---| "hex-cores-in-mode"
---| "make-trades"
---| "trades-found"
---| "sell-item-of-quality"
---| "biter-ramming"
---| "reach-hex-rank"
---| "hex-span"
---| "coins-in-inventory"
---| "loot-dungeons-on"
---| "loot-dungeons-off-planet"
---| "place-entity-on-planet"
---| "kill-entity"
---| "die-to-damage-type"
---| "use-capsule"
---| "kill-with-damage-type"
---| "mine-entity"
---| "die-to-railgun"
---| "place-tile"
---| "place-entity"
---| "favorite-trade"
---| "hex-core-trades-read"
---| "ping-trade"
---| "create-trade-map-tag"

---@alias GameplayStatisticValue string|number|nil

local recalculators = {} ---@type {[GameplayStatisticType]: fun(stat_value: GameplayStatisticValue): int}



function gameplay_statistics.register_events()
    event_system.register("entity-killed-entity", gameplay_statistics.on_entity_killed_entity)
    event_system.register("research-completed", gameplay_statistics.on_research_completed)
    event_system.register("dungeon-looted", gameplay_statistics.on_dungeon_looted)
    event_system.register("item-buff-level-changed", gameplay_statistics.on_item_buff_level_changed)
    event_system.register("item-rank-up", gameplay_statistics.on_item_rank_up)
    event_system.register("rocket-launched", gameplay_statistics.on_rocket_launched)
    event_system.register("entity-died", gameplay_statistics.on_entity_died)
    event_system.register("player-built-entity", gameplay_statistics.on_player_built_entity)
    event_system.register("player-mined-entity", gameplay_statistics.on_player_mined_entity)
    event_system.register("entity-picked-up", gameplay_statistics.on_entity_picked_up)
    event_system.register("surface-created", gameplay_statistics.on_surface_created)
    event_system.register("player-favorited-trade", gameplay_statistics.on_player_favorited_trade)
    event_system.register("player-coins-base-value-changed", gameplay_statistics.on_player_coins_base_value_changed)
    event_system.register("hex-rank-changed", gameplay_statistics.on_hex_rank_changed)
end

---Get a gameplay statistic.
---@param stat_type GameplayStatisticType
---@param stat_value GameplayStatisticValue|nil
---@return int current_value
function gameplay_statistics.get(stat_type, stat_value)
    local stats_storage = storage.gameplay_statistics
    if not stats_storage then return 0 end

    if stat_value == nil then
        return (stats_storage.stats or {})[stat_type] or 0
    else
        local stats_with_values = stats_storage.stats_with_values
        if not stats_with_values then return 0 end
        local stat_table = stats_with_values[stat_type]
        if not stat_table then return 0 end

        local key = gameplay_statistics.get_stat_value_key(stat_value)
        return stat_table[key] or 0
    end
end

---Set a gameplay statistic.
---@param stat_type GameplayStatisticType
---@param new_value int|nil
---@param stat_value GameplayStatisticValue|nil
function gameplay_statistics.set(stat_type, new_value, stat_value)
    local stats_storage = storage.gameplay_statistics
    if not stats_storage then
        stats_storage = {stats = {}, stats_with_values = {}}
        storage.gameplay_statistics = stats_storage
    end

    if stat_value == nil then
        if not stats_storage.stats then
            stats_storage.stats = {}
        end

        local prev = stats_storage.stats[stat_type] or 0
        if prev ~= new_value then
            stats_storage.stats[stat_type] = new_value
            event_system.trigger("gameplay-statistic-changed", stat_type, nil, prev, new_value)
        end
    else
        if not stats_storage.stats_with_values then
            stats_storage.stats_with_values = {}
        end
        if not stats_storage.stats_with_values[stat_type] then
            stats_storage.stats_with_values[stat_type] = {}
        end

        local key = gameplay_statistics.get_stat_value_key(stat_value)
        local prev = stats_storage.stats_with_values[stat_type][key] or 0
        if prev ~= new_value then
            stats_storage.stats_with_values[stat_type][key] = new_value
            event_system.trigger("gameplay-statistic-changed", stat_type, stat_value, prev, new_value)
        end
    end
end

---Increment a gameplay statistic.
---@param stat_type GameplayStatisticType
---@param amount int|nil
---@param stat_value GameplayStatisticValue|nil
function gameplay_statistics.increment(stat_type, amount, stat_value)
    if amount == 0 then return end
    gameplay_statistics.set(stat_type, gameplay_statistics.get(stat_type, stat_value) + (amount or 1), stat_value)
end

---Convert a stat value to a storage key.
---@param stat_value GameplayStatisticValue
---@return string|number
function gameplay_statistics.get_stat_value_key(stat_value)
    if stat_value == nil then
        return "none"
    end
    if type(stat_value) == "table" then
        ---@cast stat_value (string|number)[]
        return table.concat(stat_value, "-")
    end
    ---@cast stat_value string|number
    return stat_value
end

---Register a recalculator function for a statistic type.
---@param stat_type GameplayStatisticType
---@param func fun(stat_value: GameplayStatisticValue): int
function gameplay_statistics.define_recalculator(stat_type, func)
    recalculators[stat_type] = func
end

---Recalculate a specific statistic from scratch.
---@param stat_type GameplayStatisticType
---@param stat_value GameplayStatisticValue|nil
function gameplay_statistics.recalculate(stat_type, stat_value)
    local func = recalculators[stat_type]
    if not func then
        return
    end

    local progress = func(stat_value)
    gameplay_statistics.set(stat_type, progress, stat_value)

    lib.log("gameplay_statistics.recalculate: Recalculated " .. stat_type .. " with value " .. serpent.line(stat_value or {}) .. ". New value: " .. progress)
end

---Get all unique statistic type-value pairs currently tracked.
---@return {stat_type: GameplayStatisticType, stat_value: GameplayStatisticValue}[]
function gameplay_statistics.get_all_tracked_statistics()
    local stats_list = {}
    local stats_storage = storage.gameplay_statistics

    if not stats_storage then return stats_list end

    if stats_storage.stats then
        for stat_type, _ in pairs(stats_storage.stats) do
            table.insert(stats_list, {stat_type = stat_type, stat_value = nil})
        end
    end

    if stats_storage.stats_with_values then
        for stat_type, stat_table in pairs(stats_storage.stats_with_values) do
            for key, _ in pairs(stat_table) do
                local stat_value
                if key == "none" then
                    stat_value = nil
                elseif string.find(key, "-") then
                    local parts = {}
                    for part in string.gmatch(key, "[^-]+") do
                        table.insert(parts, part)
                    end
                    stat_value = parts
                else
                    stat_value = key
                end
                table.insert(stats_list, {stat_type = stat_type, stat_value = stat_value})
            end
        end
    end

    return stats_list
end

---Recalculate all statistics that have recalculator functions.
function gameplay_statistics.recalculate_all()
    local stats_list = gameplay_statistics.get_all_tracked_statistics()
    for _, stat_info in pairs(stats_list) do
        if recalculators[stat_info.stat_type] then
            gameplay_statistics.recalculate(stat_info.stat_type, stat_info.stat_value)
        end
    end
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
    gameplay_statistics.increment("loot-dungeons-on", 1, dungeon.surface.name)

    local passed = true
    for _, player in pairs(game.connected_players) do
        if player.character and player.character.surface == dungeon.surface then
            passed = false
        end
    end

    if passed then
        gameplay_statistics.increment "loot-dungeons-off-planet"
    end
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

---@param entity LuaEntity
function gameplay_statistics.on_entity_died(entity)
    if not entity.valid then return end
    if entity.type == "mining-drill" then
        local now_uncovered = entity_util.track_ores_covered_by_drill(entity)
        gameplay_statistics.increment("cover-ores-on", -now_uncovered, entity.surface.name)
    end
end

---@param player LuaPlayer
---@param entity LuaEntity
function gameplay_statistics.on_player_built_entity(player, entity)
    if not entity.valid then return end
    gameplay_statistics.increment("place-entity", 1, entity.name)
    gameplay_statistics.increment("place-entity-on-planet", 1, {entity.name, entity.surface.name})

    if entity.type == "mining-drill" then
        local now_covered = entity_util.track_ores_covered_by_drill(entity)
        gameplay_statistics.increment("cover-ores-on", now_covered, entity.surface.name)
    end
end

---@param player LuaPlayer
---@param entity LuaEntity
function gameplay_statistics.on_player_mined_entity(player, entity)
    gameplay_statistics.increment("mine-entity", 1, entity.name)
end

---@param entity LuaEntity
function gameplay_statistics.on_entity_picked_up(entity)
    if not entity.valid then return end
    gameplay_statistics.increment("place-entity", -1, entity.name)
    gameplay_statistics.increment("place-entity-on-planet", -1, {entity.name, entity.surface.name})

    if entity.type == "mining-drill" then
        local now_uncovered = entity_util.track_ores_covered_by_drill(entity)
        gameplay_statistics.increment("cover-ores-on", -now_uncovered, entity.surface.name)
    end
end

---@param surface LuaSurface
function gameplay_statistics.on_surface_created(surface)
    gameplay_statistics.set("visit-planet", 1, surface.name)
end

---@param player LuaPlayer
---@param trade any
function gameplay_statistics.on_player_favorited_trade(player, trade)
    gameplay_statistics.set("favorite-trade", 1)
end

---@param player LuaPlayer
---@param coin_value int
function gameplay_statistics.on_player_coins_base_value_changed(player, coin_value)
    gameplay_statistics.set("coins-in-inventory", coin_value)
end

---@param prev_val int
---@param new_val int
function gameplay_statistics.on_hex_rank_changed(prev_val, new_val)
    gameplay_statistics.set("reach-hex-rank", new_val)
end



gameplay_statistics.define_recalculator("visit-planet", function(stat_value)
    local surface_name = stat_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    return 1
end)

gameplay_statistics.define_recalculator("items-at-rank", function(stat_value)
    local rank = stat_value
    local total = 0
    for item_name, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if lib.is_catalog_item(item_name) then
            if rank_obj.rank >= rank then
                total = total + 1
            end
        end
    end
    return total
end)

gameplay_statistics.define_recalculator("total-item-rank", function(stat_value)
    local total = 0
    for item_name, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if lib.is_catalog_item(item_name) then
            total = total + rank_obj.rank - 1
        end
    end
    return total
end)

gameplay_statistics.define_recalculator("claimed-hexes-on", function(stat_value)
    local surface_name = stat_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    local surface_hexes = storage.hex_grid.surface_hexes[surface.index]
    if not surface_hexes then return 0 end

    local total = 0
    for _, Q in pairs(surface_hexes) do
        for _, state in pairs(Q) do
            if state.claimed then
                total = total + 1
            end
        end
    end

    return total
end)

gameplay_statistics.define_recalculator("total-hexes-claimed", function(stat_value)
    local total = 0
    for surface_id, hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(hexes) do
            for _, state in pairs(Q) do
                if state.claimed then
                    total = total + 1
                end
            end
        end
    end
    return total
end)

gameplay_statistics.define_recalculator("total-strongbox-level", function(stat_value)
    local total_level = 0
    for surface_id, hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(hexes) do
            for _, state in pairs(Q) do
                if state.strongboxes then
                    for _, sb_entity in pairs(state.strongboxes) do
                        total_level = total_level + (entity_util.get_tier_of_strongbox(sb_entity) or 1) - 1
                    end
                end
            end
        end
    end
    return total_level
end)

gameplay_statistics.define_recalculator("cover-ores-on", function(stat_value)
    local surface_name = stat_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    local total_ores = 0
    for _, entity in pairs(surface.find_entities_filtered {
        type = "mining-drill",
    }) do
        total_ores = total_ores + entity_util.track_ores_covered_by_drill(entity)
    end

    return total_ores
end)



return gameplay_statistics
