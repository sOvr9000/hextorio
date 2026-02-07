
-- Generates a ribbon world, but as a maze.

local hex_sets = require "api.hex_sets"
local hex_maze = require "api.hex_maze"



return function(params)
    local radius = params.radius or 30
    local width = params.width or 7
    local algorithm = params.algorithm or "kruskal"

    local dilation_factor = 2
    local div_radius = math.ceil(radius / dilation_factor)
    local div_width = math.ceil(width / dilation_factor)

    local allowed_positions = hex_sets.new()
    local direction = math.random(1, 3)

    local centering = math.random(0, div_width - 1)
    local upper_w = div_width - 1 - centering
    if direction == 1 then
        for q = -div_radius, div_radius do
            for w = -centering, upper_w do
                hex_sets.add(allowed_positions, {q = q, r = w})
            end
        end
    elseif direction == 2 then
        for q = -div_radius, div_radius do
            for w = -centering, upper_w do
                hex_sets.add(allowed_positions, {q = q, r = w - q})
            end
        end
    else
        for r = -div_radius, div_radius do
            for w = -centering, upper_w do
                hex_sets.add(allowed_positions, {q = w, r = r})
            end
        end
    end

    local maze = hex_maze.new(allowed_positions)
    hex_maze.generate(maze, algorithm)

    local island = hex_maze.dilated(maze, dilation_factor)
    return island
end


