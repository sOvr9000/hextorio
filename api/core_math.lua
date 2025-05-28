


local core_math = {}



-- Helper function to calculate the distance from a point to a line segment
function core_math.point_to_line_distance(point, p1, p2)
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
function core_math.is_point_in_rect(point, rect_top_left, rect_bottom_right)
    return point.x >= rect_top_left.x and point.x <= rect_bottom_right.x and
           point.y >= rect_top_left.y and point.y <= rect_bottom_right.y
end

-- Helper function to check if a point is inside a polygon (hex)
function core_math.is_point_in_polygon(point, polygon)
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
function core_math.do_segments_intersect(p1, p2, p3, p4)
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
function core_math.does_segment_intersect_rect(p1, p2, rect_top_left, rect_bottom_right)
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
        if core_math.do_segments_intersect(p1, p2, rect_corners[i], rect_corners[next_i]) then
            return true
        end
    end

    return false
end



return core_math
