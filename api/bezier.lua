local bezier = {}


---Round fractional axial coordinates to the nearest hex
---@param frac_q number
---@param frac_r number
---@return HexPos
local function round_hex(frac_q, frac_r)
    local frac_s = -frac_q - frac_r

    local q = math.floor(frac_q + 0.5)
    local r = math.floor(frac_r + 0.5)
    local s = math.floor(frac_s + 0.5)

    local q_diff = math.abs(q - frac_q)
    local r_diff = math.abs(r - frac_r)
    local s_diff = math.abs(s - frac_s)

    if q_diff > r_diff and q_diff > s_diff then
        q = -r - s
    elseif r_diff > s_diff then
        r = -q - s
    end

    return {q = q, r = r}
end

---Evaluate a cubic Bezier curve at parameter t (0 to 1)
---@param p0 table Start point {q, r}
---@param p1 table Control point 1
---@param p2 table Control point 2
---@param p3 table End point {q, r}
---@param t number Parameter from 0 to 1
---@return table Point with fractional coordinates {q, r}
function bezier.cubic_bezier_point(p0, p1, p2, p3, t)
    local t2 = t * t
    local t3 = t2 * t
    local mt = 1 - t
    local mt2 = mt * mt
    local mt3 = mt2 * mt

    return {
        q = mt3 * p0.q + 3 * mt2 * t * p1.q + 3 * mt * t2 * p2.q + t3 * p3.q,
        r = mt3 * p0.r + 3 * mt2 * t * p1.r + 3 * mt * t2 * p2.r + t3 * p3.r
    }
end

---Sample points along a cubic Bezier curve and round to hex positions
---@param p0 HexPos Start point
---@param p1 table Control point 1 (may have fractional coordinates)
---@param p2 table Control point 2 (may have fractional coordinates)
---@param p3 HexPos End point
---@param num_samples int Number of samples along the curve
---@return HexPos[] Array of hex positions along the curve
function bezier.cubic_bezier_hex(p0, p1, p2, p3, num_samples)
    local points = {}
    local added = {}

    for i = 0, num_samples do
        local t = i / num_samples
        local point = bezier.cubic_bezier_point(p0, p1, p2, p3, t)
        local hex_pos = round_hex(point.q, point.r)

        local key = hex_pos.q .. "," .. hex_pos.r
        if not added[key] then
            table.insert(points, hex_pos)
            added[key] = true
        end
    end

    return points
end


return bezier
