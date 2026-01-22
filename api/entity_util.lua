
local entity_util = {}



---Get the tier of a strongbox entity from its name. Return nil if the entity is not a strongbox.
---@param sb_entity LuaEntity
---@return int|nil
function entity_util.get_tier_of_strongbox(sb_entity)
    return tonumber(sb_entity.name:sub(16))
end

---@param surface_id int
---@return IndexMap
function entity_util.get_covered_ore_counters(surface_id)
    local ore_counters = storage.hex_grid.ores_covered
    if not ore_counters then
        ore_counters = {} ---@type {[int]: IndexMap}
        storage.hex_grid.ores_covered = ore_counters
    end

    local surface_ore_counters = ore_counters[surface_id]
    if not surface_ore_counters then
        surface_ore_counters = {}
        ore_counters[surface_id] = surface_ore_counters
    end

    return surface_ore_counters
end

---Get a list of ore entities that are within the given drill's mining area.
---@param drill_entity LuaEntity
---@return LuaEntity[]
function entity_util.get_ores_within_drill_coverage(drill_entity)
    if not drill_entity or not drill_entity.valid or drill_entity.type ~= "mining-drill" then return {} end

    local prototype = drill_entity.prototype
    local mining_radius = prototype.mining_drill_radius
    if not mining_radius then return {} end

    local resources = drill_entity.surface.find_entities_filtered{
        type = "resource",
        area = {
            left_top = {
                x = drill_entity.position.x - mining_radius,
                y = drill_entity.position.y - mining_radius,
            },
            right_bottom = {
                x = drill_entity.position.x + mining_radius,
                y = drill_entity.position.y + mining_radius,
            },
        },
    }

    -- Exclude resource wells like crude oil or lithium brine
    local solid_ores = {}
    for _, resource in pairs(resources) do
        if resource.prototype.resource_category == "basic-solid" then
            table.insert(solid_ores, resource)
        end
    end

    return solid_ores
end

---Add ores to the total ores covered counter.
---@param drill_entity LuaEntity
---@return int now_covered How many ores are now covered by the drill entity when they weren't previously covered by any drills.
function entity_util.track_ores_covered_by_drill(drill_entity)
    local ore_counters = entity_util.get_covered_ore_counters(drill_entity.surface.index)
    local ore_entities = entity_util.get_ores_within_drill_coverage(drill_entity)

    local now_covered = 0
    for _, e in pairs(ore_entities) do
        if entity_util.track_ore_entity_in_coverage(e, ore_counters) then
            now_covered = now_covered + 1
        end
    end

    return now_covered
end

---Remove ores from the total ores covered counter.
---@param drill_entity LuaEntity
---@return int now_uncovered How many ores are no longer covered by any drill entities when they were previously covered by this drill.
function entity_util.untrack_ores_covered_by_drill(drill_entity)
    local ore_counters = entity_util.get_covered_ore_counters(drill_entity.surface.index)
    local ore_entities = entity_util.get_ores_within_drill_coverage(drill_entity)

    local now_uncovered = 0
    for _, e in pairs(ore_entities) do
        if entity_util.untrack_ore_entity_in_coverage(e, ore_counters) then
            now_uncovered = now_uncovered + 1
        end
    end

    return now_uncovered
end

---Add an ore entity to the covered ores counters.  Return whether the counter for the given entity was 0 (or nil) before increasing.
---@param ore_entity LuaEntity
---@param ore_counters IndexMap|nil
---@return boolean
function entity_util.track_ore_entity_in_coverage(ore_entity, ore_counters)
    if not ore_entity.valid then return false end
    ore_counters = ore_counters or entity_util.get_covered_ore_counters(ore_entity.surface.index)

    local Y = ore_counters[ore_entity.position.y]
    if not Y then
        Y = {}
        ore_counters[ore_entity.position.y] = Y
    end

    local prev = Y[ore_entity.position.x] or 0
    Y[ore_entity.position.x] = prev + 1

    -- game.print("entity at " .. ore_entity.gps_tag .. " now has counter = " .. Y[ore_entity.position.x])

    return prev == 0
end

---Remove an ore entity from the covered ores counters.  Return whether the counter for the given entity became zero (nil) after decreasing.
---@param ore_entity LuaEntity
---@param ore_counters IndexMap|nil
---@return boolean
function entity_util.untrack_ore_entity_in_coverage(ore_entity, ore_counters)
    if not ore_entity.valid then return false end
    ore_counters = ore_counters or entity_util.get_covered_ore_counters(ore_entity.surface.index)

    local Y = ore_counters[ore_entity.position.y]
    if not Y then return false end

    local prev = Y[ore_entity.position.x] or 0
    Y[ore_entity.position.x] = math.max(0, prev - 1)

    -- game.print("entity at " .. ore_entity.gps_tag .. " now has counter = " .. Y[ore_entity.position.x])

    if Y[ore_entity.position.x] <= 0 then
        Y[ore_entity.position.x] = nil
    end

    return prev == 1
end



return entity_util
