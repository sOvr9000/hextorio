
-- Generates a full hexagon, containing zero holes.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"

local function estimate_radius(total_hexes)
    local radius = (-3 + math.sqrt(3 * (4 * total_hexes - 1))) / 6
    return math.max(1, math.floor(radius + 0.5))
end

return function(params)
    local total_hexes = params.total_hexes or 2800
    local radius = estimate_radius(total_hexes)

    local island = hex_sets.new()
    hex_sets.add(island, {q = 0, r = 0})

    for r = 1, radius do
        for _, pos in pairs(axial.ring({q=0, r=0}, r)) do
            hex_sets.add(island, pos)
        end
    end

    return island
end


