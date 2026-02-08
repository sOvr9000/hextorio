
-- Generates a large maze, filling in a giant hexagon.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local hex_maze = require "api.hex_maze"

local function estimate_radius(total_hexes)
    local radius = (-3 + math.sqrt(3 * (4 * total_hexes - 1))) / 6
    return math.max(1, math.floor(radius + 0.5))
end

return function(params)
    local total_hexes = params.total_hexes or 2800
    local algorithm = params.algorithm or "kruskal"

    local dilation_factor = 2
    local target_total_hexes = total_hexes * dilation_factor
    local radius = estimate_radius(target_total_hexes)
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


