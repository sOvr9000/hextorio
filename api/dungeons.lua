
---@alias EntityRadii {[string]: number[]}
---@alias DungeonPrototype {wall_entities: EntityRadii, normal_loot_value: number, center_loot_value: number, max_loot_radius: number}
---@alias Dungeon {surface: LuaSurface, prototype_idx: int, id: int, maze: HexMaze|nil, turrets: LuaEntity[], last_turret_reload: int}

local lib = require "api.lib"
local axial = require "api.axial"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local terrain = require "api.terrain"
local hex_maze = require "api.hex_maze"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"

local TURRET_RELOAD_INTERVAL = 3600

local dungeons = {}



function dungeons.init()
    storage.dungeons.prototypes = {} --[[@as {[string]: DungeonPrototype[]}]]
    storage.dungeons.dungeons = {} --[=[@as Dungeon[]]=]
    storage.dungeons.dungeon_idx_by_position = {} --[[@as {[int]: IndexMap}]]
    storage.dungeons.used_hexes = {} --[[@as {[int]: HexSet}]]

    for _, def in pairs(storage.dungeons.defs) do
        local prot = dungeons.new_prototype(def.wall_entities, def.normal_loot_value, def.center_loot_value)
        if not storage.dungeons.prototypes[def.surface_name] then
            storage.dungeons.prototypes[def.surface_name] = {}
        end
        table.insert(storage.dungeons.prototypes[def.surface_name], prot)
    end

    event_system.register_callback("dungeon-update", function(player)
        local transformation = terrain.get_surface_transformation(player.surface)
        local hex_pos = axial.get_hex_containing(player.position, transformation.scale, transformation.rotation)
        for _, hex in pairs(axial.ring(hex_pos, 2)) do
            local dungeon = dungeons.get_dungeon_at_hex_pos(player.surface.index, hex)
            if dungeon then
                dungeons.try_reload_turrets(dungeon)
            end
        end
    end)
end

---@param wall_entities EntityRadii
---@param normal_loot_value number
---@param center_loot_value number
---@return DungeonPrototype
function dungeons.new_prototype(wall_entities, normal_loot_value, center_loot_value)
    local prot = table.deepcopy {
        wall_entities = wall_entities,
        normal_loot_value = normal_loot_value,
        center_loot_value = center_loot_value,
    }

    prot.max_loot_radius = math.huge
    for _, radii in pairs(prot.wall_entities) do
        for _, radius in pairs(radii) do
            prot.max_loot_radius = math.min(prot.max_loot_radius, radius)
        end
    end
    prot.max_loot_radius = math.max(0, prot.max_loot_radius - 2)

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
        last_turret_reload = 0,
    }

    return dungeon
end

---Get the dungeon that occupies a given hex position. Generate one if it doesn't yet exist and can be generated. Return nil if a dungeon cannot be generated.
---@param surface_id int
---@param hex_pos HexPos
---@return Dungeon|nil
function dungeons.get_dungeon_at_hex_pos(surface_id, hex_pos)
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
    if used_hexes and used_hexes[hex_pos.q] and used_hexes[hex_pos.q][hex_pos.r] then
        return
    end

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
    local dungeon = dungeons.get_dungeon_at_hex_pos(surface_id, hex_pos)
    if not dungeon then return end

    -- Generate tiles
    local tile_type = "brown-refined-concrete"
    local tile_positions = axial.get_hex_tile_positions(hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)
    terrain.set_tiles(surface_id, tile_positions, tile_type)
    dungeons.fill_edges_between_dungeon_hexes(dungeon, hex_pos, tile_type)
    dungeons.fill_corners_between_dungeon_hexes(dungeon, hex_pos, tile_type)

    -- Generate turrets and other entities
    dungeons.spawn_entities(dungeon, hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)

    -- Spawn loot
    -- TODO

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

    local entities = {}
    local used_positions = {}
    for entity_name, radii in pairs(prot.wall_entities) do
        local entity_prot = prototypes["entity"][entity_name]
        if entity_prot then
            local max_dim = math.max(entity_prot.tile_width, entity_prot.tile_height)
            for _, radius in pairs(radii) do
                local positions = axial.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, max_dim * 1.5, hex_stroke_width + radius, false)
                positions = axial.filter_positions_by_directions(hex_center, positions, directions)
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
                    local entity = surface.create_entity {
                        name = entity_name,
                        position = pos_dir.position,
                        direction = pos_dir.direction,
                    }
                    if entity then
                        table.insert(dungeon.turrets, entity)
                        table.insert(entities, entity)
                    end
                end
            end
        end
    end

    -- Initial ammo load of turrets
    lib.reload_turrets(entities)
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
    local allowed_positions, perimeter = dungeons.get_positions_for_maze(dungeon.surface.index, start_pos, math.random(9, 49))

    -- Mark all perimeter hexes outside of generated positions as used.
    -- This makes it so that separate dungeons don't meet at the edges and are instead separated by non-land tiles like water or heavy oil ocean.
    local used_hexes = storage.dungeons.used_hexes[dungeon.surface.index]
    if not used_hexes then
        used_hexes = {}
        storage.dungeons.used_hexes[dungeon.surface.index] = used_hexes
    end
    for _, hex in pairs(perimeter) do
        hex_sets.add(used_hexes, hex)
    end

    -- Mark the sampled positions as used.
    for q, Q in pairs(allowed_positions) do
        for r, _ in pairs(Q) do
            used_hexes[q][r] = true
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
        lib.log_error("Failed to generate dungeon maze for surface " .. surface.name)
        return false
    end

    return true
end

---Randomly sample allowed positions for a maze to be generated for a dungeon, and also return the resulting adjacent hexes (which weren't included in the selected positions) around the selected positions.
---@param surface_id int
---@param start_pos any
---@param amount int
---@return HexSet, HexPos[]
function dungeons.get_positions_for_maze(surface_id, start_pos, amount)
    local used_hexes = storage.dungeons.used_hexes[surface_id] or {}
    local positions = {} --[[@as HexSet]]
    local visited = {} --[[@as HexSet]]
    local open = {start_pos} --[=[@as HexPos[]]=]

    for i = 1, amount do
        if #open == 0 then break end
        local idx = math.random(1, #open)
        local cur = table.remove(open, idx)

        -- Add unvisited, unused adjacent hexes to the open list.
        local adj_hexes = axial.get_adjacent_hexes(cur)
        for _, adj in pairs(adj_hexes) do
            local is_visited = hex_sets.contains(visited, adj)
            local is_used = hex_sets.contains(used_hexes, adj)
            if not is_visited and not is_used then
                table.insert(open, adj)
                hex_sets.add(visited, adj)
            end
        end

        -- Add the current hex to the positions list.
        hex_sets.add(positions, cur)
    end

    return positions, open
end

---Return whether the given hex position is available for a dungeon.
---@param surface_id int
---@param hex_pos HexPos
function dungeons.is_hex_pos_used(surface_id, hex_pos)
    if storage.dungeons.used_hexes[surface_id] and storage.dungeons.used_hexes[surface_id][hex_pos.q] and storage.dungeons.used_hexes[surface_id][hex_pos.q][hex_pos.r] then
        return true
    end
    -- There may be more logic here in the future.
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
    local entity_positions = {} --[=[@as MapPositionAndDirection[]]=]
    local used_positions = {} --[[@as MapPositionSet]]

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
    if dungeon.last_turret_reload + TURRET_RELOAD_INTERVAL < game.tick then return end
    dungeon.last_turret_reload = game.tick
    lib.reload_turrets(dungeon.turrets)
end



return dungeons


