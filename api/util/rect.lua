
local lib = require "api.lib"

local rect = {}



---Return a string representation of a vector.
---@param x number|MapPosition
---@param y number|nil Must not be nil if `x` is a number
---@return string
function rect.position_to_string(x, y)
    local _x, _y

    if not y then
        _x = x.x or x[1]
        _y = x.y or x[2]
    else
        _x = x
        _y = y
    end

    return "(" .. _x .. ", " .. _y .. ")"
end

---Add two vectors.
---@param a any
---@param b any
---@return table
function rect.vector_add(a, b)
    return {x=(a.x or a[1])+(b.x or b[1]), y=(a.y or a[2])+(b.y or b[2])}
end

---Get the square of the Euclidean distance between two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function rect.square_distance(pos1, pos2)
    local dx = (pos1.x or pos1[1]) - (pos2.x or pos2[1])
    local dy = (pos1.y or pos1[2]) - (pos2.y or pos2[2])
    return dx * dx + dy * dy
end

---Return a 2D vector of length `length` with a random angle.
---@param length number|nil
---@return MapPosition
function rect.random_unit_vector(length)
    length = length or 1
    local angle = math.random() * 2 * math.pi
    return {x=length*math.cos(angle), y=length*math.sin(angle)}
end

---Linearly interpolate from `a` to `b` by the factor `t`.
---@param a MapPosition
---@param b MapPosition
---@param t number
---@return MapPosition
function rect.lerp_positions(a, b, t)
    -- TODO: Optimize by using variables for each coordinate instead of creating two more tables than needed to compute this.
    local _a = {a[1] or a.x, a[2] or a.y}
    local _b = {b[1] or b.x, b[2] or b.y}

    return {
        x = _a[1] + (_b[1] - _a[1]) * t,
        y = _a[2] + (_b[2] - _a[2]) * t,
    }
end

---Round the position to integer coordinates, and optionally offset by 0.5.
---@param pos MapPosition
---@param offset_by_half boolean|nil
---@return MapPosition
function rect.rounded_position(pos, offset_by_half)
    if offset_by_half then
        return {x = math.floor(0.5 + (pos.x or pos[1])) + 0.5, y = math.floor(0.5 + (pos.y or pos[2])) + 0.5}
    end
    return {x = math.floor(0.5 + (pos.x or pos[1])), y = math.floor(0.5 + (pos.y or pos[2]))}
end

---Convert chunk position to rectangular coordinates.
---@param chunk_pos ChunkPosition
---@return MapPosition, MapPosition
function rect.chunk_to_rect(chunk_pos)
    local top_left = {
        x = chunk_pos.x * 32,
        y = chunk_pos.y * 32
    }

    local bottom_right = {
        x = top_left.x + 31,
        y = top_left.y + 31
    }

    return top_left, bottom_right
end

---Get a ChunkPosition from a MapPosition.
---@param pos MapPosition
---@return ChunkPosition
function rect.get_chunk_pos_from_tile_position(pos)
    return {x = math.floor((pos.x or pos[1]) / 32), y = math.floor((pos.y or pos[2]) / 32)}
end

---Return whether a position is in the given rectangular area.
---@param position MapPosition
---@param top_left MapPosition
---@param bottom_right MapPosition
---@return boolean
function rect.is_position_in_rect(position, top_left, bottom_right)
    return position.x >= top_left.x and position.x <= bottom_right.x and position.y >= top_left.y and position.y <= bottom_right.y
end

---Flattened a 2D array of positions that are indexed by x and y coordinates.
---@param arr MapPositionSet
---@return MapPosition[]
function rect.flattened_position_array(arr)
    local flat = {}
    local idx = 1
    for x, Y in pairs(arr) do
        for y, _ in pairs(Y) do
            flat[idx] = {x = x, y = y}
            idx = idx + 1
        end
    end
    return flat
end

---Convert a list of positions to a 2D array indexed by x and y coordinates.
---@param arr MapPosition[]
---@return MapPositionSet
function rect.indexed_position_array(arr)
    local set = {}
    for _, pos in pairs(arr) do
        if not set[pos.x] then
            set[pos.x] = {}
        end
        set[pos.x][pos.y] = true
    end
    return set
end

---Calculate the distance from a point to a line segment.
---@param point MapPosition
---@param p1 MapPosition
---@param p2 MapPosition
---@return number
function rect.point_to_line_distance(point, p1, p2)
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

---Return whether a point is inside a polygon.
---@param point MapPosition
---@param polygon MapPosition[]
---@return boolean
function rect.is_point_in_polygon(point, polygon)
    local inside = false
    local j = #polygon

    for i = 1, #polygon do
        if (
            (polygon[i].y > point.y) ~= (polygon[j].y > point.y)
        ) and (
            point.x < (polygon[j].x - polygon[i].x) * (point.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x
        ) then
            inside = not inside
        end
        j = i
    end

    return inside
end

---Return whether two line segments intersect.
---@param p1 MapPosition
---@param p2 MapPosition
---@param p3 MapPosition
---@param p4 MapPosition
---@return boolean
function rect.segments_intersect(p1, p2, p3, p4)
    local d1x, d1y = p2.x - p1.x, p2.y - p1.y
    local d2x, d2y = p4.x - p3.x, p4.y - p3.y
    local det = d1x * d2y - d1y * d2x

    if math.abs(det) < 1e-10 then
        return false
    end

    local dx, dy = p1.x - p3.x, p1.y - p3.y
    local t1 = (dx * d2y - dy * d2x) / det
    local t2 = (dx * d1y - dy * d1x) / det

    return t1 >= 0 and t1 <= 1 and t2 >= 0 and t2 <= 1
end

---Return whether a line segment intersects a rectangle.
---@param p1 MapPosition
---@param p2 MapPosition
---@param rect_top_left MapPosition
---@param rect_bottom_right MapPosition
function rect.segment_intersects_rect(p1, p2, rect_top_left, rect_bottom_right)
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
        if rect.segments_intersect(p1, p2, rect_corners[i], rect_corners[next_i]) then
            return true
        end
    end

    return false
end



return rect
