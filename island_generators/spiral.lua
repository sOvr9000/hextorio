
-- Generates a spiral.

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"

local function estimate_radius(total_hexes)
    local radius = (-3 + math.sqrt(3 * (4 * total_hexes - 1))) / 6
    return math.max(1, math.floor(radius + 0.5))
end

return function(params)
    local total_hexes = params.total_hexes or 2800
    local target_total_hexes = total_hexes * 2
    local radius = estimate_radius(target_total_hexes)

    local island = hex_sets.new()

    local pos = {q = 0, r = 0}
    hex_sets.add(island, pos)

    local orientiation = 0 -- counter-clockwise
    if math.random() < 0.5 then
        orientiation = -2 -- clockwise
    end

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


