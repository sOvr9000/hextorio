
-- Generates a full hexagon, containing zero holes.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"



return function(params)
    local radius = params.radius or 30

    local island = hex_sets.new()
    hex_sets.add(island, {q = 0, r = 0})

    for r = 1, radius do
        for _, pos in pairs(axial.ring({q=0, r=0}, r)) do
            hex_sets.add(island, pos)
        end
    end

    return island
end


