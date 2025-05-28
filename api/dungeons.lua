
---@alias EntityRadii {[string]: number|number[]}
---@alias EntityCounts {[string]: {min: int, max: int}}
---@alias DungeonHex {outer_entities: EntityRadii, inner_entities: EntityCounts, loot_value: number, loot_wc: table}
---@alias DungeonHexWeights {hexes: DungeonHex[], weights: number[]}
---@alias DungeonPrototype {walls: DungeonHexWeights, walls_wc: table, interior: DungeonHexWeights, interior_wc: table, center: DungeonHexWeights, center_wc: table, center_size: int}

local lib = require "api.lib"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"

local dungeons = {}



function dungeons.init()
    for _, def in pairs(storage.dungeons.defs) do
        local walls = dungeons.new_hex(def.walls.outer_entities, def.walls.inner_entities, def.walls.loot_value)
        local interior = dungeons.new_hex(def.interior.outer_entities, def.interior.inner_entities, def.interior.loot_value)
        local center = dungeons.new_hex(def.center.outer_entities, def.center.inner_entities, def.center.loot_value)
        local center_size = def.center_size
        local prot = dungeons.new(walls, interior, center, center_size)
        table.insert(storage.dungeons.prototypes[def.surface], prot)
    end
end

---@param walls DungeonHex[]
---@param interior DungeonHex[]
---@param center DungeonHex[]
---@param center_size DungeonHex[]
---@return DungeonPrototype
function dungeons.new(walls, interior, center, center_size)
    return table.deepcopy {
        walls = walls,
        interior = interior,
    }
end

---@param outer_entities EntityRadii
---@param inner_entities EntityCounts
---@param loot_value any
---@return table
function dungeons.new_hex(outer_entities, inner_entities, loot_value)
    local dhex = {
        outer_entities = outer_entities,
        inner_entities = inner_entities,
        loot_value = loot_value,
    }
    dhex.loot_wc = {} -- TODO
    return dhex
end

---@param surface LuaSurface
---@param hex_pos {q: int, r: int}
---@param size int
---@param dungeon_prot DungeonPrototype
function dungeons.spawn_hex(surface, hex_pos, size, dungeon_prot)
    -- todo
end



return dungeons


