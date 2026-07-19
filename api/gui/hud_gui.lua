
local event_system = require "api.event_system"

local hud_gui = {}



function hud_gui.register_events()
    event_system.register("player-display-scale-changed", hud_gui.reinitialize)
    event_system.register("player-display-resolution-changed", hud_gui.reinitialize)
end

---@param player LuaPlayer|nil
function hud_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.players) do
            hud_gui.reinitialize(p)
        end
        return
    end

    local hud = player.gui.center["hextorio-hud"]
    if hud then
        hud.destroy()
    end

    hud = player.gui.center.add {
        type = "flow",
        name = "hextorio-hud",
        direction = "vertical",
        ignored_by_interaction = true,
    }

    local resolution = player.display_resolution
    hud.style.vertically_stretchable = true
    hud.style.height = resolution.height * 0.98 / player.display_scale
    hud.style.vertically_squashable = true

    event_system.trigger("hud-reinitialized", player)
end

---@param player LuaPlayer
---@return LuaGuiElement
function hud_gui.get_hud_gui(player)
    local hud = player.gui.center["hextorio-hud"]

    if not hud then
        hud_gui.reinitialize(player)
        hud = player.gui.center["hextorio-hud"]
    end

    return hud
end



return hud_gui
