-- Generate hex sets which represent a single, connected island.

local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"
local hex_util = require "api.util.hex"
local mgs_util = require "api.util.mgs"

local hex_island = {}



---@class IslandConfig
---@field total_hexes int Target number of hexes in the island
---@field fill_ratio number The proportion of hexes within the radius that should be land (0.0 to 1.0)
---@field algorithm string The island generation algorithm to use
---@field seed int|nil Optional random seed for reproducible island generation
---@field start_pos HexPos|nil Optional starting hex position for island generation

---@class HexIslandStorage
---@field islands {[string]: HexSet} Mapping of surface names to the set of hexes which form the island on that surface
---@field distances {[string]: IndexMap} Mapping of surface names to the BFS distance of each hex from the spawn hex on that surface
---@field extents {[string]: int} Mapping of surface names to the BFS distance of the farthest hex from the spawn hex on that surface



local island_generators = {}

for _, generator_name in pairs {
    "standard",
    "maze",
    "spiral",
    "double-spiral",
    "triple-spiral",
    "double-triple-spiral",
    "triangular",
    "ribbon",
    "ribbon-maze",
    "spider-web",
    "lattice",
    "solid",
    "donut",
    "clusters",
} do
    island_generators[generator_name] = require("island_generators." .. generator_name)
end



---Get the maximum distance in the distances array.
---@param distances IndexMap
---@return int
local function calculate_extent(distances)
    local max_distance = 0
    for _, Q in pairs(distances) do
        for _, distance in pairs(Q) do
            if distance > max_distance then
                max_distance = distance
            end
        end
    end
    return max_distance
end



function hex_island.register_events()
    event_system.register("surface-created", hex_island.process_surface_creation)
end

---@return HexIslandStorage
function hex_island._get_hex_island_storage()
    local hex_island_storage = storage.hex_island
    if not hex_island_storage then
        hex_island_storage = {}
        storage.hex_island = hex_island_storage
    end

    if not hex_island_storage.islands then
        hex_island_storage.islands = {}
    end

    if not hex_island_storage.distances then
        hex_island_storage.distances = {}
    end

    if not hex_island_storage.extents then
        hex_island_storage.extents = {}
    end

    return hex_island_storage
end

function hex_island.process_surface_creation(surface)
    local hex_island_storage = hex_island._get_hex_island_storage()

    local total_hexes = lib.runtime_setting_value_as_int("total-hexes-" .. surface.name)
    local generator_name = lib.runtime_setting_value_as_string("world-generation-mode-" .. surface.name)
    local maze_algorithm = lib.runtime_setting_value_as_string "maze-generation-algorithm"
    local params = {total_hexes = total_hexes}

    if generator_name == "standard" then
        local mgs = storage.hex_grid.mgs[surface.name]
        if not mgs then
            lib.log_error("hex_island.init: No map gen settings found for surface " .. surface.name)
            return
        end

        local surface_controls = {
            nauvis = "water",
            vulcanus = "vulcanus_volcanism",
            fulgora = "fulgora_islands",
            gleba = "gleba_water"
        }

        local land_chance = 0
        local control_key = surface_controls[surface.name]
        if control_key then
            local control = mgs.autoplace_controls[control_key]
            if control and control.size > 0 then
                land_chance = (mgs_util.remap_map_gen_setting(1 / control.frequency) + mgs_util.remap_map_gen_setting(control.size)) * 0.5
            end
        elseif surface.name == "aquilo" then
            land_chance = 0.60
        end

        if surface.name ~= "fulgora" and surface.name ~= "aquilo" then
            land_chance = (1 - land_chance * land_chance) ^ 0.5 -- basically turning a triangle into a circle
        end
        params.fill_ratio = land_chance

    elseif island_generators[generator_name] then
        local extra_params_by_generator = {
            maze = {algorithm = maze_algorithm},
            ribbon = {width = 5},
            ["ribbon-maze"] = {width = 7, algorithm = maze_algorithm},
            lattice = {spacing = 3},
            donut = {width = 5},
            clusters = {min_cluster_size = 2, max_cluster_size = 5}
        }

        local extras = extra_params_by_generator[generator_name]
        if extras then
            for k, v in pairs(extras) do
                params[k] = v
            end
        end
    end

    lib.log("hex_island.process_surface_creation: Generating island with generator = " .. generator_name .. ", params = " .. serpent.line(params))
    local island = hex_island.generate_island(generator_name, params)

    lib.log("hex_island.process_surface_creation: Centering island")
    island = hex_island.auto_center(island)

    hex_island_storage.islands[surface.name] = island

    lib.log("hex_island.process_surface_creation: Calculating distances")
    local distances = hex_util.calculate_distances({q=0, r=0}, island)
    hex_island_storage.distances[surface.name] = distances

    local extent = calculate_extent(distances)
    hex_island_storage.extents[surface.name] = extent

    local actual_hex_count = hex_sets.size(island)
    lib.log(string.format("hex_island.process_surface_creation: Generated %d hexes for %s (target: %d, extent: %d)", actual_hex_count, surface.name, total_hexes, extent))

    event_system.trigger("hex-island-generated", surface, island)
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
    local hex_island_storage = hex_island._get_hex_island_storage()

    local island = hex_island_storage.islands[surface_name]
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
    return hex_sets.to_array(hex_island.get_island_hex_set(surface_name))
end

---Get the HexSet of all land hexes on the surface.
---@param surface_name string
---@return HexSet
function hex_island.get_island_hex_set(surface_name)
    local hex_island_storage = hex_island._get_hex_island_storage()

    local island = hex_island_storage.islands[surface_name]
    if not island then
        lib.log_error("hex_island.get_island_hex_set: Could not find island structure for surface " .. surface_name)
        return {}
    end

    return island
end

---Get the array of distances from spawn to each hex in the surface's island.
---@param surface_name string
---@return IndexMap
function hex_island.get_island_distances(surface_name)
    local hex_island_storage = hex_island._get_hex_island_storage()

    local distances = hex_island_storage.distances[surface_name]
    if not distances then
        local island = hex_island_storage.islands[surface_name]
        if not island then
            lib.log_error("hex_island.get_island_extent: Could not find island for surface " .. surface_name)
            return {}
        end

        distances = hex_util.calculate_distances({q=0, r=0}, island)
        hex_island_storage.distances[surface_name] = distances
    end

    return distances
end

---Get the maximum distance from spawn to any land hex on the surface.
---@param surface_name string
---@return int
function hex_island.get_island_extent(surface_name)
    local hex_island_storage = hex_island._get_hex_island_storage()

    local extent = hex_island_storage.extents[surface_name]
    if not extent then
        local distances = hex_island.get_island_distances(surface_name)

        extent = calculate_extent(distances)
        hex_island_storage.extents[surface_name] = extent
    end

    return extent
end

---Get the distance from spawn to `position`.
---@param surface_name string
---@param position HexPos
---@return int|nil
function hex_island.get_distance_from_spawn(surface_name, position)
    local distances = hex_island.get_island_distances(surface_name)
    local Q = distances[position.q]
    if not Q then return end
    return Q[position.r]
end

---Auto-center an island by finding its deepest inland point and translating to origin.
---@param island HexSet
---@return HexSet
function hex_island.auto_center(island)
    if hex_sets.contains(island, {q = 0, r = 0}) then
        return island
    end

    local current_layer = table.deepcopy(island)
    local previous_layer = table.deepcopy(island)

    -- Erosion algorithm to find deep centers of bodies of land, works especially nice for Clusters world gen mode, but should extend well to other island generators if needed
    while true do
        local current_array = hex_sets.to_array(current_layer)
        if #current_array == 0 then
            break
        end

        previous_layer = current_layer
        local next_layer = hex_sets.new()

        for _, hex_pos in ipairs(current_array) do
            local all_neighbors_in_layer = true
            for _, neighbor in pairs(axial.get_adjacent_hexes(hex_pos)) do
                if not hex_sets.contains(current_layer, neighbor) then
                    all_neighbors_in_layer = false
                    break
                end
            end

            if all_neighbors_in_layer then
                hex_sets.add(next_layer, hex_pos)
            end
        end

        if #hex_sets.to_array(next_layer) == 0 then
            break
        end

        current_layer = next_layer
    end

    local deepest_hexes = hex_sets.to_array(previous_layer)
    local new_center

    if #deepest_hexes == 0 then
        local all_hexes = hex_sets.to_array(island)
        local sum_q, sum_r = 0, 0
        for _, pos in ipairs(all_hexes) do
            sum_q = sum_q + pos.q
            sum_r = sum_r + pos.r
        end
        new_center = {
            q = math.floor(sum_q / #all_hexes + 0.5),
            r = math.floor(sum_r / #all_hexes + 0.5)
        }
    else
        new_center = deepest_hexes[math.random(1, #deepest_hexes)]
    end

    local centered_island = hex_sets.new()
    for _, hex_pos in pairs(hex_sets.to_array(island)) do
        hex_sets.add(centered_island, {
            q = hex_pos.q - new_center.q,
            r = hex_pos.r - new_center.r
        })
    end

    return centered_island
end

---Generate a hexagonal island.
---@param generator_name string
---@param params table
---@return HexSet
function hex_island.generate_island(generator_name, params)
    local gen = island_generators[generator_name]
    if not gen then
        error("hex_island.generate_island: No generator found with name " .. generator_name)
    end

    return gen(params)
end



return hex_island
