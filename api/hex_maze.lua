
---@alias HexMazeTile {pos: HexPos, open: boolean[]}
---@alias HexMaze {tiles: HexMazeTile[], tiles_by_position: IndexMap}

local lib = require "api.lib"
local axial = require "api.axial"

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
    -- TODO
end

---@param maze HexMaze
---@param pos HexPos
---@return HexMazeTile|nil
function hex_maze.get_tile(maze, pos)
    local idx = (maze.tiles_by_position[pos.q] or {})[pos.r]
    if not idx then return end
    return maze.tiles[idx]
end

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

---@param tile1 HexMazeTile
---@param tile2 HexMazeTile
---@param flag boolean
function hex_maze.set_open_between_tiles(tile1, tile2, flag)
    if flag == nil then flag = true end
    local offset = axial.subtract(tile2.pos, tile1.pos)
    local dir = axial.get_direction_from_offset(offset)
    tile1.open[dir] = flag
    tile2.open[axial.get_opposite_direction(dir)] = flag
end

---@param maze HexMaze
---@param tile HexMazeTile
---@param dir AxialDirection
---@param flag boolean
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



return hex_maze

