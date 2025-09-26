
local hex_sets = require "api.hex_sets" -- This is not really for hexes, but the code and logic for hexes can be reused without modification for some of these tasks, and I don't feel like abstracting and refactoring all of that code.

local trade_loop_finder = {}



---@alias TradeInputMap {[string]: int[]}



---Generate a mapping of item names to trade indices based on each trade's input items.
---@param trades_list Trade[]
---@return TradeInputMap
local function preprocess_trades(trades_list)
    local input_map = {}

    for i, trade in ipairs(trades_list) do
        for _, inp in pairs(trade.input_items) do
            local item_name = inp.name
            local t = input_map[item_name]
            if t then
                table.insert(t, i)
            else
                t = {i}
                input_map[item_name] = t
            end
        end
    end

    return input_map
end

---Return whether the given trade has exactly one input and one output.
---@param trade Trade
---@return boolean
local function is_simple_trade(trade)
    return #trade.input_items == 1 and #trade.output_items == 1
end

---Return all loops of order 2 (involving only two trades) within a set of trades.
---@param trades_list Trade[]
---@return {[1]: int, [2]: int}[] loops Table containing tables of index pairs corresponding to simple, two-trade loops in `trades_list`.
function trade_loop_finder.find_simple_loops(trades_list)
    local loops_set = {} ---@as HexSet
    local input_map = preprocess_trades(trades_list)

    for i, trade in ipairs(trades_list) do
        if is_simple_trade(trade) then
            -- Try to find another trade which maps back to this one.
            for _, outp in pairs(trade.output_items) do
                local next_trade_indices = input_map[outp.name] or {}
                for _, idx in pairs(next_trade_indices) do
                    local next_trade = trades_list[idx]
                    if next_trade and is_simple_trade(next_trade) then
                        -- We found another trade which this current trade directly feeds from output to input.
                        -- Now, check if that trade directly feeds the current trade from output to input as well.
                        for _, next_outp in pairs(next_trade.output_items) do
                            local next_trade_indices2 = input_map[next_outp.name] or {}
                            for _, j in pairs(next_trade_indices2) do
                                if i == j then
                                    -- The trades at indices i and idx create a simple loop!
                                    local lesser_idx, greater_idx
                                    if i < idx then
                                        lesser_idx = i
                                        greater_idx = idx
                                    else
                                        lesser_idx = idx
                                        greater_idx = i
                                    end

                                    -- By working with sets and sorting the trade indices per loop, we eliminate the duplicate {B, A} for every {A, B}.
                                    hex_sets.add(loops_set, {q = lesser_idx, r = greater_idx})
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local loops = {}
    for _, hex in pairs(hex_sets.to_array(loops_set)) do
        table.insert(loops, {hex.q, hex.r}) -- Reconstructing the HexPos objects as two-element tables.
    end

    return loops
end

---(NOT YET IMPLEMENTED) Begin an iterative process for detecting trade loops of arbitrary order (length), triggering events as loops are found.
---@param trades_list Trade[]
---@return int trade_search_process_id PID-like number which corresponds uniquely to the search initiated at the time this function is called, for use in terminating the search.
function trade_loop_finder.find_loops(trades_list)
    return 0
end

---(NOT YET IMPLEMENTED) Perform a step in the iterative deepening search.
function trade_loop_finder.iterative_step()

end

---(NOT YET IMPLEMENTED) Terminate the given search process, obtained from the return value of `trade_loop_finder.find_loops()`.
---@param trade_search_process_id int
function trade_loop_finder.terminate(trade_search_process_id)

end



return trade_loop_finder
