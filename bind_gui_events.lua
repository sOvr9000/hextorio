
local gui_events = require "api.gui.gui_events"
local event_system = require "api.event_system"
local gui_stack    = require "api.gui.gui_stack"

script.on_event(defines.events.on_gui_opened, function (event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.entity then
        event_system.trigger("player-opened-entity", player, event.entity)
    end
end)

script.on_event(defines.events.on_gui_closed, function (event)
    local player = game.get_player(event.player_index)
    -- log("closed: " .. tostring(event.element))
    if event.element then
        -- log(event.element.name)
        if player then
            gui_stack.handle_gui_closed(player, event.element)
        end
        gui_events.trigger(player, event.element, "on-closed")
    elseif event.entity then
        -- log("CLOSED GUI IS FROM ENTITY:")
        -- log(event.entity.name)
        event_system.trigger("player-closed-entity", player, event.entity)
    end
end)

script.on_event(defines.events.on_gui_confirmed, function (event)
    local player = game.get_player(event.player_index)
    -- log("confirmed: " .. tostring(event.element))
    -- if event.element then
    --     log(event.element.name)
    -- end
    gui_events.trigger(player, event.element, "on-closed") -- FOR NOW, handle "confirming" as closing.  No frames in Hextorio currently act as confirmation UI.
end)

script.on_event(defines.events.on_gui_click, function (event)
    local player = game.get_player(event.player_index)
    -- log("clicked: " .. tostring(event.element))
    -- if event.element then
    --     log(event.element.name)
    -- end
    gui_events.trigger(player, event.element, "on-clicked")
end)

script.on_event(defines.events.on_gui_elem_changed, function (event)
    local player = game.get_player(event.player_index)
    gui_events.trigger(player, event.element, "on-elem-selected")
end)

script.on_event(defines.events.on_gui_value_changed, function (event)
    local player = game.get_player(event.player_index)
    gui_events.trigger(player, event.element, "on-slider-changed")
end)

script.on_event(defines.events.on_gui_selection_state_changed, function (event)
    local player = game.get_player(event.player_index)
    gui_events.trigger(player, event.element, "on-selection-changed")
end)

script.on_event(defines.events.on_gui_switch_state_changed, function (event)
    local player = game.get_player(event.player_index)
    gui_events.trigger(player, event.element, "on-switch-changed")
end)
