
-- Generates a huge ring (circular, not hexagonal).

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"

local function estimate_radius(total_hexes, width)
    -- For a hexagonal ring: hexes = 3*width*(2*r - width + 1)
    -- Solving for r: r = total_hexes/(6*width) + width/2 - 1/2
    local radius = total_hexes / (6 * width) + width / 2 - 0.5
    return math.max(width + 2, math.floor(radius + 0.5))
end

return function(params)
    local total_hexes = params.total_hexes or 2800
    local width = params.width or 5
    local radius = estimate_radius(total_hexes, width - 2)

    local function axial_to_cartesian(pos)
        local x = math.sqrt(3) * pos.q + math.sqrt(3) / 2 * pos.r
        local y = 3 / 2 * pos.r
        return x, y
    end

    local candidates = {}
    for q = -radius - 2, radius + 2 do
        for r = -radius - 2, radius + 2 do
            local pos = {q = q, r = r}
            local x, y = axial_to_cartesian(pos)
            local dist = math.sqrt(x * x + y * y)
            if math.abs(dist - radius) <= 2 then
                table.insert(candidates, pos)
            end
        end
    end
    local ring_center = candidates[math.random(1, #candidates)]

    local inner_radius = radius - width / 2 - 1
    local outer_radius = radius + width / 2 + 1

    local cx, cy = axial_to_cartesian(ring_center)

    local function in_band(pos)
        local x, y = axial_to_cartesian(pos)
        local dx = x - cx
        local dy = y - cy
        local dist = math.sqrt(dx * dx + dy * dy)
        return dist >= inner_radius and dist <= outer_radius
    end

    local start_pos = {q = 0, r = 0}
    if not in_band(start_pos) then
        local found = false
        for q = ring_center.q - radius - 10, ring_center.q + radius + 10 do
            for r = ring_center.r - radius - 10, ring_center.r + radius + 10 do
                local pos = {q = q, r = r}
                if in_band(pos) then
                    start_pos = pos
                    found = true
                    break
                end
            end
            if found then break end
        end
    end

    local island = hex_sets.new()
    local visited = hex_sets.new()
    local queue = {start_pos}
    hex_sets.add(visited, start_pos)
    hex_sets.add(island, start_pos)

    while #queue > 0 do
        local current = table.remove(queue, 1)

        for _, neighbor in pairs(axial.get_adjacent_hexes(current)) do
            if not hex_sets.contains(visited, neighbor) and in_band(neighbor) then
                hex_sets.add(visited, neighbor)
                hex_sets.add(island, neighbor)
                table.insert(queue, neighbor)
            end
        end
    end

    return island
end


