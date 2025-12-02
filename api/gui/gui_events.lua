
local lib = require "api.lib"

local gui_events = {}

local callbacks = {}



---Get the callbacks subscribed to the given event name and player index for the given gui element index.
---@param player_index int
---@param event_name string
---@param gui_elem_index int
---@param create boolean If true, create an empty record of callbacks first for the gui_elem_index if it doesn't exist.
---@return function[]|nil
function gui_events._get_callbacks(player_index, event_name, gui_elem_index, create)
    local player_callbacks = callbacks[player_index]
    if not player_callbacks then
        player_callbacks = {}
        callbacks[player_index] = player_callbacks
    end

    local event_callbacks = player_callbacks[event_name]
    if not event_callbacks then
        event_callbacks = {}
        player_callbacks[event_name] = event_callbacks
    end

    local gui_elem_callbacks = event_callbacks[gui_elem_index]
    if create and not gui_elem_callbacks then
        gui_elem_callbacks = {}
        event_callbacks[gui_elem_index] = gui_elem_callbacks
    end

    return gui_elem_callbacks
end

---Subscribe a callback function to an event for a GUI element.
---@param gui_elem LuaGuiElement
---@param event_name GuiEventName
---@param callback function
function gui_events.register(gui_elem, event_name, callback)
    if not gui_elem.valid then return end

    local player = game.get_player(gui_elem.player_index)
    if not player then
        lib.log_error("gui_events.register: Failed to register event for gui element " .. gui_elem.name .. ": player not found")
        return
    end

    local c = gui_events._get_callbacks(
        player.index,
        event_name,
        gui_elem.index,
        true
    ) --[=[@as function[]]=]

    table.insert(c, callback)
end

---Execute all callback functions subscribed to an event for a GUI element.
---@param player LuaPlayer|nil
---@param gui_elem LuaGuiElement
---@param event_name GuiEventName
function gui_events.trigger(player, gui_elem, event_name)
    if not player then
        lib.log_error("gui_events.trigger: Player not found for event " .. event_name)
        return
    end

    if not gui_elem.valid then return end

    local c = gui_events._get_callbacks(
        player.index,
        event_name,
        gui_elem.index,
        false
    )

    if not c then return end

    local params
    if event_name == "on-dropdown-selected" or event_name == "on-list-item-selected" then
        local index = gui_elem.selected_index
        local value
        if index ~= 0 then
            value = gui_elem.get_item(gui_elem.selected_index)
        end
        params = {value}
    else
        params = {}
    end

    local args = table.unpack(params)
    for _, callback in pairs(c) do
        callback(args)
    end
end



return gui_events
