-- Generate hex sets which represent a single, connected island.

local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"

local hex_island = {}



---@class IslandConfig
---@field radius int The radius of the hexagonal island in hex tiles
---@field fill_ratio number The proportion of hexes within the radius that should be land (0.0 to 1.0)
---@field algorithm string The island generation algorithm to use
---@field seed int|nil Optional random seed for reproducible island generation
---@field start_pos HexPos|nil Optional starting hex position for island generation



local island_generators = {}

for _, generator_name in pairs {
    "standard",
    "maze",
    "spiral",
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



---Calculate the maximum distance from origin to any hex in the island.
---@param island HexSet
---@return int
local function calculate_max_distance(island)
    local max_distance = 0
    for _, hex_pos in pairs(hex_sets.to_array(island)) do
        local distance = axial.distance(hex_pos, {q = 0, r = 0})
        if distance > max_distance then
            max_distance = distance
        end
    end
    return max_distance
end



function hex_island.register_events()
    event_system.register("surface-created", hex_island.process_surface_creation)
end

function hex_island.process_surface_creation(surface)
    if not storage.hex_island then
        storage.hex_island = {}
    end
    if not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local planet_size = lib.startup_setting_value("planet-size-" .. surface.name)

    if not planet_size then
        lib.log_error("hex_island.init: Could not find planet size setting value for " .. surface.name)
        return
    end

    ---@cast planet_size int
    local generator_name = lib.runtime_setting_value_as_string "world-generation-mode"
    local maze_algorithm = lib.runtime_setting_value_as_string "maze-generation-algorithm"
    local params

    if generator_name == "standard" then
        local mgs = storage.hex_grid.mgs[surface.name]
        if not mgs then
            lib.log_error("hex_island.init: No map gen settings found for surface " .. surface.name)
        end

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

        params = {
            radius = planet_size,
            fill_ratio = land_chance,
        }
    elseif generator_name == "maze" then
        params = {
            radius = planet_size,
            algorithm = maze_algorithm,
        }
    elseif generator_name == "spiral" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "triangular" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "ribbon" then
        params = {
            radius = planet_size,
            width = 5,
        }
    elseif generator_name == "ribbon-maze" then
        params = {
            radius = planet_size,
            width = 7,
            algorithm = maze_algorithm,
        }
    elseif generator_name == "spider-web" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "lattice" then
        params = {
            radius = planet_size,
            spacing = 2,
        }
    elseif generator_name == "solid" then
        params = {
            radius = planet_size,
        }
    elseif generator_name == "donut" then
        params = {
            radius = planet_size,
            width = 5,
        }
    elseif generator_name == "clusters" then
        params = {
            radius = planet_size,
            cluster_size = 5,
            spacing = 15,
        }
    end

    local island = hex_island.generate_island(generator_name, params)
    storage.hex_island.islands[surface.name] = island

    if not storage.hex_island.max_distances then
        storage.hex_island.max_distances = {}
    end

    storage.hex_island.max_distances[surface.name] = calculate_max_distance(island)
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
    return hex_sets.to_array(hex_island.get_island_hex_set(surface_name))
end

---Get the HexSet of all land hexes on the surface.
---@param surface_name string
---@return HexSet
function hex_island.get_island_hex_set(surface_name)
    if not storage.hex_island then
        storage.hex_island = {islands = {}}
    elseif not storage.hex_island.islands then
        storage.hex_island.islands = {}
    end

    local island = storage.hex_island.islands[surface_name]
    if not island then
        lib.log_error("hex_island.get_island_hex_set: Could not find island structure for surface " .. surface_name)
        return {}
    end

    return island
end

---Get the maximum distance from spawn to any land hex on the surface.
---@param surface_name string
---@return int
function hex_island.get_island_extent(surface_name)
    local hex_island_storage = storage.hex_island

    if not hex_island_storage.max_distances then
        hex_island_storage.max_distances = {}
    end

    local max_distance = hex_island_storage.max_distances[surface_name]
    if not max_distance then
        local island = hex_island_storage.islands[surface_name]
        if not island then
            lib.log_error("hex_island.get_island_extent: Could not find island for surface " .. surface_name)
            return 0
        end

        max_distance = calculate_max_distance(island)
        hex_island_storage.max_distances[surface_name] = max_distance
    end

    return max_distance
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

    lib.log("hex_island.generate_island: Generating island with generator = " .. generator_name .. ", params = " .. serpent.line(params))

    return gen(params)
end



return hex_island
