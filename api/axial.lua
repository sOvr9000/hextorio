
-- Mathematics for two-way rectangular-axial coordinate system conversion,
-- as well as various utility functions for working with an axial coordinate system.
-- i.e. squares vs. hexagons

---@alias HexPos {q: int, r: int}
---@alias HexPosMap {[int]: {[int]: any}}
---@alias AxialDirection 1|2|3|4|5|6

local core_math = require "api.core_math"
local lib = require "api.lib"



local axial = {}



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

-- Convert axial coordinates to rectangular coordinates (center of hex)
-- hex_pos: {q, r} hex coordinates
-- axial_scale: size of hexes (distance from center to corner)
-- axial_rotation: rotation of the grid in radians
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
    return (directions_by_offset[offset.q] or {})[offset.r] or 1
end

---@param dir AxialDirection
---@return AxialDirection
function axial.get_opposite_direction(dir)
    return (dir + 3) % 6 + 1
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
        q = center.q + adjacency_offsets[4].q * radius,
        r = center.r + adjacency_offsets[4].r * radius
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

-- Generate a random rectangular coordinate point within a given hex
function axial.random_rect_in_hex(hex_pos, axial_scale, axial_rotation)
    -- Default values
    axial_scale = axial_scale or 1
    axial_rotation = axial_rotation or 0

    -- Get the center and corners of the hex
    local center = axial.get_hex_center(hex_pos, axial_scale, axial_rotation)
    local corners = axial.get_hex_corners(hex_pos, axial_scale, axial_rotation)

    -- Instead of rejection sampling, use triangular decomposition
    -- Pick one of the 6 triangles formed by the center and two adjacent corners
    local triangle_idx = math.random(1, 6)
    local corner1 = corners[triangle_idx]
    local corner2 = corners[triangle_idx % 6 + 1] -- Wrap around to first corner if needed

    -- Generate random barycentric coordinates
    -- For a random point in a triangle, we need 3 random numbers that sum to 1
    local a = math.random()
    local b = math.random() * (1 - a)
    local c = 1 - a - b

    -- Calculate the point using barycentric coordinates
    local x = a * center.x + b * corner1.x + c * corner2.x
    local y = a * center.y + b * corner1.y + c * corner2.y

    return {x = x, y = y}
end

-- Check if a hex overlaps a rectangle
function axial.does_hex_overlap_rect(hex_pos, hex_grid_scale, hex_grid_rotation, rect_top_left, rect_bottom_right)
    -- Get the corners of the hex
    local corners = axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)

    -- 1. Check if any hex corner is inside the rectangle
    for _, corner in pairs(corners) do
        if core_math.is_point_in_rect(corner, rect_top_left, rect_bottom_right) then
            return true
        end
    end

    -- 2. Check if any rectangle corner is inside the hex
    local rect_corners = {
        {x = rect_top_left.x, y = rect_top_left.y},           -- Top left
        {x = rect_bottom_right.x, y = rect_top_left.y},       -- Top right
        {x = rect_bottom_right.x, y = rect_bottom_right.y},   -- Bottom right
        {x = rect_top_left.x, y = rect_bottom_right.y}        -- Bottom left
    }

    for _, corner in pairs(rect_corners) do
        if core_math.is_point_in_polygon(corner, corners) then
            return true
        end
    end

    -- 3. Check if any hex edge intersects any rectangle edge
    for i = 1, 6 do
        local next_i = i % 6 + 1
        if core_math.does_segment_intersect_rect(corners[i], corners[next_i], rect_top_left, rect_bottom_right) then
            return true
        end
    end

    return false
end

-- Get all hexes that overlap a rectangular area
function axial.get_overlapping_hexes(rect_top_left, rect_bottom_right, hex_grid_scale, hex_grid_rotation)
    local coords = {x = rect_top_left.x, y = rect_top_left.y}
    local result = lib.get_at_multi_index(storage.cached, "overlapping-hexes", coords.x, coords.y, hex_grid_scale, hex_grid_rotation)
    if result then return result end
    result = axial._get_overlapping_hexes(rect_top_left, rect_bottom_right, hex_grid_scale, hex_grid_rotation)
    lib.set_at_multi_index(storage.cached, result, "overlapping-hexes", coords.x, coords.y, hex_grid_scale, hex_grid_rotation)
    return result
end

-- Get all hexes that overlap a rectangular area
function axial._get_overlapping_hexes(rect_top_left, rect_bottom_right, hex_grid_scale, hex_grid_rotation)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0

    -- Normalize the rectangle coordinates (ensure top_left is actually top-left)
    local tl = {
        x = math.min(rect_top_left.x, rect_bottom_right.x),
        y = math.min(rect_top_left.y, rect_bottom_right.y)
    }
    local br = {
        x = math.max(rect_top_left.x, rect_bottom_right.x),
        y = math.max(rect_top_left.y, rect_bottom_right.y)
    }

    -- Calculate a margin to accommodate rotated hexes that might overlap
    -- This margin should be at least the hex size plus some buffer for rotation
    local margin = hex_grid_scale * 2

    -- Get hexes for the four corners of the rectangle (plus margin)
    local tl_hex = axial.get_hex_containing({x = tl.x - margin, y = tl.y - margin}, hex_grid_scale, hex_grid_rotation)
    local tr_hex = axial.get_hex_containing({x = br.x + margin, y = tl.y - margin}, hex_grid_scale, hex_grid_rotation)
    local bl_hex = axial.get_hex_containing({x = tl.x - margin, y = br.y + margin}, hex_grid_scale, hex_grid_rotation)
    local br_hex = axial.get_hex_containing({x = br.x + margin, y = br.y + margin}, hex_grid_scale, hex_grid_rotation)

    -- Find the min/max q and r to create a bounding box of hexes
    local min_q = math.min(tl_hex.q, tr_hex.q, bl_hex.q, br_hex.q)
    local max_q = math.max(tl_hex.q, tr_hex.q, bl_hex.q, br_hex.q)
    local min_r = math.min(tl_hex.r, tr_hex.r, bl_hex.r, br_hex.r)
    local max_r = math.max(tl_hex.r, tr_hex.r, bl_hex.r, br_hex.r)

    -- Check each hex in the bounding box
    local overlapping_hexes = {}
    for q = min_q, max_q do
        for r = min_r, max_r do
            local hex = {q = q, r = r}
            if axial.does_hex_overlap_rect(hex, hex_grid_scale, hex_grid_rotation, tl, br) then
                table.insert(overlapping_hexes, hex)
            end
        end
    end

    return overlapping_hexes
end

-- Get all hexes that overlap a rectangular area
function axial.get_overlapping_chunks(hex_pos, hex_grid_scale, hex_grid_rotation)
    local result = lib.get_at_multi_index(storage.cached, "overlapping-chunks", hex_pos.q, hex_pos.r, hex_grid_scale, hex_grid_rotation)
    if result then return result end
    result = axial._get_overlapping_chunks(hex_pos, hex_grid_scale, hex_grid_rotation)
    lib.set_at_multi_index(storage.cached, result, "overlapping-chunks", hex_pos.q, hex_pos.r, hex_grid_scale, hex_grid_rotation)
    return result
end

---Return a normally indexed table of chunk positions which overlap with the given hex.
---@param hex_pos {q: int, r: int}
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@return {[int]: {x: int, y: int}}
function axial._get_overlapping_chunks(hex_pos, hex_grid_scale, hex_grid_rotation)
    local chunks = {}
    local minx, miny, maxx, maxy
    for _, vertex in pairs(axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)) do
        local x, y = math.floor(vertex.x), math.floor(vertex.y)
        if not minx then
            minx = x
            miny = y
        else
            minx = math.min(minx, x)
            miny = math.min(miny, y)
        end
        if not maxx then
            maxx = x
            maxy = y
        else
            maxx = math.max(maxx, x)
            maxy = math.max(maxy, y)
        end
    end
    local chunk_size = 32
    local chunk_minx = math.floor(minx / chunk_size) * chunk_size
    local chunk_miny = math.floor(miny / chunk_size) * chunk_size
    local chunk_maxx = math.ceil(maxx / chunk_size) * chunk_size
    local chunk_maxy = math.ceil(maxy / chunk_size) * chunk_size
    for x = chunk_minx, chunk_maxx, chunk_size do
        for y = chunk_miny, chunk_maxy, chunk_size do
            local top_left = {x = x, y = y}
            local bottom_right = {x = x + chunk_size, y = y + chunk_size}
            if axial.does_hex_overlap_rect(hex_pos, hex_grid_scale, hex_grid_rotation, top_left, bottom_right) then
                -- Convert world coordinates back to chunk coordinates
                table.insert(chunks, {x = x / chunk_size, y = y / chunk_size})
            end
        end
    end
    return chunks
end

-- Get all integer rectangular coordinates within a hex, excluding the border
function axial.get_hex_tile_positions(hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0
    stroke_width = stroke_width or 0

    -- stroke_width = stroke_width * 0.4 -- don't ask why this is necessary, it just is

    -- Get the corners of the hex
    local corners = axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)

    -- Find the bounding rectangle of the hex
    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for _, corner in pairs(corners) do
        min_x = math.min(min_x, corner.x)
        min_y = math.min(min_y, corner.y)
        max_x = math.max(max_x, corner.x)
        max_y = math.max(max_y, corner.y)
    end

    -- Round to integers (expanding slightly to ensure we cover the full hex)
    min_x = math.floor(min_x - 0.5)
    min_y = math.floor(min_y - 0.5)
    max_x = math.ceil(max_x + 0.5)
    max_y = math.ceil(max_y + 0.5)

    -- Collect all integer positions within the hex, excluding border
    local positions = {}

    for x = min_x, max_x do
        for y = min_y, max_y do
            local point = {x = x, y = y}

            -- Check if the point is inside the hex
            if core_math.is_point_in_polygon(point, corners) then
                -- If stroke_width is provided, check distance from edges
                local include = true

                if stroke_width > 0 then
                    -- Calculate minimum distance from the point to any edge of the hex
                    local min_distance = math.huge

                    for i = 1, 6 do
                        local next_i = i % 6 + 1
                        local p1 = corners[i]
                        local p2 = corners[next_i]

                        -- Calculate distance from point to line segment
                        local distance = core_math.point_to_line_distance(point, p1, p2)
                        min_distance = math.min(min_distance, distance)
                    end

                    -- Exclude points that are within stroke_width of the edge
                    include = min_distance >= stroke_width
                end

                if include then
                    table.insert(positions, {x = x, y = y})
                end
            end
        end
    end

    return positions
end

function axial.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width, hex_size_decrement, flatten_array)
    if flatten_array == nil then
        flatten_array = true
    end

    local added = {}

    hex_size_decrement = hex_size_decrement or 0
    stroke_width = stroke_width - 1
    stroke_width = stroke_width * 1.25 -- dividing by the 0.8 factor for tile overlap

    -- For each edge of the hex, place water tiles along it
    for i = 1, 6 do
        local next_i = i % 6 + 1
        local start = corners[i]
        local finish = corners[next_i]

        -- Calculate the number of steps needed (depends on hex size)
        -- Higher number for smoother border, but more intensive
        local steps = math.max(10, math.floor(hex_grid_scale * 2))

        -- Calculate direction vector of the edge
        local dir_x = finish.x - start.x
        local dir_y = finish.y - start.y

        -- Calculate perpendicular vector (for stroke width)
        local length = math.sqrt(dir_x * dir_x + dir_y * dir_y)
        local perp_x = -dir_y / length
        local perp_y = dir_x / length

        -- For each position along the edge
        for step = 1, steps do
            local t = step / steps
            local base_x = start.x + dir_x * t
            local base_y = start.y + dir_y * t

            -- Create tiles for the stroke width
            for w = -1, math.ceil(stroke_width * 1.25) do
                -- Offset in the perpendicular direction
                -- We want the stroke to go inward from the edge
                local offset = w * 0.8  -- 0.8 factor for tile overlap
                local x = math.floor(base_x + perp_x * offset + 0.5)
                local y = math.floor(base_y + perp_y * offset + 0.5)

                if not added[x] then
                    added[x] = {}
                end
                added[x][y] = true
            end
        end
    end

    if flatten_array then
        return lib.flattened_position_array(added)
    end

    return added
end

function axial.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, hex_size_decrement, flatten_array)
    hex_size_decrement = math.min(hex_size_decrement, hex_grid_scale)
    stroke_width = math.min(stroke_width, hex_grid_scale - hex_size_decrement)
    local corners = axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation, hex_size_decrement)
    return axial.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width, hex_size_decrement, flatten_array)
end

function axial.clear_cache(...)
    lib.remove_at_multi_index(storage.cached, ...)
end



return axial
