
-- This uses a min heap to cut score searching from O(n) to O(logn).

local axial = require "api.util.axial"
local hex_sets = require "api.hex_sets"
local lib      = require "api.lib"
local hex_state_manager = require "api.hex_state_manager"
local event_system      = require "api.event_system"

local hex_pathfinding = {}



---@class HexPathfindingStorage
---@field traversable_hexes {[int]: HexSet}



function hex_pathfinding.register_events()
    event_system.register("hex-claimed", hex_pathfinding.on_hex_claimed)
    event_system.register("hex-generated", hex_pathfinding.on_hex_generated)
end

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
---@param omit_collinear boolean
---@return HexPos[]
local function reconstruct_path(came_from, current, omit_collinear)
    local path = {}
    local pos = current

    repeat
        table.insert(path, 1, {q = pos.q, r = pos.r})
        Q = came_from[pos.q]
        if not Q then break end
        pos = Q[pos.r]
    until not pos

    if omit_collinear and #path >= 3 then
        -- Omit collinear hexes to simplify path
        for i = #path - 1, 2, -1 do
            local hex1 = path[i-1]
            local hex2 = path[i]
            local hex3 = path[i+1]
            if axial.is_collinear(hex1, hex2, hex3) then
                table.remove(path, i)
            end
        end
    end

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

---@return HexPathfindingStorage
function hex_pathfinding._get_hex_pathfinding_storage()
    local hex_pathfinding_storage = storage.hex_pathfinding
    if not hex_pathfinding_storage then
        hex_pathfinding_storage = {}
        storage.hex_pathfinding = hex_pathfinding_storage
    end

    if not hex_pathfinding_storage.traversable_hexes then
        hex_pathfinding_storage.traversable_hexes = {}
    end

    return hex_pathfinding_storage
end

---@param surface_index int
function hex_pathfinding.get_traversable_hexes_on_surface(surface_index)
    local hex_pathfinding_storage = hex_pathfinding._get_hex_pathfinding_storage()
    local traversable_hexes = hex_pathfinding_storage.traversable_hexes

    local surface_traversable_hexes = traversable_hexes[surface_index]
    if not surface_traversable_hexes then
        surface_traversable_hexes = {}
        traversable_hexes[surface_index] = surface_traversable_hexes
    end

    return surface_traversable_hexes
end

---Return a path of hex positions from `from_hex_pos` to `to_hex_pos` within a hex set, including both end points.
---Returns `nil` if no path exists.
---Uses A* search.
---@param hex_set HexSet
---@param from_hex_pos HexPos
---@param to_hex_pos HexPos
---@param omit_collinear boolean|nil
---@return HexPos[]|nil
function hex_pathfinding.find_path(hex_set, from_hex_pos, to_hex_pos, omit_collinear)
    if not hex_sets.contains(hex_set, from_hex_pos) or not hex_sets.contains(hex_set, to_hex_pos) then
        lib.log_error("hex_pathfinding.find_path: Tried to find a path where at least one end point is not in the hex set.")
        return
    end

    if omit_collinear == nil then omit_collinear = true end

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
                return reconstruct_path(came_from, current_pos, omit_collinear)
            end
            local current_g = g_score[current_pos.q][current_pos.r]
            for _, neighbor in pairs(axial.get_adjacent_hexes(current_pos)) do
                relax_neighbor(hex_set, open_heap, closed, g_score, came_from, neighbor, current_g, current_pos, to_hex_pos)
            end
        end
    end
end

---Return a path of hex positions from `from_hex_pos` to `to_hex_pos` within the traversable hexes on a surface, including both end points.
---Returns `nil` if no path exists or the traversable hexes on the given surface are not yet defined.
---Uses A* search.
---@param surface_index int
---@param from_hex_pos HexPos
---@param to_hex_pos HexPos
---@param omit_collinear boolean|nil
---@return HexPos[]|nil
function hex_pathfinding.find_path_on_surface(surface_index, from_hex_pos, to_hex_pos, omit_collinear)
    local traversable_hexes = hex_pathfinding.get_traversable_hexes_on_surface(surface_index)
    return hex_pathfinding.find_path(traversable_hexes, from_hex_pos, to_hex_pos, omit_collinear)
end

---Recalculate the traversability of this hex in pathfinding.
---
---Hexes near dungeons and unclaimed hexes are intraversable.
---@param state HexState
function hex_pathfinding.recalculate_hex_traversability(state)
    local surface_traversable_hexes = hex_pathfinding.get_traversable_hexes_on_surface(state.surface_index)
    local surface = game.get_surface(state.surface_index)
    local unclaimed_okay = surface ~= nil and surface.name == "fulgora"
    if not unclaimed_okay and not state.claimed or hex_state_manager.is_adjacent_to_dungeon(state) then
        hex_sets.remove(surface_traversable_hexes, state.position)
    else
        hex_sets.add(surface_traversable_hexes, state.position)
    end
end

---@param state HexState
function hex_pathfinding._handle_traversability_changes(state)
    hex_pathfinding.recalculate_hex_traversability(state)
    if state.was_dungeon then
        local adj_states = hex_state_manager.get_adjacent_hex_states(state, false)
        for _, adj_state in pairs(adj_states) do
            hex_pathfinding.recalculate_hex_traversability(adj_state)
        end
    end
end

---@param surface LuaSurface
---@param state HexState
function hex_pathfinding.on_hex_claimed(surface, state)
    hex_pathfinding._handle_traversability_changes(state)
end

---@param surface_index int
---@param hex_pos HexPos
function hex_pathfinding.on_hex_generated(surface_index, hex_pos)
    local state = hex_state_manager.get_hex_state(surface_index, hex_pos, false)
    if not state then return end
    hex_pathfinding._handle_traversability_changes(state)
end



return hex_pathfinding
