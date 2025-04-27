
-- sets.lua
-- A module for set operations in Lua
-- Sets are represented as tables with elements as keys and values as true

local sets = {}



-- Create a new set from a list of values
function sets.new(list)
    local set = {}
    for k, v in pairs(list or {}) do
        if type(v) == "boolean" then
            -- this happens when it's already a set
            set[k] = true
        else
            set[v] = true
        end
    end
    return set
end

function sets.add(set, item)
    set[item] = true
end

function sets.remove(set, item)
    set[item] = nil
end

-- Convert a set to an array
function sets.to_array(set)
    local array = {}
    for k, _ in pairs(set) do
        table.insert(array, k)
    end
    return array
end

-- Union of two sets (elements from either set)
function sets.union(set1, set2)
    local result = {}
    for k, _ in pairs(set1) do
        result[k] = true
    end
    for k, _ in pairs(set2) do
        result[k] = true
    end
    return result
end

-- Intersection of two sets (elements common to both sets)
function sets.intersection(set1, set2)
    local result = {}
    for k in pairs(set1) do
        if set2[k] then
            result[k] = true
        end
    end
    return result
end

-- Difference of two sets (set1 - set2)
function sets.difference(set1, set2)
    local result = {}
    for k, _ in pairs(set1) do
        if not set2[k] then
            -- print(tostring(k) .. " is in set")
            result[k] = true
        end
    end
    return result
end

-- Symmetric difference of two sets (elements in either set but not both)
function sets.symmetric_difference(set1, set2)
    local result = {}
    for k, _ in pairs(set1) do
        if not set2[k] then
            result[k] = true
        end
    end
    for k, _ in pairs(set2) do
        if not set1[k] then
            result[k] = true
        end
    end
    return result
end

-- Check if set1 is a subset of set2
function sets.is_subset(set1, set2)
    for k, _ in pairs(set1) do
        if not set2[k] then
            return false
        end
    end
    return true
end

-- Check if set1 is a proper subset of set2
function sets.is_proper_subset(set1, set2)
    if next(set1) == nil then
        return next(set2) ~= nil  -- Empty set is a proper subset of any non-empty set
    end

    local proper = false
    for k, _ in pairs(set2) do
        if not set1[k] then
            proper = true
            break
        end
    end

    return proper and sets.is_subset(set1, set2)
end

-- Check if two sets are equal
function sets.equals(set1, set2)
    for k, _ in pairs(set1) do
        if not set2[k] then
            return false
        end
    end
    for k, _ in pairs(set2) do
        if not set1[k] then
            return false
        end
    end
    return true
end

-- Check if a set is empty
function sets.is_empty(set)
    return next(set) == nil
end

-- Get the number of elements in a set
function sets.size(set)
    local count = 0
    for _ in pairs(set) do
        count = count + 1
    end
    return count
end

-- Check if an element is in a set
function sets.contains(set, element)
    return set[element] == true
end



return sets
