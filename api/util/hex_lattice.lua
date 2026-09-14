
local rect = require "api.util.rect"

-- The integer half-offset grid that the hexagons of a hex grid are drawn over.
-- i.e. where the hexagons actually sit on the map, as opposed to where irrational arithmetic would put them.
--
-- A hex grid laid out with the exact regular-hexagon spacing puts hex centers at multiples of sqrt(3) * scale,
-- which is irrational, so centers land further and further away from the tile grid the further out you go.
-- Instead, this module picks a pair of whole numbers per hex grid scale:
--
--   * `width`  - the horizontal distance between the centers of two hexes in the same row (always even)
--   * `height` - the vertical distance between two adjacent rows of hexes
--
-- and places the center of hex (q, r) at (width * q + half_width * r, height * r), which is always integral.
-- Every other row is therefore offset by exactly half of `width`, hence "half-offset".
--
-- The hexagon drawn over that lattice is the one whose vertices are (+-half_width, +-height/3) and (0, +-2/3 * height).
-- It tiles the plane with no gaps or overlaps for any `width` and `height`, and it is a regular hexagon exactly when
-- height == sqrt(3) * half_width, which is what the lattice is chosen to approximate as closely as whole numbers allow.
--
-- A hex grid rotated by a whole quarter turn stays on the lattice, since a quarter turn only swaps the two axes.
-- One rotated by anything else (the "random" grid rotation mode) does not, and keeps the drift it always had.

local hex_lattice = {}



---@class HexLattice
---@field scale number The hex grid scale that this lattice was derived from.
---@field half_width int Half of `width`, i.e. how far each row is offset from the row above it.
---@field width int The horizontal distance between the centers of two hexes in the same row. Always even.
---@field height int The vertical distance between two adjacent rows of hexes.
---@field side number The length of a hexagon's side, equal to two thirds of `height`. This is what a hex grid scale becomes once it is snapped to the lattice.

---@class BlueprintSnapping
---@field snap_to_grid TilePosition The grid size to assign to `LuaItemCommon.blueprint_snap_to_grid`.
---@field position_relative_to_grid TilePosition The offset to assign to `LuaItemCommon.blueprint_position_relative_to_grid`.

local ROOT_THREE = math.sqrt(3)
local ROOT_THREE_OVER_TWO = ROOT_THREE * 0.5
local QUARTER_TURN = math.pi * 0.5

-- How far a rotation may sit from a whole quarter turn and still be treated as one.
local QUARTER_TURN_TOLERANCE = 1e-9

-- The six corners of a hexagon, in the order of the angles 30, 90, 150, 210, 270 and 330 degrees,
-- as multiples of half the hexagon's width and a third of its height.
local CORNER_OFFSETS = {
    {1, 1}, {0, 2}, {-1, 1}, {-1, -1}, {0, -2}, {1, -1},
}

-- Lattices are derived once per hex grid scale and reused. Deriving one is deterministic and depends on nothing
-- but its scale, so this cache does not belong in storage.
local lattices = {} ---@type {[number]: HexLattice}



---Derive the lattice for a hex grid scale.
---A regular hexagon of radius `scale` wants half_width = scale * sqrt(3)/2 and height = sqrt(3) * half_width, neither
---of which is a whole number.  For each of the three whole half widths closest to the ideal one, `height` is rounded to
---the nearest whole number, and the candidate is scored on how far the resulting hexagon is from regular (anisotropy)
---plus how far it is from the requested size.  Both terms are relative, so neither one dominates at large scales.
---@param scale number
---@return HexLattice
local function derive_lattice(scale)
    local ideal_half_width = math.max(1, math.floor(0.5 + scale * ROOT_THREE_OVER_TWO))
    local half_width_lower = math.max(1, ideal_half_width - 1)
    local half_width_upper = ideal_half_width + 1

    local best ---@type HexLattice
    local best_cost

    for half_width = half_width_lower, half_width_upper do
        local regular_height = ROOT_THREE * half_width
        local height = math.max(1, math.floor(0.5 + regular_height))

        local anisotropy = math.abs(height - regular_height) / regular_height
        -- The lattice implies a hexagon radius twice, once through each axis; average how far both are from the request.
        local size_error = (math.abs(half_width / ROOT_THREE_OVER_TWO - scale) + math.abs(height / 1.5 - scale)) / (2 * scale)

        local cost = anisotropy + size_error
        if not best_cost or cost < best_cost then
            best_cost = cost
            best = {
                scale = scale,
                half_width = half_width,
                width = half_width * 2,
                height = height,
                side = height * 2 / 3,
            }
        end
    end

    return best
end



---Rotate a position about the origin.
---Differs from `rect.rotate()` in that positions on the lattice stay on the tile grid.
---@param pos MapPosition
---@param rotation number
---@return MapPosition
function hex_lattice.rotate(pos, rotation)
    if rotation == 0 then
        return pos
    end

    local x = pos[1] or pos.x
    local y = pos[2] or pos.y

    local quarter_turns = rotation / QUARTER_TURN
    local turns = math.floor(0.5 + quarter_turns)
    if math.abs(quarter_turns - turns) < QUARTER_TURN_TOLERANCE then
        turns = turns % 4
        if turns == 0 then
            return pos
        elseif turns == 1 then
            return {x=-y, y=x}
        elseif turns == 2 then
            return {x=-x, y=-y}
        end
        return {x=y, y=-x}
    end

    -- This rotation can only be off-grid.
    return rect.rotate(pos, rotation)
end

---Get the half-offset lattice that the hexagons of the given hex grid scale are drawn over.
---The returned lattice is shared between every caller that asks for the same scale, so treat it as read only.
---@param axial_scale number|nil
---@return HexLattice
function hex_lattice.get_lattice(axial_scale)
    axial_scale = math.max(1, axial_scale or 1)

    local lattice = lattices[axial_scale]
    if not lattice then
        lattice = derive_lattice(axial_scale)
        lattices[axial_scale] = lattice
    end

    return lattice
end

---Convert axial coordinates to the rectangular coordinates of the hex's center.
---@param hex_pos HexPos
---@param axial_scale number
---@param axial_rotation number|nil
---@return MapPosition
function hex_lattice.get_hex_center(hex_pos, axial_scale, axial_rotation)
    axial_rotation = axial_rotation or 0

    local lattice = hex_lattice.get_lattice(axial_scale)
    local x = lattice.width * hex_pos.q + lattice.half_width * hex_pos.r
    local y = lattice.height * hex_pos.r

    return hex_lattice.rotate({x=x, y=y}, axial_rotation)
end

---Convert rectangular coordinates to the fractional axial q and r coordinates of the position.
---This is the exact inverse of `hex_lattice.get_hex_center`, so rounding the result to the nearest hex (see
---`axial.round`) names the hexagon that contains the position.
---@param rect_pos MapPosition
---@param axial_scale number
---@param axial_rotation number|nil
---@return HexPos
function hex_lattice.get_fractional_hex(rect_pos, axial_scale, axial_rotation)
    axial_rotation = axial_rotation or 0

    local lattice = hex_lattice.get_lattice(axial_scale)
    local rotated = hex_lattice.rotate(rect_pos, -axial_rotation)

    local r = rotated.y / lattice.height
    local q = rotated.x / lattice.width - r * 0.5

    return {q = q, r = r}
end

---Get the corner points of a hex in rectangular coordinates, in the order of the angles 30, 90, 150, 210, 270 and 330
---degrees around the hex's center.
---@param hex_pos HexPos
---@param axial_scale number
---@param axial_rotation number|nil
---@param hex_size_decrement number|nil How much shorter than `lattice.side` the hexagon's side should be, negative to make it longer. Defaults to 0.
---@return MapPosition[]
function hex_lattice.get_hex_corners(hex_pos, axial_scale, axial_rotation, hex_size_decrement)
    local lattice = hex_lattice.get_lattice(axial_scale)
    axial_rotation = axial_rotation or 0

    -- Get center without rotation
    local center = hex_lattice.get_hex_center(hex_pos, axial_scale, 0)

    local shrink = 1
    if hex_size_decrement and hex_size_decrement ~= 0 then
        shrink = math.max(0, lattice.side - hex_size_decrement) / lattice.side
    end

    local half_width = lattice.half_width * shrink
    local third_height = lattice.height * shrink / 3

    local corners = {}
    for _, offset in pairs(CORNER_OFFSETS) do
        local absolute_pos = {
            x = center.x + offset[1] * half_width,
            y = center.y + offset[2] * third_height,
        }

        -- Apply rotation around the origin if needed
        local rotated = hex_lattice.rotate(absolute_pos, axial_rotation)

        table.insert(corners, rotated)
    end

    return corners
end

---Get the blueprint snapping that lines a blueprint's grid up with the hex grid.
---This is the finest axis-aligned grid that every hex center lands on, so a blueprint snapped to it can be placed the
---same way in every hex.  Because each row of hexes is offset by half of `width`, the grid also has an intersection
---between every pair of neighbouring centers, which a blueprint can be placed on just as well.  Returns nil for a hex
---grid that is rotated by anything other than a whole quarter turn, since no axis-aligned grid can follow one.
---@param axial_scale number
---@param axial_rotation number|nil
---@return BlueprintSnapping|nil
function hex_lattice.get_blueprint_snapping(axial_scale, axial_rotation)
    local lattice = hex_lattice.get_lattice(axial_scale)
    axial_rotation = axial_rotation or 0

    local quarter_turns = axial_rotation / QUARTER_TURN
    local turns = math.floor(0.5 + quarter_turns)
    if math.abs(quarter_turns - turns) >= QUARTER_TURN_TOLERANCE then
        return
    end

    local snap_to_grid
    if turns % 2 == 0 then
        snap_to_grid = {x = lattice.half_width, y = lattice.height}
    else
        -- A quarter turn swaps the two axes of the lattice
        snap_to_grid = {x = lattice.height, y = lattice.half_width}
    end

    -- The hex at (0, 0) is centered on the map origin, so the grid needs no offset to line up with the hex grid.
    return {snap_to_grid = snap_to_grid, position_relative_to_grid = {x = 0, y = 0}}
end



return hex_lattice
