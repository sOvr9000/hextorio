
-- Generates a lattice of hexes, filling in a hexagonal shape.  The nonland hexes inside the island are in a dilated hexagonal pattern.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"

local function estimate_radius(total_hexes)
    local radius = (-3 + math.sqrt(3 * (4 * total_hexes - 1))) / 6
    return math.max(1, math.floor(radius + 0.5))
end

return function(params)
    local total_hexes = params.total_hexes or 2800
    local spacing = params.spacing or 3
    local s = spacing + 1

    local target_total_hexes = total_hexes * s * s / (3 * spacing + 1)
    local radius = estimate_radius(target_total_hexes)

    local island = hex_sets.new()
    for q = -radius, radius do
        for r = -radius, radius do
            if axial.distance({q = q, r = r}, {q = 0, r = 0}) <= radius then
                if q % s == 0 or r % s == 0 or (q + r) % s == 0 then
                    hex_sets.add(island, {q = q, r = r})
                end
            end
        end
    end

    return island
end


