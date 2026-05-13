
local lib = require "api.lib"

local blueprints = {}



function blueprints.init()
    for string_name, string_def in pairs(storage.blueprints.strings) do
        local stack = blueprints.load_string(string_name, string_def.string)
        if stack then
            blueprints.save_item_stack(string_name, stack)
        else
            lib.log_error("blueprints.init: Failed to load blueprint string for " .. string_name)
        end
    end
end

---@param stack LuaItemStack
---@param surface SurfaceIdentification
---@param position MapPosition
---@param force ForceID|nil
---@return LuaEntity[]
function blueprints.build(stack, surface, position, force)
    local ghosts = stack.build_blueprint {
        surface = surface,
        position = position,
        build_mode = defines.build_mode.forced,
        force = force or "player",
    }
    return ghosts
    -- for _, e in pairs(ghosts) do
    --     e.revive()
    -- end
end

---Build a blueprint from its indexed name.
---@param string_name string
---@param surface SurfaceIdentification
---@param position MapPosition
---@param force ForceID|nil
---@return LuaEntity[]|nil
function blueprints.build_from_name(string_name, surface, position, force)
    local stack = blueprints.get_item_stack(string_name)
    if not stack then
        lib.log_error("blueprints.build_from_name: Failed to get item stack for " .. string_name)
        return
    end

    return blueprints.build(stack, surface, position, force)
end

---@param string_name string The name under which the result of the import gets stored.
---@param bp_string string
---@return LuaItemStack|nil
function blueprints.load_string(string_name, bp_string)
    local temp_inventory = game.create_inventory(1)
    local stack = temp_inventory.find_empty_stack()
    if not stack then
        temp_inventory.destroy()
        return
    end

    local result = stack.import_stack(bp_string)
    if result == 0 and stack.is_blueprint_setup() then
        blueprints.save_item_stack(string_name, stack)
        return stack
    end
    temp_inventory.destroy()
end

---@param string_name string
---@return LuaItemStack|nil
function blueprints.get_item_stack(string_name)
    if not storage.blueprints.item_stacks[string_name] then
        lib.log_error("blueprints.get_item_stack: Could not find item stack for \"" .. string_name .. "\"")
        return
    end
    return storage.blueprints.item_stacks[string_name]
end

---@param string_name string
---@param stack LuaItemStack
function blueprints.save_item_stack(string_name, stack)
    storage.blueprints.item_stacks[string_name] = stack
end



return blueprints
