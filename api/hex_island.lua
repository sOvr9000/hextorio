-- Generate hex sets which represent a single, connected island.

local lib = require "api.lib"
local axial = require "api.axial"
local hex_sets = require "api.hex_sets"
local event_system = require "api.event_system"
local hex_maze = require "api.hex_maze"

local hex_island = {}



---@class IslandConfig
---@field radius int The radius of the hexagonal island in hex tiles
---@field fill_ratio number The proportion of hexes within the radius that should be land (0.0 to 1.0)
---@field algorithm string The island generation algorithm to use
---@field seed int|nil Optional random seed for reproducible island generation
---@field start_pos HexPos|nil Optional starting hex position for island generation



local island_generators = {
    ["standard"] = function(params)
        local radius = params.radius or 30
        local fill_ratio = params.fill_ratio or 0.866

        -- Initialize hex set.
        local set = hex_sets.new()
        local current_size = 0
        local max_size = 3 * radius * (radius + 1) + 1
        local target_size = math.ceil(max_size * fill_ratio)

        -- Initialize the open set.
        local open_list = {}
        local open_set = hex_sets.new()

        -- Guarantee some nonland tiles
        local blacklist = hex_sets.new()

        for i = 1, 5 do
            local ring = axial.ring({q=0, r=0}, i)
            local idx = math.random(1, #ring)
            local pos = ring[idx]
            if i > 1 and (pos.q == -pos.r or pos.q ~= 0 and pos.r == 0 or pos.r ~= 0 and pos.q == 0) then
                -- The randomly selected hex on the ring is on a line going out to a vertex of the giant hex island
                if math.random() < 0.5 then
                    idx = idx + 1
                else
                    idx = idx - 1
                end
                pos = ring[1 + (idx - 1) % #ring]
            end
            hex_sets.add(blacklist, pos)
        end

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
                        if not hex_sets.contains(set, adj) and not hex_sets.contains(open_set, adj) and not hex_sets.contains(blacklist, adj) then
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
            for _, pos in pairs {
                {q = i, r = 0},
                {q = i, r = -i},
                {q = 0, r = i},
            } do
                if not hex_sets.contains(blacklist, pos) then
                    add_hex(pos)
                end
            end
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
    end,

    ["maze"] = function(params)
        local radius = params.radius or 30

        local dilation_factor = 2
        local div_radius = math.ceil(radius / dilation_factor)

        local allowed_positions = hex_sets.new()
        hex_sets.add(allowed_positions, {q=0, r=0})

        for r = 1, div_radius do
            for _, pos in pairs(axial.ring({q=0, r=0}, r)) do
                hex_sets.add(allowed_positions, pos)
            end
        end

        local maze = hex_maze.new(allowed_positions)
        hex_maze.generate(maze)

        local island = hex_maze.dilated(maze, dilation_factor)
        return island
    end,

    ["spiral"] = function(params)
        local radius = params.radius or 30

        local island = hex_sets.new()

        local pos = {q = 0, r = 0}
        hex_sets.add(island, pos)

        local dir = math.random(1, 6)
        local done = false
        for i = 1, 999 do
            if done then break end
            for j = 1, 3 do
                dir = 1 + dir % 6
                local offset = axial.get_adjacency_offset(dir)
                for n = 1, i do
                    pos = axial.add(pos, offset)
                    if axial.distance(pos, {q=0, r=0}) > radius then
                        done = true
                        break
                    end
                    hex_sets.add(island, pos)
                end
                if done then break end
            end
        end

        return island
    end,
}



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
        }
    elseif generator_name == "spiral" then
        params = {
            radius = planet_size,
        }
    end

    local island = hex_island.generate_island(generator_name, params)
    storage.hex_island.islands[surface.name] = island
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
