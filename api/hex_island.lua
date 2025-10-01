-- Generate hex sets which represent a single, connected island.

local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"

local hex_island = {}



function hex_island.register_events()
    event_system.register_callback("surface-created", hex_island.process_surface_creation)
end

function hex_island.process_surface_creation(surface)
    if not storage.hex_island then
        storage.hex_island = {}
    end
    if not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local planet_size = lib.startup_setting_value("planet-size-" .. surface.name)

    if planet_size then
        planet_size = planet_size --[[@as int]]

        local mgs = storage.hex_grid.mgs[surface.name]
        if mgs then
            local land_chance
            if surface.name == "nauvis" then
                if mgs.autoplace_controls.water.size == 0 then
                    land_chance = 0
                else
                    land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.water.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.water.size)) * 0.5
                end
            elseif surface.name == "vulcanus" then
                land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.vulcanus_volcanism.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.vulcanus_volcanism.size)) * 0.5
            elseif surface.name == "fulgora" then
                land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.fulgora_islands.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.fulgora_islands.size)) * 0.5
            elseif surface.name == "gleba" then
                land_chance = (lib.remap_map_gen_setting(1 / mgs.autoplace_controls.gleba_water.frequency) + lib.remap_map_gen_setting(mgs.autoplace_controls.gleba_water.size)) * 0.5
            elseif surface.name == "aquilo" then
                land_chance = 0.60
            end
            if surface.name ~= "fulgora" and surface.name ~= "aquilo" then
                land_chance = (1 - land_chance * land_chance) ^ 0.5 -- basically turning a triangle into a circle
            end

            local fill_ratio = land_chance
            lib.log("hex_island.process_surface_creation: Generating island for " .. surface.name .. ", radius = " .. planet_size .. ", fill ratio = " .. fill_ratio)

            local island = hex_island.generate_island(planet_size, fill_ratio)
            storage.hex_island.islands[surface.name] = island
        else
            lib.log_error("hex_island.init: No map gen settings found for surface " .. surface.name)
        end
    else
        lib.log_error("hex_island.init: Could not find planet size setting value for " .. surface.name)
    end
end

---Initialize islands for each planet.
function hex_island.init()
    hex_island.process_surface_creation(game.surfaces.nauvis)
end

---Return whether the given hex at a position should be land.
---@param surface_name string
---@param hex_pos HexPos
---@return boolean
function hex_island.is_land_hex(surface_name, hex_pos)
    if not storage.hex_island then
        storage.hex_island = {islands = {}}
    elseif not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local island = storage.hex_island.islands[surface_name]
    if not island then
        lib.log_error("hex_island.is_land_hex: Could not find island structure for surface " .. surface_name)
        return false
    end

    return hex_sets.contains(island, hex_pos)
end

---Get a list of all land hexes on the surface.
---@param surface_name string
---@return HexPos[]
function hex_island.get_land_hex_list(surface_name)
    if not storage.hex_island then
        storage.hex_island = {islands = {}}
    elseif not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local island = storage.hex_island.islands[surface_name]
    if not island then
        lib.log_error("hex_island.is_land_hex: Could not find island structure for surface " .. surface_name)
        return {}
    end

    return hex_sets.to_array(island)
end

---Generate a hexagonal island.
---@param radius int
---@param fill_ratio number
---@return HexSet
function hex_island.generate_island(radius, fill_ratio)
    log("generating island")

    -- Initialize hex set.
    local set = hex_sets.new()
    local current_size = 0
    local max_size = 3 * radius * (radius + 1) + 1
    local target_size = math.ceil(max_size * fill_ratio)

    -- Initialize the open set.
    local open_list = {}
    local open_set = hex_sets.new()

    -- Misc parameters
    -- local radius_inv = 1 / radius

    -- Helper function for managing the open set, island construction, and stopping condition.
    local function add_hex(pos)
        if hex_sets.add(set, pos) then
            current_size = current_size + 1

            local adj_list = axial.get_adjacent_hexes(pos)
            for i, adj in ipairs(adj_list) do
                local dist = axial.distance(adj, {q=0, r=0})
                if dist <= radius then
                    if not hex_sets.contains(set, adj) and not hex_sets.contains(open_set, adj) then
                        hex_sets.add(open_set, adj)
                        table.insert(open_list, adj)
                    end
                end
            end
        end
        return current_size >= target_size
    end

    -- Draw lines along the three diameters.
    for i = -radius, radius do
        add_hex {q = i, r = 0}
        add_hex {q = i, r = -i}
        add_hex {q = 0, r = i}
    end

    -- Randomly sample from the open set.
    for i = 1, target_size do
        if not next(open_list) then break end

        local idx = math.random(1, #open_list)

        -- -- Construct weights for sampling
        -- local weights = {}
        -- local total_weight = 0
        -- for j, pos in ipairs(open_list) do
        --     local weight = 1
        --     for _, adj in pairs(axial.get_adjacent_hexes(pos)) do
        --         if hex_sets.contains(set, adj) then
        --             weight = weight * 0.1
        --         end
        --     end
        --     weights[j] = weight
        --     total_weight = total_weight + weight
        -- end

        -- -- Non-uniform sample such that more distant hexes are more likely to be sampled.
        -- local r = math.random() * total_weight
        -- local cur_w = 0
        -- local idx = 0
        -- for j, w in ipairs(weights) do
        --     cur_w = cur_w + w
        --     if cur_w >= r then
        --         idx = j
        --         break
        --     end
        -- end

        local pos = table.remove(open_list, idx)
        hex_sets.remove(open_set, pos)

        if add_hex(pos) then break end
    end

    log("finished island generation")

    return set
end



return hex_island
