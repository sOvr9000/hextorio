-- Generate hex sets which represent a single, connected island.

local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"
local hex_maze = require "api.hex_maze"
local bezier = require "api.bezier"

local hex_island = {}



---@class IslandConfig
---@field radius int The radius of the hexagonal island in hex tiles
---@field fill_ratio number The proportion of hexes within the radius that should be land (0.0 to 1.0)
---@field algorithm string The island generation algorithm to use
---@field seed int|nil Optional random seed for reproducible island generation
---@field start_pos HexPos|nil Optional starting hex position for island generation



local island_generators = {
    ["standard"] = function(params)
        -- Generates a snowflake-like island.

        local radius = params.radius or 30
        local fill_ratio = params.fill_ratio or 0.866

        -- Initialize hex set.
        local set = hex_sets.new()
        local current_size = 0
        local max_size = 3 * radius * (radius + 1) + 1
        local target_size = math.ceil(max_size * fill_ratio)

        -- Initialize the open set.
        local open_list = {}
        local open_set = hex_sets.new()

        -- Guarantee some nonland tiles
        local blacklist = hex_sets.new()

        for i = 1, 5 do
            local ring = axial.ring({q=0, r=0}, i)
            local idx = math.random(1, #ring)
            local pos = ring[idx]
            if i > 1 and (pos.q == -pos.r or pos.q ~= 0 and pos.r == 0 or pos.r ~= 0 and pos.q == 0) then
                -- The randomly selected hex on the ring is on a line going out to a vertex of the giant hex island
                if math.random() < 0.5 then
                    idx = idx + 1
                else
                    idx = idx - 1
                end
                pos = ring[1 + (idx - 1) % #ring]
            end
            hex_sets.add(blacklist, pos)
        end

        -- Misc parameters
        -- local radius_inv = 1 / radius

        -- Helper function for managing the open set, island construction, and stopping condition.
        local function add_hex(pos)
            if hex_sets.add(set, pos) then
                current_size = current_size + 1

                local adj_list = axial.get_adjacent_hexes(pos)
                for i, adj in ipairs(adj_list) do
                    local dist = axial.distance(adj, {q=0, r=0})
                    if dist <= radius then
                        if not hex_sets.contains(set, adj) and not hex_sets.contains(open_set, adj) and not hex_sets.contains(blacklist, adj) then
                            hex_sets.add(open_set, adj)
                            table.insert(open_list, adj)
                        end
                    end
                end
            end
            return current_size >= target_size
        end

        -- Draw lines along the three diameters.
        for i = -radius, radius do
            for _, pos in pairs {
                {q = i, r = 0},
                {q = i, r = -i},
                {q = 0, r = i},
            } do
                if not hex_sets.contains(blacklist, pos) then
                    add_hex(pos)
                end
            end
        end

        -- Randomly sample from the open set.
        for i = 1, target_size do
            if not next(open_list) then break end

            local idx = math.random(1, #open_list)

            -- -- Construct weights for sampling
            -- local weights = {}
            -- local total_weight = 0
            -- for j, pos in ipairs(open_list) do
            --     local weight = 1
            --     for _, adj in pairs(axial.get_adjacent_hexes(pos)) do
            --         if hex_sets.contains(set, adj) then
            --             weight = weight * 0.1
            --         end
            --     end
            --     weights[j] = weight
            --     total_weight = total_weight + weight
            -- end

            -- -- Non-uniform sample such that more distant hexes are more likely to be sampled.
            -- local r = math.random() * total_weight
            -- local cur_w = 0
            -- local idx = 0
            -- for j, w in ipairs(weights) do
            --     cur_w = cur_w + w
            --     if cur_w >= r then
            --         idx = j
            --         break
            --     end
            -- end

            local pos = table.remove(open_list, idx)
            hex_sets.remove(open_set, pos)

            if add_hex(pos) then break end
        end

        return set
    end,

    ["maze"] = function(params)
        local radius = params.radius or 30
        local algorithm = params.algorithm or "kruskal"

        local dilation_factor = 2
        local div_radius = math.ceil(radius / dilation_factor)

        local allowed_positions = hex_sets.new()
        hex_sets.add(allowed_positions, {q=0, r=0})

        for r = 1, div_radius do
            for _, pos in pairs(axial.ring({q=0, r=0}, r)) do
                hex_sets.add(allowed_positions, pos)
            end
        end

        local maze = hex_maze.new(allowed_positions)
        hex_maze.generate(maze, algorithm)

        local island = hex_maze.dilated(maze, dilation_factor)
        return island
    end,

    ["spiral"] = function(params)
        local radius = params.radius or 30

        local island = hex_sets.new()

        local pos = {q = 0, r = 0}
        hex_sets.add(island, pos)

        local dir = math.random(1, 6)
        local done = false
        for i = 1, 999 do
            if done then break end
            for j = 1, 3 do
                dir = 1 + dir % 6
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
    end,

    ["ribbon"] = function(params)
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
    end,

    ["ribbon-maze"] = function(params)
        local radius = params.radius or 30
        local width = params.width or 7
        local algorithm = params.algorithm or "kruskal"

        local dilation_factor = 2
        local div_radius = math.ceil(radius / dilation_factor)
        local div_width = math.ceil(width / dilation_factor)

        local allowed_positions = hex_sets.new()
        local direction = math.random(1, 3)

        local centering = math.random(0, div_width - 1)
        local upper_w = div_width - 1 - centering
        if direction == 1 then
            for q = -div_radius, div_radius do
                for w = -centering, upper_w do
                    hex_sets.add(allowed_positions, {q = q, r = w})
                end
            end
        elseif direction == 2 then
            for q = -div_radius, div_radius do
                for w = -centering, upper_w do
                    hex_sets.add(allowed_positions, {q = q, r = w - q})
                end
            end
        else
            for r = -div_radius, div_radius do
                for w = -centering, upper_w do
                    hex_sets.add(allowed_positions, {q = w, r = r})
                end
            end
        end

        local maze = hex_maze.new(allowed_positions)
        hex_maze.generate(maze, algorithm)

        local island = hex_maze.dilated(maze, dilation_factor)
        return island
    end,

    ["spider-web"] = function(params)
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
    end,

    ["lattice"] = function(params)
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
    end,

    ["solid"] = function(params)
        local radius = params.radius or 30

        local island = hex_sets.new()
        hex_sets.add(island, {q = 0, r = 0})

        for r = 1, radius do
            for _, pos in pairs(axial.ring({q=0, r=0}, r)) do
                hex_sets.add(island, pos)
            end
        end

        return island
    end,

    ["donut"] = function(params)
        local radius = params.radius or 30
        local width = params.width or 5

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
    end,

    ["clusters"] = function(params)
        local radius = params.radius or 30
        local cluster_size = params.cluster_size or 5
        local spacing = params.spacing or 15

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
            local size = math.max(2, cluster_size + math.random(-2, 2))

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

        return island
    end,

}



function hex_island.register_events()
    event_system.register("surface-created", hex_island.process_surface_creation)
end

function hex_island.process_surface_creation(surface)
    if not storage.hex_island then
        storage.hex_island = {}
    end
    if not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local planet_size = lib.startup_setting_value("planet-size-" .. surface.name)

    if not planet_size then
        lib.log_error("hex_island.init: Could not find planet size setting value for " .. surface.name)
        return
    end

    ---@cast planet_size int
    local generator_name = lib.runtime_setting_value_as_string "world-generation-mode"
    local maze_algorithm = lib.runtime_setting_value_as_string "maze-generation-algorithm"
    local params

    if generator_name == "standard" then
        local mgs = storage.hex_grid.mgs[surface.name]
        if not mgs then
            lib.log_error("hex_island.init: No map gen settings found for surface " .. surface.name)
        end

        local land_chance
        if surface.name == "nauvis" then
            if mgs.autoplace_controls.water.size == 0 then
                land_chance = 0
            else
                land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.water.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.water.size)) * 0.5
            end
        elseif surface.name == "vulcanus" then
            land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.vulcanus_volcanism.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.vulcanus_volcanism.size)) * 0.5
        elseif surface.name == "fulgora" then
            land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.fulgora_islands.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.fulgora_islands.size)) * 0.5
        elseif surface.name == "gleba" then
            land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.gleba_water.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.gleba_water.size)) * 0.5
        elseif surface.name == "aquilo" then
            land_chance = 0.60
        end
        if surface.name ~= "fulgora" and surface.name ~= "aquilo" then
            land_chance = (1 - land_chance * land_chance) ^ 0.5 -- basically turning a triangle into a circle
        end

        params = {
            radius = planet_size,
            fill_ratio = land_chance,
        }
    elseif generator_name == "maze" then
        params = {
            radius = planet_size,
            algorithm = maze_algorithm,
        }
    elseif generator_name == "spiral" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "ribbon" then
        params = {
            radius = planet_size,
            width = 5,
        }
    elseif generator_name == "ribbon-maze" then
        params = {
            radius = planet_size,
            width = 7,
            algorithm = maze_algorithm,
        }
    elseif generator_name == "spider-web" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "lattice" then
        params = {
            radius = planet_size,
            spacing = 2,
        }
    elseif generator_name == "solid" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "donut" then
        params = {
            radius = planet_size,
            width = 5,
        }
    elseif generator_name == "clusters" then
        params = {
            radius = planet_size,
            cluster_size = 5,
            spacing = 15,
        }
    end

    local island = hex_island.generate_island(generator_name, params)
    storage.hex_island.islands[surface.name] = island
end

---Initialize islands for each planet.
function hex_island.init()
    hex_island.process_surface_creation(game.surfaces.nauvis)
end

---Return whether the given hex at a position should be land.
---@param surface_name string
---@param hex_pos HexPos
---@return boolean
function hex_island.is_land_hex(surface_name, hex_pos)
    if not storage.hex_island then
        storage.hex_island = {islands = {}}
    elseif not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local island = storage.hex_island.islands[surface_name]
    if not island then
        lib.log_error("hex_island.is_land_hex: Could not find island structure for surface " .. surface_name)
        return false
    end

    return hex_sets.contains(island, hex_pos)
end

---Get a list of all land hexes on the surface.
---@param surface_name string
---@return HexPos[]
function hex_island.get_land_hex_list(surface_name)
    return hex_sets.to_array(hex_island.get_island_hex_set(surface_name))
end

---Get the HexSet of all land hexes on the surface.
---@param surface_name string
---@return HexSet
function hex_island.get_island_hex_set(surface_name)
    if not storage.hex_island then
        storage.hex_island = {islands = {}}
    elseif not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local island = storage.hex_island.islands[surface_name]
    if not island then
        lib.log_error("hex_island.get_island_hex_set: Could not find island structure for surface " .. surface_name)
        return {}
    end

    return island
end

---Generate a hexagonal island.
---@param generator_name string
---@param params table
---@return HexSet
function hex_island.generate_island(generator_name, params)
    local gen = island_generators[generator_name]
    if not gen then
        error("hex_island.generate_island: No generator found with name " .. generator_name)
    end

    lib.log("hex_island.generate_island: Generating island with generator = " .. generator_name .. ", params = " .. serpent.line(params))

    return gen(params)
end



return hex_island
