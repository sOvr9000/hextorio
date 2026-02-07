
-- Generates a ribbon world.

local hex_sets = require "api.hex_sets"



return function(params)
    local radius = params.radius or 30
    local width = params.width or 5

    local island = hex_sets.new()
    local direction = math.random(1, 3)

    local half_width = math.floor((width - 1) / 2)

    local centering = math.random(0, width - 1)
    local upper_w = half_width - centering
    if direction == 1 then
        for q = -radius, radius do
            for w = -half_width - centering, upper_w do
                hex_sets.add(island, {q = q, r = w})
            end
        end
    elseif direction == 2 then
        for q = -radius, radius do
            for w = -half_width - centering, upper_w do
                hex_sets.add(island, {q = q, r = w - q})
            end
        end
    else
        for r = -radius, radius do
            for w = -half_width - centering, upper_w do
                hex_sets.add(island, {q = w, r = r})
            end
        end
    end

    return island
end


