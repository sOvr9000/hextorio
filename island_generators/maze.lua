
-- Generates a large maze, filling in a giant hexagon.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local hex_maze = require "api.hex_maze"



return function(params)
    local radius = params.radius or 30
    local algorithm = params.algorithm or "kruskal"

    local dilation_factor = 2
    local div_radius = math.ceil(radius / dilation_factor)

    local allowed_positions = hex_sets.new()
    hex_sets.add(allowed_positions, {q=0, r=0})

    for r = 1, div_radius do
        for _, pos in pairs(axial.ring({q=0, r=0}, r)) do
            hex_sets.add(allowed_positions, pos)
        end
    end

    local maze = hex_maze.new(allowed_positions)
    hex_maze.generate(maze, algorithm)

    local island = hex_maze.dilated(maze, dilation_factor)
    return island
end


