
local lib = require "api.lib"
local axial = require "api.axial"
local hex_island = require "api.hex_island"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local loot_tables = require "api.loot_tables"
local terrain = require "api.terrain"
local hex_maze = require "api.hex_maze"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"
local coin_tiers = require "api.coin_tiers"
local inventories = require "api.inventories"

local TURRET_RELOAD_INTERVAL = 3600

local dungeons = {}



---@alias EntityRadii {[string]: number[]}
---@alias MapPositionAndDirection {position: MapPosition, direction: defines.direction}
---@alias MapPositionSet {[int]: {[int]: true}}

---@class AmmoReloadParameters
---@field bullet_type string|nil Magazine item name for gun turrets
---@field flamethrower_type string|nil Fluid name for flamethrower turrets
---@field rocket_type string|nil Rocket item name for rocket turrets
---@field railgun_type string|nil Railgun shell item name for railgun turrets
---@field bullet_count int|nil Count of magazines to load per reload
---@field flamethrower_count int|nil Count of fluid to load per reload
---@field rocket_count int|nil Count of rockets to load per reload
---@field railgun_count int|nil Count of shells to load per reload

---@class DungeonPrototype
---@field wall_entities EntityRadii Entity names mapped to arrays of radii for spawning walls/turrets around hex borders
---@field loot_value number Approximate total loot value for each dungeon chest
---@field rolls int Average number of times items are sampled for loot generation, affecting overall number of types of items per chest
---@field qualities string[] Quality names that can be randomly assigned to spawned entities
---@field tile_type string Tile name used for the dungeon floor
---@field ammo AmmoReloadParameters Configuration for reloading turrets
---@field chests_per_hex int Number of loot chests that spawn per hex in the dungeon
---@field amount_scaling number Divisor of base item value per stack, and multiplier of item count per stack
---@field item_rolls {[string]: number} Item names mapped to chance values for extra bonus item rolls

---@class Dungeon
---@field surface LuaSurface The surface where this dungeon exists
---@field prototype_idx int Index into the prototypes array for this dungeon
---@field id int Unique identifier for this dungeon, used as an index in storage.dungeons.dungeons
---@field maze HexMaze|nil Maze structure defining the occupied hexes and open wall sections between dungeon hexes
---@field turrets LuaEntity[] List of turret entities in this dungeon
---@field walls LuaEntity[] List of wall entities in this dungeon
---@field loot_chests LuaEntity[] List of dungeon chest entities in this dungeon
---@field last_turret_reload int Last tick when this dungeon's turrets were reloaded
---@field internal_hexes HexSet Hex positions that are fully surrounded by other hexes within this same dungeon
---@field is_looted boolean|nil Whether all loot chests have been picked up



function dungeons.register_events()
    event_system.register("dungeon-update", function()
        if #game.connected_players == 0 then return end
        local player = game.connected_players[(game.tick / 300) % #game.connected_players + 1]
        if not player or lib.is_space_platform(player.surface.name) then return end

        local transformation = terrain.get_surface_transformation(player.surface)
        local hex_pos = axial.get_hex_containing(player.position, transformation.scale, transformation.rotation)
        for _, hex in pairs(axial.ring(hex_pos, 2)) do
            local dungeon = dungeons.get_dungeon_at_hex_pos(player.surface.index, hex, false)
            if dungeon then
                dungeons.try_reload_turrets(dungeon)
            end
        end
    end)

    event_system.register("entity-picked-up", function(entity)
        if entity.name == "dungeon-chest" then
            dungeons.on_dungeon_chest_picked_up(entity)
        end
    end)

    event_system.register("hex-generated", function(surface_id, hex_pos)
        local used = storage.dungeons.used_hexes[surface_id]
        if not used then
            used = {}
            storage.dungeons.used_hexes[surface_id] = used
        end

        -- Doing this prevents dungeons from trying to generate on top of hexes that have already generated.
        -- We don't want to see dungeons popping up out of nowhere on top of your factory if the newly generating dungeons are large enough to do so.
        hex_sets.add(used, hex_pos)
    end)

    event_system.register("runtime-setting-changed-dungeon-min-dist", function()
        storage.dungeons.min_dist = lib.runtime_setting_value "dungeon-min-dist"
    end)
end

function dungeons.init()
    dungeons.init_prototypes()

    storage.dungeons.dungeons = {} --[=[@as Dungeon[]]=]
    storage.dungeons.dungeon_idx_by_position = {} --[[@as {[int]: IndexMap}]]
    storage.dungeons.used_hexes = {} --[[@as {[int]: HexSet}]]
    storage.dungeons.min_dist = lib.runtime_setting_value "dungeon-min-dist"
end

function dungeons.init_prototypes()
    storage.dungeons.prototypes = {} --[[@as {[string]: DungeonPrototype[]}]]

    for _, def in pairs(storage.dungeons.defs) do
        local prot = dungeons.new_prototype(def.wall_entities, def.loot_value, def.rolls, def.chests, def.amount_scaling, def.qualities, def.tile_type, def.ammo, def.item_rolls)
        if not storage.dungeons.prototypes[def.surface_name] then
            storage.dungeons.prototypes[def.surface_name] = {}
        end
        table.insert(storage.dungeons.prototypes[def.surface_name], prot)
    end
end

---@param wall_entities EntityRadii
---@param loot_value number
---@param rolls int
---@param chests int
---@param qualities string[]
---@param tile_type string
---@param ammo AmmoReloadParameters
---@param item_rolls {[string]: number}
---@return DungeonPrototype
function dungeons.new_prototype(wall_entities, loot_value, rolls, chests, amount_scaling, qualities, tile_type, ammo, item_rolls)
    local prot = table.deepcopy {
        wall_entities = wall_entities,
        loot_value = loot_value,
        rolls = rolls,
        chests_per_hex = chests,
        amount_scaling = amount_scaling,
        qualities = qualities,
        tile_type = tile_type,
        ammo = ammo,
        item_rolls = item_rolls,
    }

    return prot
end

---Create a new dungeon.
---@param surface LuaSurface
---@param prot DungeonPrototype
---@return Dungeon|nil
function dungeons.new(surface, prot)
    local prot_idx = lib.table_index(storage.dungeons.prototypes[surface.name], prot)
    if not prot_idx then
        lib.log_error("Dungeon prototype not found for surface " .. surface.name)
        return
    end

    local dungeon = {
        surface = surface,
        prototype_idx = prot_idx,
        id = #storage.dungeons.dungeons + 1,
        turrets = {},
        walls = {},
        loot_chests = {},
        last_turret_reload = 0,
        internal_hexes = {},
    }

    return dungeon
end

---Get the dungeon that occupies a given hex position.
---@param surface_id int
---@param hex_pos HexPos
---@param try_generate boolean|nil Defaults to false. If true, then generate one if it doesn't yet exist and can be generated. Return nil if a dungeon cannot be generated.
---@return Dungeon|nil
function dungeons.get_dungeon_at_hex_pos(surface_id, hex_pos, try_generate)
    local dungeon_idx = storage.dungeons.dungeon_idx_by_position[surface_id]

    -- Always create a mapping for an unseen surface.
    if not dungeon_idx then
        dungeon_idx = {}
        storage.dungeons.dungeon_idx_by_position[surface_id] = dungeon_idx
    end

    -- If there is already a dungeon at this position, return it.
    if dungeon_idx[hex_pos.q] and dungeon_idx[hex_pos.q][hex_pos.r] then
        local idx = dungeon_idx[hex_pos.q][hex_pos.r]
        local dungeon = storage.dungeons.dungeons[idx]
        if dungeon then return dungeon end
    end

    -- If it's a used position, return nil without errors.
    local used_hexes = storage.dungeons.used_hexes[surface_id]
    if used_hexes and hex_sets.contains(used_hexes, hex_pos) then
        return
    end

    if not try_generate then return end

    local dist = axial.distance({q=0, r=0}, hex_pos)
    if dist < storage.dungeons.min_dist then return end

    -- Otherwise, try to generate one.
    local surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("dungeons.get_dungeon_at_hex_pos: Surface not found with id = " .. surface_id)
        return
    end

    local prot = dungeons.random_prototype(surface.name, hex_pos)
    if not prot then
        lib.log_error("dungeons.get_dungeon_at_hex_pos: Could not find a prototype to use.")
        return
    end

    local dungeon = dungeons.new(surface, prot)
    if not dungeon then
        lib.log_error("dungeons.get_dungeon_at_hex_pos: Failed to generate dungeon for surface " .. surface.name)
        return
    end

    -- Add the dungeon to the dungeons list.
    storage.dungeons.dungeons[dungeon.id] = dungeon

    -- Generate the maze immediately.
    if not dungeons.init_maze(dungeon, hex_pos) then
        lib.log_error("dungeons.get_dungeon_at_hex_pos: Maze failed to generate.")
        return
    end

    return dungeon
end

---Return whether the given hex is occupied by a dungeon.
---@param surface_id any
---@param hex_pos any
---@return boolean
function dungeons.is_dungeon_hex(surface_id, hex_pos)
    local dungeon_idx = storage.dungeons.dungeon_idx_by_position[surface_id]

    -- Always create a mapping for an unseen surface.
    if not dungeon_idx then
        dungeon_idx = {}
        storage.dungeons.dungeon_idx_by_position[surface_id] = dungeon_idx
    end

    -- If there is a dungeon at this position, return true.
    if dungeon_idx[hex_pos.q] and dungeon_idx[hex_pos.q][hex_pos.r] then
        return true
        -- local idx = dungeon_idx[hex_pos.q][hex_pos.r]
        -- local dungeon = storage.dungeons.dungeons[idx]
        -- if dungeon then return true end
    end

    return false
end

---Get a random dungeon prototype for a given surface.
---@param surface_name string
---@param hex_pos HexPos
---@return DungeonPrototype|nil
function dungeons.random_prototype(surface_name, hex_pos)
    -- There can be some logic based on hex position.  Maybe use tougher dungeon prototypes at greater distances?
    local prots = storage.dungeons.prototypes[surface_name]
    if not prots or #prots == 0 then
        lib.log_error("dungeons.random_prototype: No dungeon prototypes found for surface " .. surface_name)
        return
    end
    return prots[math.random(1, #prots)]
end

---Generate the hex tiles and entities for a dungeon.
---@param surface_id int
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@param hex_stroke_width number
function dungeons.spawn_hex(surface_id, hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)
    local dungeon = dungeons.get_dungeon_at_hex_pos(surface_id, hex_pos, true)
    if not dungeon then return end
    local prot = dungeons.get_prototype_of_dungeon(dungeon)
    if not prot then return end
    local surface = game.get_surface(surface_id)
    if not surface then return end

    -- Generate tiles
    local tile_positions = axial.get_hex_tile_positions(hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)
    terrain.set_tiles(surface_id, tile_positions, prot.tile_type)
    dungeons.fill_edges_between_dungeon_hexes(dungeon, hex_pos, prot.tile_type)
    dungeons.fill_corners_between_dungeon_hexes(dungeon, hex_pos, prot.tile_type)

    -- Generate turrets and other entities
    dungeons.spawn_entities(dungeon, hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)

    -- Spawn loot
    dungeons.spawn_loot(dungeon, hex_pos, hex_grid_scale, hex_grid_rotation)

    if surface.name == "fulgora" then
        local transformation = terrain.get_surface_transformation(surface_id)
        local hex_center = axial.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
        surface.create_entity {
            name = "fulgoran-ruin-attractor",
            quality = "rare",
            position = {x = hex_center.x, y = hex_center.y - 4},
        }
    end
end

---Spawn the turrets on a hex in a dungeon.
---@param dungeon Dungeon
---@param hex_pos HexPos
function dungeons.spawn_entities(dungeon, hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)
    local prot = dungeons.get_prototype_of_dungeon(dungeon)
    if not prot then
        lib.log_error("dungeons.spawn_entities: Tile not found for hex " .. hex_pos.q .. ", " .. hex_pos.r)
        return
    end
    if not hex_maze.tile_exists_at(dungeon.maze, hex_pos) then
        lib.log_error("dungeons.spawn_entities: Tile not found for hex " .. hex_pos.q .. ", " .. hex_pos.r)
        return
    end

    local tile = hex_maze.get_tile(dungeon.maze, hex_pos)
    local surface = dungeon.surface
    local hex_center = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
    local directions = {}

    for dir, open in ipairs(tile.open) do
        if not open then -- Only spawn turrets in directions that are NOT open.
            directions[dir] = true
        end
    end

    local wall_entities = {}
    local turret_entities = {}
    local used_positions = {}
    for entity_name, radii in pairs(prot.wall_entities) do
        local entity_prot = prototypes["entity"][entity_name]
        if entity_prot then
            local max_dim = math.max(entity_prot.tile_width, entity_prot.tile_height)
            for _, radius in pairs(radii) do
                local positions = axial.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, max_dim * 1.5, hex_stroke_width + radius, false)
                positions = axial.filter_positions_by_directions(hex_center, positions, directions, hex_grid_rotation)
                for x, X in pairs(used_positions) do
                    if positions[x] then
                        for y, _ in pairs(X) do
                            positions[x][y] = nil
                        end
                    end
                end
                local entity_positions, _used_positions = dungeons.get_entity_positions(hex_center, positions, max_dim)
                for x, X in pairs(_used_positions) do
                    if not used_positions[x] then
                        used_positions[x] = {}
                    end
                    for y, _ in pairs(X) do
                        used_positions[x][y] = true
                    end
                end
                for _, pos_dir in pairs(entity_positions) do
                    local quality = prot.qualities[math.random(1, #prot.qualities)]
                    local entity = surface.create_entity {
                        name = entity_name,
                        position = pos_dir.position,
                        direction = pos_dir.direction,
                        quality = quality,
                    }
                    if entity then
                        if entity.prototype.turret_range then
                            table.insert(dungeon.turrets, entity)
                            table.insert(turret_entities, entity)
                        else
                            table.insert(dungeon.walls, entity)
                            table.insert(wall_entities, entity)
                        end
                    end
                end
            end
        end
    end

    -- Initial ammo load of turrets
    lib.reload_turrets(turret_entities, prot.ammo)
end

---Fill the edges between dungeon hexes.
---@param dungeon Dungeon
---@param hex_pos HexPos
---@param tile_type string
function dungeons.fill_edges_between_dungeon_hexes(dungeon, hex_pos, tile_type)
    local adj_hexes = axial.get_adjacent_hexes(hex_pos)
    for _, adj in pairs(adj_hexes) do
        if dungeon.maze.tiles_by_position[adj.q] and dungeon.maze.tiles_by_position[adj.q][adj.r] then
            terrain.fill_edges_between_hexes(dungeon.surface, adj, hex_pos, tile_type)
        end
    end
end

---Fill the corners between dungeon hexes.
---@param dungeon Dungeon
---@param hex_pos HexPos
---@param tile_type string
function dungeons.fill_corners_between_dungeon_hexes(dungeon, hex_pos, tile_type)
    local adj_hexes = axial.get_adjacent_hexes(hex_pos)
    for i, adj in ipairs(adj_hexes) do
        if dungeon.maze.tiles_by_position[adj.q] and dungeon.maze.tiles_by_position[adj.q][adj.r] then
            for j, adj2 in ipairs(adj_hexes) do
                if i ~= j then
                    if dungeon.maze.tiles_by_position[adj2.q] and dungeon.maze.tiles_by_position[adj2.q][adj2.r] then
                        terrain.fill_corners_between_hexes(dungeon.surface, adj, adj2, hex_pos, tile_type)
                    end
                end
            end
        end
    end
end

---Initialize the maze for a dungeon and return whether it was successfully generated.
---@param dungeon Dungeon
---@param start_pos HexPos
---@return boolean
function dungeons.init_maze(dungeon, start_pos)
    local prot = dungeons.get_prototype_of_dungeon(dungeon)
    if not prot then
        lib.log("dungeons.init_maze: Could not find dungeon prototype")
        return false
    end

    local dist = axial.distance(start_pos, {q=0, r=0})
    -- local size = 2 + math.floor(0.5 + dist ^ 0.5)
    local size = 4

    local allowed_positions, perimeter = dungeons.get_positions_for_maze(dungeon.surface.index, start_pos, size, 3)

    local used_hexes = storage.dungeons.used_hexes[dungeon.surface.index]
    if not used_hexes then
        used_hexes = {}
        storage.dungeons.used_hexes[dungeon.surface.index] = used_hexes
    end

    -- Mark all perimeter hexes outside of generated positions as used.
    for _, hex in pairs(perimeter) do
        hex_sets.add(used_hexes, hex)
    end

    -- Mark the sampled positions as used.
    for q, Q in pairs(allowed_positions) do
        for r, _ in pairs(Q) do
            hex_sets.add(used_hexes, {q=q, r=r})
        end
    end

    -- Set the sampled positions to map to the dungeon index.
    local dungeon_idx = storage.dungeons.dungeon_idx_by_position[dungeon.surface.index]
    if not dungeon_idx then
        dungeon_idx = {}
        storage.dungeons.dungeon_idx_by_position[dungeon.surface.index] = dungeon_idx
    end
    for q, Q in pairs(allowed_positions) do
        if not dungeon_idx[q] then
            dungeon_idx[q] = {}
        end
        for r, _ in pairs(Q) do
            dungeon_idx[q][r] = dungeon.id
        end
    end

    -- Attempt to generate the maze.
    dungeon.maze = hex_maze.new(allowed_positions)
    if not hex_maze.generate(dungeon.maze) then
        lib.log_error("dungeons.init_maze: Failed to generate dungeon maze")
        return false
    end

    -- Determine which hexes are internal.
    -- for _, tile in pairs(dungeon.maze.tiles) do
    --     local is_internal = #hex_maze.get_adjacent_tiles(dungeon.maze, tile.pos) == 6
    --     if is_internal then
    --         hex_sets.add(dungeon.internal_hexes, tile.pos)
    --     end
    -- end

    return true
end

---Randomly sample allowed positions for a maze to be generated for a dungeon, and also return the resulting adjacent hexes (which weren't included in the selected positions) around the selected positions.
---@param surface_id int
---@param start_pos HexPos
---@param amount int
---@return HexSet, HexPos[]
function dungeons.get_positions_for_maze(surface_id, start_pos, amount, max_dist)
    local surface = game.get_surface(surface_id)
    if not surface then return {}, {} end

    -- local planet_size = lib.startup_setting_value("planet-size-" .. surface.name)
    local min_dist = lib.runtime_setting_value "dungeon-min-dist"

    local used_hexes = storage.dungeons.used_hexes[surface_id] or {}
    local positions = {} --[[@as HexSet]]
    local visited = {} --[[@as HexSet]]
    local open = {start_pos} --[=[@as HexPos[]]=]

    for _ = 1, amount do
        if #open == 0 then break end

        local weights = {}
        for i, pos in ipairs(open) do
            local dist = axial.distance(pos, start_pos)
            weights[i] = 1 / math.max(1, dist * dist) -- dist is only zero on the start_pos
        end
        local wc = weighted_choice.new(weights)

        local idx = weighted_choice.choice(wc)
        local cur = table.remove(open, idx)

        -- Add unvisited, unused adjacent hexes to the open list.
        local adj_hexes = axial.get_adjacent_hexes(cur)
        for _, adj in pairs(adj_hexes) do
            local dist = axial.distance(adj, {q=0, r=0})
            if dist >= min_dist and hex_island.is_land_hex(surface.name, adj) and axial.distance(adj, start_pos) <= max_dist then
                local is_visited = hex_sets.contains(visited, adj)
                local is_used = hex_sets.contains(used_hexes, adj)
                if not is_visited and not is_used then
                    table.insert(open, adj)
                    hex_sets.add(visited, adj)
                end
            end
        end

        -- Add the current hex to the positions list.
        hex_sets.add(positions, cur)
    end

    return positions, open
end

---Return whether the given hex position is used by a dungeon.
---@param surface_id int
---@param hex_pos HexPos
---@return boolean
function dungeons.is_hex_pos_used(surface_id, hex_pos)
    local used = storage.dungeons.used_hexes[surface_id]
    if used and hex_sets.contains(used, hex_pos) then
        return true
    end
    -- There may be more logic here in the future.
    return false
end

---Return whether the given hex position is fully surrounded by other hexes in the same dungeon.
---@param dungeon Dungeon
---@param hex_pos HexPos
---@return boolean
function dungeons.is_hex_pos_internal(dungeon, hex_pos)
    return hex_sets.contains(dungeon.internal_hexes, hex_pos)
end

---Return whether the hex pos is adjacent to an existing dungeon hex and the given hex is not a dungeon hex itself.
---@param surface_id int
---@param hex_pos HexPos
---@return boolean
function dungeons.is_adjacent_to_dungeon(surface_id, hex_pos)
    if dungeons.is_hex_pos_used(surface_id, hex_pos) then return false end
    for _, adj_pos in pairs(axial.get_adjacent_hexes(hex_pos)) do
        if dungeons.is_hex_pos_used(surface_id, adj_pos) then
            return true
        end
    end
    return false
end

---Get the prototype that a dungeon uses.
---@param dungeon Dungeon
---@return DungeonPrototype|nil
function dungeons.get_prototype_of_dungeon(dungeon)
    local surface = dungeon.surface
    local prots = storage.dungeons.prototypes[surface.name]
    if not prots then
        lib.log_error("dungeons.get_prototype_of_dungeon: No prototypes found for surface " .. surface.name)
        return
    end

    local prot = prots[dungeon.prototype_idx]
    if not prot then
        lib.log_error("dungeons.get_prototype_of_dungeon: No prototype found for dungeon " .. dungeon.id)
        return
    end

    return prot
end

---Find compact positions for entities to be placed on the given positions, and also return the positions that would likely be used if the entities are placed.
---@param hex_center MapPosition
---@param available_positions MapPositionSet
---@param max_dim int The maximum width and height of the entity throughout rotation.
---@return MapPositionAndDirection[], MapPositionSet
function dungeons.get_entity_positions(hex_center, available_positions, max_dim)
    available_positions = table.deepcopy(available_positions)
    local entity_positions = {} ---@type MapPositionAndDirection[]
    local used_positions = {} ---@type MapPositionSet

    ---@param x int
    ---@param y int
    local function is_valid_position(x, y)
        for _x = x, x + max_dim - 1 do
            for _y = y, y + max_dim - 1 do
                if not available_positions[_x] or not available_positions[_x][_y] or (used_positions[_x] and used_positions[_x][_y]) then
                    return false
                end
            end
        end
        return true
    end

    ---@param x int
    ---@param y int
    local function use_position(x, y)
        for _x = x, x + max_dim - 1 do
            if not used_positions[_x] then
                used_positions[_x] = {}
            end
            for _y = y, y + max_dim - 1 do
                used_positions[_x][_y] = true
                available_positions[_x][_y] = nil
            end
        end
        local center = {x = x + (max_dim / 2), y = y + (max_dim / 2)}
        local angle = math.atan2(center.y - hex_center.y, center.x - hex_center.x)
        local direction = math.floor(-2 + (angle + math.pi) * 8 / math.pi) % 16
        if max_dim % 2 == 0 then
            x = x + 0.5
            y = y + 0.5
        end
        table.insert(entity_positions, {position = {x = x, y = y}, direction = direction})
    end

    for x, X in pairs(available_positions) do
        for y, _ in pairs(X) do
            if is_valid_position(x, y) then
                use_position(x, y)
            end
        end
    end

    return entity_positions, used_positions
end

---Attempt to reload the turrets in the dungeon.
---@param dungeon Dungeon
function dungeons.try_reload_turrets(dungeon)
    if dungeon.last_turret_reload + TURRET_RELOAD_INTERVAL > game.tick then return end
    dungeon.last_turret_reload = game.tick

    local prot = dungeons.get_prototype_of_dungeon(dungeon)
    if not prot then return end

    dungeons._queue_turret_reload {
        dungeon_id = dungeon.id,
        turrets = dungeon.turrets,
        ammo = prot.ammo,
    }
end

---Spawn the loot chests in a dungeon tile.
---@param dungeon Dungeon
---@param hex_pos HexPos
---@return LuaEntity[]
function dungeons.spawn_loot(dungeon, hex_pos, hex_grid_scale, hex_grid_rotation)
    local prot = dungeons.get_prototype_of_dungeon(dungeon)
    if not prot then
        lib.log_error("dungeons.spawn_loot: No prototype found for dungeon " .. dungeon.id)
        return {}
    end

    local loot_table = loot_tables.get_loot_table(dungeon.surface.name, "dungeon")
    if not loot_table then
        lib.log_error("dungeons.spawn_loot: No loot table found for dungeon on surface " .. dungeon.surface.name)
        return {}
    end

    local dist = axial.distance(hex_pos, {q = 0, r = 0}) - 2
    dist = math.max(0, dist) -- Shouldn't need this, but it's here just in case.

    local loot_value = prot.loot_value * (1 + dist * 0.0625) * lib.runtime_setting_value("dungeon-loot-scale-" .. dungeon.surface.name)
    local expected_num_samples = prot.rolls
    local min_item_value = loot_value / (10 * expected_num_samples * (prot.amount_scaling or 1))
    local max_item_value = math.huge -- No upper limit. Allow for very rare but valuable loot.
    local better_loot_table = loot_tables.clip_items_by_value(loot_table, dungeon.surface.name, min_item_value, max_item_value)

    local hex_center = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
    local entities = {}

    for i = 1, prot.chests_per_hex or 1 do
        local radius = math.max(5, math.random() ^ 0.5 * 10)
        local random_pos = lib.vector_add(lib.random_unit_vector(radius), hex_center)
        local pos = dungeon.surface.find_non_colliding_position("dungeon-chest", lib.rounded_position(random_pos, true), 2, 1, true)
        if pos then
            local chest = dungeon.surface.create_entity {
                name = "dungeon-chest",
                position = pos,
                force = "player",
            }

            if chest then
                local inv = chest.get_inventory(defines.inventory.chest)
                if inv then
                    local max_num_samples = #inv
                    local loot_items = loot_tables.sample_until_total_value(better_loot_table, dungeon.surface.name, expected_num_samples, max_num_samples, loot_value, prot.amount_scaling or 1)

                    local total_coin_value = 0
                    for _, item in pairs(loot_items) do
                        local item_name = item.loot_item.item_name
                        local quality = lib.get_quality_at_tier(item.loot_item.quality_tier)
                        local count = item.count
                        inv.insert {
                            name = item_name,
                            quality = quality,
                            count = count,
                        }
                        total_coin_value = total_coin_value + item_values.get_item_value(dungeon.surface.name, item_name, true, quality) * count
                    end

                    local coin = coin_tiers.from_base_value(total_coin_value / (10 * item_values.get_item_value("nauvis", "hex-coin")))
                    inventories.add_coin_to_inventory(inv, coin)

                    -- Additionally roll for extra items
                    for item_name, chance in pairs(prot.item_rolls) do
                        local count = lib.multi_roll(chance)
                        if count > 0 then
                            inv.insert {
                                name = item_name,
                                count = count,
                            }
                        end
                    end

                    inv.sort_and_merge()
                end

                chest.destructible = false

                table.insert(entities, chest)
                table.insert(dungeon.loot_chests, chest)
            end
        end
    end

    return entities
end

---Remove a chest from a dungeon's record of loot chests.
---@param dungeon Dungeon
---@param chest LuaEntity
function dungeons.remove_loot_chest(dungeon, chest)
    local index = lib.table_index(dungeon.loot_chests, chest)
    if not index then
        -- This may happen if a player places a dungeon chest in a dungeon hex and then picks it up again.
        lib.log_error("dungeons.remove_loot_chest: Loot chest not found in dungeon")
        return
    end

    table.remove(dungeon.loot_chests, index)

    if not dungeon.is_looted and dungeons.is_looted(dungeon) then
        dungeon.is_looted = true

        -- The dungeon was looted! Destroy all of its entities.
        for _, e in pairs(dungeon.walls or {}) do
            if e.valid then
                e.destroy()
            end
        end
        dungeon.walls = {}
        for _, e in pairs(dungeon.turrets or {}) do
            if e.valid then
                e.destroy()
            end
        end
        dungeon.turrets = {}

        event_system.trigger("dungeon-looted", dungeon)
    end
end

---Handle the event where a dungeon chest is picked up.
---@param chest LuaEntity
function dungeons.on_dungeon_chest_picked_up(chest)
    local surface = chest.surface
    local transformation = terrain.get_surface_transformation(surface.name)
    local hex_pos = axial.get_hex_containing(chest.position, transformation.scale, transformation.rotation)
    local dungeon = dungeons.get_dungeon_at_hex_pos(surface.index, hex_pos, false)
    if not dungeon then return end

    dungeons.remove_loot_chest(dungeon, chest)
end

---Return whether the dungeon is fully looted, where all loot chests have been mined.
---@param dungeon Dungeon
---@return boolean
function dungeons.is_looted(dungeon)
    for _, chest in pairs(dungeon.loot_chests) do
        if chest.valid then -- Chests can become invalid if an /editor mode deconstruction planner is used.
            return false
        end
    end
    return true
end

---Request turrets to be reloaded over time.
---@param params any
function dungeons._queue_turret_reload(params)
    if storage.dungeons.queued_reload_dungeon_indices[params.dungeon_id] then return end
    storage.dungeons.queued_reload_dungeon_indices[params.dungeon_id] = true

    -- log("reload starting for " .. params.dungeon_id)
    params.progress = 0
    table.insert(storage.dungeons.queued_reloads, params)
end

function dungeons._tick_turret_reload()
    if not next(storage.dungeons.queued_reloads) then return end

    -- local prof = game.create_profiler()

    local queue_idx = game.tick % #storage.dungeons.queued_reloads + 1
    local params = storage.dungeons.queued_reloads[queue_idx]



    local turrets = {}
    for i = 1, 20 do
        local idx = params.progress + i
        if idx > #params.turrets then
            break
        end
        turrets[i] = params.turrets[idx]
    end

    params.progress = params.progress + #turrets

    if next(turrets) then
        lib.reload_turrets(turrets, params.ammo)
        if params.progress < #params.turrets then
            -- prof.stop()
            -- log("tick:")
            -- log(prof)
            return
        end
    end

    -- log("reload finished for " .. params.dungeon_id)
    -- prof.stop()
    -- log(prof)

    storage.dungeons.queued_reload_dungeon_indices[params.dungeon_id] = nil
    table.remove(storage.dungeons.queued_reloads, queue_idx)
end

---@param new_data table
function dungeons.migrate_old_data(new_data)
    storage.dungeons.defs = new_data.defs
    dungeons.init_prototypes()
end



return dungeons


