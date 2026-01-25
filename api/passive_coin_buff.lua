
local coin_tiers = require "api.coin_tiers"
local inventories = require "api.inventories"
local quests      = require "api.quests"
local piggy_bank  = require "api.piggy_bank"

local passive_coin_buff = {}



function passive_coin_buff.process_accumulation()
    local rate = storage.item_buffs.passive_coins_rate
    if rate <= 0 then return end

    local pcb = storage.passive_coin_buff
    if not pcb then
        pcb = {}
        storage.passive_coin_buff = pcb
    end

    local ticks_since_last_processing = game.tick - (pcb.last_processing or game.tick)
    pcb.last_processing = game.tick

    local coin = passive_coin_buff.calculate_passive_gain(ticks_since_last_processing)
    if coin_tiers.is_negative(coin) or coin_tiers.is_zero(coin) then return end

    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    for _, player in pairs(game.players) do
        if is_piggy_bank_unlocked then
            -- This is to be done without normalizing the entire inventory, to avoid annoying situations where the coins you're about to grab suddenly transfer themselves into your piggy bank.
            piggy_bank.increment_player_stored_coins(player.index, coin)
        else
            -- This would normalize the entire inventory if piggy bank was unlocked (impossible with this flow control).
            local inv = player.get_main_inventory()
            if inv then
                inventories.add_coin_to_inventory(inv, coin)
            end
        end
    end
end

---Get the current passive income of coins from the buff.
---@param tick_interval int Number of ticks between coin accumulation.
---@return Coin
function passive_coin_buff.calculate_passive_gain(tick_interval)
    local progressive_calculations = passive_coin_buff.get_passive_gain_calculation_steps(tick_interval)
    return coin_tiers.from_base_value(math.floor(0.5 + (progressive_calculations[#progressive_calculations] or 0)))
end

---Get the progressively calculated values during the passive coin calculation.
---@param tick_interval int
---@return number[]
function passive_coin_buff.get_passive_gain_calculation_steps(tick_interval)
    local rate = storage.item_buffs.passive_coins_rate
    if tick_interval <= 0 or rate <= 0 then return {} end

    local pcb = storage.passive_coin_buff
    if not pcb then
        pcb = {}
        storage.passive_coin_buff = pcb
    end

    local progressive_calculations = {}

    local total_hex_coins = 0
    for _, surface in pairs(game.surfaces) do
        if storage.item_values.values[surface.name] then
            local prod_stats = game.forces.player.get_item_production_statistics(surface)
            local produced = prod_stats.get_flow_count {name = "hex-coin", category = "input", precision_index = defines.flow_precision_index.one_hour}
            local consumed = prod_stats.get_flow_count {name = "hex-coin", category = "output", precision_index = defines.flow_precision_index.one_hour}
            total_hex_coins = total_hex_coins + produced - consumed
        end
    end
    if total_hex_coins < 0 then
        total_hex_coins = 0
    end
    table.insert(progressive_calculations, total_hex_coins)

    local second_interval = tick_interval / 60
    total_hex_coins = total_hex_coins * second_interval / 3600 -- get_flow_count() returns values measured in per-minute
    table.insert(progressive_calculations, total_hex_coins)

    total_hex_coins = total_hex_coins * rate
    table.insert(progressive_calculations, total_hex_coins)

    return progressive_calculations
end



return passive_coin_buff
