
local piggy_bank = require "api.piggy_bank"
local event_system = require "api.event_system"
local coin_tier_gui= require "api.gui.coin_tier_gui"
local inventories  = require "api.inventories"
local lib          = require "api.lib"
local coin_tiers   = require "api.coin_tiers"
local quests       = require "api.quests"

local piggy_bank_gui = {}



function piggy_bank_gui.register_events()
    event_system.register_gui("gui-clicked", "piggy-bank-withdraw", piggy_bank_gui.on_piggy_bank_coin_clicked)
    event_system.register_gui("gui-clicked", "piggy-bank-deposit", piggy_bank_gui.on_piggy_bank_deposit_button_clicked)

    event_system.register("player-piggy-bank-changed", piggy_bank_gui.on_player_piggy_bank_changed)
    event_system.register("quest-reward-received", piggy_bank_gui.on_quest_reward_received)
end

---@param player LuaPlayer
function piggy_bank_gui.reinitialize(player)
    piggy_bank_gui.init(player)
end

---@param player LuaPlayer
function piggy_bank_gui.init(player)
    local frame = piggy_bank_gui.get_piggy_bank_elem(player)
    if frame then
        frame.destroy()
    end

    local anchor = {
        gui = defines.relative_gui_type.controller_gui,
        position = defines.relative_gui_position.top,
    }

    frame = player.gui.relative.add {
        type = "frame",
        name = "piggy-bank",
        anchor = anchor,
        direction = "horizontal",
    }

    local deposit = frame.add {
        type = "sprite-button",
        name = "deposit",
        sprite = "virtual-signal/signal-input",
        tags = {handlers = {["gui-clicked"] = "piggy-bank-deposit"}},
    }

    local stored_coins_flow = coin_tier_gui.create_coin_tier(frame, "stored")

    for _, elem in pairs(stored_coins_flow.children) do
        elem.tags = {handlers = {["gui-clicked"] = "piggy-bank-withdraw"}}
    end

    piggy_bank_gui.update_piggy_bank(player)
end

---@param player LuaPlayer
---@return boolean
function piggy_bank_gui.is_initialized(player)
    return piggy_bank_gui.get_piggy_bank_elem(player) ~= nil
end

---@param player LuaPlayer
---@return LuaGuiElement|nil
function piggy_bank_gui.get_piggy_bank_elem(player)
    return player.gui.relative["piggy-bank"]
end

---@param player LuaPlayer
---@return LuaGuiElement
function piggy_bank_gui.get_or_create_piggy_bank_elem(player)
    local frame = player.gui.relative["piggy-bank"]
    if frame then
        return frame
    end
    piggy_bank_gui.init(player)
    return player.gui.relative["piggy-bank"]
end

---@param player LuaPlayer
function piggy_bank_gui.update_piggy_bank(player)
    local frame = piggy_bank_gui.get_or_create_piggy_bank_elem(player)

    if not quests.is_feature_unlocked "piggy-bank" then
        frame.visible = false
        return
    end

    frame.visible = true
    local stored_coins_flow = frame["stored"]

    local player_id = player.index
    local stored_coins = piggy_bank.get_player_stored_coins(player_id)
    coin_tier_gui.update_coin_tier(stored_coins_flow, stored_coins, true)
end

---@param player LuaPlayer
function piggy_bank_gui.on_player_piggy_bank_changed(player)
    piggy_bank_gui.update_piggy_bank(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function piggy_bank_gui.on_piggy_bank_coin_clicked(player, elem)
    local inv = player.get_main_inventory()
    if not inv then return end

    local player_id = player.index
    local stored_coin = piggy_bank.get_player_stored_coins(player_id)

    local clicked_tier = elem.name
    local withdraw_tier = stored_coin.values[lib.get_tier_of_coin_name(clicked_tier)]
    local to_add = coin_tiers.from_coin_values_by_name({
        [clicked_tier] = -withdraw_tier,
    })

    -- inventories.skip_auto_normalization(inv)
    inventories.remove_coin_from_inventory(inv, to_add, nil, false)
    piggy_bank.increment_player_stored_coins(player_id, to_add)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function piggy_bank_gui.on_piggy_bank_deposit_button_clicked(player, elem)
    local inv = player.get_main_inventory()
    if not inv then return end

    local player_id = player.index
    local coins_in_inv = inventories.get_coin_from_inventory(inv)

    piggy_bank.increment_player_stored_coins(player_id, coins_in_inv)
    inventories.remove_coin_from_inventory(inv, coins_in_inv, nil, false)
end

---@param reward_type QuestRewardType
---@param value any
function piggy_bank_gui.on_quest_reward_received(reward_type, value)
    if reward_type == "unlock-feature" then
        if value == "piggy-bank" then
            for _, player in pairs(game.players) do
                piggy_bank_gui.update_piggy_bank(player)
            end
        end
    end
end



return piggy_bank_gui
