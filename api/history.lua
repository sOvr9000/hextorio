
-- Currently only used for storing trade overview filters and revisiting past ones

local history = {}



---Create a new history stack.
---@generic T
---@param data_type `T`
---@param capacity int
---@return {data: T[], index: int, capacity: int}
function history.new(data_type, capacity)
    local obj = {
        data = {},
        index = 0,
        capacity = capacity,
    }
    return obj
end

---Visit forward or backward in the history object, returning the data at the visited location.
---@generic T
---@param history_obj {data: T[], index: int, capacity: int}
---@param steps int
---@return T|nil
function history.step(history_obj, steps)
    history_obj.index = math.max(0, math.min(#history_obj.data, history_obj.index + steps))
    return history_obj.data[history_obj.index]
end

---Add data right after the currently visited position in the history object, clearing all history after it.
---Immediately visit the data after adding it.
---If the history object would exceed its capacity after adding the data, the oldest data item is removed to make room.
---@generic T
---@param history_obj {data: T[], index: int, capacity: int}
---@param data_obj T
function history.add(history_obj, data_obj)
    local d = history_obj.data
    local index = history_obj.index + 2
    for i = #d, index, -1 do
        d[i] = nil
    end

    d[index - 1] = data_obj
    history_obj.index = index - 1

    if #d > history_obj.capacity then
        table.remove(history_obj, 1)
        history_obj.index = history_obj.capacity
    end
end

---Return whether the currently visited position in the history data is the most recently added data (end of the list).
---@param history_obj {data: any[], index: int, capacity: int}
---@return boolean
function history.is_current(history_obj)
    return history_obj.index == #history_obj.data
end



return history
