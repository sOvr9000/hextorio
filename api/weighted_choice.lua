
local lib = require "api.lib"

---@alias WeightedChoice {[any]: number, __total_weight: number}

local weighted_choice = {}



---Create a new weighted choice object (which shallow copies the passed weights table)
---@param weights {[any]: number}
---@return WeightedChoice
function weighted_choice.new(weights)
    if not next(weights) then
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

---Get an item's weight
---@param wc WeightedChoice
---@param item any
---@return number
function weighted_choice.get_weight(wc, item)
    return wc[item] or 0
end

---Sample an item from the weighted choice object
---@param wc WeightedChoice
---@return any
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

---Shallow copy a weighted choice object
---@param wc WeightedChoice
---@return WeightedChoice
function weighted_choice.copy(wc)
    local new_wc = {}
    for item, weight in pairs(wc) do
        new_wc[item] = weight
    end
    return new_wc
end

---Add bias (any number from -inf to inf) to an item in the weighted choice object, returning a new object.
---If bias < 0, the item weight will be adjusted to `wc[item] = wc[item] / -bias`, which means that `item` is `1 / -bias` times as likely to be chosen.
---If bias > 0, the item weight will be adjusted to `wc[item] = wc[item] * bias`, which means that `item` is `bias` times as likely to be chosen.
---If bias = 0, the item weight will be unchanged.
---@param wc WeightedChoice
---@param item any
---@param bias number
---@return WeightedChoice
function weighted_choice.add_bias(wc, item, bias)
    local new_wc = weighted_choice.copy(wc)
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

---Apply a bias to all weights, returning a new weighted choice object.
---Positive bias favors items with smaller weights (rarer items), negative bias favors items with larger weights (common items).
---@param wc WeightedChoice
---@param bias number
---@return WeightedChoice
function weighted_choice.add_global_bias(wc, bias)
    local new_wc = weighted_choice.copy(wc)
    if bias == 0 then return new_wc end

    -- Collect all items and weights (excluding __total_weight)
    local items = {}
    local normalized_weights = {}
    local original_total = new_wc["__total_weight"]
    local index = 1

    for item, weight in pairs(new_wc) do
        if item ~= "__total_weight" then
            items[index] = item
            -- Normalize to [0,1] range based on total weight
            normalized_weights[index] = weight / original_total
            index = index + 1
        end
    end

    -- Apply softmax-like transformation
    -- bias > 0: base < 1, favors small weights (rare items)
    -- bias < 0: base > 1, favors large weights (common items)
    local base = math.exp(-bias)
    local transformed_weights = {}
    local sum_transformed = 0

    for i = 1, #normalized_weights do
        transformed_weights[i] = math.pow(base, normalized_weights[i])
        sum_transformed = sum_transformed + transformed_weights[i]
    end

    -- Normalize and scale back to preserve original total weight magnitude
    local new_total_weight = 0
    for i = 1, #items do
        local final_weight = (transformed_weights[i] / sum_transformed) * original_total
        new_wc[items[i]] = final_weight
        new_total_weight = new_total_weight + final_weight
    end

    new_wc["__total_weight"] = new_total_weight

    return new_wc
end

---Return a new weighted choice object where the provided item is `ratio` of the total weight in the given weighted choice object.
---@param wc WeightedChoice
---@param item any
---@param ratio number
function weighted_choice.set_ratio(wc, item, ratio)
    -- Algebraically,
    -- Let W = current item weight
    -- Let I = increment to item weight
    -- Let T = total weight before item's weight adjustment
    -- Let R = desired ratio of item weight to total weight
    -- Then,
    -- (W + I) / (T + I) = R
    -- which means,
    -- I = R * (T + I) - W
    -- => I = RT + RI - W
    -- => I * (1 - R) = RT - W
    -- => I = (RT - W) / (1 - R)
    -- So we set the weight of the item to W + (RT - W) / (1 - R)

    local item_weight = weighted_choice.get_weight(wc, item)
    local I = (ratio * wc["__total_weight"] - item_weight) / (1 - ratio)
    local new_wc = weighted_choice.copy(wc)
    weighted_choice.set_weight(new_wc, item, item_weight + I)

    return new_wc
end



return weighted_choice
