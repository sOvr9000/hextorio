
-- Yet another hex module...
-- Intended to provide utility functions such as pathfinding algorithms or other filtering methods of hex sets.
-- Or to extend the axial module's logic onto hex sets.

local axial = require "api.util.axial"
local rect = require "api.util.rect"
local hex_sets = require "api.hex_sets"

local hex_util = {}



---Get a list of all hexes within range of the given hex, given a HexSet defining which hex positions are allowed to be included.
---Uses BFS to calculate minimum pathing distance through allowed positions only.
---@param center HexPos
---@param range int
---@param allowed_positions HexSet
---@return HexSet, IndexMap tuple A tuple containing the actual hex set as well as the distances calculated during the search.
function hex_util.all_hexes_within_range(center, range, allowed_positions)
    local included = hex_sets.new()
    local distances = {}

    local queue = {{pos = center, distance = 0}}
    local head = 1

    while head <= #queue do
        local current = queue[head]
        head = head + 1

        local pos = current.pos
        local dist = current.distance

        if not hex_sets.contains(included, pos) and hex_sets.contains(allowed_positions, pos) and dist <= range then
            -- Can use directed indexing for hex_set calls to improve performance, but that's more frequent and would be less readable
            hex_sets.add(included, pos)

            -- Direct indexing for performance, as abstraction may add extra overhead in the loop
            distances[pos.q] = distances[pos.q] or {}
            distances[pos.q][pos.r] = dist

            for _, adj_pos in pairs(axial.get_adjacent_hexes(pos)) do
                if not hex_sets.contains(included, adj_pos) then
                    table.insert(queue, {pos = adj_pos, distance = dist + 1})
                end
            end
        end
    end

    return included, distances
end

---Calculate distances from `center` to each position in `positions` using BFS.
---@param center HexPos
---@param positions HexSet
---@return IndexMap distances A mapping of hex positions to their distances from `center`
function hex_util.calculate_distances(center, positions)
    local distances = {}
    local visited = hex_sets.new()
    local found_count = 0
    local target_count = hex_sets.size(positions)

    if target_count == 0 then
        return distances
    end

    local queue = {{pos = center, distance = 0}}
    local head = 1

    while head <= #queue and found_count < target_count do
        local current = queue[head]
        head = head + 1

        local pos = current.pos
        local dist = current.distance

        if not hex_sets.contains(visited, pos) and hex_sets.contains(positions, pos) then
            hex_sets.add(visited, pos)

            distances[pos.q] = distances[pos.q] or {}
            distances[pos.q][pos.r] = dist
            found_count = found_count + 1

            for _, adj_pos in pairs(axial.get_adjacent_hexes(pos)) do
                if not hex_sets.contains(visited, adj_pos) then
                    table.insert(queue, {pos = adj_pos, distance = dist + 1})
                end
            end
        end
    end

    return distances
end

---Check if a hex overlaps a rectangular area.
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@param rect_top_left MapPosition
---@param rect_bottom_right MapPosition
---@return boolean
function hex_util.hex_overlaps_rect(hex_pos, hex_grid_scale, hex_grid_rotation, rect_top_left, rect_bottom_right)
    -- Get the corners of the hex
    local corners = axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation)

    -- Check if any hex corner is inside the rectangle
    for _, corner in pairs(corners) do
        if rect.is_position_in_rect(corner, rect_top_left, rect_bottom_right) then
            return true
        end
    end

    -- Check if any rectangle corner is inside the hex
    local rect_corners = {
        {x = rect_top_left.x, y = rect_top_left.y},           -- Top left
        {x = rect_bottom_right.x, y = rect_top_left.y},       -- Top right
        {x = rect_bottom_right.x, y = rect_bottom_right.y},   -- Bottom right
        {x = rect_top_left.x, y = rect_bottom_right.y}        -- Bottom left
    }

    for _, corner in pairs(rect_corners) do
        if rect.is_point_in_polygon(corner, corners) then
            return true
        end
    end

    -- Check if any hex edge intersects any rectangle edge
    for i = 1, 6 do
        local next_i = i % 6 + 1
        if rect.segment_intersects_rect(corners[i], corners[next_i], rect_top_left, rect_bottom_right) then
            return true
        end
    end

    return false
end

---Get all hexes that overlap a rectangular area.
---@param rect_top_left MapPosition
---@param rect_bottom_right MapPosition
---@param hex_grid_scale number
---@param hex_grid_rotation number|nil
function hex_util.get_overlapping_hexes(rect_top_left, rect_bottom_right, hex_grid_scale, hex_grid_rotation)
    hex_grid_rotation = hex_grid_rotation or 0

    -- Normalize the rectangle coordinates (ensure top_left is actually top-left)
    local tl_x = math.min(rect_top_left.x, rect_bottom_right.x)
    local tl_y = math.min(rect_top_left.y, rect_bottom_right.y)
    local br_x = math.max(rect_top_left.x, rect_bottom_right.x)
    local br_y = math.max(rect_top_left.y, rect_bottom_right.y)

    -- Calculate a margin to accommodate rotated hexes that might overlap
    -- This margin should be at least the hex size plus some buffer for rotation
    local margin = hex_grid_scale * 2

    -- Get hexes for the four corners of the rectangle (plus margin)
    local temp_pos = {}
    temp_pos.x = tl_x - margin
    temp_pos.y = tl_y - margin
    local tl_hex = axial.get_hex_containing(temp_pos, hex_grid_scale, hex_grid_rotation)

    temp_pos.x = br_x + margin
    temp_pos.y = tl_y - margin
    local tr_hex = axial.get_hex_containing(temp_pos, hex_grid_scale, hex_grid_rotation)

    temp_pos.x = tl_x - margin
    temp_pos.y = br_y + margin
    local bl_hex = axial.get_hex_containing(temp_pos, hex_grid_scale, hex_grid_rotation)

    temp_pos.x = br_x + margin
    temp_pos.y = br_y + margin
    local br_hex = axial.get_hex_containing(temp_pos, hex_grid_scale, hex_grid_rotation)

    -- Find the min/max q and r to create a bounding box of hexes
    local min_q = math.min(tl_hex.q, tr_hex.q, bl_hex.q, br_hex.q)
    local max_q = math.max(tl_hex.q, tr_hex.q, bl_hex.q, br_hex.q)
    local min_r = math.min(tl_hex.r, tr_hex.r, bl_hex.r, br_hex.r)
    local max_r = math.max(tl_hex.r, tr_hex.r, bl_hex.r, br_hex.r)

    -- Check each hex in the bounding box
    local overlapping_hexes = {}
    local tl = {x = tl_x, y = tl_y}
    local br = {x = br_x, y = br_y}
    local hex = {}
    for q = min_q, max_q do
        for r = min_r, max_r do
            hex.q = q
            hex.r = r
            if hex_util.hex_overlaps_rect(hex, hex_grid_scale, hex_grid_rotation, tl, br) then
                table.insert(overlapping_hexes, {q = q, r = r})
            end
        end
    end

    return overlapping_hexes
end

---Return a list of chunk positions which overlap with the given hex.
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@return ChunkPosition[]
function hex_util.get_overlapping_chunks(hex_pos, hex_grid_scale, hex_grid_rotation)
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
            if hex_util.hex_overlaps_rect(hex_pos, hex_grid_scale, hex_grid_rotation, top_left, bottom_right) then
                -- Convert world coordinates back to chunk coordinates
                table.insert(chunks, {x = x / chunk_size, y = y / chunk_size})
            end
        end
    end
    return chunks
end

---Get all integer rectangular coordinates within a hex, excluding the border.
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@param stroke_width number
---@return MapPosition[]
function hex_util.get_hex_tile_positions(hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    -- Default values
    hex_grid_scale = hex_grid_scale or 1
    hex_grid_rotation = hex_grid_rotation or 0
    stroke_width = stroke_width or 0

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
    local point = {}

    for x = min_x, max_x do
        for y = min_y, max_y do
            point.x = x
            point.y = y

            -- Check if the point is inside the hex
            if rect.is_point_in_polygon(point, corners) then
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
                        local distance = rect.point_to_line_distance(point, p1, p2)
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

---Get the tile positions within a hex's stroke width, given the hex's vertices.
---@param corners MapPosition[]
---@param hex_grid_scale number
---@param stroke_width number
---@param flatten_array boolean|nil Defaults to true
---@return MapPosition[]|{[int]: {[int]: MapPosition}}
function hex_util.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width, flatten_array)
    if flatten_array == nil then
        flatten_array = true
    end

    local added = {}

    stroke_width = stroke_width - 1
    stroke_width = stroke_width * 1.25 -- dividing by the 0.8 factor for tile overlap

    local max_w = math.ceil(stroke_width * 1.25)

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
        local perp_x, perp_y
        if dir_x == 0 and dir_y == 0 then
            perp_x = 0
            perp_y = 0
        else
            local length = math.sqrt(dir_x * dir_x + dir_y * dir_y)
            perp_x = -dir_y / length
            perp_y = dir_x / length
        end

        -- For each position along the edge
        for step = 1, steps do
            local t = step / steps
            local base_x = start.x + dir_x * t
            local base_y = start.y + dir_y * t

            -- Create tiles for the stroke width
            for w = -1, max_w do
                -- Offset in the perpendicular direction
                -- We want the stroke to go inward from the edge
                local offset = w * 0.8  -- 0.8 factor for tile overlap
                local x = math.floor(base_x + perp_x * offset + 0.5)
                local y = math.floor(base_y + perp_y * offset + 0.5)

                local X = added[x]
                if not X then
                    X = {}
                    added[x] = X
                end
                X[y] = true
            end
        end
    end

    if flatten_array then
        return rect.flattened_position_array(added)
    end

    return added
end

---Get the tile positions within a hex's stroke width, given the hex's axial center position (`hex_pos`).
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@param stroke_width number
---@param hex_size_decrement number|nil Defaults to 0
---@param flatten_array boolean|nil Defaults to true
---@return MapPosition[]|{[int]: {[int]: MapPosition}}
function hex_util.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, hex_size_decrement, flatten_array)
    hex_size_decrement = math.min(hex_size_decrement or 0, hex_grid_scale)
    stroke_width = math.min(stroke_width, hex_grid_scale - hex_size_decrement)
    local corners = axial.get_hex_corners(hex_pos, hex_grid_scale, hex_grid_rotation, hex_size_decrement)
    return hex_util.get_hex_border_tiles_from_corners(corners, hex_grid_scale, stroke_width, flatten_array)
end



return hex_util
