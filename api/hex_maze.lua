
---@alias HexMazeTile {pos: HexPos, open: boolean[]}
---@alias HexMaze {tiles: HexMazeTile[], tiles_by_position: IndexMap}

local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"

local hex_maze = {}



---@param allowed_positions HexPosMap
---@return HexMaze
function hex_maze.new(allowed_positions)
    local maze = {tiles = {}, tiles_by_position = {}}

    for q, Q in pairs(allowed_positions) do
        for r, _ in pairs(Q) do
            local tile = hex_maze.new_tile {q = q, r = r}
            local idx = #maze.tiles + 1
            if not maze.tiles_by_position[q] then
                maze.tiles_by_position[q] = {}
            end
            if maze.tiles_by_position[q][r] then
                lib.log("hex_maze.generate: Duplicate hex position found in allowed_positions: " .. axial.to_string(q, r))
            end
            maze.tiles_by_position[q][r] = idx
            table.insert(maze.tiles, tile)
        end
    end

    return maze
end

---@param hex_pos HexPos
---@return HexMazeTile
function hex_maze.new_tile(hex_pos)
    return {
        pos = hex_pos,
        open = {false, false, false, false, false, false},
    }
end

--- Generate a maze in the axial coordinate system using Kruskal's algorithm.
--- https://en.wikipedia.org/wiki/Kruskal%27s_algorithm
---@param maze HexMaze
function hex_maze.generate(maze)
    -- Ensure that if the maze has already been generated or partially generated, it is reset to an initial state with all passages closed.
    hex_maze.close_all_passages(maze)

    -- Initialize sets
    local sets = {}
    local sets_by_position = {} -- Helps to calculate the "find" in "union-find"
    for i, tile in ipairs(maze.tiles) do
        sets[i] = hex_sets.new_set {tile.pos}
        if not sets_by_position[tile.pos.q] then
            sets_by_position[tile.pos.q] = {}
        end
        sets_by_position[tile.pos.q][tile.pos.r] = i
    end

    -- Create a list of tile indices to be shuffled and used for randomized search order.
    local tile_indices = lib.array_range(#maze.tiles)

    ---Helper function to properly manage the sets during union.
    ---@param i int
    ---@param j int
    local function union(i, j)
        sets[i] = hex_sets.union(sets[i], sets[j])
        for _ , hex_pos in pairs(hex_sets.to_array(sets[j])) do
            sets_by_position[hex_pos.q][hex_pos.r] = i
        end
        sets[j] = nil
    end

    ---Helper function to randomly find the next two tiles from different sets to be unioned.
    ---@return int|nil, int|nil, HexMazeTile|nil, HexMazeTile|nil
    local function get_next_edge()
        -- In random search order, find the first tile that has at least one neighbor that isn't in the same set.
        -- TODO: Maybe need to uniformly select from edges rather than tiles because this can result in some tiles having an excessive number of connections to other tiles. But maybe that's fine or not probable enough to care?

        lib.table_shuffle(tile_indices)
        for _, _idx in ipairs(tile_indices) do
            local tile = maze.tiles[_idx]
            i = sets_by_position[tile.pos.q][tile.pos.r]
            local adj_tiles = hex_maze.get_adjacent_tiles(maze, tile.pos)
            lib.table_shuffle(adj_tiles)
            for _, adj_tile in pairs(adj_tiles) do
                j = sets_by_position[adj_tile.pos.q][adj_tile.pos.r]
                if i ~= j then
                    return i, j, tile, adj_tile
                end
            end
        end

        -- Can only get to this point if the maze cannot be generated with the given tile arrangement (i.e. some tiles are isolated)
        lib.log_error("hex_maze.generate: Could not fully generate maze. Are there any isolated tiles?\n" .. serpent.block(maze.tiles))
        return nil, nil, nil, nil
    end

    local limit = #maze.tiles - 1 -- The exact number of union operations needed to complete the maze.
    for _ = 1, limit do
        local i, j, tile, adj_tile = get_next_edge()
        if not i then return end

        -- Suppress nil warnings from LuaLS. These values cannot be nil if at least one is not nil.
        ---@cast j int
        ---@cast tile HexMazeTile
        ---@cast adj_tile HexMazeTile

        union(i, j)
        hex_maze.set_open_between_tiles(tile, adj_tile)
    end
end

---Get a tile in the maze at the given position.
---@param maze HexMaze
---@param pos HexPos
---@return HexMazeTile|nil
function hex_maze.get_tile(maze, pos)
    local idx = (maze.tiles_by_position[pos.q] or {})[pos.r]
    if not idx then return end
    return maze.tiles[idx]
end

---Get the valid adjacent tiles of a given tile in the maze.
---@param maze HexMaze
---@param pos HexPos
---@return HexMazeTile[]
function hex_maze.get_adjacent_tiles(maze, pos)
    local tiles = {}
    for dir = 1, 6 do
        local offset = axial.get_adjacency_offset(dir)
        local adj = axial.add(pos, offset)
        local tile = hex_maze.get_tile(maze, adj)
        if tile then
            table.insert(tiles, tile)
        end
    end
    return tiles
end

---Open or close the passage between two tiles.
---@param tile1 HexMazeTile
---@param tile2 HexMazeTile
---@param flag boolean|nil
function hex_maze.set_open_between_tiles(tile1, tile2, flag)
    if flag == nil then flag = true end
    local offset = axial.subtract(tile2.pos, tile1.pos)
    local dir = axial.get_direction_from_offset(offset)
    tile1.open[dir] = flag
    tile2.open[axial.get_opposite_direction(dir)] = flag
end

---Open or close the passage in the given direction from a tile in the maze.
---@param maze HexMaze
---@param tile HexMazeTile
---@param dir AxialDirection
---@param flag boolean|nil
function hex_maze.set_open_in_direction(maze, tile, dir, flag)
    if flag == nil then flag = true end
    local offset = axial.get_adjacency_offset(dir)
    local tile2 = hex_maze.get_tile(maze, axial.add(tile.pos, offset))
    if not tile2 then
        lib.log_error("hex_maze.set_open_in_direction: No tile found in direction " .. dir .. " from " .. serpent.line(tile.pos))
        return
    end
    tile.open[dir] = flag
    tile2.open[axial.get_opposite_direction(dir)] = flag
end

---Check whether a tile has an opening to another tile.
---@param tile1 HexMazeTile
---@param tile2 HexMazeTile
---@return boolean
function hex_maze.is_open_between_tiles(tile1, tile2)
    local offset = axial.subtract(tile2.pos, tile1.pos)
    local dir = axial.get_direction_from_offset(offset)
    return tile1.open[dir]
end

---Check whether a tile has an opening in the given direction.
---@param tile HexMazeTile
---@param dir AxialDirection
function hex_maze.is_open_in_direction(tile, dir)
    return tile.open[dir]
end

---Close all passages between tiles in the maze.
---@param maze HexMaze
function hex_maze.close_all_passages(maze)
    for _, tile in pairs(maze.tiles) do
        for dir = 1, 6 do
            tile.open[dir] = false
        end
    end
end

---Open all passages between tiles in the maze.
---@param maze HexMaze
function hex_maze.open_all_passages(maze)
    -- Ensure that all passages that are on the perimeter of the maze are closed.
    hex_maze.close_all_passages(maze)

    -- Open all passages between tiles.
    for _, tile in pairs(maze.tiles) do
        -- Iterate over existing neighbors so that openings aren't created in directions toward positions that don't exist in the maze.
        for _, adj_tile in pairs(hex_maze.get_adjacent_tiles(maze, tile.pos)) do
            hex_maze.set_open_between_tiles(tile, adj_tile)
        end
    end
end



return hex_maze

