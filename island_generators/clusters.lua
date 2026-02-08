
-- Generates several large interconnected hexagons.

local lib = require "api.lib"
local axial = require "api.axial"
local bezier = require "api.bezier"
local hex_sets = require "api.hex_sets"

local function estimate_cluster_count_and_spacing(total_hexes, min_cluster_size, max_cluster_size)
    local avg_cluster_size = (min_cluster_size + max_cluster_size) / 2
    local avg_cluster_hexes = 3 * avg_cluster_size * (avg_cluster_size + 1) + 1
    local num_clusters = math.max(1, math.floor(total_hexes / avg_cluster_hexes + 0.5))
    local spacing = math.max(15, math.floor(math.sqrt(total_hexes / num_clusters) * 2))
    return num_clusters, spacing
end

return function(params)
    local total_hexes = params.total_hexes or 2800
    local min_cluster_size = params.min_cluster_size or 2
    local max_cluster_size = params.max_cluster_size or 5

    max_cluster_size = math.max(max_cluster_size, min_cluster_size)

    local num_clusters, spacing = estimate_cluster_count_and_spacing(total_hexes, min_cluster_size, max_cluster_size)

    local radius = math.ceil(math.sqrt(num_clusters) * spacing / 2)

    local lattice_points = {}
    for q = -radius, radius, spacing do
        for r = -radius, radius, spacing do
            local pos = {q = q, r = r}
            if axial.distance(pos, {q = 0, r = 0}) <= radius then
                table.insert(lattice_points, pos)
            end
        end
    end

    local max_displacement = math.floor(spacing / 3)
    local cluster_centers = {}

    for _, point in ipairs(lattice_points) do
        local offset_q = math.random(-max_displacement, max_displacement)
        local offset_r = math.random(-max_displacement, max_displacement)
        local size = math.random(min_cluster_size, max_cluster_size)

        local center = {
            q = point.q + offset_q,
            r = point.r + offset_r,
            lattice_q = point.q,
            lattice_r = point.r,
            size = size
        }
        table.insert(cluster_centers, center)
    end

    local valid_centers = {}
    for _, center1 in ipairs(cluster_centers) do
        local valid = true
        for _, center2 in ipairs(valid_centers) do
            local dist = axial.distance(center1, center2)
            local min_separation = center1.size + center2.size + 2
            if dist < min_separation then
                valid = false
                break
            end
        end
        if valid then
            table.insert(valid_centers, center1)
        end
    end

    local island = hex_sets.new()

    for _, center in ipairs(valid_centers) do
        hex_sets.add(island, center)
        for r = 1, center.size do
            for _, pos in pairs(axial.ring(center, r)) do
                hex_sets.add(island, pos)
            end
        end
    end

    for i = 1, #valid_centers - 1 do
        for j = i + 1, #valid_centers do
            local c1 = valid_centers[i]
            local c2 = valid_centers[j]

            local lattice_dist = axial.distance(
                {q = c1.lattice_q, r = c1.lattice_r},
                {q = c2.lattice_q, r = c2.lattice_r}
            )

            if math.abs(lattice_dist - spacing) < 1 then
                local dx = c2.q - c1.q
                local dy = c2.r - c1.r
                local dist = axial.distance(c1, c2)

                local perp_q = -dy
                local perp_r = dx
                local perp_len = math.sqrt(perp_q * perp_q + perp_r * perp_r)
                if perp_len > 0 then
                    perp_q = perp_q / perp_len
                    perp_r = perp_r / perp_len
                end

                local curve_strength = dist * 0.5
                local sign = math.random() > 0.5 and 1 or -1

                local p1 = {
                    q = c1.q + dx * 0.33 + perp_q * curve_strength * sign,
                    r = c1.r + dy * 0.33 + perp_r * curve_strength * sign
                }
                local p2 = {
                    q = c1.q + dx * 0.67 - perp_q * curve_strength * sign,
                    r = c1.r + dy * 0.67 - perp_r * curve_strength * sign
                }

                local num_samples = math.ceil(dist * 3)
                local curve_points = bezier.cubic_bezier_hex(c1, p1, p2, c2, num_samples)

                for _, point in ipairs(curve_points) do
                    hex_sets.add(island, point)
                end
            end
        end
    end

    local function is_connected(island)
        local all_positions = hex_sets.to_array(island)
        if #all_positions == 0 then return true end

        local visited = hex_sets.new()
        local queue = {all_positions[1]}
        hex_sets.add(visited, all_positions[1])
        local count = 1

        while #queue > 0 do
            local current = table.remove(queue, 1)
            for _, adj in pairs(axial.get_adjacent_hexes(current)) do
                if hex_sets.contains(island, adj) and not hex_sets.contains(visited, adj) then
                    hex_sets.add(visited, adj)
                    table.insert(queue, adj)
                    count = count + 1
                end
            end
        end

        return count == #all_positions
    end

    while not is_connected(island) do
        local all_positions = hex_sets.to_array(island)
        local visited = hex_sets.new()
        local queue = {all_positions[1]}
        hex_sets.add(visited, all_positions[1])

        while #queue > 0 do
            local current = table.remove(queue, 1)
            for _, adj in pairs(axial.get_adjacent_hexes(current)) do
                if hex_sets.contains(island, adj) and not hex_sets.contains(visited, adj) then
                    hex_sets.add(visited, adj)
                    table.insert(queue, adj)
                end
            end
        end

        local found = false
        for _, pos in ipairs(all_positions) do
            if hex_sets.contains(visited, pos) then
                for _, adj in pairs(axial.get_adjacent_hexes(pos)) do
                    if hex_sets.contains(island, adj) and not hex_sets.contains(visited, adj) then
                        hex_sets.add(island, pos)
                        found = true
                        break
                    end
                end
                if found then break end
            end
        end

        if not found then break end
    end

    lib.log("island_generators.clusters: Generated " .. #valid_centers .. " clusters")

    return island
end


