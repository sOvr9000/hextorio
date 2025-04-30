local lib = require "api.lib"
local coin_tiers = require "api.coin_tiers"
local weighted_choice = require "api.weighted_choice"
local sets = require "api.sets"
local trades = require "api.trades"
local item_values = require "api.item_values"
local item_ranks  = require "api.item_ranks"
local event_system = require "api.event_system"



local hex_grid = {}

-- Get the third coordinate (s) in the cube coordinate system
-- In axial coords, we only store q,r but sometimes need s for calculations
function hex_grid.get_s(hex)
    return -hex.q - hex.r
end

-- Convert from cube coordinates to axial coordinates
function hex_grid.cube_to_axial(cube)
    return {q = cube.q, r = cube.r}
end

-- Convert from axial coordinates to cube coordinates
function hex_grid.axial_to_cube(hex)
    return {q = hex.q, r = hex.r, s = -hex.q - hex.r}
end

-- Round floating point cube coordinates to the nearest hex
function hex_grid.cube_round(cube)
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
function hex_grid.round(hex)
    local cube = hex_grid.axial_to_cube(hex)
    local rounded_cube = hex_grid.cube_round(cube)
    return hex_grid.cube_to_axial(rounded_cube)
end

-- Convert rectangular coordinates to axial coordinates
-- rect_pos: {x, y} rectangular coordinates
-- hex_grid_scale: size of hexes (distance from center to corner)
-- hex_grid_rotation: rotation of the grid in radians
function hex_grid.get_hex_containing(rect_pos, hex_grid_scale, hex_grid_rotation)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0

    -- Apply rotation if needed
    local x, y = rect_pos.x, rect_pos.y
    if hex_grid_rotation ~= 0 then
        local cos_r = math.cos(-hex_grid_rotation)
        local sin_r = math.sin(-hex_grid_rotation)
        x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
    end

    -- Convert to cube coordinates using the inverse of the hex to pixel transformation
    local size = hex_grid_scale
    local q = (storage.constants.ROOT_THREE_OVER_THREE * x - 1/3 * y) / size
    local r = (2/3 * y) / size

    -- Create hith floating point coordinates
    local hex = {q = q, r = r}
    -- Round to the nearest hex
    return hex_grid.round(hex)
end

-- Convert axial coordinates to rectangular coordinates (center of hex)
-- hex_pos: {q, r} hex coordinates
-- hex_grid_scale: size of hexes (distance from center to corner)
-- hex_grid_rotation: rotation of the grid in radians
function hex_grid.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0

    -- Convert hex to pixel
    local size = hex_grid_scale
    local x = size * (storage.constants.ROOT_THREE * hex_pos.q + storage.constants.ROOT_THREE_OVER_TWO * hex_pos.r)
    local y = size * (1.5 * hex_pos.r)

    -- Apply rotation if needed
    if hex_grid_rotation ~= 0 then
        local cos_r = math.cos(hex_grid_rotation)
        local sin_r = math.sin(hex_grid_rotation)
        x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
    end

    return {x = x, y = y}
end

-- Get the six hexes adjacent to the given hex
function hex_grid.get_adjacent_hexes(hex_pos)
    local neighbors = {}
    for i, dir in pairs(storage.hex_grid.directions) do
        table.insert(neighbors, {
            q = hex_pos.q + dir.q,
            r = hex_pos.r + dir.r
        })
    end
    return neighbors
end

-- Calculate the distance between two hexes
function hex_grid.distance(a, b)
    -- In axial coordinates, the distance is calculated as:
    return (math.abs(a.q - b.q) + 
            math.abs(a.q + a.r - b.q - b.r) +
            math.abs(a.r - b.r)) / 2
end

-- Get a line of hexes from a to b
function hex_grid.line(a, b)
    local distance = hex_grid.distance(a, b)
    local results = {}

    -- For each point along the line
    for i = 0, distance do
        local t = distance > 0 and i / distance or 0

        -- Linear interpolation in cube space
        local ac = hex_grid.axial_to_cube(a)
        local bc = hex_grid.axial_to_cube(b)

        -- Interpolate each coordinate separately
        local q = ac.q + (bc.q - ac.q) * t
        local r = ac.r + (bc.r - ac.r) * t
        local s = ac.s + (bc.s - ac.s) * t

        -- Round to nearest hex and convert back to axial
        local cube = hex_grid.cube_round({q = q, r = r, s = s})
        local hex = hex_grid.cube_to_axial(cube)

        table.insert(results, hex)
    end

    return results
end

-- Get a ring of hexes at a specific radius from the center
function hex_grid.ring(center, radius)
    if radius < 1 then
        return {center}
    end

    local results = {}

    -- Start at a specific position on the ring
    local hex = {
        q = center.q + storage.hex_grid.directions[4].q * radius,
        r = center.r + storage.hex_grid.directions[4].r * radius
    }

    -- Follow the ring by moving in each of the 6 directions
    for i = 1, 6 do
        local dir = i % 6 + 1 -- Wrap around to the next direction (1-based indexing)

        -- Move radius hexes in this direction
        for j = 1, radius do
            table.insert(results, {q = hex.q, r = hex.r})

            -- Move to the next hex in this direction
            hex.q = hex.q + storage.hex_grid.directions[dir].q
            hex.r = hex.r + storage.hex_grid.directions[dir].r
        end
    end

    return results
end

-- Get a spiral of hexes up to a specific radius
function hex_grid.spiral(center, radius)
    local results = {{q = center.q, r = center.r}}

    -- Add each ring from 1 to radius
    for r = 1, radius do
        local ring = hex_grid.ring(center, r)
        for _, hex in pairs(ring) do
            table.insert(results, hex)
        end
    end

    return results
end

-- Rotate a hex around a center (in 60-degree increments)
function hex_grid.rotate(hex, center, rotation_steps)
    -- Convert to cube coordinates relative to center
    local cube = hex_grid.axial_to_cube(hex)
    local center_cube = hex_grid.axial_to_cube(center)

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
function hex_grid.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation, hex_size_decrement)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0
    hex_size_decrement = hex_size_decrement or 0

    -- Get center without rotation
    local center = hex_grid.get_hex_center(hex_pos, hex_grid_scale, 0)
    local corners = {}

    -- Calculate the six corners
    local adjusted_scale = hex_grid_scale - hex_size_decrement
    for i = 1, 6 do
        local angle = (i - 1) * math.pi / 3 + math.pi / 6 -- +30 degrees offset for flat-top orientation
        local x = center.x + adjusted_scale * math.cos(angle)
        local y = center.y + adjusted_scale * math.sin(angle)

        -- Apply rotation around the origin if needed
        if hex_grid_rotation ~= 0 then
            local cos_r = math.cos(hex_grid_rotation)
            local sin_r = math.sin(hex_grid_rotation)
            x, y = x * cos_r - y * sin_r, x * sin_r + y * cos_r
        end

        table.insert(corners, {x = x, y = y})
    end

    return corners
end

-- Check if two hexes are equal
function hex_grid.equals(a, b)
    return a.q == b.q and a.r == b.r
end

-- Calculate a hash value for a hex for use in tables
function hex_grid.hash(hex)
    -- Simple hash function for hex coordinates
    return hex.q * 10000 + hex.r
end

-- Add two hexes together
function hex_grid.add(a, b)
    return {q = a.q + b.q, r = a.r + b.r}
end

-- Subtract hex b from hex a
function hex_grid.subtract(a, b)
    return {q = a.q - b.q, r = a.r - b.r}
end

-- Multiply a hex by a scalar
function hex_grid.multiply(hex, k)
    return {q = hex.q * k, r = hex.r * k}
end

-- Get a random hex within a certain radius of a center hex
function hex_grid.random_hex(center, radius)
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
function hex_grid.is_within_radius(hex, center, radius)
    return hex_grid.distance(hex, center) <= radius
end

-- Generate a random rectangular coordinate point within a given hex
function hex_grid.random_rect_in_hex(hex_pos, hex_grid_scale, hex_grid_rotation)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0

    -- Get the center and corners of the hex
    local center = hex_grid.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
    local corners = hex_grid.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)

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

-- Helper function to calculate the distance from a point to a line segment
local function point_to_line_distance(point, p1, p2)
    -- Vector from p1 to p2
    local v_x = p2.x - p1.x
    local v_y = p2.y - p1.y

    -- Vector from p1 to point
    local w_x = point.x - p1.x
    local w_y = point.y - p1.y

    -- Project w onto v
    local c1 = v_x * w_x + v_y * w_y
    if c1 <= 0 then
        -- Point is closest to p1
        return math.sqrt(w_x * w_x + w_y * w_y)
    end

    -- Length of v squared
    local c2 = v_x * v_x + v_y * v_y
    if c2 <= c1 then
        -- Point is closest to p2
        local dx = point.x - p2.x
        local dy = point.y - p2.y
        return math.sqrt(dx * dx + dy * dy)
    end

    -- Point is closest to a point on the line segment
    local t = c1 / c2
    local proj_x = p1.x + t * v_x
    local proj_y = p1.y + t * v_y

    local dx = point.x - proj_x
    local dy = point.y - proj_y
    return math.sqrt(dx * dx + dy * dy)
end

-- Helper function to check if a point is inside a rectangle
local function is_point_in_rect(point, rect_top_left, rect_bottom_right)
    return point.x >= rect_top_left.x and point.x <= rect_bottom_right.x and
           point.y >= rect_top_left.y and point.y <= rect_bottom_right.y
end

-- Helper function to check if a point is inside a polygon (hex)
local function is_point_in_polygon(point, polygon)
    local inside = false
    local j = #polygon

    for i = 1, #polygon do
        if ((polygon[i].y > point.y) ~= (polygon[j].y > point.y)) and
           (point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / 
            (polygon[j].y - polygon[i].y) + polygon[i].x) then
            inside = not inside
        end
        j = i
    end

    return inside
end

-- Helper function to check if two line segments intersect
local function do_segments_intersect(p1, p2, p3, p4)
    -- Calculate the direction vectors
    local d1x, d1y = p2.x - p1.x, p2.y - p1.y
    local d2x, d2y = p4.x - p3.x, p4.y - p3.y

    -- Calculate the determinant
    local det = d1x * d2y - d1y * d2x

    -- Lines are parallel if det is close to 0
    if math.abs(det) < 1e-10 then
        return false
    end

    -- Calculate the parameters of intersection
    local dx, dy = p1.x - p3.x, p1.y - p3.y
    local t1 = (dx * d2y - dy * d2x) / det
    local t2 = (dx * d1y - dy * d1x) / det

    -- Check if the intersection is within both line segments
    return t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1
end

-- Helper function to check if a line segment intersects a rectangle
local function does_segment_intersect_rect(p1, p2, rect_top_left, rect_bottom_right)
    -- Rectangle corners
    local rect_corners = {
        {x = rect_top_left.x, y = rect_top_left.y},           -- Top left
        {x = rect_bottom_right.x, y = rect_top_left.y},       -- Top right
        {x = rect_bottom_right.x, y = rect_bottom_right.y},   -- Bottom right
        {x = rect_top_left.x, y = rect_bottom_right.y}        -- Bottom left
    }

    -- Check intersection with each edge of the rectangle
    for i = 1, 4 do
        local next_i = i % 4 + 1
        if do_segments_intersect(p1, p2, rect_corners[i], rect_corners[next_i]) then
            return true
        end
    end

    return false
end

-- Helper function to check if a hex overlaps a rectangle
local function does_hex_overlap_rect(hex_pos, hex_grid_scale, hex_grid_rotation, rect_top_left, rect_bottom_right)
    -- Get the corners of the hex
    local corners = hex_grid.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)

    -- 1. Check if any hex corner is inside the rectangle
    for _, corner in pairs(corners) do
        if is_point_in_rect(corner, rect_top_left, rect_bottom_right) then
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
        if is_point_in_polygon(corner, corners) then
            return true
        end
    end

    -- 3. Check if any hex edge intersects any rectangle edge
    for i = 1, 6 do
        local next_i = i % 6 + 1
        if does_segment_intersect_rect(corners[i], corners[next_i], rect_top_left, rect_bottom_right) then
            return true
        end
    end

    return false
end

-- Get all hexes that overlap a rectangular area
function hex_grid.get_overlapping_hexes(rect_top_left, rect_bottom_right, hex_grid_scale, hex_grid_rotation)
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
    local tl_hex = hex_grid.get_hex_containing({x = tl.x - margin, y = tl.y - margin}, hex_grid_scale, hex_grid_rotation)
    local tr_hex = hex_grid.get_hex_containing({x = br.x + margin, y = tl.y - margin}, hex_grid_scale, hex_grid_rotation)
    local bl_hex = hex_grid.get_hex_containing({x = tl.x - margin, y = br.y + margin}, hex_grid_scale, hex_grid_rotation)
    local br_hex = hex_grid.get_hex_containing({x = br.x + margin, y = br.y + margin}, hex_grid_scale, hex_grid_rotation)

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
            if does_hex_overlap_rect(hex, hex_grid_scale, hex_grid_rotation, tl, br) then
                table.insert(overlapping_hexes, hex)
            end
        end
    end

    return overlapping_hexes
end

-- Get all integer rectangular coordinates within a hex, excluding the border
function hex_grid.get_hex_tile_positions(hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0
    stroke_width = stroke_width or 0

    -- stroke_width = stroke_width * 0.4 -- don't ask why this is necessary, it just is

    -- Get the corners of the hex
    local corners = hex_grid.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)

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
            if is_point_in_polygon(point, corners) then
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
                        local distance = point_to_line_distance(point, p1, p2)
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

function hex_grid.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width, hex_size_decrement)
    local border_tiles = {}
    local added = {}

    hex_size_decrement = hex_size_decrement or 0
    stroke_width = stroke_width * 2.5 -- dividing by the 0.8 factor for tile overlap and multiplying by two to adjust for the halving of stroke width

    -- For each edge of the hex, place water tiles along it
    for i = 1, 6 do
        local next_i = i % 6 + 1
        local start = corners[i]
        local finish = corners[next_i]

        -- Calculate the number of steps needed (depends on hex size)
        -- Higher number for smoother border, but more intensive
        local steps = math.max(10, math.floor((hex_grid_scale - hex_size_decrement) * 2))

        -- Calculate direction vector of the edge
        local dir_x = finish.x - start.x
        local dir_y = finish.y - start.y

        -- Calculate perpendicular vector (for stroke width)
        local length = math.sqrt(dir_x * dir_x + dir_y * dir_y)
        local perp_x = -dir_y / length
        local perp_y = dir_x / length

        -- For each position along the edge
        for step = 0, steps do
            local t = step / steps
            local base_x = start.x + dir_x * t
            local base_y = start.y + dir_y * t

            -- Create tiles for the stroke width
            for w = 0, stroke_width - 1 do
                -- Offset in the perpendicular direction
                -- We want the stroke to go inward from the edge
                local offset = (w - (stroke_width - 1) / 2) * 0.8  -- 0.8 factor for tile overlap
                local x = math.floor(base_x + perp_x * offset + 0.5)
                local y = math.floor(base_y + perp_y * offset + 0.5)

                if not added[x] then
                    added[x] = {}
                end
                if not added[x][y] then
                    table.insert(border_tiles, {x = x, y = y})
                    added[x][y] = true
                end
            end
        end
    end

    -- Remove duplicates

    return border_tiles
end

function hex_grid.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, hex_size_decrement)
    hex_size_decrement = math.min(hex_size_decrement, hex_grid_scale)
    stroke_width = math.min(stroke_width, hex_grid_scale - hex_size_decrement)
    local corners = hex_grid.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation, hex_size_decrement)
    return hex_grid.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width, hex_size_decrement)
end

----------------------------------------
-- Hex grid generation and management --
----------------------------------------

function hex_grid.register_events()
    event_system.register_callback("item-rank-up", function(item_name)
        if item_ranks.get_item_rank(item_name) == 2 then
            hex_grid.apply_extra_trades_bonus_retro(item_name)
        end
        hex_grid.update_all_trades()
    end)

    event_system.register_callback("command-add-trade", function(player, params)
        local hex_core = player.selected
        if not hex_core then return end
        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end
        local trade = trades.from_item_names(hex_core.surface.name, params[1], params[2])
        if not trade then
            player.print("Failed to generate trade with inputs = " .. serpent.line(params[1]) .. ", outputs = " .. serpent.line(params[2]))
            return
        end
        hex_grid.add_trade(state, trade)
    end)

    event_system.register_callback("command-remove-trade", function(player, params)
        local hex_core = player.selected
        if not hex_core then return end
        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end
        local idx = params[1]
        if idx <= 0 or idx > #state.trades then
            player.print("Failed to remove trade at index " .. idx)
            return
        end
        local trade = state.trades[idx]
        player.print("Removed trade: " .. lib.get_trade_img_str(trade))
        hex_grid.remove_trade(state, idx)
    end)

    event_system.register_callback("command-debug-mode", function(player, params)
        hex_grid.claim_hexes_range(player.surface.name, {q = 0, r = 0}, 1, nil, true) -- claim by server
    end)

    event_system.register_callback("command-claim", function(player, params)
        if params[1] then
            if params[1] > 2 then
                player.print("The claim range is too large!")
                return
            end
            if params[1] < 0 then
                player.print("The claim range must be nonnegative.")
                return
            end
        end
        local transformation = hex_grid.get_surface_transformation(player.surface)
        if not transformation then return end
        local hex_pos = hex_grid.get_hex_containing(player.position, transformation.scale, transformation.rotation)
        hex_grid.claim_hexes_range(player.surface.name, hex_pos, params[1] or 0, nil, false) -- claim by server
    end)

    event_system.register_callback("command-force-claim", function(player, params)
        if params[1] then
            if params[1] > 2 then
                player.print("The claim range is too large!")
                return
            end
            if params[1] < 0 then
                player.print("The claim range must be nonnegative.")
                return
            end
        end
        local transformation = hex_grid.get_surface_transformation(player.surface)
        if not transformation then return end
        local hex_pos = hex_grid.get_hex_containing(player.position, transformation.scale, transformation.rotation)
        hex_grid.claim_hexes_range(player.surface.name, hex_pos, params[1] or 0, nil, true) -- claim by server
    end)
end

-- Get or create surface storage
function hex_grid.get_surface_hexes(surface)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("hex_grid.get_surface_hexes: surface not found: " .. tostring(surface))
        surface_id = 0
    end
    local surface_hexes = storage.hex_grid.surface_hexes[surface_id]
    if not surface_hexes then
        surface_hexes = {}
        storage.hex_grid.surface_hexes[surface_id] = surface_hexes
    end
    return surface_hexes
end

-- Same as get_surface_hexes, but the returned array is one-dimensional.
function hex_grid.get_flattened_surface_hexes(surface)
    local surface_hexes = hex_grid.get_surface_hexes(surface)
    local flattened_surface_hexes = {}
    for _, Q in pairs(surface_hexes) do
        for _, state in pairs(Q) do
            table.insert(flattened_surface_hexes, state)
        end
    end
    return flattened_surface_hexes
end

-- Get a hex by its axial coordinates in a surface's hex grid.  Defaults and sets to an empty table if the hex does not exist.
function hex_grid.get_hex_in_surface_hexes(surface_hexes, hex_pos)
    local Q = surface_hexes[hex_pos.q]
    if not Q then
        Q = {}
        surface_hexes[hex_pos.q] = Q
    end
    local state = Q[hex_pos.r]
    if not state then
        state = {}
        Q[hex_pos.r] = state
    end
    return state
end

-- Get the state of a hex on a specific surface
function hex_grid.get_hex_state(surface, hex_pos)
    local surface_hexes = hex_grid.get_surface_hexes(surface)
    local state = hex_grid.get_hex_in_surface_hexes(surface_hexes, hex_pos)

    if not state.position then
        state.position = {q = hex_pos.q, r = hex_pos.r} -- copy position just in case
    end

    return state
end

-- Get the state of a hex from a hex core entity
function hex_grid.get_hex_state_from_core(hex_core)
    if not hex_core then return end

    local transformation = hex_grid.get_surface_transformation(hex_core.surface.name)
    if not transformation then
        lib.log_error("No transformation found for surface " .. serpent.line(hex_core.surface.name))
        return
    end

    local hex_pos = hex_grid.get_hex_containing(hex_core.position, transformation.scale, transformation.rotation)
    local state = hex_grid.get_hex_state(hex_core.surface.name, hex_pos)

    if state.hex_core ~= hex_core then
        lib.log_error("hex core entities do not match")
        lib.log_error(state.hex_core)
        lib.log_error(hex_core)
    end

    return state
end

-- Add a trade to a hex core.
function hex_grid.add_trade(hex_core_state, trade)
    if not hex_core_state then
        lib.log_error("hex_grid.add_trade: nil hex core state")
        return
    end
    if not trades.is_trade_valid(trade) then
        lib.log_error("hex_grid.add_trade: trade is invalid")
        return
    end
    trade.hex_core_state = hex_core_state
    table.insert(hex_core_state.trades, trades.copy_trade(trade))

    hex_grid.update_hex_core_inventory_filters(hex_core_state)

    if hex_core_state.claimed then
        trades.discover_items_in_trades {trade}
    end
end

function hex_grid.remove_trade(hex_core_state, idx)
    if not hex_core_state then
        lib.log_error("hex_grid.add_trade: nil hex core state")
        return
    end
    if idx <= 0 or idx > #hex_core_state.trades then
        lib.log_error("hex_grid.remove_trade: invalid index " .. idx)
        return
    end
    table.remove(hex_core_state.trades, idx)
end

function hex_grid.apply_extra_trade_bonus(state, item_name, volume)
    if state.mode == "sink" or state.mode == "generator" then return end
    if math.random() > 0.01 then return end
    local input_names, output_names = trades.random_trade_item_names(state.hex_core.surface.name, volume, {blacklist = sets.new {item_name}})
    if not input_names or not output_names then
        lib.log_error("hex_grid.apply_extra_trade_bonus: failed to get random trade item name from volume = " .. volume)
        return
    end
    local for_output = math.random() < 0.5
    if for_output then
        input_names, output_names = output_names, input_names
    end
    input_names[math.random(1, #input_names)] = item_name
    if for_output then
        input_names, output_names = output_names, input_names
    end
    local trade = trades.from_item_names(state.hex_core.surface.name, input_names, output_names)
    hex_grid.add_trade(state, trade)
    -- game.print{"hextorio.bonus-trade", lib.get_gps_str_from_hex_core(state.hex_core), "[item=" .. item_name .. "]"}
    return trade
end

function hex_grid.apply_extra_trades_bonus(state)
    if not state or not state.hex_core or not state.trades then return end
    local surface = state.hex_core.surface
    local surface_values = item_values.get_item_values_for_surface(surface.name)
    if surface_values then
        local added_trades = {}
        for item_name, _ in pairs(surface_values) do
            if lib.is_catalog_item(item_name) then -- prevent defining an item rank for something that shouldn't have a rank
                local rank = item_ranks.get_item_rank(item_name)
                if rank >= 2 then
                    local trade = hex_grid.apply_extra_trade_bonus(state, item_name, trades.get_random_volume_for_item(surface.name, item_name))
                    if trade then -- "if" check isn't necessary, technically
                        added_trades[item_name] = trade
                    end
                end
            end
        end
        if next(added_trades) then
            local new_trades_str = ""
            for item_name, trade in pairs(added_trades) do
                new_trades_str = new_trades_str .. "[img=item." .. item_name .. "]"
            end
            game.print{"hextorio.bonus-trade", lib.get_gps_str_from_hex_core(state.hex_core), new_trades_str}
        end
    end
end

function hex_grid.set_trade_active(hex_core_state, trade_index, flag)
    if not trades.set_trade_active(hex_core_state.trades[trade_index], flag) then return end
    -- hex_grid.update_loader_filters(hex_core_state)
end

function hex_grid.switch_hex_core_mode(state, mode)
    if not mode then
        lib.log_error("hex_grid.switch_hex_core_mode: Tried to set mode to nil")
        return false
    end
    if not state or not state.trades or state.mode then return false end

    if mode == "generator" then
        local all_outputs = sets.new()
        for i = #state.trades, 1, -1 do
            for _, output in pairs(state.trades[i].output_items) do
                if not lib.is_coin(output.name) then
                    sets.add(all_outputs, output.name)
                end
            end
            hex_grid.remove_trade(state, i)
        end
        local params = {target_efficiency = 0.1}
        for item_name, _ in pairs(all_outputs) do
            local trade = trades.from_item_names(state.hex_core.surface.name, {"hex-coin"}, {item_name}, params) -- TODO: Implement target_efficiency
            if trade then

                -- TODO: when target_efficiency is implemented, remove the loop below
                for _, input in pairs(trade.input_items) do
                    input.count = math.floor(0.5 + input.count / params.target_efficiency)
                end

                hex_grid.add_trade(state, trade)
            end
        end
    elseif mode == "sink" then
        local all_inputs = sets.new()
        for i = #state.trades, 1, -1 do
            for _, input in pairs(state.trades[i].input_items) do
                if not lib.is_coin(input.name) then
                    sets.add(all_inputs, input.name)
                end
            end
            hex_grid.remove_trade(state, i)
        end
        local params = {target_efficiency = 0.1}
        for item_name, _ in pairs(all_inputs) do
            local trade = trades.from_item_names(state.hex_core.surface.name, {item_name}, {"hex-coin"}, params) -- TODO: Implement target_efficiency
            if trade then

                -- TODO: when target_efficiency is implemented, remove the loop below
                for _, input in pairs(trade.input_items) do
                    input.count = math.floor(0.5 + input.count / params.target_efficiency)
                end

                hex_grid.add_trade(state, trade)
            end
        end
    else
        lib.log_error("hex_grid.switch_hex_core_mode: Unrecognized mode: " .. mode)
        return false
    end

    state.mode = mode
    return true
end

function hex_grid.update_hex_core_inventory_filters(hex_core_state)
    local inventory = hex_core_state.hex_core_input_inventory
    if not inventory or not inventory.valid then return end

    -- Clear all filters
    for i = 1, #inventory do
        inventory.set_filter(i, nil)
    end

    -- Set filters for non-coin items in trades
    i = 1
    j = 0
    for _, trade in pairs(hex_core_state.trades) do
        for _, input in pairs(trade.input_items) do
            if i - j > #inventory then break end
            if input.name:sub(-5) == "-coin" then
                j = j + 1
            else
                inventory.set_filter(i - j, {name = input.name, quality = "normal"})
            end
            i = i + 1
        end
        for _, output in pairs(trade.output_items) do
            if i - j > #inventory then break end
            if output.name:sub(-5) == "-coin" then
                j = j + 1
            else
                inventory.set_filter(i - j, {name = output.name, quality = "normal"})
            end
            i = i + 1
        end
    end

    -- Set filters for coins
    i = i - j
    if j > 0 then
        if i <= #inventory then inventory.set_filter(i, {name = "hex-coin", quality = "normal"}) end
        if i+1 <= #inventory then inventory.set_filter(i+1, {name = "gravity-coin", quality = "normal"}) end
        if i+2 <= #inventory then inventory.set_filter(i+2, {name = "meteor-coin", quality = "normal"}) end
        if i+3 <= #inventory then inventory.set_filter(i+3, {name = "hexaprism-coin", quality = "normal"}) end
    end
end

-- Set the tile type for a specific position
function hex_grid.set_tile(surface, position, tile_type)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    if not surface then
        lib.log_error("Invalid surface")
        return
    end

    surface.set_tiles({{name = tile_type, position = position}})
end

-- Set the tile type for a list of positions
function hex_grid.set_tiles(surface, positions, tile_type)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    if not surface then
        lib.log_error("Invalid surface")
        return
    end

    local tiles = {}
    for _, position in pairs(positions) do
        table.insert(tiles, {name = tile_type, position = position})
    end
    surface.set_tiles(tiles)
end

-- Set all tiles within a hex to tile_type
function hex_grid.set_hex_tiles(surface, hex_pos, tile_type, overwrite_water)
    if tile_type == "none" then return end

    if overwrite_water == nil then
        overwrite_water = true
    end

    local transformation = hex_grid.get_surface_transformation(surface)
    if not transformation then
        lib.log_error("No transformation found for surface " .. serpent.line(surface))
        return
    end

    local positions = hex_grid.get_hex_tile_positions(hex_pos, transformation.scale, transformation.rotation, transformation.stroke_width)

    hex_grid.set_tiles(surface, positions, tile_type)
end

-- Generate tiles along the border of a hex
function hex_grid.generate_hex_border(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0
    stroke_width = stroke_width or 3

    local corners = hex_grid.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)
    local border_tiles = hex_grid.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width)

    -- Set all border tiles to water
    hex_grid.set_tiles(surface, border_tiles, "water")
end

function hex_grid.get_surface_transformation(surface)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("Cannot find surface from " .. serpent.line(surface))
        return
    end

    local transformations = storage.hex_grid.surface_transformations
    local transformation = transformations[surface_id]
    if not transformation then
        transformation = {}
        transformations[surface_id] = transformation
    end
    if not transformation.scale then
        transformation.scale = lib.startup_setting_value "hex-size"
    end
    if not transformation.rotation then
        local mode = lib.startup_setting_value "grid-rotation-mode"
        if mode == "random" then
            transformation.rotation = math.random() * math.pi
        elseif mode == "flat-top" then
            transformation.rotation = math.pi * 0.5
        elseif mode == "pointed-top" then
            transformation.rotation = 0
        end
    end
    if not transformation.stroke_width then
        transformation.stroke_width = lib.startup_setting_value "hex-stroke-width"
    end
    return transformation
end

-- Initialize a hex with default state and generate its border
function hex_grid.initialize_hex(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("initialize_hex: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local state = hex_grid.get_hex_state(surface_id, hex_pos)

    -- Skip if this hex has already been generated
    if state.generated then
        return
    end

    hex_grid.generate_hex_border(surface_id, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)

    local land_chance = (lib.remap_map_gen_setting(1 / storage.hex_grid.nauvis_mgs_original.autoplace_controls.water.frequency) + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls.water.size)) * 0.5
    if storage.hex_grid.nauvis_mgs_original.autoplace_controls.water.size == 0 then
        land_chance = 0
    end
    land_chance = (1 - land_chance * land_chance) ^ 0.5
    -- lib.log("land chance: " .. land_chance)

    local dist = hex_grid.distance(hex_pos, {q=0, r=0})
    local is_starting_hex = dist == 0
    local is_land = is_starting_hex or math.random() < land_chance

    if is_starting_hex then
        state.is_starting_hex = true
    end

    if is_land then
        state.is_land = true

        -- Calculating these parameters for each newly spawned hex because map gen settings can change.
        local total_resource_freq = 0
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["iron-ore"].frequency)
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["copper-ore"].frequency)
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["coal"].frequency)
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["stone"].frequency)
        -- total_resource_freq = total_resource_freq + storage.hex_grid.nauvis_mgs_original.autoplace_controls["uranium-ore"].frequency
        total_resource_freq = total_resource_freq * 0.25

        local resource_chance = 0.1 + 0.9 * total_resource_freq
        resource_chance = resource_chance * resource_chance
        local is_resource_hex = is_starting_hex or math.random() < resource_chance

        if is_resource_hex then
            state.is_resources = true

            local min_uranium_dist = lib.runtime_setting_value "min-uranium-dist"
            local wc = weighted_choice.copy(storage.hex_grid.nauvis_resource_weighted_choice)
            if is_starting_hex then
                wc = weighted_choice.copy(storage.hex_grid.starting_resource_weighted_choice)
            elseif dist < min_uranium_dist then
                wc = weighted_choice.copy(storage.hex_grid.non_uranium_resource_weighted_choice)
            end

            if not is_starting_hex then
                -- Based on the standard weighted choice, apply a random bias
                local bias_wc = weighted_choice.copy(wc)
                local resource = weighted_choice.choice(wc)

                local bias_strength = lib.runtime_setting_value "resource-bias"

                -- Make the selected resource more likely to be chosen
                wc = weighted_choice.add_bias(bias_wc, resource, bias_strength)
            end

            local total_resource_size = 0
            total_resource_size = total_resource_size + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["iron-ore"].size)
            total_resource_size = total_resource_size + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["copper-ore"].size)
            total_resource_size = total_resource_size + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["coal"].size)
            total_resource_size = total_resource_size + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["stone"].size)
            -- total_resource_size = total_resource_size + storage.hex_grid.nauvis_mgs_original.autoplace_controls["uranium-ore"].size
            total_resource_size = total_resource_size * 0.25

            local r = math.random()
            local resource_stroke_width = 2 + r ^ 0.5 * (total_resource_size * 5 + dist * lib.runtime_setting_value "resource-width-per-dist")
            resource_stroke_width = math.min(resource_stroke_width, math.max(2, hex_grid_scale - stroke_width - 5))
            local is_mixed
            if is_starting_hex then
                is_mixed = lib.runtime_setting_value "starting-resources-mixed"
                resource_stroke_width = lib.runtime_setting_value "starting-hex-resource-stroke-width" + 1 -- plus 1 because rounding math is messed up for some reason at the starting hex
            else
                is_mixed = lib.runtime_setting_value "default-resources-mixed"
            end

            hex_grid.generate_hex_resources(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, resource_stroke_width, wc, is_mixed)
        end

        local min_biter_distance = lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.starting_area, 0, 3)
        local is_biter_hex = not is_starting_hex and dist >= min_biter_distance
        if is_biter_hex then
            local biter_chance = lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["enemy-base"].frequency)
            is_biter_hex = math.random() < biter_chance
            if is_biter_hex then
                if hex_grid.generate_hex_biters(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width) then
                    state.is_biters = true
                end
            end
        end
    else
        hex_grid.generate_non_land_tiles(surface, hex_pos)
    end

    state.generated = true
end

-- Generate a small ring of mixed resources right up to the border of the hex
function hex_grid.generate_hex_resources(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, resource_stroke_width, resource_wc, is_mixed)
    -- lib.log(serpent.line(resource_wc))

    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("generate_hex_resources: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local state = hex_grid.get_hex_state(surface_id, hex_pos)
    if not state then
        lib.log_error("generate_hex_resources: No hex state found")
        return
    end

    local inner_border_tiles = hex_grid.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, resource_stroke_width, stroke_width)
    local base_richness = 200 * lib.runtime_setting_value "base-resource-richness"

    local dist = hex_grid.distance(hex_pos, {q=0, r=0})
    local scaled_richness = base_richness + dist * lib.runtime_setting_value "resource-richness-per-dist"

    local oil_chance = lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["crude-oil"].frequency, 0.05, 0.5)
    local is_oil_hex = not state.is_starting_hex and math.random() < oil_chance

    if is_oil_hex then
        state.is_oil = true
        state.resources = {["crude-oil"] = 0}

        local amount = scaled_richness * 3000
        local num_entities_min = math.floor(0.5 + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["crude-oil"].size, 1, 3))
        local num_entities_max = math.floor(0.5 + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["crude-oil"].size, 3, 6))
        local num_entities = math.random(num_entities_min, num_entities_max)
        local radius = math.max(7, (hex_grid_scale - stroke_width) * 0.5)
        local rotation = math.random() * math.pi * 2

        for i = 1, num_entities do
            local angle = rotation + math.pi * 2 * i / num_entities
            local center = hex_grid.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
            local x = center.x + math.cos(angle) * radius
            local y = center.y + math.sin(angle) * radius
            local entity = surface.create_entity{
                name = "crude-oil",
                position = {x, y},
                amount = amount * (0.8 + 0.2 * math.random()),
            }
            if entity then
                state.resources["crude-oil"] = state.resources["crude-oil"] + entity.amount
            end
        end
    else
        state.resources = {["iron-ore"] = 0, ["copper-ore"] = 0, ["coal"] = 0, ["stone"] = 0, ["uranium-ore"] = 0}

        local uranium_freq = lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["uranium-ore"].frequency)

        local total_resource_freq = 0
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["iron-ore"].frequency)
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["copper-ore"].frequency)
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["coal"].frequency)
        total_resource_freq = total_resource_freq + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["stone"].frequency)
        total_resource_freq = total_resource_freq + uranium_freq

        local uranium_chance = uranium_freq / total_resource_freq
        local is_uranium = not state.is_starting_hex and math.random() < uranium_chance

        if is_uranium then
            -- remove all except uranium
            weighted_choice.set_weight(resource_wc, "iron-ore", 0)
            weighted_choice.set_weight(resource_wc, "copper-ore", 0)
            weighted_choice.set_weight(resource_wc, "coal", 0)
            weighted_choice.set_weight(resource_wc, "stone", 0)
        else
            -- remove uranium
            weighted_choice.set_weight(resource_wc, "uranium-ore", 0)
        end

        local pie_angles, hex_pos_rect, rotation
        if not is_mixed then
            pie_angles = lib.get_pie_angles(resource_wc)
            hex_pos_rect = hex_grid.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
            rotation = math.random() * math.pi * 2
        end

        for _, tile in pairs(inner_border_tiles) do
            if lib.is_land_tile(surface, tile) then
                local resource
                if is_mixed then
                    resource = weighted_choice.choice(resource_wc)
                    if not resource then
                        lib.log_error("generate_hex_resources: weighed choice has zero weights")
                        return
                    end
                else
                    local angle = (math.atan2(tile.y - hex_pos_rect.y, tile.x - hex_pos_rect.x) + rotation) % (2 * math.pi)
                    resource = lib.get_item_in_pie_angles(pie_angles, angle) or "iron-ore"
                end
                local amount_mean = scaled_richness * storage.hex_grid.nauvis_mgs_original.autoplace_controls[resource].richness
                local amount = math.floor(amount_mean * (0.8 + 0.2 * math.random()))
                if amount > 0 then
                    local entity = surface.create_entity {name = resource, position = tile, amount = amount}
                    if entity then
                        state.resources[resource] = state.resources[resource] + amount
                    end
                end
            end
        end
    end

    for resource, amount in pairs(state.resources) do
        if amount <= 0 then
            state.resources[resource] = nil
        end
    end
end

function hex_grid.generate_hex_biters(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("generate_hex_resources: No surface found")
        return false
    end
    surface = game.surfaces[surface_id]

    local num_spawners_min = math.floor(0.5 + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["enemy-base"].size, 1, 3))
    local num_spawners_max = math.floor(0.5 + lib.remap_map_gen_setting(storage.hex_grid.nauvis_mgs_original.autoplace_controls["enemy-base"].size, 1, 5))
    local num_spawners = math.random(num_spawners_min, num_spawners_max)
    local num_worms = math.floor(0.4999 + num_spawners * (0.5 + math.random()))
    local center = hex_grid.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)

    return hex_grid.spawn_enemy_base(surface, center, hex_grid_scale - stroke_width, num_spawners, num_worms)
end

function hex_grid.spawn_enemy_base(surface, center, max_radius, num_spawners, num_worms)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("generate_hex_resources: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local wc_table = {}
    if math.random() < 0.5 then
        wc_table["biter-spawner"] = math.floor(num_spawners / 2)
        wc_table["spitter-spawner"] = num_spawners - wc_table["biter-spawner"]
    else
        wc_table["spitter-spawner"] = math.floor(num_spawners / 2)
        wc_table["biter-spawner"] = num_spawners - wc_table["spitter-spawner"]
    end

    local worm_type = "behemoth-worm-turret"
    local evo = game.forces.player.get_evolution_factor(surface)
    if evo < 0.25 then
        worm_type = "small-worm-turret"
    elseif evo < 0.50 then
        worm_type = "medium-worm-turret"
    elseif evo < 0.75 then
        worm_type = "big-worm-turret"
    end
    wc_table[worm_type] = num_worms

    local entity_table = {}
    for name, count in pairs(wc_table) do
        for i = 1, count do
            table.insert(entity_table, name)
        end
    end

    local inner_radius = max_radius * 0.75
    local search_radius = math.max(1, max_radius - inner_radius)
    local any_spawned = false
    for i = 1, #entity_table do
        local idx = math.random(1, #entity_table)
        local entity_name = entity_table[idx]
        table.remove(entity_table, idx)

        local angle = math.random() * math.pi * 2
        local r = math.random() * inner_radius
        local x = center.x + math.cos(angle) * r
        local y = center.y + math.sin(angle) * r

        local pos = surface.find_non_colliding_position(entity_name, {x, y}, search_radius, 0.5, true)
        if pos then
            local entity = surface.create_entity {
                name = entity_name,
                position = pos,
                force = "enemy",
            }
            if entity then
                any_spawned = true
            end
        end
    end

    return any_spawned
end

function hex_grid.generate_non_land_tiles(surface, hex_pos)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("generate_non_land_tiles: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local tile_type
    if surface.name == "nauvis" then
        tile_type = "deepwater"
    elseif surface.name == "vulcanus" then
        tile_type = "lava-hot"
    elseif surface.name == "fulgora" then
        tile_type = "oil-ocean"
    elseif surface.name == "gleba" then
        tile_type = "water" -- TODO BUG FIX this
    elseif surface.name == "aquilo" then
        tile_type = "ammoniacal-ocean"
    end

    hex_grid.set_hex_tiles(surface, hex_pos, tile_type, true)
end

-- Check if a hex core can be spawned within a hex
function hex_grid.can_hex_core_spawn(surface, hex_pos)
    local state = hex_grid.get_hex_state(surface, hex_pos)
    if state.hex_core or not state.is_land then
        return false
    end
    if hex_pos.q == 0 and hex_pos.r == 0 then
        return true
    end
    if hex_grid.is_hex_near_claimed_hex(surface, hex_pos) then
        return true
    end
    return false
end

-- Check if a hex is near a claimed hex
function hex_grid.is_hex_near_claimed_hex(surface, hex_pos)
    local adjacent_hexes = hex_grid.get_adjacent_hexes(hex_pos)
    for _, adj_hex in pairs(adjacent_hexes) do
        local state = hex_grid.get_hex_state(surface, adj_hex)
        if state.claimed then
            return true
        end
    end
    return false
end

function hex_grid.can_claim_hex(player, surface, hex_pos, allow_nonland)
    local state = hex_grid.get_hex_state(surface, hex_pos)
    if state.claimed then return false end

    if not state.is_land and not allow_nonland then return end

    local coin = state.claim_price
    if not coin or coin_tiers.is_zero(coin) then
        return true
    end

    local inv = lib.get_player_inventory(player)
    if not inv then
        lib.log_error("can_claim_hex: No inventory found")
        return
    end

    return coin_tiers.ge(coin_tiers.get_coin_from_inventory(inv), coin)
end

-- Claim a hex and spawn hex cores in adjacent hexes if possible.
function hex_grid.claim_hex(surface, hex_pos, by_player, allow_nonland)
    if by_player and not hex_grid.can_claim_hex(by_player, surface, hex_pos) then return end

    local state = hex_grid.get_hex_state(surface, hex_pos)
    if state.claimed then return end

    if not state.is_land and not allow_nonland then return end

    state.claimed = true
    state.claimed_by = by_player
    if state.claimed_by then
        state.claimed_by = state.claimed_by.name -- player's name, not player object, and nil means by server
    end

    state.claimed_timestamp = game.tick

    local adjacent_hexes = hex_grid.get_adjacent_hexes(hex_pos)
    local transformation = hex_grid.get_surface_transformation(surface)

    if not transformation then
        lib.log_error("claim_hex: No transformation found")
        return
    end

    for _, adj_hex in pairs(adjacent_hexes) do
        if hex_grid.can_hex_core_spawn(surface, adj_hex) then
            hex_grid.spawn_hex_core(surface, hex_grid.get_hex_center(adj_hex, transformation.scale, transformation.rotation))
        end
    end

    -- Set tiles
    local tile_name
    if by_player then
        tile_name = lib.player_setting_value(by_player, "claimed-hex-tile")

        -- Purchase
        coin_tiers.remove_coin_from_inventory(lib.get_player_inventory(by_player), state.claim_price)
    end
    if not tile_name then
        if storage.hex_grid.last_used_claim_tile then
            tile_name = storage.hex_grid.last_used_claim_tile
        else
            tile_name = "refined-concrete"
        end
    else
        storage.hex_grid.last_used_claim_tile = tile_name
    end
    hex_grid.set_hex_tiles(surface, hex_pos, tile_name)
    -- log("claimed hex at " .. serpent.line(hex_pos) .. " / " .. serpent.line(hex_grid.get_hex_center(hex_pos, transformation.scale, transformation.rotation)))

    -- TODO: This check will never be necessary in the release.  It is needed right now for testing with "/claim q r"
    if hex_grid.can_hex_core_spawn(surface, hex_pos) then
        hex_grid.spawn_hex_core(surface, hex_grid.get_hex_center(hex_pos, transformation.scale, transformation.rotation))
    end

    local fill_tile_name
    if by_player then
        fill_tile_name = lib.player_setting_value(by_player, "edge-fill-tile")
    end
    if not fill_tile_name then
        if storage.hex_grid.last_used_edge_fill_tile then
            fill_tile_name = storage.hex_grid.last_used_edge_fill_tile
        else
            fill_tile_name = "black-refined-concrete"
        end
    else
        storage.hex_grid.last_used_edge_fill_tile = fill_tile_name
    end

    -- Fill in the edges between claimed hexes
    hex_grid.fill_edges_between_claimed_hexes(surface, hex_pos, fill_tile_name)
    hex_grid.fill_corners_between_claimed_hexes(surface, hex_pos, fill_tile_name)

    -- Add trade items to catalog list
    trades.discover_items_in_trades(state.trades)
end

-- Claim hexes within a range, covering water as well
function hex_grid.claim_hexes_range(surface, hex_pos, range, by_player, allow_nonland)
    hex_grid._claim_hexes_dfs(surface, hex_pos, range, by_player, hex_pos, allow_nonland)
end

function hex_grid._claim_hexes_dfs(surface, hex_pos, range, by_player, center_pos, allow_nonland)
    local dist = hex_grid.distance(hex_pos, center_pos)
    if dist > range then return end

    local state = hex_grid.get_hex_state(surface, hex_pos)
    if not state.claimed then
        hex_grid.claim_hex(surface, hex_pos, by_player, allow_nonland)
    end

    for _, adj_hex in pairs(hex_grid.get_adjacent_hexes(hex_pos)) do
        local adj_state = hex_grid.get_hex_state(surface, adj_hex)
        if not adj_state.claimed then
            hex_grid._claim_hexes_dfs(surface, adj_hex, range, by_player, center_pos, allow_nonland)
        end
    end
end

-- Handle chunk generation event for the hex grid
function hex_grid.on_chunk_generated(surface, chunk_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    -- lib.log("hex_grid.on_chunk_generated: " .. surface.name .. ", " .. serpent.line(chunk_pos))

    -- Default values
    local transformation = hex_grid.get_surface_transformation(surface)

    if not transformation then
        lib.log_error("on_chunk_generated: No transformation found")
        return
    end

    hex_grid_scale = transformation.scale
    hex_grid_rotation = transformation.rotation
    stroke_width = transformation.stroke_width

    -- Convert chunk position to rectangle coordinates
    local top_left, bottom_right = lib.chunk_to_rect(chunk_pos)

    -- Find all hexes that overlap with this chunk
    local overlapping_hexes = hex_grid.get_overlapping_hexes(
        top_left, bottom_right, hex_grid_scale, hex_grid_rotation
    )

    -- Initialize each overlapping hex if not already generated
    for _, hex_pos in pairs(overlapping_hexes) do
        if storage.events.has_game_started or storage.events.is_nauvis_generating then
            hex_grid.initialize_hex(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)

            local center = hex_grid.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
            if lib.is_position_in_rect(center, top_left, bottom_right) and hex_grid.can_hex_core_spawn(surface, hex_pos) then
                hex_grid.spawn_hex_core(surface, center)
            end
        end
    end

    -- Return the hexes that were processed for this chunk
    return overlapping_hexes
end

-- Spawn a hex core at the given position
function hex_grid.spawn_hex_core(surface, position)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    if not surface then
        lib.log_error("Invalid surface")
        return
    end

    local transformation = hex_grid.get_surface_transformation(surface_id)
    if not transformation then
        lib.log_error("spawn_hex_core: No transformation found")
        return
    end

    local hex_pos = hex_grid.get_hex_containing(position, transformation.scale, transformation.rotation)
    local state = hex_grid.get_hex_state(surface_id, hex_pos)
    if state.hex_core then return end

    local dist = hex_grid.distance(hex_pos, {q=0, r=0})
    local is_starting_hex = dist == 0

    local entities = surface.find_entities_filtered {
        area = {{position.x - 2.5, position.y - 2.5}, {position.x + 2.5, position.y + 2.5}},
    }
    -- lib.log("Spawning hex core. Found " .. #entities .. " entities in area")

    for _, e in pairs(entities) do
        if e.type ~= "character" then
            -- lib.log("Destroying entity: " .. serpent.line(e))
            e.destroy()
        end
    end

    -- Hex core
    local hex_core = surface.create_entity {name = "hex-core", position = position, force = "player"}
    if not hex_core then
        lib.log_error("Failed to spawn hex core")
        return
    end
    hex_core.destructible = false

    for _, e in pairs(entities) do
        if e.valid and e.type == "character" then
            lib.unstuck_player(e.player)
        end
    end

    local claim_price = hex_grid.distance(state.position, {q=0, r=0}) + 1
    claim_price = claim_price * claim_price

    state.hex_core = hex_core
    state.hex_core_input_inventory = hex_core.get_inventory(defines.inventory.chest)
    -- state.hex_core_output_inventory = output_chest.get_inventory(defines.inventory.chest)
    state.hex_core_output_inventory = state.hex_core_input_inventory
    state.claim_price = coin_tiers.from_base_value(claim_price)

    hex_grid.generate_loaders(state)

    state.trades = {}
    local hex_core_trades = {}
    if is_starting_hex then
        for _, trade in pairs(storage.trades.starting_trades) do
            table.insert(hex_core_trades, trades.from_item_names(surface.name, table.unpack(trade)))
        end
    else
        local items_sorted_by_value = item_values.get_items_sorted_by_value(surface.name)
        local max_item_value = item_values.get_item_value(surface.name, items_sorted_by_value[#items_sorted_by_value])
        local max_volume = lib.runtime_setting_value "trade-volume-per-dist-base" * (lib.runtime_setting_value "trade-volume-per-dist-exp" ^ dist)
        max_volume = math.min(max_volume, max_item_value)
        for i = 1, lib.runtime_setting_value "trades-per-hex" do
            local r = math.random()
            local random_volume = math.max(1, (1 - r * r) * max_volume)
            local trade = trades.random(surface.name, random_volume)
            if trade then
                table.insert(hex_core_trades, trade)
            end
        end
    end

    for _, trade in pairs(hex_core_trades) do
        hex_grid.add_trade(state, trade)
    end

    hex_grid.apply_extra_trades_bonus(state)

    hex_grid.update_hex_core_inventory_filters(state)

    return hex_core
end

-- Delete a hex core entity and its trades, but keep the ground tiles.
function hex_grid.delete_hex_core(hex_core)
    if not hex_core or not hex_core.valid then return end

    local surface_hexes = hex_grid.get_sur_hexes(hex_core.surface)

    local state = hex_grid.get_hex_state_from_core(hex_core)

    local entities = hex_core.surface.find_entities_filtered {name = "hex-core-loader", radius = 2}
    for _, e in pairs(entities) do
        e.destroy()
    end

    hex_core.destroy()

    if not state then return end

    local Q = surface_hexes[state.position.q]
    if not Q then return end

    Q[state.position.r] = nil
end

function hex_grid.generate_loaders(hex_core_state)
    if not hex_core_state.hex_core then return end

    hex_core_state.input_loaders = {}
    hex_core_state.output_loaders = {}

    local surface = hex_core_state.hex_core.surface
    local position = hex_core_state.hex_core.position

    local entities = surface.find_entities_filtered {
        name = "hex-core-loader",
        area = {{position.x - 2, position.y - 2}, {position.x + 2, position.y + 2}},
    }
    for _, e in pairs(entities) do
        e.destroy()
    end

    local dx = 1
    local dy = -2
    for i = 1, 4 do
        local dir_name = lib.get_direction_name((i + 1) % 4 + 1)
        local dir_name_opposite = lib.get_direction_name((i + 3) % 4 + 1)

        local input_loader = surface.create_entity {name = "hex-core-loader", position = {position.x + dx, position.y + dy}, direction = defines.direction[dir_name], type = "input", force = "player"}
        input_loader.destructible = false
        table.insert(hex_core_state.input_loaders, input_loader)

        local output_loader = surface.create_entity {name = "hex-core-loader", position = {position.x - dx, position.y + dy}, direction = defines.direction[dir_name_opposite], type = "output", force = "player"}
        output_loader.loader_filter_mode = "whitelist"
        output_loader.destructible = false
        table.insert(hex_core_state.output_loaders, output_loader)

        dx, dy = dy, -dx
    end
end

-- Fill edges between adjacent claimed hexes using sum of squared distances method
function hex_grid.fill_edges_between_claimed_hexes(surface, hex_pos, tile_type)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("fill_edges_between_claimed_hexes: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    -- If no tile type is specified, use the last claimed hex tile type
    if not tile_type then
        tile_type = storage.hex_grid.last_used_claim_tile or "refined-concrete"
    end

    local transformation = hex_grid.get_surface_transformation(surface_id)
    if not transformation then
        lib.log_error("fill_edges_between_claimed_hexes: No transformation found")
        return
    end

    -- Get adjacent hexes
    local adjacent_hexes = hex_grid.get_adjacent_hexes(hex_pos)

    -- Process each adjacent hex that is claimed
    for _, adj_hex in pairs(adjacent_hexes) do
        local adj_state = hex_grid.get_hex_state(surface_id, adj_hex)
        if adj_state.claimed then
            -- Get centers of both hexes in rectangular coordinates
            local center1 = hex_grid.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
            local center2 = hex_grid.get_hex_center(adj_hex, transformation.scale, transformation.rotation)

            -- Calculate squared distance between centers
            local dx = center1.x - center2.x
            local dy = center1.y - center2.y
            local center_dist_squared = dx * dx + dy * dy

            -- Calculate threshold based on center distance and hex radius
            -- Dynamically calculate the threshold multiplier using the formula: 2/(d/r)²
            -- Where d is center_dist and r is hex_radius (transformation.scale)
            local hex_radius = transformation.scale
            local center_dist = math.sqrt(center_dist_squared)
            local threshold_multiplier = 2 / ((center_dist / hex_radius) * (center_dist / hex_radius))

            -- Calculate the threshold
            local threshold = center_dist_squared * threshold_multiplier

            -- Get border tiles for both hexes
            local corners1 = hex_grid.get_hex_corners(hex_pos, transformation.scale, transformation.rotation)
            local corners2 = hex_grid.get_hex_corners(adj_hex, transformation.scale, transformation.rotation)
            local border_tiles1 = hex_grid.get_hex_border_tiles_from_corners(corners1, transformation.scale, transformation.stroke_width)
            local border_tiles2 = hex_grid.get_hex_border_tiles_from_corners(corners2, transformation.scale, transformation.stroke_width)

            -- Combine border tiles
            local all_border_tiles = {}
            for _, tile in pairs(border_tiles1) do
                table.insert(all_border_tiles, tile)
            end
            for _, tile in pairs(border_tiles2) do
                table.insert(all_border_tiles, tile)
            end

            -- Find water tiles that meet the sum of squared distances criteria
            local edge_tiles = {}
            for _, tile in pairs(all_border_tiles) do
                -- Calculate sum of squared distances to both centers
                local d1_squared = (tile.x - center1.x) * (tile.x - center1.x) + (tile.y - center1.y) * (tile.y - center1.y)
                local d2_squared = (tile.x - center2.x) * (tile.x - center2.x) + (tile.y - center2.y) * (tile.y - center2.y)
                local sum_squared = d1_squared + d2_squared

                -- Check if the tile meets the threshold criteria
                if sum_squared <= threshold then
                    -- Check if it's a water tile
                    local game_tile = surface.get_tile(tile.x, tile.y)
                    if game_tile and game_tile.valid and (
                        game_tile.name == "water" or 
                        game_tile.name == "deepwater" or 
                        game_tile.name == "oil-ocean" or 
                        game_tile.name == "hot-lava" or 
                        game_tile.name == "ammoniacal-solution"
                    ) then
                        table.insert(edge_tiles, {x = tile.x, y = tile.y})
                    end
                end
            end

            -- Fill the edge tiles
            if #edge_tiles > 0 then
                hex_grid.set_tiles(surface, edge_tiles, tile_type)
            end
        end
    end
end

-- Finds and fills corners where three claimed hexes meet
function hex_grid.fill_corners_between_claimed_hexes(surface, hex_pos, tile_type)
    local surface_id = lib.get_surface_id(surface)
    if not surface_id then
        lib.log_error("fill_corners_between_claimed_hexes: No surface found")
        return
    end
    surface = game.surfaces[surface_id]
    
    -- If no tile type is specified, use the last claimed hex tile type
    if not tile_type then
        tile_type = storage.hex_grid.last_used_claim_tile or "refined-concrete"
    end
    
    local transformation = hex_grid.get_surface_transformation(surface_id)
    if not transformation then
        lib.log_error("fill_corners_between_claimed_hexes: No transformation found")
        return
    end
    
    -- Get adjacent hexes
    local adjacent_hexes = hex_grid.get_adjacent_hexes(hex_pos)
    
    -- For each pair of adjacent hexes, check if they share a corner
    for i = 1, #adjacent_hexes do
        local hex1 = adjacent_hexes[i]
        local hex1_state = hex_grid.get_hex_state(surface_id, hex1)
        
        if hex1_state.claimed then
            for j = i+1, #adjacent_hexes do
                local hex2 = adjacent_hexes[j]
                local hex2_state = hex_grid.get_hex_state(surface_id, hex2)
                
                if hex2_state.claimed then
                    -- Check if these three hexes share a corner
                    -- For this to be true, hex1 and hex2 must be adjacent to each other
                    if hex_grid.distance(hex1, hex2) == 1 then
                        -- Get centers of all three hexes
                        local center0 = hex_grid.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
                        local center1 = hex_grid.get_hex_center(hex1, transformation.scale, transformation.rotation)
                        local center2 = hex_grid.get_hex_center(hex2, transformation.scale, transformation.rotation)
                        
                        -- Get corners for all three hexes
                        local corners0 = hex_grid.get_hex_corners(hex_pos, transformation.scale, transformation.rotation)
                        local corners1 = hex_grid.get_hex_corners(hex1, transformation.scale, transformation.rotation)
                        local corners2 = hex_grid.get_hex_corners(hex2, transformation.scale, transformation.rotation)
                        
                        -- Find the common corner among all three hexes
                        local common_corner = nil
                        local tolerance = 0.01
                        
                        for _, c0 in pairs(corners0) do
                            for _, c1 in pairs(corners1) do
                                if math.abs(c0.x - c1.x) < tolerance and math.abs(c0.y - c1.y) < tolerance then
                                    -- c0 and c1 are the same corner, check if it's also in corners2
                                    for _, c2 in pairs(corners2) do
                                        if math.abs(c0.x - c2.x) < tolerance and math.abs(c0.y - c2.y) < tolerance then
                                            -- Found a corner common to all three hexes
                                            common_corner = {x = (c0.x + c1.x + c2.x) / 3, y = (c0.y + c1.y + c2.y) / 3}
                                            break
                                        end
                                    end
                                    
                                    if common_corner then break end
                                end
                            end
                            
                            if common_corner then break end
                        end
                        
                        if common_corner then
                            -- Get border tiles for all three hexes
                            local border_tiles0 = hex_grid.get_hex_border_tiles_from_corners(corners0, transformation.scale, transformation.stroke_width)
                            local border_tiles1 = hex_grid.get_hex_border_tiles_from_corners(corners1, transformation.scale, transformation.stroke_width)
                            local border_tiles2 = hex_grid.get_hex_border_tiles_from_corners(corners2, transformation.scale, transformation.stroke_width)
                            
                            -- Combine all border tiles
                            local all_border_tiles = {}
                            for _, tile in pairs(border_tiles0) do table.insert(all_border_tiles, tile) end
                            for _, tile in pairs(border_tiles1) do table.insert(all_border_tiles, tile) end
                            for _, tile in pairs(border_tiles2) do table.insert(all_border_tiles, tile) end
                            
                            -- Calculate distance from each center to the common corner
                            local dist0 = math.sqrt((common_corner.x - center0.x)^2 + (common_corner.y - center0.y)^2)
                            local dist1 = math.sqrt((common_corner.x - center1.x)^2 + (common_corner.y - center1.y)^2)
                            local dist2 = math.sqrt((common_corner.x - center2.x)^2 + (common_corner.y - center2.y)^2)
                            
                            -- Average distance squared
                            local avg_dist_squared = (dist0^2 + dist1^2 + dist2^2) / 3
                            
                            -- Radius for corner detection - slightly smaller than average distance
                        local corner_radius_squared = avg_dist_squared * 0.85
                            
                            -- Find tiles close to the common corner
                            local corner_tiles = {}
                            for _, tile in pairs(all_border_tiles) do
                                -- Distance from tile to corner
                                local corner_dist_squared = (tile.x - common_corner.x)^2 + (tile.y - common_corner.y)^2
                                
                                -- If tile is close to corner
                                if corner_dist_squared < corner_radius_squared * 0.5 then
                                    -- Check if it's a water tile
                                    local game_tile = surface.get_tile(tile.x, tile.y)
                                    if game_tile and game_tile.valid and (
                                        game_tile.name == "water" or 
                                        game_tile.name == "deepwater" or 
                                        game_tile.name == "oil-ocean" or 
                                        game_tile.name == "hot-lava" or 
                                        game_tile.name == "ammoniacal-solution"
                                    ) then
                                        table.insert(corner_tiles, {x = tile.x, y = tile.y})
                                    end
                                end
                            end
                            
                            -- Fill the corner tiles
                            if #corner_tiles > 0 then
                                hex_grid.set_tiles(surface, corner_tiles, tile_type)
                            end
                        end
                    end
                end
            end
        end
    end
end

function hex_grid.get_delete_core_cost(hex_core)
    if not hex_core or not hex_core.valid then return coin_tiers.from_base_value(0) end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return 0 end

    return state.claim_price or coin_tiers.from_base_value(0)
end

function hex_grid.update_all_hex_cores()
    for surface, surface_hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(surface_hexes) do
            for _, state in pairs(Q) do
                if state.claimed then
                    hex_grid.update_hex_core(state)
                end
            end
        end
    end
end

function hex_grid.update_hex_core(state)
    -- Check if trades can occur
    local inventory_input = state.hex_core_input_inventory
    if not inventory_input then return end
    local inventory_output = state.hex_core_output_inventory
    if not inventory_output then return end
    for _, trade in pairs(state.trades) do
        local num_batches = trades.get_num_batches_for_trade(inventory_input, inventory_output, trade)
        if num_batches > 0 then
            local total_removed, total_inserted = trades.trade_items(inventory_input, inventory_output, trade, num_batches)
            for item_name, amount in pairs(total_removed) do
                if not state.total_items_sold then
                    state.total_items_sold = {}
                end
                state.total_items_sold[item_name] = (state.total_items_sold[item_name] or 0) + amount
            end
            for item_name, amount in pairs(total_inserted) do
                if not state.total_items_bought then
                    state.total_items_bought = {}
                end
                state.total_items_bought[item_name] = (state.total_items_bought[item_name] or 0) + amount
            end
        end
    end
end

function hex_grid.update_all_trades()
    for surface_name, surface_hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(surface_hexes) do
            for _, state in pairs(Q) do
                if state.trades then
                    for i, trade in ipairs(state.trades) do
                        trades.set_productivity(trade, 0)
                        for j, item in ipairs(trade.input_items) do
                            if lib.is_catalog_item(item.name) then
                                trades.increment_productivity(trade, item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)))
                            end
                        end
                        for j, item in ipairs(trade.output_items) do
                            if lib.is_catalog_item(item.name) then
                                trades.increment_productivity(trade, item_ranks.get_rank_bonus_effect(item_ranks.get_item_rank(item.name)))
                            end
                        end
                    end
                end
            end
        end
    end
end

function hex_grid.apply_extra_trades_bonus_retro(item_name)
    if not lib.is_catalog_item(item_name) then return end
    local rank = item_ranks.get_item_rank(item_name)
    local volume = trades.get_random_volume_for_item(item_name)
    local added_trades = {}
    local trades_per_hex = lib.runtime_setting_value "trades-per-hex"
    for surface_name, surface_hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(surface_hexes) do
            for _, state in pairs(Q) do
                if state.trades and #state.trades == trades_per_hex then
                    local trade = hex_grid.apply_extra_trade_bonus(state, item_name, volume)
                    if trade then
                        table.insert(added_trades, trade)
                    end
                end
            end
        end
    end
    if next(added_trades) then
        local hex_cores_str = ""
        for i, trade in ipairs(added_trades) do
            if i > 1 then
                hex_cores_str = hex_cores_str .. "   "
            end
            hex_cores_str = hex_cores_str .. lib.get_gps_str_from_hex_core(trade.hex_core_state.hex_core)
        end
        game.print({"hextorio.bonus-trades-retro", "[img=item." .. item_name .. "]"})
        game.print(hex_cores_str)
    end
end



return hex_grid
