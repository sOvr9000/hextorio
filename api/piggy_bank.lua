
local coin_tiers = require "api.coin_tiers"
local event_system = require "api.event_system"

local piggy_bank = {}



---@class PlayerPiggyBank
---@field stored Coin



function piggy_bank.init()
    storage.piggy_bank = {
        player_banks = {}, ---@type {[int]: PlayerPiggyBank}
    }
end

---Get the Coin object representing the amount of coins stored in a player's piggy bank.
---@param player_id int
---@return Coin
function piggy_bank.get_player_stored_coins(player_id)
    local bank = storage.piggy_bank.player_banks[player_id]
    if not bank then
        return coin_tiers.new()
    end
    return bank.stored
end

---Set the Coin object representing the amount of coins stored in a player's piggy bank.
---@param player_id int
---@param new_coin Coin
function piggy_bank.set_player_stored_coins(player_id, new_coin)
    local bank = storage.piggy_bank.player_banks[player_id]

    if not bank then
        bank = {stored = new_coin} ---@type PlayerPiggyBank
        storage.piggy_bank.player_banks[player_id] = bank

        if not coin_tiers.is_zero(new_coin) then
            local player = game.get_player(player_id)
            if player then
                event_system.trigger("player-piggy-bank-changed", player)
            end
        end

        return
    end

    if coin_tiers.compare(bank.stored, new_coin) ~= 0 then
        bank.stored = new_coin

        local player = game.get_player(player_id)
        if player then
            event_system.trigger("player-piggy-bank-changed", player)
        end
    end
end

---Increment the Coin object representing the amount of coins stored in a player's piggy bank.
---@param player_id int
---@param coin Coin
function piggy_bank.increment_player_stored_coins(player_id, coin)
    piggy_bank.set_player_stored_coins(player_id, coin_tiers.add(piggy_bank.get_player_stored_coins(player_id), coin))
end



return piggy_bank
