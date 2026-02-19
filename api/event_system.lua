
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

    ---@param elem LuaGuiElement
    ---@param parent_idx int
    ---@return LuaGuiElement|nil
    local function get_parent_elem(elem, parent_idx)
        if parent_idx <= 0 then return elem end

        local cur = elem
        for i = 1, parent_idx do
            if not cur.parent or not cur.parent.valid or cur.parent.object_name ~= "LuaGuiElement" then
                break
            end

            cur = cur.parent
        end

        return cur
    end

    ---@param handler_type GuiEventName
    local function create_handler(handler_type)
        return function(event)
            local player = game.get_player(event.player_index)
            if not player then return end

            -- Note: This "linked handler" functionality is primarily used by back and forward buttons delegating their "gui-click" handlers to the "gui-back" and "gui-forward" handlers from one of their parents.
            -- If linked_handler_parent_idx is 0 or nil, nothing gets delegated.
            local linked_handler_parent_idx = event.element.tags.linked_handler_parent_idx or 0
            local linked_elem = get_parent_elem(event.element, linked_handler_parent_idx)
            if not linked_elem then return end

            local linked_handler_type = handler_type
            if linked_elem ~= event.element then
                linked_handler_type = (event.element.tags.handlers or {})[handler_type]
                if not linked_handler_type or type(linked_handler_type) ~= "string" then return end
            end

            local tag = (linked_elem.tags.handlers or {})[linked_handler_type]
            if not tag or type(tag) ~= "string" then return end

            event_system.trigger_gui(linked_handler_type, tag, player, linked_elem)
        end
    end

    script.on_event(defines.events.on_gui_confirmed, create_handler "gui-confirmed")
    script.on_event(defines.events.on_gui_click, create_handler "gui-clicked")
    script.on_event(defines.events.on_gui_elem_changed, create_handler "gui-elem-changed")
    script.on_event(defines.events.on_gui_value_changed, create_handler "gui-slider-changed")
    script.on_event(defines.events.on_gui_selection_state_changed, create_handler "gui-selection-changed")
    script.on_event(defines.events.on_gui_switch_state_changed, create_handler "gui-switch-changed")



    ---@param player LuaPlayer
    local function on_control_gui_back(player)
        local frame = player.opened
        if not frame or not frame.valid or frame.object_name ~= "LuaGuiElement" or frame.get_mod() ~= "hextorio" then return end

        local tag = (frame.tags.handlers or {})["gui-back"]
        if not tag or type(tag) ~= "string" then return end

        event_system.trigger_gui("gui-back", tag, player, frame)
    end

    ---@param player LuaPlayer
    local function on_control_gui_forward(player)
        local frame = player.opened
        if not frame or not frame.valid or frame.object_name ~= "LuaGuiElement" or frame.get_mod() ~= "hextorio" then return end

        local tag = (frame.tags.handlers or {})["gui-forward"]
        if not tag or type(tag) ~= "string" then return end

        event_system.trigger_gui("gui-forward", tag, player, frame)
    end

    -- These only take effect on player.opened (root frames, no nested frames)
    event_system.register("control-gui-back", on_control_gui_back)
    event_system.register("control-gui-forward", on_control_gui_forward)
end



return event_system
