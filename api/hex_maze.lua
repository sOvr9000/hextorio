


---@alias HexMazeTile {pos: HexPos, open: boolean[]}
---@alias HexMaze {tiles: HexMazeTile[]}

local lib = require "api.lib"

local hex_maze = {}



--- Generate a maze in the axial coordinate system using Wilson's algorithm.
--- https://en.wikipedia.org/wiki/Maze_generation_algorithm#Wilson's_algorithm
---@param allowed_tiles HexPosMap
---@return HexMaze
function hex_maze.generate(allowed_tiles, )

end



return hex_maze

