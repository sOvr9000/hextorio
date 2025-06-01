
local lib = require "api.lib"

local coin_tiers = {}



-- Initialize a new coin object
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

    coin_tiers.verify_coin_object_structure(coin)

    return coin
end

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

function coin_tiers.copy(coin)
    local new_coin = coin_tiers.new()
    new_coin.tier_scaling = coin.tier_scaling
    new_coin.max_coin_tier = coin.max_coin_tier
    for i = 1, coin.max_coin_tier do
        new_coin.values[i] = coin.values[i]
    end

    coin_tiers.verify_coin_object_structure(new_coin)

    return new_coin
end

-- Normalize a coin, ensuring all tiers are within bounds and have integer values
function coin_tiers.normalized(coin)
    local new_coin = coin_tiers.copy(coin)
    local tier_scaling = new_coin.tier_scaling

    -- Convert decimals to integers
    for i = new_coin.max_coin_tier, 2, -1 do
        if new_coin.values[i] ~= math.floor(new_coin.values[i]) then
            if i > 1 then
                new_coin.values[i - 1] = new_coin.values[i - 1] + new_coin.tier_scaling * (new_coin.values[i] - math.floor(new_coin.values[i]))
                new_coin.values[i] = math.floor(new_coin.values[i])
            end
        end
    end

    for i = 1, new_coin.max_coin_tier - 1 do
        local v = new_coin.values[i]
        if v < 0 then
            -- Handle borrowing from higher tiers for negative values
            local borrow = math.ceil(-v / tier_scaling)
            new_coin.values[i + 1] = new_coin.values[i + 1] - borrow
            new_coin.values[i] = v + tier_scaling * borrow
        elseif v >= tier_scaling then
            -- Handle carrying to higher tiers
            local carry = math.floor(new_coin.values[i] / tier_scaling)
            new_coin.values[i] = v % tier_scaling
            new_coin.values[i + 1] = new_coin.values[i + 1] + carry
        end
    end

    -- If highest tier is negative, zero out everything
    if new_coin.values[new_coin.max_coin_tier] < 0 then
        for i = 1, new_coin.max_coin_tier do
            new_coin.values[i] = 0
        end
        lib.log_error("coin_tiers.normalized: Encountered negative coin value: " .. serpent.line(new_coin.values))
    end

    return new_coin
end

-- Add two coin values
function coin_tiers.add(coin1, coin2)
    -- Ensure configurations match
    if coin1.tier_scaling ~= coin2.tier_scaling or coin1.max_coin_tier ~= coin2.max_coin_tier then
        lib.log_error("Cannot add coins with different configurations")
    end
    
    local result = coin_tiers.new()
    
    for i = 1, coin1.max_coin_tier do
        result.values[i] = coin1.values[i] + coin2.values[i]
    end
    
    return coin_tiers.normalized(result)
end

-- Subtract coin2 from coin1
function coin_tiers.subtract(coin1, coin2)
    -- Ensure configurations match
    if coin1.tier_scaling ~= coin2.tier_scaling or coin1.max_coin_tier ~= coin2.max_coin_tier then
        lib.log_error("Cannot subtract coins with different configurations")
    end
    
    local result = coin_tiers.new()
    
    for i = 1, coin1.max_coin_tier do
        result.values[i] = coin1.values[i] - coin2.values[i]
    end

    return coin_tiers.normalized(result)
end

-- Multiply a coin value by a number
function coin_tiers.multiply(coin, factor)
    local result = coin_tiers.new()
    
    for i = 1, coin.max_coin_tier do
        result.values[i] = coin.values[i] * factor
    end
    
    return coin_tiers.normalized(result)
end

-- Divide a coin value by a number
function coin_tiers.divide(coin, divisor)
    if divisor == 0 then
        lib.log_error("Cannot divide by zero")
    end
    
    local result = coin_tiers.new()
    local remainder = 0
    
    -- Process from highest tier to lowest
    for i = coin.max_coin_tier, 1, -1 do
        -- Add remainder from higher tier
        local current = coin.values[i] + remainder
        
        -- Divide current tier value
        result.values[i] = math.floor(current / divisor)
        
        -- Calculate remainder and convert to lower tier units
        remainder = (current % divisor) * coin.tier_scaling
    end

    if coin_tiers.is_zero(result) and not coin_tiers.is_zero(coin) then
        result.values[1] = 1
    end
    
    return result
end

-- Return the ratio of coin1 / coin2, returning a number
function coin_tiers.divide_coins(coin1, coin2)
    local base_value_1 = coin_tiers.to_base_value(coin1)
    local base_value_2 = coin_tiers.to_base_value(coin2)
    return base_value_1 / base_value_2
end

-- Compare two coin values (returns -1 if coin1 < coin2, 0 if equal, 1 if coin1 > coin2)
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

function coin_tiers.gt(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) == 1
end

function coin_tiers.lt(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) == -1
end

function coin_tiers.ge(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) >= 0
end

function coin_tiers.le(coin1, coin2)
    return coin_tiers.compare(coin1, coin2) <= 0
end

function coin_tiers.is_zero(coin)
    for i = 1, coin.max_coin_tier do
        if coin.values[i] ~= 0 then
            return false
        end
    end
    return true
end

-- Get the total value in terms of the lowest tier
function coin_tiers.to_base_value(coin)
    local total = 0
    local multiplier = 1
    
    for i = 1, coin.max_coin_tier do
        total = total + coin.values[i] * multiplier
        multiplier = multiplier * coin.tier_scaling
    end
    
    return total
end

-- Get the total value in terms of the lowest tier and the provided tier
function coin_tiers.to_base_values(coin, base_tier)
    local total = 0
    local multiplier = 1
    
    for i = 1, coin.max_coin_tier do
        total = total + coin.values[i] * multiplier
        multiplier = multiplier * coin.tier_scaling
    end
    
    return total, total * coin.tier_scaling ^ (1 - base_tier)
end

-- Create a coin from a value in the lowest tier
function coin_tiers.from_base_value(value, tier_scaling, max_coin_tier)
    local coin = coin_tiers.new()
    coin.tier_scaling = tier_scaling or 100000
    coin.max_coin_tier = max_coin_tier or 4

    local remaining = value
    
    for i = 1, coin.max_coin_tier do
        coin.values[i] = remaining % coin.tier_scaling
        remaining = math.floor(remaining / coin.tier_scaling)
    end
    
    -- If there's remaining value beyond the highest tier, add it to the highest tier
    if remaining > 0 then
        coin.values[coin.max_coin_tier] = coin.values[coin.max_coin_tier] + remaining * coin.tier_scaling
    end
    
    return coin
end

function coin_tiers.ceil(coin)
    local norm = coin_tiers.normalized(coin)
    if norm.values[1] ~= math.ceil(norm.values[1]) then
        norm.values[1] = math.ceil(norm.values[1])
    end
    return norm
end

function coin_tiers.floor(coin)
    local norm = coin_tiers.normalized(coin)
    if norm.values[1] ~= math.floor(norm.values[1]) then
        norm.values[1] = math.floor(norm.values[1])
    end
    return norm
end

-- Get a coin object from the inventory
function coin_tiers.get_coin_from_inventory(inventory)
    if not inventory then
        error("coin_tiers.get_coin_from_inventory: inventory is nil")
        return coin_tiers.new()
    end
    local coin = coin_tiers.new()
    coin.values = {inventory.get_item_count "hex-coin", inventory.get_item_count "gravity-coin", inventory.get_item_count "meteor-coin", inventory.get_item_count "hexaprism-coin"}
    return coin
end

-- Update the inventory from one coin to another
function coin_tiers.update_inventory(inventory, current_coin, new_coin)
    -- if coin_tiers.eq(current_coin, new_coin) then return end
    storage.coin_tiers.is_processing[inventory] = true

    if new_coin.values[1] > current_coin.values[1] then
        inventory.insert {name = "hex-coin", count = new_coin.values[1] - current_coin.values[1]}
    elseif new_coin.values[1] < current_coin.values[1] then
        inventory.remove {name = "hex-coin", count = current_coin.values[1] - new_coin.values[1]}
    end

    if new_coin.values[2] > current_coin.values[2] then
        inventory.insert {name = "gravity-coin", count = new_coin.values[2] - current_coin.values[2]}
    elseif new_coin.values[2] < current_coin.values[2] then
        inventory.remove {name = "gravity-coin", count = current_coin.values[2] - new_coin.values[2]}
    end

    if new_coin.values[3] > current_coin.values[3] then
        inventory.insert {name = "meteor-coin", count = new_coin.values[3] - current_coin.values[3]}
    elseif new_coin.values[3] < current_coin.values[3] then
        inventory.remove {name = "meteor-coin", count = current_coin.values[3] - new_coin.values[3]}
    end

    if new_coin.values[4] > current_coin.values[4] then
        inventory.insert {name = "hexaprism-coin", count = new_coin.values[4] - current_coin.values[4]}
    elseif new_coin.values[4] < current_coin.values[4] then
        inventory.remove {name = "hexaprism-coin", count = current_coin.values[4] - new_coin.values[4]}
    end

    storage.coin_tiers.is_processing[inventory] = nil
end

-- Normalize the inventory, combining multiple stacks of coins into their next tiers.
function coin_tiers.normalize_inventory(inventory)
    if storage.coin_tiers.is_processing[inventory] then return end
    storage.coin_tiers.is_processing[inventory] = true

    local coin = coin_tiers.get_coin_from_inventory(inventory)
    local normalized_coin = coin_tiers.normalized(coin)
    coin_tiers.update_inventory(inventory, coin, normalized_coin)

    storage.coin_tiers.is_processing[inventory] = nil

    return normalized_coin
end

-- Add coins to the inventory
function coin_tiers.add_coin_to_inventory(inventory, coin)
    local current_coin = coin_tiers.get_coin_from_inventory(inventory)
    local new_coin = coin_tiers.add(current_coin, coin)
    -- log("add_coin_to_inventory: current_coin = " .. serpent.line(current_coin))
    -- log("add_coin_to_inventory: new_coin = " .. serpent.line(new_coin))
    coin_tiers.update_inventory(inventory, current_coin, new_coin)
end

-- Remove coins from the inventory
function coin_tiers.remove_coin_from_inventory(inventory, coin)
    local current_coin = coin_tiers.get_coin_from_inventory(inventory)
    local new_coin = coin_tiers.subtract(current_coin, coin)
    -- log("remove_coin_from_inventory: current_coin = " .. serpent.line(current_coin))
    -- log("remove_coin_from_inventory: new_coin = " .. serpent.line(new_coin))
    coin_tiers.update_inventory(inventory, current_coin, new_coin)
end

function coin_tiers.coin_to_text(coin, show_leading_zeros, sigfigs)
    if type(coin) == "number" then
        coin = coin_tiers.from_base_value(coin)
    end
    return lib.get_str_from_coin(coin, show_leading_zeros, sigfigs)
end

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

function coin_tiers.get_scale_of_tier(tier)
    return 100000 ^ (tier - 1)
end

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

function coin_tiers.shift_tier(coin, shift)
    if shift == 0 then return coin_tiers.copy(coin) end
    local new_coin = coin_tiers.new()
    if shift > 0 then
        for i = 2, new_coin.max_coin_tier do
            new_coin.values[i] = coin.values[i - 1]
        end
        new_coin.values[#new_coin.values] = new_coin.values[#new_coin.values] + coin.values[#coin.values] * coin.tier_scaling
        return coin_tiers.shift_tier(new_coin, shift - 1)
    else
        for i = 1, new_coin.max_coin_tier - 1 do
            new_coin.values[i] = coin.values[i + 1]
        end
        return coin_tiers.shift_tier(new_coin, shift + 1)
    end
end



return coin_tiers
