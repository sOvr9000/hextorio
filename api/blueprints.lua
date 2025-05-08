
local lib = require "api.lib"

local blueprints = {}



function blueprints.init()
    for _, bp_string in pairs(storage.blueprints.strings) do
        blueprints.save_item_stack(blueprints.load_string(bp_string))
    end
end

---@param stack LuaItemStack
---@param surface SurfaceIdentification
---@param position MapPosition
---@param force ForceID|nil
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

function blueprints.get_item_stack(blueprint_name)
    if not storage.blueprints.item_stacks[blueprint_name] then
        lib.log_error("blueprints.get_item_stack: Could not find item stack by blueprint name \"" .. blueprint_name .. "\"")
        return
    end
    return storage.blueprints.item_stacks[blueprint_name]
end

-- /c local stack = game.player.selected.get_inventory(1).find_empty_stack(); stack.import_stack("0eNqdluFugyAQx1+luc/aCIqtJtuLNM2iLVlILBrEZqbx3Xfq2m1WK+AnPbwff7g7uBvkRcMrJaSG9AbiVMoa0sMNavEps6K36bbikMJVKN2gxQOZXXrD+IdPoPNAyDP/gpR0noUn++NJu6MHXGqhBR8FDB/th2wuOVeIfnjrRuWlr1Um66pU2s95oZFdlTU6l7KfGIE+2TIPWnyhW9b1uiZAagkMVnihrcA1YGQJXFsws+TRFV7sHBEyD9w5A4N54H4CrKtCaI0jz8F9KSwx5pCXekhgDHpkR4A1chaKn8ZBQue4xJhLXy6UUNcQ9Cv+J3Q/hw9d8cQIH5nH+8412V3mWtlmqmPHunza8nn1O8djZCmH945yl1IucdRHjJZPLUpuLF5qEjRKXHMinOKjObzr5WRGDy2Pi6UbNHJMhXCBxxxTYeBh/yA0v6Dzb0fjQZGhK9oOP02IP/Yeb/fm5bjZ+Pi8bxZ+YEeEXLmqh1lZTJMoSVjMAsKCqOu+AZxeDqQ="); stack.build_blueprint{surface=game.player.surface, force="player", position={-10,0}, build_mode=defines.build_mode.forced}

---@param bp_string string
---@return LuaItemStack|nil
function blueprints.load_string(bp_string)
    local temp_inventory = game.create_inventory(1)
    local stack = temp_inventory.find_empty_stack()
    if not stack then
        temp_inventory.destroy()
        return
    end

    local result = stack.import_stack(bp_string)
    if result == 0 and stack.is_blueprint_setup() then
        blueprints.save_item_stack(stack)
        return stack
    end
    temp_inventory.destroy()
end

function blueprints.save_item_stack(stack)
    if not stack then
        lib.log_error("blueprints.save_item_stack: item stack is nil")
        return
    end
    local bp_name = stack.label
    if not bp_name then
        lib.log_error("blueprints.save_item_stack: Tried to save a blueprint with no label")
        return
    end
    storage.blueprints.item_stacks[bp_name] = stack
end



return blueprints
