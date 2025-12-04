
local lib = require "api.lib"

local gui_stack = {}



---Clear the opened stack of GUIs for a player.
---@param player LuaPlayer
function gui_stack.clear(player)
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.stack then
        storage.gui.stack = {}
    end
    if not storage.gui.stack[player.index] then
        storage.gui.stack[player.index] = {}
    end
    while next(storage.gui.stack[player.index]) do
        gui_stack.pop(player)
    end
end

---Get the opened stack of GUIs that a player has.
---@param player LuaPlayer
---@return LuaGuiElement[]
function gui_stack.get_stack(player)
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.stack then
        storage.gui.stack = {}
    end
    if not storage.gui.stack[player.index] then
        storage.gui.stack[player.index] = {}
    end
    return storage.gui.stack[player.index]
end

---Add a GUI element to a player's opened stack.  If the element already exists in the stack, bring it to the front.
---@param player LuaPlayer
---@param element LuaGuiElement
function gui_stack.add(player, element)
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.stack then
        storage.gui.stack = {}
    end
    if not storage.gui.stack[player.index] then
        storage.gui.stack[player.index] = {}
    end

    local stack = storage.gui.stack[player.index]
    local index = gui_stack.index_of(player, element)

    if index >= 1 then
        table.remove(stack, index)
    end
    table.insert(stack, element)

    -- log("added " .. element.name .. " to stack for " .. player.name)
    -- log("current opened stack:")
    -- for _, e in pairs(stack) do
    --     log(e.name)
    -- end

    element.visible = true
    player.opened = element
end

---Pop and return the last element off of the opened stack for a player, or the element at the given index.
---@param player LuaPlayer
---@param index int|nil
---@return LuaGuiElement|nil
function gui_stack.pop(player, index)
    local stack = gui_stack.get_stack(player)
    if not next(stack) then return end

    if not index then index = #stack end
    if index <= 0 or index > #stack then return end

    local elem = stack[index]
    table.remove(stack, index)

    if next(stack) then
        if player.opened == elem then
            player.opened = stack[index]
        else
            player.opened = stack[#stack]
        end
    else
        player.opened = nil
    end

    elem.visible = false

    -- log("removed " .. elem.name .. " to stack for " .. player.name)
    -- log("current opened stack:")
    -- for _, e in pairs(stack) do
    --     log(e.name)
    -- end

    return elem
end

---Return whether the given element is in a player's opened stack.
---@param player LuaPlayer
---@param element LuaGuiElement
---@return boolean
function gui_stack.contains(player, element)
    return gui_stack.index_of(player, element) >= 1
end

---Get the index of an element in a player's opened stack.  Return -1 if not found (conventional).
---@param player LuaPlayer
---@param element LuaGuiElement
---@return int
function gui_stack.index_of(player, element)
    for i, elem in ipairs(gui_stack.get_stack(player)) do
        if elem == element then
            return i
        end
    end
    return -1
end

---Handle the player closing the given GUI element.
---@param player LuaPlayer
---@param element LuaGuiElement
function gui_stack.handle_gui_closed(player, element)
    -- if gui_stack.contains(player, element) then
    --     gui_stack.pop(player, gui_stack.index_of(player, element))
    -- end
end



return gui_stack
