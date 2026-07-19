
-- Mathematics for two-way rectangular-axial coordinate system conversion,
-- as well as various utility functions for working with an axial coordinate system.
-- i.e. squares vs. hexagons

local lib = require "api.lib"

local axial = {}



---@alias AxialDirection 1|2|3|4|5|6
---@alias AxialDirectionSet {[AxialDirection]: boolean}



local inv_dir_map = {1, 6, 5, 4, 3, 2}

local adjacency_offsets = {
    {q = 1, r = 0}, {q = 1, r = -1}, {q = 0, r = -1},
    {q = -1, r = 0}, {q = -1, r = 1}, {q = 0, r = 1},
}

local directions_by_offset = {[-1] = {}, [0] = {}, [1] = {}}
for i = 1, 6 do
    local offset = adjacency_offsets[i]
    directions_by_offset[offset.q][offset.r] = i
end


-- Get the third coordinate (s) in the cube coordinate system
-- In axial coords, we only store q,r but sometimes need s for calculations
function axial.get_s(hex)
    return -hex.q - hex.r
end

-- Convert from cube coordinates to axial coordinates
function axial.cube_to_axial(cube)
    return {q = cube.q, r = cube.r}
end

-- Convert from axial coordinates to cube coordinates
function axial.axial_to_cube(hex)
    return {q = hex.q, r = hex.r, s = -hex.q - hex.r}
end

-- Round floating point cube coordinates to the nearest hex
function axial.cube_round(cube)
    local q = math.floor(cube.q + 0.5)
    local r = math.floor(cube.r + 0.5)
    local s = math.floor(cube.s + 0.5)

    local q_diff = math.abs(q - cube.q)
    local r_diff = math.abs(r - cube.r)
    local s_diff = math.abs(s - cube.s)

    -- Fix any rounding errors to ensure q + r + s = 0
    if q_diff > r_diff and q_diff > s_diff then
        q = -r - s
    elseif r_diff > s_diff then
        r = -q - s
    else
        s = -q - r
    end

    return {q = q, r = r, s = s}
end

-- Round floating point axial coordinates to the nearest hex
function axial.round(hex)
    local cube = axial.axial_to_cube(hex)
    local rounded_cube = axial.cube_round(cube)
    return axial.cube_to_axial(rounded_cube)
end

-- Convert rectangular coordinates to axial coordinates
-- rect_pos: {x, y} rectangular coordinates
-- axial_scale: size of hexes (distance from center to corner)
-- axial_rotation: rotation of the grid in radians
function axial.get_hex_containing(rect_pos, axial_scale, axial_rotation)
    -- Default values
    axial_scale = axial_scale or 1
    axial_rotation = axial_rotation or 0

    -- Apply rotation if needed
    local x, y = rect_pos.x, rect_pos.y
    if axial_rotation ~= 0 then
        local cos_r = math.cos(-axial_rotation)
        local sin_r = math.sin(-axial_rotation)
        x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
    end

    -- Convert to cube coordinates using the inverse of the hex to pixel transformation
    local size = axial_scale
    local q = (storage.constants.ROOT_THREE_OVER_THREE * x - 1/3 * y) / size
    local r = (2/3 * y) / size

    -- Create hith floating point coordinates
    local hex = {q = q, r = r}
    -- Round to the nearest hex
    return axial.round(hex)
end

---Convert axial coordinates to rectangular coordinates (center of hex)
---@param hex_pos HexPos
---@param axial_scale number
---@param axial_rotation number
---@return MapPosition
function axial.get_hex_center(hex_pos, axial_scale, axial_rotation)
    -- Default values
    axial_scale = axial_scale or 1
    axial_rotation = axial_rotation or 0

    -- Convert hex to pixel
    local size = axial_scale
    local x = size * (storage.constants.ROOT_THREE * hex_pos.q + storage.constants.ROOT_THREE_OVER_TWO * hex_pos.r)
    local y = size * (1.5 * hex_pos.r)

    -- Apply rotation if needed
    if axial_rotation ~= 0 then
        local cos_r = math.cos(axial_rotation)
        local sin_r = math.sin(axial_rotation)
        x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
    end

    return {x = x, y = y}
end

---@param direction AxialDirection
---@return HexPos
function axial.get_adjacency_offset(direction)
    return adjacency_offsets[direction]
end

---@param offset HexPos
---@return AxialDirection
function axial.get_direction_from_offset(offset)
    if not directions_by_offset[offset.q] or not directions_by_offset[offset.q][offset.r] then
        lib.log_error("axial.get_direction_from_offset: Invalid offset: " .. serpent.line(offset))
        return 1
    end
    return directions_by_offset[offset.q][offset.r]
end

---@param dir AxialDirection
---@return AxialDirection
function axial.get_opposite_direction(dir)
    return (dir + 2) % 6 + 1
end

-- Get the six hexes adjacent to the given hex
function axial.get_adjacent_hexes(hex_pos)
    local neighbors = {}
    for i, dir in pairs(adjacency_offsets) do
        table.insert(neighbors, {
            q = hex_pos.q + dir.q,
            r = hex_pos.r + dir.r
        })
    end
    return neighbors
end

-- Calculate the distance between two hexes
function axial.distance(a, b)
    -- In axial coordinates, the distance is calculated as:
    return (math.abs(a.q - b.q) + 
            math.abs(a.q + a.r - b.q - b.r) +
            math.abs(a.r - b.r)) / 2
end

---Return whether the three hexes are collinear.
---@param hex1 HexPos
---@param hex2 HexPos
---@param hex3 HexPos
---@return boolean
function axial.is_collinear(hex1, hex2, hex3)
    local dq1 = hex2.q - hex1.q
    local dr1 = hex2.r - hex1.r
    local dq2 = hex3.q - hex1.q
    local dr2 = hex3.r - hex1.r
    return dq1 * dr2 == dr1 * dq2
end

-- Get a line of hexes from a to b
function axial.line(a, b)
    local distance = axial.distance(a, b)
    local results = {}

    -- For each point along the line
    for i = 0, distance do
        local t = distance > 0 and i / distance or 0

        -- Linear interpolation in cube space
        local ac = axial.axial_to_cube(a)
        local bc = axial.axial_to_cube(b)

        -- Interpolate each coordinate separately
        local q = ac.q + (bc.q - ac.q) * t
        local r = ac.r + (bc.r - ac.r) * t
        local s = ac.s + (bc.s - ac.s) * t

        -- Round to nearest hex and convert back to axial
        local cube = axial.cube_round({q = q, r = r, s = s})
        local hex = axial.cube_to_axial(cube)

        table.insert(results, hex)
    end

    return results
end

-- Get a ring of hexes at a specific radius from the center
function axial.ring(center, radius)
    if radius < 1 then
        return {center}
    end

    local results = {}

    -- Start at a specific position on the ring
    local hex = {
        q = center.q + adjacency_offsets[6].q * radius,
        r = center.r + adjacency_offsets[6].r * radius
    }

    -- Follow the ring by moving in each of the 6 directions
    for i = 1, 6 do
        local dir = i % 6 + 1 -- Wrap around to the next direction (1-based indexing)

        -- Move radius hexes in this direction
        for j = 1, radius do
            table.insert(results, {q = hex.q, r = hex.r})

            -- Move to the next hex in this direction
            hex.q = hex.q + adjacency_offsets[dir].q
            hex.r = hex.r + adjacency_offsets[dir].r
        end
    end

    return results
end

-- Get a spiral of hexes up to a specific radius
function axial.spiral(center, radius)
    local results = {{q = center.q, r = center.r}}

    -- Add each ring from 1 to radius
    for r = 1, radius do
        local ring = axial.ring(center, r)
        for _, hex in pairs(ring) do
            table.insert(results, hex)
        end
    end

    return results
end

-- Rotate a hex around a center (in 60-degree increments)
function axial.rotate(hex, center, rotation_steps)
    -- Convert to cube coordinates relative to center
    local cube = axial.axial_to_cube(hex)
    local center_cube = axial.axial_to_cube(center)

    -- Calculate relative position
    local q = cube.q - center_cube.q
    local r = cube.r - center_cube.r
    local s = cube.s - center_cube.s

    -- Normalize rotation_steps to 0-5
    rotation_steps = rotation_steps % 6

    -- Rotate in 60-degree increments
    for i = 1, rotation_steps do
        local temp = q
        q = -s
        s = -r
        r = -temp
    end

    -- Convert back to axial coordinates and add center offset
    return {
        q = q + center_cube.q,
        r = r + center_cube.r
    }
end

-- Get the corner points of a hex in rectangular coordinates
function axial.get_hex_corners(hex_pos, axial_scale, axial_rotation, hex_size_decrement)
    -- Default values
    axial_scale = axial_scale or 1
    axial_rotation = axial_rotation or 0
    hex_size_decrement = hex_size_decrement or 0

    -- Get center without rotation
    local center = axial.get_hex_center(hex_pos, axial_scale, 0)
    local corners = {}

    -- Calculate the six corners
    local adjusted_scale = axial_scale - hex_size_decrement
    for i = 1, 6 do
        local angle = (i - 1) * math.pi / 3 + math.pi / 6 -- +30 degrees offset for flat-top orientation
        local x = center.x + adjusted_scale * math.cos(angle)
        local y = center.y + adjusted_scale * math.sin(angle)

        -- Apply rotation around the origin if needed
        if axial_rotation ~= 0 then
            local cos_r = math.cos(axial_rotation)
            local sin_r = math.sin(axial_rotation)
            x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
        end

        table.insert(corners, {x = x, y = y})
    end

    return corners
end

-- Check if two hexes are equal
function axial.equals(a, b)
    return a.q == b.q and a.r == b.r
end

-- Calculate a hash value for a hex for use in tables
function axial.hash(hex)
    -- Simple hash function for hex coordinates
    return hex.q * 10000 + hex.r
end

-- Add two hexes together
function axial.add(a, b)
    return {q = a.q + b.q, r = a.r + b.r}
end

-- Subtract hex b from hex a
function axial.subtract(a, b)
    return {q = a.q - b.q, r = a.r - b.r}
end

-- Multiply a hex by a scalar
function axial.multiply(hex, k)
    return {q = hex.q * k, r = hex.r * k}
end

-- Get a random hex within a certain radius of a center hex
function axial.random_hex(center, radius)
    -- Get a random number in the range [-radius, radius]
    local q_offset = math.random(-radius, radius)
    local r_min = math.max(-radius, -q_offset - radius)
    local r_max = math.min(radius, -q_offset + radius)
    local r_offset = math.random(r_min, r_max)

    return {
        q = center.q + q_offset,
        r = center.r + r_offset
    }
end

-- Check if a hex is within a certain radius of a center hex
function axial.is_within_radius(hex, center, radius)
    return axial.distance(hex, center) <= radius
end

---Return a new set of positions that are within, or not within, the given directions from the hex center.
---@param hex_center MapPosition
---@param positions MapPositionSet
---@param directions AxialDirectionSet
---@param hex_grid_rotation number|nil
---@return MapPositionSet
function axial.filter_positions_by_directions(hex_center, positions, directions, hex_grid_rotation)
    if not hex_grid_rotation then hex_grid_rotation = 0 end
    local new_positions = {}
    for x, X in pairs(positions) do
        for y, _ in pairs(X) do
            local angle = math.atan2(y - hex_center.y, x - hex_center.x)
            angle = (angle - hex_grid_rotation) % (2 * math.pi)

            local sector = math.floor((angle + math.pi/6) / (math.pi/3)) % 6
            local dir = inv_dir_map[sector + 1]

            if directions[dir] then
                if not new_positions[x] then
                    new_positions[x] = {}
                end
                new_positions[x][y] = true
            end
        end
    end
    return new_positions
end

function axial.clear_cache(...)
    lib.remove_at_multi_index(storage.cached, ...)
end



return axial
