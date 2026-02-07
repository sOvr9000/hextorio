
-- Generates a lattice of hexes, filling in a hexagonal shape.  The nonland hexes inside the island are in a dilated hexagonal pattern.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"



return function(params)
    local radius = params.radius or 30
    local spacing = params.spacing or 2
    local s = spacing + 1

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


