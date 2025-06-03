
---@alias EntityRadii {[string]: number|number[]}
---@alias DungeonPrototype {wall_entities: EntityRadii, normal_loot_value: number, center_loot_value: number}

local lib = require "api.lib"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local terrain = require "api.terrain"

local dungeons = {}



function dungeons.init()
    for _, def in pairs(storage.dungeons.defs) do
        local prot = dungeons.new(def.wall_entities, def.normal_loot_value, def.center_loot_value)
        table.insert(storage.dungeons.prototypes[def.surface], prot)
    end
end

---@param wall_entities EntityRadii
---@param normal_loot_value number
---@param center_loot_value number
---@return DungeonPrototype
function dungeons.new(wall_entities, normal_loot_value, center_loot_value)
    return table.deepcopy {
        wall_entities = wall_entities,
        normal_loot_value = normal_loot_value,
        center_loot_value = center_loot_value,
    }
end

---@param surface LuaSurface
---@param hex_pos HexPos
---@param dungeon_size int
---@param dungeon_prot DungeonPrototype
function dungeons.spawn_hex(surface, hex_pos, dungeon_size, dungeon_prot)
    -- TODO
end



return dungeons


