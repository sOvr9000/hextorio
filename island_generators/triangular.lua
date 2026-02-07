
-- Generates a giant triangle, with the player spawning at one of the corners.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"



return function(params)
    local radius = params.radius or 30

    local island = hex_sets.new()

    local pos = {q = 0, r = 0}
    hex_sets.add(island, pos)

    local orientiation = 3 -- a simple trick make the "spiral" algorithm generate a triangular island instead

    local dir = math.random(1, 6)
    local done = false
    for i = 1, 999 do
        if done then break end
        for j = 1, 3 do
            dir = 1 + (dir + orientiation) % 6
            local offset = axial.get_adjacency_offset(dir)
            for n = 1, i do
                pos = axial.add(pos, offset)
                if axial.distance(pos, {q=0, r=0}) > radius then
                    done = true
                    break
                end
                hex_sets.add(island, pos)
            end
            if done then break end
        end
    end

    return island
end


