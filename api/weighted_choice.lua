
local lib = require "api.lib"

local weighted_choice = {}



-- Create a new weighted choice object (which shallow copies the passed weights table)
function weighted_choice.new(weights)
    -- error if weights is not a table
    if type(weights) ~= "table" then
        lib.log_error("weighted_choice.new: weights must be a table")
    end

    -- error if weights is empty
    if lib.is_empty_table(weights) then
        lib.log_error("weighted_choice.new: weights must not be empty")
    end

    local wc = {}

    local s = 0
    for item, weight in pairs(weights) do
        -- shallow copy
        wc[item] = weight

        -- sum the weights for sampling
        s = s + weight
    end

    wc["__total_weight"] = s
    return wc
end

-- Set an item's weight
function weighted_choice.set_weight(wc, item, weight)
    if weight < 0 then
        lib.log("weighted_choice.set_weight: weight must be non-negative, defaulting to zero")
        weighted_choice.set_weight(wc, item, 0)
        return
    end
    -- Keep track of the total weight
    local prev_weight = wc[item] or 0
    wc[item] = weight
    wc["__total_weight"] = wc["__total_weight"] + weight - prev_weight

    if weight == 0 then
        wc[item] = nil
    end
end

-- Get an item's weight
function weighted_choice.get_weight(wc, item)
    return wc[item] or 0
end

-- Sample an item from the weighted choice object
function weighted_choice.choice(wc)
    local r = math.random() * wc["__total_weight"]
    local s = 0
    for item, weight in pairs(wc) do
        if item ~= "__total_weight" then
            s = s + weight
            if r <= s then
                return item
            end
        end
    end
end

-- Shallow copy a weighted choice object
function weighted_choice.copy(wc)
    if not wc then
        lib.log_error("weighted_choice.copy: wc is nil")
        return
    end
    local new_wc = {}
    for item, weight in pairs(wc) do
        new_wc[item] = weight
    end
    return new_wc
end

-- Add bias (any number from -inf to inf) to an item in the weighted choice object, returning a new object.
-- If bias < 0, the item weight will be adjusted to `wc[item] = wc[item] / -bias`, which means that `item` is `1 / -bias` times as likely to be chosen.
-- If bias > 0, the item weight will be adjusted to `wc[item] = wc[item] * bias`, which means that `item` is `bias` times as likely to be chosen.
-- If bias = 0, the item weight will be unchanged.
function weighted_choice.add_bias(wc, item, bias)
    if not wc then
        lib.log_error("weighted_choice.add_bias: wc is nil")
        return
    end
    local new_wc = weighted_choice.copy(wc)
    if not new_wc then return end
    if bias == 0 then return new_wc end

    local old_value = new_wc[item]
    if bias < 0 then
        new_wc[item] = new_wc[item] / -bias
    elseif bias > 0 then
        new_wc[item] = new_wc[item] * bias
    end
    new_wc["__total_weight"] = new_wc["__total_weight"] + new_wc[item] - old_value

    return new_wc
end



return weighted_choice
