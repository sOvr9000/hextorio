
local lib = require "api.lib"



local coin_tiers = {}



-- Hardcoded constant for optimal performance when rapidly computing coin operations.
local NUM_COIN_TIERS = 5



---@alias CoinName "hex-coin"|"gravity-coin"|"meteor-coin"|"hexaprism-coin"|"black-hole-coin"
---@alias CoinValues {[1]: number, [2]: number, [3]: number, [4]: number, [5]: number}
---@alias CoinValuesByName {[CoinName]: number}

---@class Coin
---@field tier_scaling number
---@field max_coin_tier int
---@field values CoinValues



function coin_tiers.init()
    storage.coin_tiers.COIN_TIERS_BY_NAME = {} ---@type {[CoinName]: int}
    for tier, coin_name in pairs(storage.coin_tiers.COIN_NAMES) do
        storage.coin_tiers.COIN_TIERS_BY_NAME[coin_name] = tier
    end
end

---Return an array of zeroes for better optimized coin value aggregation, not as a formal Coin object.
---@return CoinValues
function coin_tiers.new_coin_values()
    return {0, 0, 0, 0, 0}
end

---Initialize a new coin object
---@param values CoinValues|nil
---@return Coin
function coin_tiers.new(values)
    if not values or not next(values) then
        values = coin_tiers.new_coin_values()
    end

    -- Create the coin object with configuration
    local coin = {
        tier_scaling = storage.coin_tiers.TIER_SCALING,
        max_coin_tier = #values,
        values = values,
    }

    return coin
end

---Create a Coin object from amounts per coin name.
---@param coin_values_by_name CoinValuesByName
---@return Coin
function coin_tiers.from_coin_values_by_name(coin_values_by_name)
    local values = {}
    for i, coin_name in ipairs(storage.coin_tiers.COIN_NAMES) do
        values[i] = coin_values_by_name[coin_name] or 0
    end
    return coin_tiers.new(values)
end

---Collapse duplicate item rows and compress all coin rows to canonical denominations.
---@param items TradeItem[]|TentativeTradeItem[]
---@return TradeItem[]
function coin_tiers.canonicalize_trade_item_list(items)
    local canonical_items = {}
    local non_coin_by_name = {}
    local coin_values = coin_tiers.new_coin_values()
    local first_coin_index = nil

    for _, item in ipairs(items or {}) do
        local count = item.count or 0
        if lib.is_coin(item.name) then
            first_coin_index = first_coin_index or (#canonical_items + 1)
            local tier = storage.coin_tiers.COIN_TIERS_BY_NAME[item.name] or 1
            coin_values[tier] = coin_values[tier] + count
        else
            local existing = non_coin_by_name[item.name]
            if existing then
                existing.count = existing.count + count
            else
                existing = {
                    name = item.name,
                    count = count,
                }
                canonical_items[#canonical_items + 1] = existing
                non_coin_by_name[item.name] = existing
            end
        end
    end

    if not first_coin_index then
        return canonical_items
    end

    local coin = coin_tiers.floor(coin_tiers.new(coin_values))
    if coin_tiers.is_zero(coin) then
        return canonical_items
    end

    local coin_items = {}
    for tier, count in ipairs(coin.values) do
        if count > 0 then
            coin_items[#coin_items + 1] = {
                name = storage.coin_tiers.COIN_NAMES[tier],
                count = count,
            }
        end
    end

    for i = #coin_items, 1, -1 do
        table.insert(canonical_items, first_coin_index, coin_items[i])
    end

    return canonical_items
end

---Canonicalize both sides of a trade-like object in place.
---@param trade Trade|TentativeTrade
function coin_tiers.canonicalize_trade_items(trade)
    trade.input_items = coin_tiers.canonicalize_trade_item_list(trade.input_items)
    trade.output_items = coin_tiers.canonicalize_trade_item_list(trade.output_items)
end

---Make a copy of a coin object.
---@param coin Coin
---@return Coin
function coin_tiers.copy(coin)
    local values = {}

    for i = 1, coin.max_coin_tier do
        values[i] = coin.values[i]
    end

    local new_coin = {
        tier_scaling = coin.tier_scaling,
        max_coin_tier = coin.max_coin_tier,
        values = values,
    }

    return new_coin
end

---Normalize a coin, ensuring all tiers are within bounds and have integer values except the lowest tier, returning a new coin object.
---@param coin Coin
---@return Coin
function coin_tiers.normalized(coin)
    -- Cache frequently accessed fields as locals
    local tier_scaling = coin.tier_scaling
    local max_coin_tier = coin.max_coin_tier
    local old_values = coin.values
    local new_values = {}

    -- Copy values directly (inline the copy operation)
    for i = 1, max_coin_tier do
        new_values[i] = old_values[i]
    end

    -- Convert decimals to integers
    for i = max_coin_tier, 2, -1 do
        local val = new_values[i]
        local floor_val = math.floor(val)
        if val ~= floor_val then
            -- Cache the fractional part calculation
            local fractional = val - floor_val
            new_values[i - 1] = new_values[i - 1] + tier_scaling * fractional
            new_values[i] = floor_val
        end
    end

    -- Handle carrying and borrowing
    for i = 1, max_coin_tier - 1 do
        local v = new_values[i]
        if v < 0 then
            -- Handle borrowing from higher tiers for negative values
            local borrow = math.ceil(-v / tier_scaling)
            new_values[i + 1] = new_values[i + 1] - borrow
            new_values[i] = v + tier_scaling * borrow
        elseif v >= tier_scaling then
            -- Handle carrying to higher tiers
            local carry = math.floor(v / tier_scaling)
            new_values[i] = v % tier_scaling
            new_values[i + 1] = new_values[i + 1] + carry
        end
    end

    -- If highest tier is negative, zero out everything
    if new_values[max_coin_tier] < 0 then
        lib.log_error("coin_tiers.normalized: Encountered negative coin value: " .. serpent.line(new_values))
        for i = 1, max_coin_tier do
            new_values[i] = 0
        end
    end

    -- Return new coin directly without calling coin_tiers.new()
    return {
        tier_scaling = tier_scaling,
        max_coin_tier = max_coin_tier,
        values = new_values
    }
end

---Add coin values to an accumulator without normalization (for performance).
---Saves processing time when adding many coins together.
---Instead of using calling `coin_tiers.add()` many times, call this function instead and normalize at the end.
---@param accumulator number[] Accumulation of coin values, modified in-place
---@param coin Coin
function coin_tiers.accumulate(accumulator, coin)
    local values = coin.values
    for i = NUM_COIN_TIERS, 1, -1 do
        accumulator[i] = accumulator[i] + values[i]
    end
end

---Return a new coin object with the values negated.
---@param coin Coin
function coin_tiers.negated(coin)
    local values = coin.values
    local new_values = {}
    for i = #values, 1, -1 do
        new_values[i] = -values[i]
    end
    return coin_tiers.new(new_values)
end

---Return how many tiers of coins are nonzero in the coin object.
---Assumes that `coin` is normalized.
---@param coin Coin
---@return int
function coin_tiers.count_nonzero_tiers(coin)
    local values = coin.values
    local total = 0
    for i = #values, 1, -1 do
        if values[i] ~= 0 then -- Allow negatives, but this algorithm can possibly return an incorrect number if a single one of the values is negative because it implies the coin object is not normalized.
            total = total + 1
        end
    end
    return total
end

---Add two coin objects, returning a new coin object.
---@param coin1 Coin
---@param coin2 Coin
---@return Coin
function coin_tiers.add(coin1, coin2)
    -- Cache locals and create result values directly
    local max_coin_tier = coin1.max_coin_tier
    local values1 = coin1.values
    local values2 = coin2.values
    local result_values = {}

    for i = 1, max_coin_tier do
        result_values[i] = values1[i] + values2[i]
    end

    local result = {
        tier_scaling = coin1.tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    }

    return coin_tiers.normalized(result)
end

---Subtract coin2 from coin1, returning a new coin object.
---@param coin1 Coin
---@param coin2 Coin
---@return Coin
function coin_tiers.subtract(coin1, coin2)
    -- Cache locals and create result values directly
    local max_coin_tier = coin1.max_coin_tier
    local values1 = coin1.values
    local values2 = coin2.values
    local result_values = {}

    for i = 1, max_coin_tier do
        result_values[i] = values1[i] - values2[i]
    end

    local result = {
        tier_scaling = coin1.tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    }

    return coin_tiers.normalized(result)
end

---Multiply a coin value by a scalar value, returning a new coin object.
---@param coin Coin
---@param factor number
---@return Coin
function coin_tiers.multiply(coin, factor)
    -- Cache locals and create result values directly
    local max_coin_tier = coin.max_coin_tier
    local values = coin.values
    local result_values = {}

    for i = 1, max_coin_tier do
        result_values[i] = values[i] * factor
    end

    local result = {
        tier_scaling = coin.tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    }

    return coin_tiers.normalized(result)
end

---Divide a coin value by a scalar value, returning a new coin object.
---@param coin Coin
---@param divisor number
---@return Coin
function coin_tiers.divide(coin, divisor)
    if divisor == 0 then
        lib.log_error("Cannot divide by zero")
    end

    -- Cache locals
    local max_coin_tier = coin.max_coin_tier
    local tier_scaling = coin.tier_scaling
    local values = coin.values
    local result_values = {}
    local remainder = 0

    -- Process from highest tier to lowest
    for i = max_coin_tier, 1, -1 do
        -- Add remainder from higher tier
        local current = values[i] + remainder

        -- Divide current tier value
        result_values[i] = math.floor(current / divisor)

        -- Calculate remainder and convert to lower tier units
        remainder = (current % divisor) * tier_scaling
    end

    local result = {
        tier_scaling = tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    }

    if coin_tiers.is_zero(result) and not coin_tiers.is_zero(coin) then
        result_values[1] = 1
    end

    return result
end

---Return the ratio of coin1 / coin2, returning a scalar value.
---@param coin1 Coin
---@param coin2 Coin
---@return number
function coin_tiers.divide_coins(coin1, coin2)
    local base_value_1 = coin_tiers.to_base_value(coin1)
    local base_value_2 = coin_tiers.to_base_value(coin2)
    return base_value_1 / base_value_2
end

---Compare two coin values (returns -1 if coin1 < coin2, 0 if equal, 1 if coin1 > coin2).
---@param coin1 Coin
---@param coin2 Coin
---@return int
function coin_tiers.compare(coin1, coin2)
    for i = coin1.max_coin_tier, 1, -1 do
        if coin1.values[i] < coin2.values[i] then
            return -1
        elseif coin1.values[i] > coin2.values[i] then
            return 1
        end
    end
    return 0
end

---@param coin1 Coin
---@param coin2 Coin
---@return boolean
function coin_tiers.gt(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) == 1
end

---@param coin1 Coin
---@param coin2 Coin
---@return boolean
function coin_tiers.lt(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) == -1
end

---@param coin1 Coin
---@param coin2 Coin
---@return boolean
function coin_tiers.ge(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) >= 0
end

---@param coin1 Coin
---@param coin2 Coin
---@return boolean
function coin_tiers.le(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) <= 0
end

---Return whether the given coin object represents zero value.  Normalization may need needed if negative and positive values from different tiers cancel everything out.
---@param coin Coin
---@return boolean
function coin_tiers.is_zero(coin)
    for i = 1, coin.max_coin_tier do
        if coin.values[i] ~= 0 then
            return false
        end
    end
    return true
end

---Return whether the given coin object represents a negative total value.  Normalization is not needed for this to accurately detect negative values because it uses `coin_tiers.to_base_value()`.
---@param coin Coin
---@return boolean
function coin_tiers.is_negative(coin)
    return coin_tiers.to_base_value(coin) < 0
end

---Get the total value in terms of the lowest tier.
---@param coin Coin
---@return number
function coin_tiers.to_base_value(coin)
    local total = 0
    local multiplier = 1

    for i = 1, coin.max_coin_tier do
        total = total + coin.values[i] * multiplier
        multiplier = multiplier * coin.tier_scaling
    end

    return total
end

---Get the total value in terms of the lowest tier and the provided tier
---@param coin Coin
---@param base_tier int
---@return number, number
function coin_tiers.to_base_values(coin, base_tier)
    local total = 0
    local multiplier = 1

    for i = 1, coin.max_coin_tier do
        total = total + coin.values[i] * multiplier
        multiplier = multiplier * coin.tier_scaling
    end

    return total, total * coin.tier_scaling ^ (1 - base_tier)
end

---Create a coin from a value in the lowest tier
---@param value number
---@param tier_scaling number|nil
---@param max_coin_tier int|nil
---@return Coin
function coin_tiers.from_base_value(value, tier_scaling, max_coin_tier)
    -- Cache locals
    local scaling = tier_scaling or storage.coin_tiers.TIER_SCALING
    local max_tier = max_coin_tier or #storage.coin_tiers.COIN_NAMES
    local values = {}
    local remaining = value

    for i = 1, max_tier do
        values[i] = remaining % scaling
        remaining = math.floor(remaining / scaling)
    end

    -- If there's remaining value beyond the highest tier, add it to the highest tier
    if remaining > 0 then
        values[max_tier] = values[max_tier] + remaining * scaling
    end

    return {
        tier_scaling = scaling,
        max_coin_tier = max_tier,
        values = values
    }
end

---Round a coin value to the next highest integral base value if it's not already integral, returning a new coin object.
---@param coin Coin
---@return Coin
function coin_tiers.ceil(coin)
    local norm = coin_tiers.normalized(coin)
    local val = norm.values[1]
    local ceil_val = math.ceil(val)
    if val ~= ceil_val then
        norm.values[1] = ceil_val
    end
    return norm
end

---Round a coin value to the next lowest integral base value if it's not already integral, returning a new coin object.
---@param coin Coin
---@return Coin
function coin_tiers.floor(coin)
    local norm = coin_tiers.normalized(coin)
    local val = norm.values[1]
    local floor_val = math.floor(val)
    if val ~= floor_val then
        norm.values[1] = floor_val
    end
    return norm
end

---Return coin1 if coin1's value is less than or equal to coin2's value.  Otherwise, return coin2.
---Assumes both coins are in normalized form.
---@param coin1 Coin
---@param coin2 Coin
---@return Coin
function coin_tiers.min(coin1, coin2)
    local values1 = coin1.values
    local values2 = coin2.values
    for i = #storage.coin_tiers.COIN_NAMES, 1, -1 do
        local val1 = values1[i]
        local val2 = values2[i]
        if val1 < val2 then
            return coin1
        elseif val2 < val1 then
            return coin2
        end
    end
    return coin1
end

---Return coin1 if coin1's value is greater than or equal to coin2's value.  Otherwise, return coin2.
---Assumes both coins are in normalized form.
---@param coin1 Coin
---@param coin2 Coin
---@return Coin
function coin_tiers.max(coin1, coin2)
    local values1 = coin1.values
    local values2 = coin2.values
    for i = #storage.coin_tiers.COIN_NAMES, 1, -1 do
        local val1 = values1[i]
        local val2 = values2[i]
        if val1 > val2 then
            return coin1
        elseif val2 > val1 then
            return coin2
        end
    end
    return coin1
end

---Convert a coin object to a human-readable string which represents its value.
---@param coin table
---@param show_leading_zeros boolean|nil
---@param sigfigs int|nil
---@return string
function coin_tiers.coin_to_text(coin, show_leading_zeros, sigfigs)
    return lib.get_str_from_coin(coin, show_leading_zeros, sigfigs)
end

---Convert a base coin value to a human-readable string which represents its value.
---@param base_coin_value number
---@param show_leading_zeros boolean|nil
---@param sigfigs int|nil
---@return string
function coin_tiers.base_coin_value_to_text(base_coin_value, show_leading_zeros, sigfigs)
    local coin = coin_tiers.from_base_value(base_coin_value)
    return coin_tiers.coin_to_text(coin, show_leading_zeros, sigfigs)
end

---Get the tier of the given base coin value.
---@param base_value number
---@return int
function coin_tiers.get_tier_of_base_value(base_value)
    -- could be made more efficient but this works and makes sense and reuses logic
    local coin = coin_tiers.from_base_value(base_value)
    for i = coin.max_coin_tier, 1, -1 do
        if coin.values[i] > 0 then
            return i
        end
    end
    return 1
end

---Get the tier of the given coin object that's suitable for display.
---@param coin Coin
---@return int
function coin_tiers.get_tier_for_display(coin)
    coin = coin_tiers.normalized(coin)
    local passed = false
    for i = coin.max_coin_tier, 1, -1 do
        if coin.values[i] > 10 then
            return i
        elseif coin.values[i] > 0 then
            if passed then
                return i
            end
            passed = true
        end
    end
    return 1
end

---Get the multiplier of base coin value for the given tier and tier scaling.
---@param tier int
---@param tier_scaling number|nil
---@return number
function coin_tiers.get_scale_of_tier(tier, tier_scaling)
    return (tier_scaling or storage.coin_tiers.TIER_SCALING) ^ (tier - 1)
end

---Get the name of the coin at the given tier.
---@param tier int
---@return string
function coin_tiers.get_name_of_tier(tier)
    return lib.get_coin_name_of_tier(tier)
end

---Modify a list in place to ensure that the item names (coins or not) are the best coin tiers for display, given a central value for item values.
---@param list string[]
---@param item_value number
function coin_tiers.validate_coin_names(list, item_value)
    for i, item_name in pairs(list) do
        if lib.is_coin(item_name) then
            list[i] = coin_tiers.get_name_of_tier(coin_tiers.get_tier_for_display(coin_tiers.from_base_value(item_value / (storage.item_values.base_coin_value or 10))))
        end
    end
end

---Shift the tier of the given coin, returning a new coin object.
---@param coin Coin
---@param shift int
---@return Coin
function coin_tiers.shift_tier(coin, shift)
    if shift == 0 then
        -- Inline copy for shift == 0 case
        local max_coin_tier = coin.max_coin_tier
        local old_values = coin.values
        local new_values = {}
        for i = 1, max_coin_tier do
            new_values[i] = old_values[i]
        end
        return {
            tier_scaling = coin.tier_scaling,
            max_coin_tier = max_coin_tier,
            values = new_values
        }
    end

    -- Cache locals
    local max_coin_tier = coin.max_coin_tier
    local tier_scaling = coin.tier_scaling
    local old_values = coin.values
    local new_values = coin_tiers.new_coin_values()

    if shift > 0 then
        for i = 2, max_coin_tier do
            new_values[i] = old_values[i - 1]
        end
        new_values[max_coin_tier] = new_values[max_coin_tier] + old_values[max_coin_tier] * tier_scaling
        return coin_tiers.shift_tier({
            tier_scaling = tier_scaling,
            max_coin_tier = max_coin_tier,
            values = new_values
        }, shift - 1)
    else
        for i = 1, max_coin_tier - 1 do
            new_values[i] = old_values[i + 1]
        end
        return coin_tiers.shift_tier({
            tier_scaling = tier_scaling,
            max_coin_tier = max_coin_tier,
            values = new_values
        }, shift + 1)
    end
end

---Convert any older version of a coin object to the newest version.
---@param coin table
---@return Coin
function coin_tiers.migrate_coin(coin)
    local values = coin_tiers.new_coin_values()

    for i = 1, #values do
        values[i] = coin.values[i] or 0
    end

    return coin_tiers.new(values)
end



return coin_tiers
