
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

    blueprints._normalize_entity_and_tile_positions_to_grid_size(blueprint)

    return snapping.snap_to_grid
end

---Translate all entity and tile positions such that their center of mass is closest to the origin, preserving relative positions to the tiling grid.
---CAUTION: This translation can irreversibly corrupt blueprint data under narrow conditions in Factorio 2.1.17: https://forums.factorio.com/viewtopic.php?t=133849
---@param blueprint LuaItemStack|LuaRecord
function blueprints._normalize_entity_and_tile_positions_to_grid_size(blueprint)
    local grid_size = blueprint.blueprint_snap_to_grid
    if not grid_size then return end

    local sum_x = 0
    local sum_y = 0
    local total_positions = 0

    local entities = blueprint.get_blueprint_entities()
    if entities then
        for _, e in pairs(entities) do
            sum_x = sum_x + e.position.x
            sum_y = sum_y + e.position.y
        end
        total_positions = total_positions + #entities
    end

    local tiles = blueprint.get_blueprint_tiles()
    if tiles then
        for _, t in pairs(tiles) do
            sum_x = sum_x + t.position.x
            sum_y = sum_y + t.position.y
        end
        total_positions = total_positions + #tiles
    end

    if total_positions == 0 then
        -- This should never happen because Factorio prevents creating a completely empty blueprint.  But it's here just in case.
        lib.log_error("blueprints._normalize_entity_and_tile_positions_to_grid_size: Cannot normalize positions in blueprint with no tiles or entities.")
        return
    end

    local total_positions_inv = 1 / total_positions
    local center_of_mass = {
        x = sum_x * total_positions_inv,
        y = sum_y * total_positions_inv,
    }

    -- Quantize to grid size.
    local translation_x = math.floor(0.5 + center_of_mass.x / grid_size.x) * grid_size.x
    local translation_y = math.floor(0.5 + center_of_mass.y / grid_size.y) * grid_size.y

    if entities then
        for _, e in pairs(entities) do
            e.position = {
                x = e.position.x - translation_x,
                y = e.position.y - translation_y,
            }
        end
        blueprint.set_blueprint_entities(entities)
    end

    if tiles then
        for _, t in pairs(tiles) do
            t.position = {
                x = t.position.x - translation_x,
                y = t.position.y - translation_y,
            }
        end
        blueprint.set_blueprint_tiles(tiles)
    end
end



return blueprints
