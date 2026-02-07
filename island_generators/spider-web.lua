
-- Generates a series of hexagonal rings spaced by water, but with the main axes of the world connecting them, forming what looks like a spider web.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"



return function(params)
    local radius = params.radius or 30

    local dilation_factor = 2
    local div_radius = math.ceil(radius / dilation_factor)

    local island = hex_sets.new()
    hex_sets.add(island, {q=0, r=0})

    for r = 1, div_radius do
        local dilated_r = r * dilation_factor
        local ring = axial.ring({q=0, r=0}, dilated_r)
        for _, pos in pairs(ring) do
            hex_sets.add(island, pos)
        end
    end

    for i = -radius, radius do
        for _, pos in pairs {
            {q = i, r = 0},
            {q = i, r = -i},
            {q = 0, r = i},
        } do
            hex_sets.add(island, pos)
        end
    end

    return island
end


