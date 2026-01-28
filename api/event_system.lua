
local lib = require "api.lib"

local event_system = {}

local funcs = {}



---Register an event handler
---@param name string
---@param callback function
function event_system.register(name, callback)
    funcs[name] = (funcs[name] or {})
    table.insert(funcs[name], callback)
end

---Register an event handler for a GUI element
---@param name GuiEventName
---@param callback fun(player: LuaPlayer, elem: LuaGuiElement)
function event_system.register_gui(name, tag, callback)
    funcs[name] = (funcs[name] or {})
    funcs[name][tag] = (funcs[name][tag] or {})
    table.insert(funcs[name][tag], callback)
end

---Trigger an event
---@param name string
---@param ... any
function event_system.trigger(name, ...)
    for _, callback in pairs(funcs[name] or {}) do
        callback(...)
    end
end

---Trigger an event for a GUI element
---@param name GuiEventName
---@param tag string
---@param player LuaPlayer
---@param elem LuaGuiElement
function event_system.trigger_gui(name, tag, player, elem)
    for _, callback in pairs((funcs[name] or {})[tag] or {}) do
        callback(player, elem)
    end
end

function event_system.bind_gui_events()
    script.on_event(defines.events.on_gui_hover, function(event)
        if not storage.gui then
            storage.gui = {}
        end

        if not storage.gui.hovered_element then
            storage.gui.hovered_element = {}
        end

        storage.gui.hovered_element[event.player_index] = event.element
    end)

    script.on_event(defines.events.on_gui_leave, function(event)
        if not storage.gui then
            storage.gui = {}
        end

        if storage.gui.hovered_element then
            storage.gui.hovered_element[event.player_index] = nil
        else
            storage.gui.hovered_element = {}
        end
    end)

    script.on_event(defines.events.on_gui_opened, function (event)
        local player = game.get_player(event.player_index)
        if not player then return end

        if event.element and event.element.valid then
            local tag = (event.element.tags.handlers or {})["gui-opened"]
            if tag and type(tag) == "string" then
                event_system.trigger_gui("gui-opened", tag, player, event.element)
            end
        elseif event.entity and event.entity.valid then
            event_system.trigger("player-opened-entity", player, event.entity)
        end
    end)

    script.on_event(defines.events.on_gui_closed, function (event)
        local player = game.get_player(event.player_index)
        if not player then return end

        if event.element and event.element.valid then
            local tag = (event.element.tags.handlers or {})["gui-closed"]
            if tag and type(tag) == "string" then
                event_system.trigger_gui("gui-closed", tag, player, event.element)
            end
        elseif event.entity and event.entity.valid then
            event_system.trigger("player-closed-entity", player, event.entity)
        end
    end)

    ---@param handler_type GuiEventName
    local function create_handler(handler_type)
        return function(event)
            local player = game.get_player(event.player_index)
            if not player then return end

            local tag = (event.element.tags.handlers or {})[handler_type]
            if not tag or type(tag) ~= "string" then return end

            event_system.trigger_gui(handler_type, tag, player, event.element)
        end
    end

    script.on_event(defines.events.on_gui_confirmed, create_handler "gui-confirmed")
    script.on_event(defines.events.on_gui_click, create_handler "gui-clicked")
    script.on_event(defines.events.on_gui_elem_changed, create_handler "gui-elem-changed")
    script.on_event(defines.events.on_gui_value_changed, create_handler "gui-slider-changed")
    script.on_event(defines.events.on_gui_selection_state_changed, create_handler "gui-selection-changed")
    script.on_event(defines.events.on_gui_switch_state_changed, create_handler "gui-switch-changed")
end



return event_system
