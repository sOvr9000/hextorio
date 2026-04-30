
local event_system = require "api.event_system"
local quests = require "api.quests"

local tray_gui = {}



---@class TrayButtonDefinition
---@field name string
---@field sprite string
---@field handler string
---@field tooltip LocalisedString
---@field feature FeatureName|nil



---@type TrayButtonDefinition[]
local BUTTON_DEFS = {
    {
        name = "questbook-button",
        sprite = "questbook-black",
        handler = "questbook-button",
        tooltip = {"hextorio-gui.questbook-button-tooltip"},
        feature = nil,
    },
    {
        name = "catalog-button",
        sprite = "catalog-black",
        handler = "catalog-button",
        tooltip = {"hextorio-gui.catalog-button-tooltip"},
        feature = "catalog",
    },
    {
        name = "trade-overview-button",
        sprite = "trade-overview-black",
        handler = "trade-overview-button",
        tooltip = {"hextorio-gui.trade-overview-button-tooltip"},
        feature = "trade-overview",
    },
    {
        name = "hex-rank-button",
        sprite = "hex-rank-button-black",
        handler = "hex-rank-button",
        tooltip = {"hextorio-gui.frame-toggle-button-tooltip"},
        feature = "hex-rank",
    },
}



function tray_gui.register_events()
    event_system.register("quest-reward-received", function(reward_type, value)
        if reward_type ~= "unlock-feature" then return end
        for _, player in pairs(game.players) do
            tray_gui.update_button_states(player)
        end
    end)
end

---Reinitialize the button tray for the given player, or all players if no player is provided.
---@param player LuaPlayer|nil
function tray_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.players) do
            tray_gui.reinitialize(p)
        end
        return
    end

    local tray = player.gui.top["hextorio-tray"]
    if tray then tray.destroy() end

    tray_gui.init_tray(player)
end

---Initialize the button tray in the top GUI for the given player.
---@param player LuaPlayer
function tray_gui.init_tray(player)
    if player.gui.top["hextorio-tray"] then return end

    local tray = player.gui.top.add {
        type = "frame",
        name = "hextorio-tray",
        direction = "horizontal",
    }

    for i, def in pairs(BUTTON_DEFS) do
        local btn = tray.add {
            type = "sprite-button",
            name = def.name,
            sprite = def.sprite,
            style = "shortcut_bar_button",
        }
        btn.tags = {handlers = {["gui-clicked"] = def.handler}}

        if i > 1 then
            btn.style.left_margin = 2
        end

        tray_gui._update_button_state(btn, def)
    end
end

---Update the enabled state and tooltip of a button based on current feature unlock status.
---@param player LuaPlayer
function tray_gui.update_button_states(player)
    local tray = player.gui.top["hextorio-tray"]
    if not tray then return end

    for _, def in ipairs(BUTTON_DEFS) do
        local btn = tray[def.name]
        if btn then
            tray_gui._update_button_state(btn, def)
        end
    end
end

---Update the enabled state and tooltip of a button based on current feature unlock status.
---@param elem LuaGuiElement
---@param def TrayButtonDefinition
function tray_gui._update_button_state(elem, def)
    if def.feature == nil or quests.is_feature_unlocked(def.feature) then
        elem.enabled = true
        elem.tooltip = def.tooltip
    else
        elem.enabled = false
        elem.tooltip = {"hextorio-gui.tray-button-locked-tooltip"}
    end
end



return tray_gui
