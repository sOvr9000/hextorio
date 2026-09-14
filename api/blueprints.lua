
local lib = require "api.lib"
local hex_lattice = require "api.util.hex_lattice"

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

---Line a blueprint's grid up with a hex grid, so that the blueprint lands the same way in every hex it is placed in.
---@param blueprint LuaItemStack|LuaRecord
---@param axial_scale number
---@param axial_rotation number
---@return TilePosition|nil snap_to_grid The grid that the blueprint was snapped to, or nil if the hex grid is rotated off of the tile grid.
function blueprints.apply_hex_snapping(blueprint, axial_scale, axial_rotation)
    local snapping = hex_lattice.get_blueprint_snapping(axial_scale, axial_rotation)
    if not snapping then return end

    blueprint.blueprint_snap_to_grid = snapping.snap_to_grid
    blueprint.blueprint_absolute_snapping = true
    blueprint.blueprint_position_relative_to_grid = snapping.position_relative_to_grid

    blueprints._normalize_entity_positions_to_grid_size(blueprint)

    return snapping.snap_to_grid
end

---Translate all entity positions such that their center of mass is closest to the origin.
---@param blueprint LuaItemStack|LuaRecord
function blueprints._normalize_entity_positions_to_grid_size(blueprint)
    local sum_x = 0
    local sum_y = 0

    -- TODO: find center of mass of entities in `blueprint`, then overwrite entity data to the same entities but with translated positions such that the center of mass is as close to the origin as possible.
    -- avoid this bug: https://forums.factorio.com/viewtopic.php?t=133849
    -- (ensure that this works okay with rail entities and other non-1x1-snapping entities)
end



return blueprints
