
local lib                 = require "api.lib"
local quests              = require "api.quests"
local coin_tiers          = require "api.coin_tiers"
local piggy_bank          = require "api.piggy_bank"
local inventories         = require "api.inventories"
local event_system        = require "api.event_system"
local gameplay_statistics = require "api.gameplay_statistics"

local strongboxes = {}



function strongboxes.register_events()
    event_system.register("runtime-setting-changed-strongbox-spawn-chance", function()
        strongboxes.fetch_strongbox_settings()
    end)

    event_system.register("runtime-setting-changed-strongbox-loot-scale", function()
        strongboxes.fetch_strongbox_settings()
    end)

    event_system.register("gameplay-statistic-changed", function(stat_type, stat_value, prev, new_value)
        if stat_type ~= "net-coin-production" then return end
        strongboxes.dish_out_rewards_retro(new_value - prev)
    end)
end

function strongboxes.init()
    strongboxes.fetch_strongbox_settings()

    if not storage.strongboxes.total_coins_earned then
        storage.strongboxes.total_coins_earned = coin_tiers.new()
    end
end

function strongboxes.fetch_strongbox_settings()
    storage.strongboxes.spawn_chance = lib.runtime_setting_value_as_number "strongbox-spawn-chance"
    storage.strongboxes.loot_scale = lib.runtime_setting_value_as_number "strongbox-loot-scale"
end

---Attempt to spawn a strongbox at a given pos.
---@param surface LuaSurface
---@param pos MapPosition
---@return LuaEntity|nil
function strongboxes.try_spawn(surface, pos)
    if math.random() > storage.strongboxes.spawn_chance then return end
    return strongboxes.spawn(surface, pos, 1)
end

---Forcibly spawn a strongbox at a given pos.
---@param surface LuaSurface
---@param pos MapPosition
---@param tier int
---@return LuaEntity|nil
function strongboxes.spawn(surface, pos, tier)
    local sb_entity = surface.create_entity {
        name = "strongbox-tier-" .. tier,
        position = pos,
        force = "enemy",
    }

    if not sb_entity then
        lib.log_error("strongboxes.spawn: Failed to spawn strongbox")
        return
    end

    strongboxes.insert_loot(sb_entity)

    return sb_entity
end

---Calculate coin reward based on the given net coin production statistic.
---@param net_coins int
---@return int
function strongboxes.get_coin_reward_from_net_coin_production(net_coins)
    -- Base number of minutes of net coin production to use
    local minutes = 5

    local scaled_net_coins = minutes * net_coins -- net coin production is measured in per-minute

    -- Scaling factors from mod setting and item buffs
    local mod_setting = storage.strongboxes.loot_scale
    local item_buff_effect = storage.item_buffs.strongbox_loot

    return math.ceil(0.5 + scaled_net_coins * mod_setting * item_buff_effect)
end

---Get the Coin object to be placed in a strongbox.
---@return Coin
function strongboxes.get_loot()
    local net_coins = gameplay_statistics.get "net-coin-production"
    if net_coins <= 0 then return coin_tiers.new() end
    local coin_reward = strongboxes.get_coin_reward_from_net_coin_production(net_coins)
    return coin_tiers.from_base_value(coin_reward)
end

---Insert loot into a strongbox, clearing whatever it had before.
---@param sb_entity LuaEntity
function strongboxes.insert_loot(sb_entity)
    local inv = sb_entity.get_inventory(defines.inventory.chest)
    if not inv then return end
    inv.clear()

    local coin_loot = strongboxes.get_loot()
    inventories.add_coin_to_inventory(inv, coin_loot)
end

---Give all players the coins that would've been received from strongboxes had they been destroyed while having a higher net coin production statistic.
---@param net_coins_diff int The difference (improvement) from the old net coin production to the new net coin production.
function strongboxes.dish_out_rewards_retro(net_coins_diff)
    if net_coins_diff <= 0 then return end

    log("net: " .. net_coins_diff)

    local total_defeated = gameplay_statistics.get "total-strongbox-level"
    local coin_diff = total_defeated * strongboxes.get_coin_reward_from_net_coin_production(net_coins_diff)
    local coin_to_insert = coin_tiers.from_base_value(coin_diff)

    log("to insert: " .. coin_diff)

    -- TODO: This is repeated code from hex_grid.on_strongbox_killed().  Put this coin insertion logic in one place and reuse it.
    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    for _, player in pairs(game.players) do
        if is_piggy_bank_unlocked then
            -- This is to be done without normalizing the entire inventory, to avoid annoying situations where the coins you're about to grab suddenly transfer themselves into your piggy bank.
            piggy_bank.increment_player_stored_coins(player.index, coin_to_insert)
        else
            -- This would normalize the entire inventory if piggy bank was unlocked (impossible with this flow control).
            local player_inv = lib.get_player_inventory(player)
            if player_inv then
                inventories.add_coin_to_inventory(player_inv, coin_to_insert)
            end
        end
    end

    storage.strongboxes.total_coins_earned = coin_tiers.add(storage.strongboxes.total_coins_earned or coin_tiers.new(), coin_to_insert)
end



return strongboxes
