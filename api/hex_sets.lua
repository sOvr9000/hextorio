
local hex_sets = {}



---Create a set of hex coordinates from a list of hex coordinates.
---@param hex_list HexPos[]|nil
---@return HexSet
function hex_sets.new(hex_list)
    local set = {}
    if hex_list then
        for _, hex in pairs(hex_list) do
            hex_sets.add(set, hex)
        end
    end
    return set
end

---Create a copy of a hex set.
---@param set HexSet
---@return HexSet
function hex_sets.copy(set)
    local new_set = {}
    for q, Q in pairs(set) do
        local new_Q = {}
        for r, _ in pairs(Q) do
            new_Q[r] = true
        end
        new_set[q] = new_Q
    end
    return new_set
end

---Add a hex coordinate pair to a set, returning whether the set has changed
---@param set HexSet
---@param hex HexPos
---@return boolean
function hex_sets.add(set, hex)
    local Q = set[hex.q]
    if not Q then
        Q = {}
        set[hex.q] = Q
    end
    local changed = Q[hex.r] ~= true
    Q[hex.r] = true
    return changed
end

---Remove a hex coordinate pair from a set, returning whether the set has changed.
---@param set HexSet
---@param hex HexPos
---@return boolean
function hex_sets.remove(set, hex)
    local Q = set[hex.q]
    if not Q then
        return false
    end
    local changed = Q[hex.r] == true
    Q[hex.r] = nil
    if not next(Q) then
        set[hex.q] = nil
    end
    return changed
end

---Convert a hex set to an array of HexPos objects.
---@param set HexSet
---@return HexPos[]
function hex_sets.to_array(set)
    local array = {}
    for q, Q in pairs(set) do
        for r, _ in pairs(Q) do
            table.insert(array, {q = q, r = r})
        end
    end
    return array
end

---Check whether a set contains a hex coordinate pair.
---@param set HexSet
---@param hex HexPos
---@return boolean
function hex_sets.contains(set, hex)
    local Q = set[hex.q]
    return Q and Q[hex.r] == true
end

---Union two sets, returning a new set.
---@param set1 HexSet
---@param set2 HexSet
---@return HexSet
function hex_sets.union(set1, set2)
    local new_set = hex_sets.copy(set1)
    for q, Q in pairs(set2) do
        for r, _ in pairs(Q) do
            hex_sets.add(new_set, {q = q, r = r})
        end
    end
    return new_set
end

---Find the intersection of two sets, returning a new set.
---@param set1 HexSet
---@param set2 HexSet
---@return HexSet
function hex_sets.intersection(set1, set2)
    local new_set = {}
    for q, Q in pairs(set1) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if hex_sets.contains(set2, hex) then
                hex_sets.add(new_set, hex)
            end
        end
    end
    return new_set
end

---Find the difference between two sets (set1 - set2), returning a new set.
---@param set1 HexSet
---@param set2 HexSet
---@return HexSet
function hex_sets.difference(set1, set2)
    local new_set = {}
    for q, Q in pairs(set1) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set2, hex) then
                hex_sets.add(new_set, hex)
            end
        end
    end
    return new_set
end

---Find the symmetric difference of two sets (elements in either set but not both).
---@param set1 HexSet
---@param set2 HexSet
---@return HexSet
function hex_sets.symmetric_difference(set1, set2)
    local new_set = {}
    -- Add elements from set1 that are not in set2
    for q, Q in pairs(set1) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set2, hex) then
                hex_sets.add(new_set, hex)
            end
        end
    end
    -- Add elements from set2 that are not in set1
    for q, Q in pairs(set2) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set1, hex) then
                hex_sets.add(new_set, hex)
            end
        end
    end
    return new_set
end

---Check if set1 is a subset of set2.
---@param set1 HexSet
---@param set2 HexSet
---@return boolean
function hex_sets.is_subset(set1, set2)
    for q, Q in pairs(set1) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set2, hex) then
                return false
            end
        end
    end
    return true
end

---Check if set1 is a proper subset of set2.
---@param set1 HexSet
---@param set2 HexSet
---@return boolean
function hex_sets.is_proper_subset(set1, set2)
    if hex_sets.is_empty(set1) then
        return not hex_sets.is_empty(set2)  -- Empty set is a proper subset of any non-empty set
    end

    local proper = false
    for q, Q in pairs(set2) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set1, hex) then
                proper = true
                break
            end
        end
        if proper then break end
    end

    return proper and hex_sets.is_subset(set1, set2)
end

---Check if two sets are equal.
---@param set1 HexSet
---@param set2 HexSet
---@return boolean
function hex_sets.equals(set1, set2)
    -- Check if all elements in set1 are in set2
    for q, Q in pairs(set1) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set2, hex) then
                return false
            end
        end
    end
    -- Check if all elements in set2 are in set1
    for q, Q in pairs(set2) do
        for r, _ in pairs(Q) do
            local hex = {q = q, r = r}
            if not hex_sets.contains(set1, hex) then
                return false
            end
        end
    end
    return true
end

---Check if a set is empty.
---@param set HexSet
---@return boolean
function hex_sets.is_empty(set)
    return next(set) == nil
end

---Get the number of elements in a set.
---@param set HexSet
---@return int
function hex_sets.size(set)
    local count = 0
    for _, Q in pairs(set) do
        for _ in pairs(Q) do
            count = count + 1
        end
    end
    return count
end



return hex_sets
