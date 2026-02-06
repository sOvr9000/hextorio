
-- Yet another hex module...
-- Intended to provide utility functions such as pathfinding algorithms or other filtering methods of hex sets.
-- Or to extend the axial module's logic onto hex sets.

local axial = require "api.axial"
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

-- TODO: Eventually include a pathfinding function, probably implementing A*
-- This would be used by sentient spiders (or general spidertron logic) if/when their functionality finally gets implemented



return hex_util
