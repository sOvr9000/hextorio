
local event_system = require "api.event_system"
local gameplay_statistics = require "api.gameplay_statistics"
local lib = require "api.lib"
local entity_util = require "api.entity_util"
local dungeons    = require "api.dungeons"

local recalculators = {}



---@alias GameplayStatisticRecalculator fun(stat_value: any): int

---@type {[GameplayStatisticType]: GameplayStatisticRecalculator}
local recalculator_functions = {}

function recalculators.register_events()
    event_system.register("recalculate-statistic", gameplay_statistics.on_recalculate_statistic)
    event_system.register("recalculate-all-statistics", gameplay_statistics.on_recalculate_all_statistics)
end

---Register a recalculator function for a statistic type.
---@param stat_type GameplayStatisticType
---@param func GameplayStatisticRecalculator
function recalculators.define_recalculator(stat_type, func)
    recalculator_functions[stat_type] = func
end

---@param stat_type GameplayStatisticType
---@param stat_value GameplayStatisticValue
function gameplay_statistics.on_recalculate_statistic(stat_type, stat_value)
    local func = recalculator_functions[stat_type]
    if not func then
        lib.log("gameplay_statistics_recalculators.on_recalculate_statistics: Missing recalculator for stat type " .. stat_type)
        return
    end

    local prev = gameplay_statistics.get(stat_type, stat_value)
    local new_value = func(stat_value)
    gameplay_statistics.set(stat_type, new_value, stat_value)

    lib.log("gameplay_statistics_recalculators.on_recalculate_statistics: Recalculated " .. stat_type .. " with value " .. serpent.line(stat_value or {}) .. ". Prev value: " .. prev .. ", New value: " .. new_value)
end



recalculators.define_recalculator("visit-planet", function(stat_value)
    local surface_name = stat_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    return 1
end)

recalculators.define_recalculator("items-at-rank", function(stat_value)
    local rank = stat_value
    local total = 0
    for _, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if rank_obj.rank >= rank then
            total = total + 1
        end
    end
    return total
end)

recalculators.define_recalculator("all-items-at-rank", function(stat_value)
    local rank = stat_value
    local progress = 1
    for _, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if rank_obj.rank < rank then
            progress = 0
            break
        end
    end
    return progress
end)

recalculators.define_recalculator("total-item-rank", function(stat_value)
    local total = 0
    for item_name, rank_obj in pairs(storage.item_ranks.item_ranks) do
        total = total + rank_obj.rank - 1
    end
    return total
end)

recalculators.define_recalculator("claimed-hexes-on", function(stat_value)
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

recalculators.define_recalculator("total-hexes-claimed", function(stat_value)
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

recalculators.define_recalculator("total-strongbox-level", function(stat_value)
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

recalculators.define_recalculator("total-dungeons-looted", function(stat_value)
    local total = 0
    for _, surface in pairs(game.surfaces) do
        if lib.is_vanilla_planet_name(surface.name) then
            for _, dungeon in pairs(dungeons.get_dungeons_on_surface(surface.index)) do
                if dungeon.is_looted then
                    total = total + 1
                end
            end
        end
    end
    return total
end)

recalculators.define_recalculator("total-spawners-killed", function(stat_value)
    local entity_names = {}
    for _, prot in pairs(prototypes.entity) do
        if prot.type == "unit-spawner" then
            log(prot.name)
            entity_names[#entity_names+1] = prot.name
        end
    end

    local total = 0
    for _, surface in pairs(game.surfaces) do
        local flow_stats = game.forces.player.get_kill_count_statistics(surface)
        for _, entity_name in pairs(entity_names) do
            total = total + flow_stats.get_input_count(entity_name)
        end
    end

    return total
end)

recalculators.define_recalculator("total-rockets-launched", function(stat_value)
    local total = 0
    for _, surface in pairs(game.surfaces) do
        local flow_stats = game.forces.player.get_item_production_statistics(surface)
        total = total + flow_stats.get_input_count "rocket-part"
    end
    total = math.floor(total / 50) -- approximation
    return total
end)

recalculators.define_recalculator("cover-ores-on", function(stat_value)
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

recalculators.define_recalculator("tech-tree-completion", function(stat_value)
    local total = 0
    for _, tech in pairs(game.forces.player.technologies) do
        if tech.researched then
            total = total + 1
        end
    end
    return total
end)



return recalculators
