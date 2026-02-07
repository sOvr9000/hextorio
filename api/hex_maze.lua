
local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"

local hex_maze = {}



---@alias MazeGenerationAlgorithm
---| "kruskal"
---| "wilson"
---| "recursive-backtracker"
---| "binary-tree"

---@class HexMazeTile
---@field pos HexPos The axial coordinate position of this tile
---@field open boolean[] Array of 6 booleans indicating if passages are open in each direction (indexed 1-6)

---@class HexMaze
---@field tiles HexMazeTile[] Array of all tiles in the maze
---@field tiles_by_position IndexMap Lookup table mapping hex positions to tile indices for fast access
---@field generated boolean Whether the maze has been successfully generated



---Binary Tree algorithm.
---Creates a strong diagonal bias with all paths leading toward one direction.
---https://en.wikipedia.org/wiki/Maze_generation_algorithm#Simple_algorithms
---@param maze HexMaze
---@return boolean
local function generate_binary_tree(maze)
    hex_maze.close_all_passages(maze)
    maze.generated = false

    if #maze.tiles == 0 then
        maze.generated = true
        return true
    end

    local diagonal_choices = {
        {1, 2},
        {3, 4},
        {5, 6}
    }
    local chosen_diagonal = diagonal_choices[math.random(1, 3)]
    local dir1 = chosen_diagonal[1]
    local dir2 = chosen_diagonal[2]

    for _, tile in ipairs(maze.tiles) do
        local neighbors = {}

        for _, dir in ipairs({dir1, dir2}) do
            local offset = axial.get_adjacency_offset(dir)
            local neighbor_pos = axial.add(tile.pos, offset)
            if hex_maze.tile_exists_at(maze, neighbor_pos) then
                table.insert(neighbors, {
                    tile = hex_maze.get_tile(maze, neighbor_pos),
                    dir = dir
                })
            end
        end

        if #neighbors > 0 then
            local chosen = neighbors[math.random(1, #neighbors)]
            hex_maze.set_open_between_tiles(tile, chosen.tile)
        end
    end

    -- Ensure connectivity by bridging disconnected components (critical for ribbons).
    while true do
        local visited = {}
        for i = 1, #maze.tiles do
            visited[i] = false
        end

        local function mark_component(start_idx)
            local queue = {start_idx}
            visited[start_idx] = true
            local count = 1

            while #queue > 0 do
                local current_idx = table.remove(queue, 1)
                local current_tile = maze.tiles[current_idx]

                for _, connected_tile in pairs(hex_maze.get_connected_tiles(maze, current_tile)) do
                    local connected_idx = maze.tiles_by_position[connected_tile.pos.q][connected_tile.pos.r]
                    if not visited[connected_idx] then
                        visited[connected_idx] = true
                        table.insert(queue, connected_idx)
                        count = count + 1
                    end
                end
            end

            return count
        end

        local component_size = mark_component(1)
        if component_size == #maze.tiles then
            break
        end

        local found = false
        for i = 1, #maze.tiles do
            if visited[i] then
                local tile = maze.tiles[i]
                for _, adj_tile in pairs(hex_maze.get_adjacent_tiles(maze, tile.pos)) do
                    local adj_idx = maze.tiles_by_position[adj_tile.pos.q][adj_tile.pos.r]
                    if not visited[adj_idx] then
                        hex_maze.set_open_between_tiles(tile, adj_tile)
                        found = true
                        break
                    end
                end
                if found then break end
            end
        end

        if not found then
            break
        end
    end

    maze.generated = true
    return true
end

---Recursive Backtracker algorithm (Depth-First Search).
---Creates long winding passages with relatively few dead ends.
---https://en.wikipedia.org/wiki/Maze_generation_algorithm#Recursive_backtracker
---@param maze HexMaze
---@return boolean
local function generate_recursive_backtracker(maze)
    hex_maze.close_all_passages(maze)
    maze.generated = false

    if #maze.tiles == 0 then
        maze.generated = true
        return true
    end

    local visited = {}
    for i = 1, #maze.tiles do
        visited[i] = false
    end

    local stack = {}
    local start_idx = math.random(1, #maze.tiles)
    table.insert(stack, start_idx)
    visited[start_idx] = true
    local visited_count = 1

    while #stack > 0 and visited_count < #maze.tiles do
        local current_idx = stack[#stack]
        local current_tile = maze.tiles[current_idx]

        local unvisited_neighbors = {}
        for _, adj_tile in pairs(hex_maze.get_adjacent_tiles(maze, current_tile.pos)) do
            local adj_idx = maze.tiles_by_position[adj_tile.pos.q][adj_tile.pos.r]
            if not visited[adj_idx] then
                table.insert(unvisited_neighbors, {tile = adj_tile, idx = adj_idx})
            end
        end

        if #unvisited_neighbors > 0 then
            local chosen = unvisited_neighbors[math.random(1, #unvisited_neighbors)]
            hex_maze.set_open_between_tiles(current_tile, chosen.tile)
            visited[chosen.idx] = true
            visited_count = visited_count + 1
            table.insert(stack, chosen.idx)
        else
            table.remove(stack)
        end
    end

    maze.generated = true
    return true
end

---Wilson's algorithm (loop-erased random walk).
---Creates uniform spanning trees with no bias.
---https://en.wikipedia.org/wiki/Maze_generation_algorithm#Wilson's_algorithm
---@param maze HexMaze
---@return boolean
local function generate_wilson(maze)
    hex_maze.close_all_passages(maze)
    maze.generated = false

    if #maze.tiles == 0 then
        maze.generated = true
        return true
    end

    local in_maze = {}
    for i = 1, #maze.tiles do
        in_maze[i] = false
    end

    local start_idx = math.random(1, #maze.tiles)
    in_maze[start_idx] = true

    local remaining = {}
    for i = 1, #maze.tiles do
        if i ~= start_idx then
            table.insert(remaining, i)
        end
    end

    while #remaining > 0 do
        local walk_start_idx = remaining[math.random(1, #remaining)]
        local path = {walk_start_idx}
        local path_set = {[walk_start_idx] = 1}

        local current_idx = walk_start_idx
        while not in_maze[current_idx] do
            local current_tile = maze.tiles[current_idx]
            local neighbors = hex_maze.get_adjacent_tiles(maze, current_tile.pos)
            if #neighbors == 0 then break end

            local next_tile = neighbors[math.random(1, #neighbors)]
            local next_idx = maze.tiles_by_position[next_tile.pos.q][next_tile.pos.r]

            if path_set[next_idx] then
                local loop_start = path_set[next_idx]
                for i = #path, loop_start + 1, -1 do
                    path_set[path[i]] = nil
                    table.remove(path)
                end
            else
                table.insert(path, next_idx)
                path_set[next_idx] = #path
            end

            current_idx = next_idx
        end

        for i = 1, #path - 1 do
            local tile1 = maze.tiles[path[i]]
            local tile2 = maze.tiles[path[i + 1]]
            hex_maze.set_open_between_tiles(tile1, tile2)
            in_maze[path[i]] = true
        end

        local new_remaining = {}
        for _, idx in ipairs(remaining) do
            if not in_maze[idx] then
                table.insert(new_remaining, idx)
            end
        end
        remaining = new_remaining
    end

    maze.generated = true
    return true
end

---Kruskal's algorithm.
---https://en.wikipedia.org/wiki/Kruskal%27s_algorithm
---@param maze HexMaze
---@return boolean
local function generate_kruskal(maze)
    -- Ensure that if the maze has already been generated or partially generated, it is reset to an initial state with all passages closed.
    hex_maze.close_all_passages(maze)
    maze.generated = false

    -- Initialize sets
    local sets = {}
    local sets_by_position = {} -- Helps to calculate the "find" in "union-find"
    for i, tile in ipairs(maze.tiles) do
        sets[i] = hex_sets.new {tile.pos}
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
        if not i then
            -- Keep maze.generated=false.
            return false
        end

        -- Suppress nil warnings from LuaLS. These values cannot be nil if at least one is not nil.
        ---@cast j int
        ---@cast tile HexMazeTile
        ---@cast adj_tile HexMazeTile

        union(i, j)
        hex_maze.set_open_between_tiles(tile, adj_tile)
    end

    maze.generated = true
    return true
end



---@param allowed_positions HexPosMap
---@return HexMaze
function hex_maze.new(allowed_positions)
    local maze = {tiles = {}, tiles_by_position = {}, generated = false}

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

---Generate a maze in the axial coordinate system using a specific algorithm, returning whether the maze was successfully generated.
---@param maze HexMaze
---@param algorithm MazeGenerationAlgorithm|nil
---@return boolean
function hex_maze.generate(maze, algorithm)
    if not algorithm then algorithm = "kruskal" end

    if algorithm == "kruskal" then
        return generate_kruskal(maze)
    elseif algorithm == "wilson" then
        return generate_wilson(maze)
    elseif algorithm == "recursive-backtracker" then
        return generate_recursive_backtracker(maze)
    elseif algorithm == "binary-tree" then
        return generate_binary_tree(maze)
    else
        lib.log_error("hex_maze.generate: Unknown algorithm: " .. algorithm)
        return false
    end
end

---Get a tile in the maze at the given position.
---@param maze HexMaze
---@param pos HexPos
---@return HexMazeTile
function hex_maze.get_tile(maze, pos)
    local idx = (maze.tiles_by_position[pos.q] or {})[pos.r]
    if not idx then
        error("hex_maze.get_tile: Could not find tile at position " .. axial.to_string(pos))
    end
    local tile = maze.tiles[idx]
    if not tile then
        error("hex_maze.get_tile: Tile index maps to nothing.")
    end
    return tile
end

---Return whether the maze contains a specific tile.
---@param maze HexMaze
---@param pos HexPos
function hex_maze.tile_exists_at(maze, pos)
    return (maze.tiles_by_position[pos.q] or {})[pos.r] ~= nil
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
        if hex_maze.tile_exists_at(maze, adj) then
            table.insert(tiles, hex_maze.get_tile(maze, adj))
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

---Get the tiles that this tile has an open passage to.
---@param maze HexMaze
---@param tile HexMazeTile
---@return HexMazeTile[]
function hex_maze.get_connected_tiles(maze, tile)
    local connected = {}
    for _, adj_tile in pairs(hex_maze.get_adjacent_tiles(maze, tile.pos)) do
        if hex_maze.is_open_between_tiles(tile, adj_tile) then
            table.insert(connected, adj_tile)
        end
    end
    return connected
end

---Return a set of hex positions where the world space is scaled up by `scale`, where hex positions are added to the dilated space to bridge between connected hexes in the maze.
---@param maze HexMaze
---@param scale int
---@return HexSet
function hex_maze.dilated(maze, scale)
    local set = hex_sets.new()

    for _, tile in pairs(maze.tiles) do
        local pos = axial.multiply(tile.pos, scale)
        hex_sets.add(set, pos)

        for i = 1, 6 do
            if tile.open[i] then
                local offset = axial.get_adjacency_offset(i)
                for n = scale - 1, 1, -1 do
                    local bridge_pos = axial.add(pos, axial.multiply(offset, n))
                    if hex_sets.contains(set, bridge_pos) then
                        break
                    end
                    hex_sets.add(set, bridge_pos)
                end
            end
        end
    end

    return set
end



return hex_maze

