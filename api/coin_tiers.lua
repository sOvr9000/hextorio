
local lib = require "api.lib"



local coin_tiers = {}



---Initialize a new coin object
---@param values CoinValues|nil
---@return Coin
function coin_tiers.new(values)
    if not values or not next(values) then
        values = {0, 0, 0, 0}
    end

    -- If the values are indexed by coin names, then update values
    if values["hex-coin"] or values["gravity-coin"] or values["meteor-coin"] or values["hexaprism-coin"] then
        values = {values["hex-coin"] or 0, values["gravity-coin"] or 0, values["meteor-coin"] or 0, values["hexaprism-coin"] or 0}
    end

    -- Create the coin object with configuration
    local coin = {
        tier_scaling = 100000,
        max_coin_tier = #values,
        values = values,
    }

    -- coin_tiers.verify_coin_object_structure(coin)

    return coin
end

---Verify that the given coin object has a valid structure.
---@param coin Coin
function coin_tiers.verify_coin_object_structure(coin)
    if #coin.values ~= coin.max_coin_tier then
        lib.log_error("coin_tiers.verify_coin_object_structure: coin values array does not have " .. coin.max_coin_tier .. " values")
    end
    for k, v in pairs(coin.values) do
        if type(k) ~= "number" or type(v) ~= "number" then
            lib.log_error("coin_tiers.verify_coin_object_structure: coin values array has an invalid key-value pair: [" .. k .. "] = " .. v)
        end
    end
    if coin.max_coin_tier == 0 then
        lib.log_error("coin_tiers.verify_coin_object_structure: max coin tier is zero")
    end
end

---Make a copy of a coin object.
---@param coin Coin
---@return Coin
function coin_tiers.copy(coin)
    local new_coin = coin_tiers.new()
    new_coin.tier_scaling = coin.tier_scaling
    new_coin.max_coin_tier = coin.max_coin_tier
    for i = 1, coin.max_coin_tier do
        new_coin.values[i] = coin.values[i]
    end

    -- coin_tiers.verify_coin_object_structure(new_coin)

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
---@param accumulator number[] -- Array of 4 numbers (modified in-place)
---@param coin Coin
function coin_tiers.accumulate(accumulator, coin)
    local values = coin.values
    accumulator[1] = accumulator[1] + values[1]
    accumulator[2] = accumulator[2] + values[2]
    accumulator[3] = accumulator[3] + values[3]
    accumulator[4] = accumulator[4] + values[4]
end

---Add two coin objects, returning a new coin object.
---@param coin1 Coin
---@param coin2 Coin
---@return Coin
function coin_tiers.add(coin1, coin2)
    -- Ensure configurations match
    if coin1.tier_scaling ~= coin2.tier_scaling or coin1.max_coin_tier ~= coin2.max_coin_tier then
        lib.log_error("Cannot add coins with different configurations")
    end

    -- Cache locals and create result values directly
    local max_coin_tier = coin1.max_coin_tier
    local values1 = coin1.values
    local values2 = coin2.values
    local result_values = {}

    for i = 1, max_coin_tier do
        result_values[i] = values1[i] + values2[i]
    end

    return coin_tiers.normalized({
        tier_scaling = coin1.tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    })
end

---Subtract coin2 from coin1, returning a new coin object.
---@param coin1 Coin
---@param coin2 Coin
---@return Coin
function coin_tiers.subtract(coin1, coin2)
    -- Ensure configurations match
    if coin1.tier_scaling ~= coin2.tier_scaling or coin1.max_coin_tier ~= coin2.max_coin_tier then
        lib.log_error("Cannot subtract coins with different configurations")
    end

    -- Cache locals and create result values directly
    local max_coin_tier = coin1.max_coin_tier
    local values1 = coin1.values
    local values2 = coin2.values
    local result_values = {}

    for i = 1, max_coin_tier do
        result_values[i] = values1[i] - values2[i]
    end

    return coin_tiers.normalized({
        tier_scaling = coin1.tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    })
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

    return coin_tiers.normalized({
        tier_scaling = coin.tier_scaling,
        max_coin_tier = max_coin_tier,
        values = result_values
    })
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
    -- Ensure configurations match
    -- This could technically be handled correctly by converting the tier scaling, but it is not needed for Hextorio.
    -- It can be handled easily by comparing base values (coin_tiers.to_base_value() comparison),
    -- but that involves multiplcation, whereas this method does not.
    if coin1.tier_scaling ~= coin2.tier_scaling or coin1.max_coin_tier ~= coin2.max_coin_tier then
        lib.log_error("Cannot compare coins with different configurations")
    end

    for i = coin1.max_coin_tier, 1, -1 do
        if coin1.values[i] < coin2.values[i] then
            return -1
        elseif coin1.values[i] > coin2.values[i] then
            return 1
        end
    end

    return 0  -- They are equal
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
    local scaling = tier_scaling or 100000
    local max_tier = max_coin_tier or 4
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

---Get a coin object from the given inventory.
---@param inventory LuaInventory|LuaTrain
---@return Coin
function coin_tiers.get_coin_from_inventory(inventory)
    return coin_tiers.new {inventory.get_item_count "hex-coin", inventory.get_item_count "gravity-coin", inventory.get_item_count "meteor-coin", inventory.get_item_count "hexaprism-coin"}
end

---Update the inventory contents such that it contains the given coin.
---@param inventory LuaInventory|LuaTrain
---@param current_coin Coin
---@param new_coin Coin
function coin_tiers.update_inventory(inventory, current_coin, new_coin)
    storage.coin_tiers.is_processing[inventory] = true

    local is_train = inventory.object_name == "LuaTrain"

    for tier = 1, 4 do
        local coin_name = lib.get_coin_name_of_tier(tier)
        local new_amount = new_coin.values[tier]
        local current_amount = current_coin.values[tier]

        if new_amount > current_amount then
            inventory.insert {name = coin_name, count = new_amount - current_amount}
        elseif new_amount < current_amount then
            if is_train then
                inventory.remove_item {name = coin_name, count = current_amount - new_amount}
            else
                inventory.remove {name = coin_name, count = current_amount - new_amount}
            end
        end
    end

    storage.coin_tiers.is_processing[inventory] = nil
end

---Normalize the inventory, combining multiple stacks of coins into their next tiers.
---@param inventory LuaInventory|LuaTrain
---@return Coin|nil
function coin_tiers.normalize_inventory(inventory)
    if storage.coin_tiers.is_processing[inventory] then return end
    storage.coin_tiers.is_processing[inventory] = true

    local coin = coin_tiers.get_coin_from_inventory(inventory)
    local normalized_coin = coin_tiers.normalized(coin)
    coin_tiers.update_inventory(inventory, coin, normalized_coin)
    storage.coin_tiers.is_processing[inventory] = nil

    return normalized_coin
end

---Add coins to the inventory.
---@param inventory LuaInventory|LuaTrain
---@param coin Coin
function coin_tiers.add_coin_to_inventory(inventory, coin)
    local current_coin = coin_tiers.get_coin_from_inventory(inventory)
    local new_coin = coin_tiers.add(current_coin, coin)
    coin_tiers.update_inventory(inventory, current_coin, new_coin)
end

---Remove coins from the inventory
---@param inventory LuaInventory|LuaTrain
---@param coin Coin
function coin_tiers.remove_coin_from_inventory(inventory, coin)
    local current_coin = coin_tiers.get_coin_from_inventory(inventory)
    local new_coin = coin_tiers.subtract(current_coin, coin)
    coin_tiers.update_inventory(inventory, current_coin, new_coin)
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
        if coin.values[i] > 1000 then
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
    return (tier_scaling or 100000) ^ (tier - 1)
end

---Get the name of the coin at the given tier.
---@param tier int
---@return string
function coin_tiers.get_name_of_tier(tier)
    if tier <= 1 then
        return "hex-coin"
    elseif tier == 2 then
        return "gravity-coin"
    elseif tier == 3 then
        return "meteor-coin"
    else
        return "hexaprism-coin"
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
    local new_values = {0, 0, 0, 0}  -- Initialize with zeros

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



return coin_tiers
