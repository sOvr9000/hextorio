
-- This uses a min heap to cut score searching from O(n) to O(logn).

local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local lib      = require "api.lib"

local hex_pathfinding = {}



---@param heap table
---@param priority int
---@param hex_pos HexPos
local function heap_push(heap, priority, hex_pos)
    table.insert(heap, {priority = priority, hex_pos = hex_pos})
    local i = #heap
    while i > 1 do
        local parent = math.floor(i / 2)
        if heap[parent].priority <= heap[i].priority then break end
        heap[parent], heap[i] = heap[i], heap[parent]
        i = parent
    end
end

---@param heap {priority: int, hex_pos: HexPos}[]
---@return {priority: int, hex_pos: HexPos}
local function heap_pop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap == 0 then return top end
    heap[1] = last
    local i, size = 1, #heap
    while true do
        local left, right, smallest = i * 2, i * 2 + 1, i
        if left <= size and heap[left].priority < heap[smallest].priority then
            smallest = left
        end
        if right <= size and heap[right].priority < heap[smallest].priority then
            smallest = right
        end
        if smallest == i then break end
        heap[i], heap[smallest] = heap[smallest], heap[i]
        i = smallest
    end
    return top
end

---@param came_from table
---@param current HexPos
---@return HexPos[]
local function reconstruct_path(came_from, current)
    local path = {}
    local pos = current

    repeat
        table.insert(path, 1, {q = pos.q, r = pos.r})
        Q = came_from[pos.q]
        if not Q then break end
        pos = Q[pos.r]
    until not pos

    return path
end

---@param hex_set HexSet
---@param open_heap {priority: int, hex_pos: HexPos}[]
---@param closed HexSet
---@param g_score {[int]: {[int]: int}}
---@param came_from {[int]: {[int]: HexPos}}
---@param neighbor HexPos
---@param current_g int
---@param current HexPos
---@param to_hex_pos HexPos
local function relax_neighbor(hex_set, open_heap, closed, g_score, came_from, neighbor, current_g, current, to_hex_pos)
    if not hex_sets.contains(hex_set, neighbor) or hex_sets.contains(closed, neighbor) then return end

    local tentative_g = current_g + 1

    local Q_g = g_score[neighbor.q]
    if not Q_g then
        Q_g = {}
        g_score[neighbor.q] = Q_g
    end

    local neighbor_g = Q_g[neighbor.r]
    if neighbor_g and tentative_g >= neighbor_g then return end

    Q_g[neighbor.r] = tentative_g

    local Q_c = came_from[neighbor.q]
    if not Q_c then
        Q_c = {}
        came_from[neighbor.q] = Q_c
    end
    Q_c[neighbor.r] = current

    heap_push(open_heap, tentative_g + axial.distance(neighbor, to_hex_pos), neighbor)
end

---Return a path of hex positions from `from_hex_pos` to `to_hex_pos` within a hex set, including both end points.
---Returns `nil` if no path exists.
---Uses A* search.
---@param hex_set HexSet
---@param from_hex_pos HexPos
---@param to_hex_pos HexPos
---@return HexPos[]|nil
function hex_pathfinding.find_path(hex_set, from_hex_pos, to_hex_pos)
    if not hex_sets.contains(hex_set, from_hex_pos) or not hex_sets.contains(hex_set, to_hex_pos) then
        lib.log_error("hex_pathfinding.find_path: Tried to find a path where at least one end point is not in the hex set.")
        return
    end

    if axial.equals(from_hex_pos, to_hex_pos) then
        return {{q = from_hex_pos.q, r = from_hex_pos.r}}
    end

    local closed = hex_sets.new()
    local open_heap, came_from = {}, {}

    local g_score = {
        [from_hex_pos.q] = {
            [from_hex_pos.r] = 0
        }
    }

    heap_push(open_heap, axial.distance(from_hex_pos, to_hex_pos), from_hex_pos)

    while #open_heap > 0 do
        local entry = heap_pop(open_heap)
        local current_pos = entry.hex_pos

        if not hex_sets.contains(closed, current_pos) then
            hex_sets.add(closed, current_pos)
            if axial.equals(current_pos, to_hex_pos) then
                return reconstruct_path(came_from, current_pos)
            end
            local current_g = g_score[current_pos.q][current_pos.r]
            for _, neighbor in pairs(axial.get_adjacent_hexes(current_pos)) do
                relax_neighbor(hex_set, open_heap, closed, g_score, came_from, neighbor, current_g, current_pos, to_hex_pos)
            end
        end
    end
end



return hex_pathfinding
