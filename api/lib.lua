
local sets = require "api.sets"

local lib = {data = {}}



local non_land_tile_names = {
    "water",
    "deepwater",
    "oil-ocean-shallow",
    "oil-ocean-deep",
    "gleba-deep-lake",
    "ammoniacal-solution",
    "ammoniacal-solution-2",
    "lava",
    "lava-hot",
}
local non_land_tile_name_lookup = sets.new(non_land_tile_names)

local hazard_tile_name_lookup = sets.new {
    "hazard-concrete-left",
    "hazard-concrete-right",
    "refined-hazard-concrete-left",
    "refined-hazard-concrete-right",
}

local immune_to_hex_core_clearing = sets.new {
    "character",
    "spider-vehicle",
    "spider-leg",
    "car",
    "segment",
    "segmented-unit",
}

local non_buildable_on_tile_lookup = sets.union(non_land_tile_name_lookup, sets.new {
    "deepwater",
    "deepwater-green",
    "water",
    "water-green",
    "water-mud",
    "water-shallow",
    "water-wube",
    "lava",
    "lava-hot",
    "wetland-yumako",
    "wetland-jellynut",
    "wetland-dead-skin",
    "wetland-light-dead-skin",
    "wetland-green-slime",
    "wetland-light-green-slime",
    "wetland-red-tentacle",
    "wetland-pink-tentacle",
    "wetland-blue-slime",
    "gleba-deep-lake",
    "oil-ocean-shallow",
    "oil-ocean-deep",
    "ammoniacal-ocean",
    "ammoniacal-ocean-2",
    "brash-ice",
})

-- This can probably be auto-populated, but that may not work well with modded items.
local raw_items = sets.new {
    "iron-ore",
    "copper-ore",
    "stone",
    "coal",
    "uranium-ore",
    "wood",
    "raw-fish",
    "tungsten-ore",
    "calcite",
    "carbon", -- Just so that coal synthesis isn't needed to be unlocked from Gleba before trading on Vulcanus
    "scrap",
    "yumako",
    "jellynut",
    "carbonic-asteroid-chunk",
    "metallic-asteroid-chunk",
    "oxide-asteroid-chunk",
    "promethium-asteroid-chunk",

    "hex-coin",
    "gravity-coin",
    "meteor-coin",
    "hexaprism-coin",
}



function lib.position_to_string(x, y)
    if not y then
        y = x.y or x[2]
        x = x.x or x[1]
    end
    return "(" .. tostring(x) .. ", " .. tostring(y) .. ")"
end

function lib.vector_add(a, b)
    return {x=(a.x or a[1])+(b.x or b[1]), y=(a.y or a[2])+(b.y or b[2])}
end

function lib.vector_multiply(a, b)
    return {x=(a.x or a[1]) * b, y=(a.y or a[2]) * b}
end

---Get the square of the L2 (a.k.a. Euclidean) distance between two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function lib.square_distance(pos1, pos2)
    local dx = (pos1.x or pos1[1]) - (pos2.x or pos2[1])
    local dy = (pos1.y or pos1[2]) - (pos2.y or pos2[2])
    return dx * dx + dy * dy
end

---Get the L1 (a.k.a. Manhattan) distance between the two positions.
---@param pos1 MapPosition
---@param pos2 MapPosition
---@return number
function lib.manhattan_distance(pos1, pos2)
    local dx = (pos1.x or pos1[1]) - (pos2.x or pos2[1])
    local dy = (pos1.y or pos1[2]) - (pos2.y or pos2[2])
    return math.abs(dx) + math.abs(dy)
end

---@param surface LuaSurface|SurfaceIdentification|int|string
---@return int
function lib.get_surface_id(surface)
    if not surface then
        lib.log_error("get_surface_id: No surface provided")
        return -1
    end
    if type(surface) == "number" then
        return surface
    elseif type(surface) == "string" then
        local s = game.get_surface(surface)
        if not s then
            lib.log_error("get_surface_id: Surface not found for name: " .. surface)
            return -1
        end
        return s.index
    elseif type(surface) == "userdata" then
        surface = surface--[[@as LuaSurface]]
        return surface.index
    end
    lib.log_error("Invalid surface type")
    return -1
end

function lib.random_unit_vector(length)
    length = length or 1
    local angle = math.random() * 2 * math.pi
    return {x=length*math.cos(angle), y=length*math.sin(angle)}
end

---Linearly interpolate from `a` to `b` by the factor `t`.
---@param a number
---@param b number
---@param t number
---@return number
function lib.lerp(a, b, t)
    return a + (b - a) * t
end

---Round the position to integer coordinates, and optionally offset by 0.5.
---@param pos MapPosition
---@param offset_by_half boolean|nil
---@return MapPosition
function lib.rounded_position(pos, offset_by_half)
    if offset_by_half then
        return {x = math.floor(0.5 + (pos.x or pos[1])) + 0.5, y = math.floor(0.5 + (pos.y or pos[2])) + 0.5}
    end
    return {x = math.floor(0.5 + (pos.x or pos[1])), y = math.floor(0.5 + (pos.y or pos[2]))}
end

function lib.startup_setting_value(name)
    if not name then
        lib.log_error("Name not specified")
        return
    end
    local prefixedName = "hextorio-" .. name
    local v = settings.startup[prefixedName]
    if not v then
        lib.log_error("Startup setting " .. name .. " (" .. prefixedName .. ") not found")
        return
    end
    return v.value
end

function lib.runtime_setting_value(name)
    if not name then
        lib.log_error("Name not specified")
        return
    end
    local prefixedName = "hextorio-" .. name
    local v = settings.global[prefixedName]
    if not v then
        lib.log_error("Runtime setting " .. name .. " (" .. prefixedName .. ") not found")
        return
    end
    return v.value
end

function lib.player_setting_value(player, name)
    if not player then
        lib.log_error("Player not specified")
        return
    end
    if not name then
        lib.log_error("Name not specified")
        return
    end
    local s = settings.get_player_settings(player)
    if not s then
        lib.log_error("Player " .. player.name .. " has no settings. Is the player invalid?")
        return
    end
    local prefixedName = "hextorio-" .. name
    local v = s[prefixedName]
    if not v then
        lib.log_error("Player setting " .. name .. " (" .. prefixedName .. ") not found for player " .. player.name)
        return
    end
    return v.value
end

function lib.table_length(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

function lib.table_reversed(t)
    local reversed = {}
    for i = #t, 1, -1 do
        reversed[#t - i + 1] = t[i]
    end
    return reversed
end

-- Combine tables with integral indices, returning a new table.
function lib.table_extend(t1, t2)
    local t = {}
    for i = 1, #t1 do
        table.insert(t, table.deepcopy(t1[i]))
    end
    for i = 1, #t2 do
        table.insert(t, table.deepcopy(t2[i]))
    end
    return t
end

function lib.is_empty_table(t)
    for _ in pairs(t) do return false end
    return true
end

---Shuffle a table in-place.
---@param t any[]
function lib.table_shuffle(t)
    local n = #t
    if n <= 1 then return end

    -- Fisher-Yates algorithm
    for i = n, 2, -1 do
        local j = math.random(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

---Generate a list of integers from 1 to n (inclusive) in ascending order.
---@param n int
---@return int[]
function lib.array_range(n)
    local t = {}
    for i = 1, n do
        t[i] = i
    end
    return t
end

---Get the index of an element in a table, or nil if it does not exist.
---@param t table
---@param element any
---@return any
function lib.table_index(t, element)
    for k, v in pairs(t) do
        if v == element then
            return k
        end
    end
end

---Remove an element from a table if it exists.
---@param t table
---@param element any
function lib.table_remove_element(t, element)
    for k, v in pairs(t) do
        if v == element then
            t[k] = nil
            return
        end
    end
end

---Recursively applies a function to all non-table values in a table.
---@param root_table table
---@param func function Receives (key, value) as parameters
function lib.apply_to_table(root_table, func)
    for key, value in pairs(root_table) do
        if type(value) == "table" then
            -- Recursively process nested tables
            lib.apply_to_table(value, func)
        else
            -- Apply function to non-table values
            root_table[key] = func(key, value)
        end
    end
end

---Recursively applies a function to all non-table values in a table.
---@param root_table table
---@param func function Receives (current_path, key, value) as parameters
function lib.apply_to_table_with_path(root_table, func)
    lib._apply_to_table_with_path(root_table, func, {})
end

---Recursively applies a function to all non-table values in a table.
---@param root_table table
---@param func function Receives (current_path, key, value) as parameters
---@param current_path any[]
function lib._apply_to_table_with_path(root_table, func, current_path)
    for key, value in pairs(root_table) do
        local new_path = {}
        -- Copy current path and add new key
        for i = 1, #current_path do
            new_path[i] = current_path[i]
        end
        new_path[#new_path + 1] = key

        if type(value) == "table" then
            -- Recursively process nested tables
            lib._apply_to_table_with_path(value, func, new_path)
        else
            -- Apply function to non-table values with full path
            root_table[key] = func(new_path, key, value)
        end
    end
end

function lib.table_to_string(t, indent)
    -- courtesy ChatGPT

    indent = indent or 0  -- Keep track of indentation level
    local result = "{\n" -- Start the table representation

    for k, v in pairs(t) do
        local key
        if type(k) == "string" then
            key = string.format("[\"%s\"]", k)
        else
            key = string.format("[%s]", tostring(k))
        end

        local value
        if type(v) == "table" then
            value = lib.table_to_string(v, indent + 2) -- Recursive call for nested tables
        elseif type(v) == "string" then
            value = string.format("\"%s\"", v)
        else
            value = tostring(v)
        end

        result = result .. string.rep(" ", indent + 2) .. key .. " = " .. value .. ",\n"
    end

    result = result .. string.rep(" ", indent) .. "}"
    return result
end

function lib.color_localized_string(str, color, font)
    local rich_text
    if type(color) == "string" then
        if color:sub(1, 7) == "[color=" and color:sub(-1) == "]" then
            rich_text = color
        else
            rich_text = "[color=" .. color .. "]"
        end
    else
        rich_text = lib.color_to_rich_text(color)
    end
    if font then
        return {"", "[font=" .. font .. "]" .. rich_text, str, "[.color][.font]"}
    end
    return {"", rich_text, str, "[.color]"}
end

function lib.log_error(txt)
    lib.log(txt, true)
end

function lib.log(txt, error)
    local prefix = "HEXTORIO | "
    if error then
        prefix = prefix .. "ERROR: "
    end
    local s
    if type(txt) == "table" then
        s = prefix .. "\n" .. serpent.block(txt)
    else
        s = prefix .. tostring(txt)
    end
    -- if error then
    --     s = s .. "\n"
    -- end
    log(s)
end

-- Convert chunk position to rectangular coordinates
function lib.chunk_to_rect(chunk_pos)
    local top_left = {
        x = chunk_pos.x * 32,
        y = chunk_pos.y * 32
    }

    local bottom_right = {
        x = top_left.x + 31,
        y = top_left.y + 31
    }

    return top_left, bottom_right
end

function lib.get_chunk_pos_from_tile_position(pos)
    return {x = math.floor((pos.x or pos[1]) / 32), y = math.floor((pos.y or pos[2]) / 32)}
end

function lib.get_area_for_chunk_position(chunk_pos)
    return {
        left_top = {
            x = chunk_pos.x * 32,
            y = chunk_pos.y * 32,
        },
        right_bottom = {
            x = chunk_pos.x * 32 + 31,
            y = chunk_pos.y * 32 + 31,
        },
    }
end

function lib.is_position_in_rect(position, top_left, bottom_right)
    return position.x >= top_left.x and position.x <= bottom_right.x and position.y >= top_left.y and position.y <= bottom_right.y
end

function lib.unstuck_player(player)
    if not player then return end
    local surface = player.surface
    if not surface then return end
    local position = surface.find_non_colliding_position("character", player.position, 20, 0.5, false)
    if not position then return end
    player.teleport(position, surface)
end

---Teleport a player to a position on a surface.
---@param player LuaPlayer
---@param position MapPosition
---@param surface LuaSurface|nil Defaults to the current surface of the player's character.
---@param allow_vehicle boolean|nil Whether to instead teleport the vehicle that the player is driving if they are in one. Defaults to false.
function lib.teleport_player(player, position, surface, allow_vehicle)
    if not player.character then
        lib.log_error("lib.teleport_player: player has no character")
        return
    end

    if not surface then
        surface = player.character.surface
    end

    local entity_name = "character"
    if player.character.vehicle then
        if not allow_vehicle then
            return
        end
        if not player.character.vehicle.valid then
            lib.log_error("lib.teleport_player: Player vehicle entity is invalid.")
            return
        end
        local prot_type = player.character.vehicle.prototype.type
        if prot_type ~= "car" and prot_type ~= "spider-vehicle" then
            return
        end
        entity_name = player.character.vehicle.name
    end

    local non_colliding_position = surface.find_non_colliding_position(entity_name, position, 20, 0.5, false)
    if not non_colliding_position then
        lib.log_error("lib.teleport_player: Could not find a non-colliding position for the player's character or vehicle.")
        return
    end

    if player.character.vehicle then
        player.character.vehicle.teleport(non_colliding_position, surface)
        player.set_controller {
            type = defines.controllers.character,
            character = player.character,
        }
        player.set_driving(true)
    else
        player.teleport(non_colliding_position, surface)
    end
end

---Teleport a player to a position on a surface.  If the surface is different from the player's character's current one, then prevent teleportation if items exist in the player's inventory, or the main inventory of the player's current vehicle if they are in one.
---@param player LuaPlayer
---@param position MapPosition
---@param surface LuaSurface|nil Defaults to the current surface of the player's character.
---@param allow_vehicle boolean|nil Whether to instead teleport the vehicle that the player is driving if they are in one. Defaults to false.
---@return boolean succeeded Whether the teleportation succeeded, failing when the player is in locomotive or cargo wagon, or when items other than equipment are in any connected inventories.
function lib.teleport_player_cross_surface(player, position, surface, allow_vehicle)
    if not player.character then
        return false
    end

    if player.character.surface == surface then
        lib.teleport_player(player, position, surface, allow_vehicle)
        return true
    end

    for _, inv_type in pairs {
        defines.inventory.character_main,
        defines.inventory.character_trash,
        defines.inventory.character_ammo,
    } do
        local inv = player.character.get_inventory(inv_type)
        if inv and inv.valid and not inv.is_empty() then
            return false
        end
    end

    if player.character.vehicle and allow_vehicle then
        local prot_type = player.character.vehicle.prototype.type
        if prot_type ~= "car" and prot_type ~= "spider-vehicle" then
            return false
        end
        for _, inv_type in pairs {
            defines.inventory.spider_trash,
            defines.inventory.spider_trunk,
            defines.inventory.spider_ammo,
            defines.inventory.car_trash,
            defines.inventory.car_trunk,
            defines.inventory.car_ammo,
            defines.inventory.fuel,
        } do
            local inv = player.character.vehicle.get_inventory(inv_type)
            if inv and inv.valid and not inv.is_empty() then
                return false
            end
        end
    end

    lib.teleport_player(player, position, surface, allow_vehicle)

    return true
end

function lib.initial_player_spawn(player)
    if not player then return end
    player.teleport({0, 5}, game.surfaces.nauvis)
    lib.unstuck_player(player)
end

function lib.get_player_inventory(player)
    if not player then
        lib.log_error("get_player_inventory: player is nil")
        return
    end

    local inv = player.get_inventory(defines.inventory.character_main)
    if inv then return inv end

    if not player.character then
        lib.log_error("get_player_inventory: could not find player character")
        return
    end

    inv = player.character.get_main_inventory()
    if inv then return inv end

    lib.log_error("get_player_inventory: could not find inventory of player")
end

---Turn a map gen setting between 0.16667 and 6 into a number between 0 and 1, or to a specified range
---@param x number|nil
---@param to_min number | nil
---@param to_max number | nil
---@return number
function lib.remap_map_gen_setting(x, to_min, to_max)
    if not x then return ((to_min or 0) + (to_max or 1)) * 0.5 end
    local v = math.log(x, 6) * 0.5 + 0.5
    if to_min and to_max then
        return to_min + (to_max - to_min) * v
    end
    return v
end

function lib.disable_everything(t)
    for key, value in pairs(t) do
        if key == "size" and type(value) == "number" then
            t[key] = 0
        elseif type(value) == "table" then
            lib.disable_everything(value)
        end
    end
end

-- Check if a tile at a given position is land
function lib.is_land_tile(surface, tile_position)
    local tile = surface.get_tile(tile_position)
    if not tile or not tile.valid then return false end
    return not non_land_tile_name_lookup[tile.name]
end

---Return whether entities can generally be built on the tile at the given position.
---@param surface LuaSurface
---@param tile_position MapPosition
function lib.is_tile_buildable_on(surface, tile_position)
    local tile = surface.get_tile(tile_position.x or tile_position[1], tile_position.y or tile_position[2])
    if not tile or not tile.valid then return false end
    return not non_buildable_on_tile_lookup[tile.name]
end

function lib.is_hazard_tile(surface, tile_position)
    local tile = surface.get_tile(tile_position)
    if not tile or not tile.valid then return false end
    return hazard_tile_name_lookup[tile.name]
end

-- Convert the recipe data into the structure:
-- {name: name, ingredients: {ing1, ing2, ...}, products: {prod1, prod2, ...}, energy: energy, surfaces: surfaces}
-- where ing and prod tables are both of the form:
-- {name: name, amount: amount}
-- regardless of type being fluid or item. And surfaces is the table of surface names where the recipe is able to be used.
-- Product amounts are the average amount per batch if random (between some min and max and/or with some probability)
-- Product amounts are also increased if the recipe can only be made in a +50% prod kind of building.
function lib.normalize_recipe_structure(recipe)
    local r = {
        name = recipe.name,
        energy = recipe.energy,
        ingredients = {},
        products = {},
    }
    for _, ing in pairs(recipe.ingredients) do
        table.insert(r.ingredients, {name = ing.name, amount = ing.amount})
    end
    local mult = 1
    if recipe.category == "metallurgy" or recipe.category == "electromagnetics" or recipe.category == "organic" then
        mult = 1.5
    end
    for _, prod in pairs(recipe.products) do
        local min = prod.amount_min or prod.amount
        local max = prod.amount_max or prod.amount
        local mean = (min + max) * 0.5 * prod.probability
        table.insert(r.products, {name = prod.name, amount = mean * mult})
    end
    return r
end

-- Return a lookup table of all recipes with consistent structure
function lib.get_recipe_tree()
    local recipe_tree = {}
    for name, recipe in pairs(prototypes.recipe) do
        if recipe.category ~= "recycling" then
            recipe_tree[name] = lib.normalize_recipe_structure(recipe)
        end
    end
    return recipe_tree
end

-- Generate a graph of all recipes in the game from the recipe tree, adding useful information for advanced calculations
function lib.get_recipe_graph(recipe_tree)
    local recipe_graph = {
        made_from = {},
        used_in = {},
        recipes_by_name = {},
        item_edges = {},
        all_items = {},
    }

    local added_edges = {}
    for recipe_name, recipe in pairs(recipe_tree) do
        recipe_graph.recipes_by_name[recipe_name] = recipe
        for _, ing in pairs(recipe.ingredients) do
            local t = recipe_graph.used_in[ing.name]
            if not t then
                t = {}
                recipe_graph.used_in[ing.name] = t
            end
            table.insert(t, recipe.name)
            if not recipe_graph.all_items[ing.name] then
                recipe_graph.all_items[ing.name] = true
            end
        end
        for _, prod in pairs(recipe.products) do
            local t = recipe_graph.made_from[prod.name]
            if not t then
                t = {}
                recipe_graph.made_from[prod.name] = t
            end
            table.insert(t, recipe.name)
            if not recipe_graph.all_items[prod.name] then
                recipe_graph.all_items[prod.name] = true
            end
            for _, ing in pairs(recipe.ingredients) do
                local edge_key = ing.name .. "->" .. prod.name
                if not added_edges[edge_key] then
                    added_edges[edge_key] = true
                    table.insert(recipe_graph.item_edges, {ing.name, prod.name})
                end
            end
        end
    end

    recipe_graph.all_items = sets.to_array(recipe_graph.all_items)

    return recipe_graph
end

-- Return a table of all technologies in the game from the tech tree, adding useful information for advanced calculations
function lib.get_technology_graph()
    local tech_graph = {}
    -- Each tech is of the form:
    -- {name: name, unlocked_by: unlocked_by, unlocks: unlocks, effects: effects, required_planet: required_planet}

    for name, tech in pairs(prototypes.technology) do
        local t = {name = name, unlocks = {}, unlocked_by = {}, effects = {}, techs_by_item = {}}
        for successor_name, _ in pairs(tech.successors) do
            table.insert(t.unlocks, successor_name)
        end
        for prereq_name, _ in pairs(tech.prerequisites) do
            table.insert(t.unlocked_by, prereq_name)
        end
        for _, effect in pairs(tech.effects) do
            table.insert(t.effects, effect)
        end
        t.required_planet = nil -- will be calculated by DFS
        t.required_planet_depth = math.huge
        tech_graph[name] = t
    end

    -- Use DFS to find the latest planet discovery techs if they exist for each tech, labeling which tech comes from which planet
    local function dfs(tech_name, depth)
        -- each dfs call returns a planet name and depth of search
        local tech = tech_graph[tech_name]

        if not tech then
            lib.log_error("no tech found for " .. tech_name)
        end

        -- Check if this tech has the modifier type "unlock-space-location"
        for _, modifier in pairs(tech.effects) do
            if modifier.type == "unlock-space-location" then
                tech.required_planet = modifier.space_location
                tech.required_planet_depth = depth
                return modifier.space_location, depth
            end
        end

        local min_depth = math.huge
        local min_planet
        for _, name in pairs(tech.unlocked_by) do
            local planet, d = dfs(name, depth + 1)
            if d < min_depth then
                min_depth = d
                min_planet = planet
            end
        end

        if not min_planet then
            min_planet = "nauvis"
            min_depth = depth
        end
        if not tech.required_planet or min_depth < tech.required_planet_depth then
            tech.required_planet = min_planet
            tech.required_planet_depth = min_depth
        end
        return min_planet, min_depth
    end

    for name, tech in pairs(tech_graph) do
        dfs(name, 0)
        if tech.required_planet then
            lib.log("tech " .. name .. " requires planet " .. tech.required_planet .. " at depth " .. tech.required_planet_depth)
        else
            lib.log_error("no planet found for tech " .. name)
        end
    end

    -- For each recipe, list all techs which directly unlock it


    return tech_graph
end

-- Return a lookup table of angles for a pie chart from a weighted choice
function lib.get_pie_angles(wc)
    local angles = {}
    local total = wc["__total_weight"]
    local angle = 0
    for item, weight in pairs(wc) do
        angles[item] = angle
        angle = angle + weight / total * math.pi * 2
    end
    return angles
end

-- Given the lookup table of angles for a pie chart and an angle, return the corresponding item
function lib.get_item_in_pie_angles(angles, angle)
    if angle < 0 then
        lib.log_error("negative angle")
        return
    end
    local item
    local min_angle = math.huge
    for ref_item, ref_angle in pairs(angles) do
        local diff = angle - ref_angle
        if diff > 0 then
            min_angle = math.min(min_angle, diff)
            item = ref_item
        end
    end
    return item
end

function lib.tostring_sigfigs(number, sigfigs)
    -- Input validation
    if sigfigs <= 0 then
        error("Number of significant figures must be positive")
    end

    -- Handle edge case: zero
    if number == 0 then
        if sigfigs <= 1 then
            return "0"
        else
            return "0." .. string.rep("0", sigfigs - 1)
        end
    end

    -- Handle sign
    local sign = ""
    if number < 0 then
        sign = "-"
        number = -number  -- Work with absolute value
    end

    -- Convert to scientific notation: num = mantissa * 10^magnitude
    -- where 1 <= mantissa < 10
    local magnitude = math.floor(math.log(number, 10))
    local mantissa = number / (10 ^ magnitude)

    -- Round the mantissa to sig_figs - 1 decimal places
    local scaled_mantissa = mantissa * (10 ^ (sigfigs - 1))
    local rounded_mantissa = math.floor(scaled_mantissa + 0.5) / (10 ^ (sigfigs - 1))

    -- Check if rounding changed the magnitude (e.g., 9.95 -> 10.0)
    if rounded_mantissa >= 10 then
        magnitude = magnitude + 1
        rounded_mantissa = rounded_mantissa / 10
    end

    -- Format the result based on the magnitude
    local result

    if magnitude >= sigfigs - 1 then
        -- For large numbers, we need trailing zeros
        -- First, get the significant digits as an integer
        local digits = math.floor(rounded_mantissa * (10 ^ (sigfigs - 1)) + 0.5)
        -- Then add the trailing zeros
        result = tostring(digits) .. string.rep("0", magnitude - sigfigs + 1)
    else
        -- For smaller numbers or those with decimal places
        local decimal_places = sigfigs - 1 - magnitude
        local format_string = "%." .. decimal_places .. "f"
        result = string.format(format_string, rounded_mantissa * (10 ^ magnitude))
    end

    return sign .. result
end

-- Converts a number of ticks to a formatted time string with zero components omitted
function lib.ticks_to_string(ticks)
    local seconds = math.floor(ticks / 60)

    -- Calculate days
    local days = math.floor(seconds / 86400)  -- 86400 = seconds in a day (24*60*60)
    local remainder = seconds % 86400
    
    -- Calculate hours
    local hours = math.floor(remainder / 3600)  -- 3600 = seconds in an hour (60*60)
    remainder = remainder % 3600
    
    -- Calculate minutes
    local minutes = math.floor(remainder / 60)
    
    -- Calculate remaining seconds
    local secs = remainder % 60
    
    -- Build the formatted string, only including non-zero components
    local parts = {}
    if days > 0 then
        table.insert(parts, days .. "d")
    end
    if hours > 0 then
        table.insert(parts, hours .. "h")
    end
    if minutes > 0 then
        table.insert(parts, minutes .. "m")
    end
    if secs > 0 or #parts == 0 then  -- Always include seconds if it's the only component
        table.insert(parts, secs .. "s")
    end
    
    -- Join the parts with commas and spaces
    return table.concat(parts, " ")
end

---Get a string formatted for displaying star images of a rank.
---@param rank int
---@param left_half boolean|nil If provided, a bronze rank image can be halved.
---@return string
function lib.get_rank_img_str(rank, left_half)
    if rank == 1 then
        if left_half ~= nil then
            if left_half then
                return "[img=bronze-star-left-half][img=star-silhouette][img=star-silhouette]"
            end
            return "[img=bronze-star-right-half][img=star-silhouette][img=star-silhouette]"
        end
        return "[img=star-silhouette][img=star-silhouette][img=star-silhouette]"
    elseif rank == 2 then
        return "[img=bronze-star][img=star-silhouette][img=star-silhouette]"
    elseif rank == 3 then
        return "[img=silver-star][img=silver-star][img=star-silhouette]"
    elseif rank == 4 then
        return "[img=gold-star][img=gold-star][img=gold-star]"
    elseif rank == 5 then
        return "[img=red-star][img=red-star][img=red-star]"
    end
    return ""
end

function lib.get_trade_img_str(trade, is_interplanetary)
    local s = ""
    for _, item in pairs(trade.input_items) do
        s = s .. "[img=item." .. item.name .. "]"
    end
    if is_interplanetary then
        s = s .. "[img=interplanetary-trade-arrow]"
    else
        s = s .. "[img=trade-arrow]"
    end
    for i = 1, #trade.output_items do
        s = s .. "[img=item." .. trade.output_items[#trade.output_items + 1 - i].name .. "]"
    end
    return s
end

function lib.is_coin(item_name)
    if type(item_name) ~= "string" then
        lib.log_error("lib.is_coin: item_name is not a string, received type: " .. type(item_name))
        return false
    end
    return item_name:sub(-5) == "-coin"
end

function lib.is_fluid(item_name)
    return prototypes.fluid[item_name] ~= nil
end

function lib.is_item(item_name)
    return prototypes.item[item_name] ~= nil
end

function lib.is_catalog_item(item_name)
    return not lib.is_coin(item_name) and lib.is_item(item_name)
end

function lib.format_percentage(x, decimal_places, include_symbol, include_sign)
    if include_symbol == nil then include_symbol = true end
    local p = 10 ^ decimal_places
    s = tostring(math.floor(x * 100 * p + 0.5) / p)
    if include_symbol then
        s = s .. "%"
    end
    if include_sign and x >= 0 then
        s = "+" .. s
    end
    return s
end

function lib.get_gps_str_from_hex_core(hex_core)
    return "[gps=" .. hex_core.position.x .. "," .. hex_core.position.y .. "," .. hex_core.surface.name .. "]"
end

function lib.insert_endgame_armor(player)
    local inv = player.get_inventory(5)

    if not inv and player.character then
        inv = player.character.get_inventory(5)
    end

    if not inv then
        lib.log_error("lib.insert_endgame_armor: Could not find player's armor inventory")
        return
    end

    inv.clear()
    inv.clear() -- has to be done twice IF the player inventory is too full

    local q = lib.get_hextreme_or_next_highest_quality()

    player.insert{name = "construction-robot", quality=q, count = 340}
    player.insert{name="mech-armor", quality=q, count = 1}

    local mech_armor = inv[1].grid
    for _ = 1, 8 do
        mech_armor.put({name = "fusion-reactor-equipment", quality = q})
    end
    for _ = 1, 8 do
        mech_armor.put({name = "battery-mk3-equipment", quality = q})
    end
    for _ = 1, 4 do
        mech_armor.put({name = "personal-roboport-mk2-equipment", quality = q})
    end
    mech_armor.put({name = "night-vision-equipment"})
    for _ = 1, 4 do
        mech_armor.put({name = "discharge-defense-equipment", quality = q})
    end
    for _ = 1, 18 do
        mech_armor.put({name = "energy-shield-mk2-equipment", quality = q})
    end
    for _ = 1, 9 do
        mech_armor.put({name = "exoskeleton-equipment", quality = q})
    end
    for _ = 1, 12 do
        mech_armor.put({name = "toolbelt-equipment", quality = q})
    end
end

function lib.color_to_rich_text(color)
    return "[color=" .. (color.r or color[1]) .. "," .. (color.g or color[2]) .. "," .. (color.b or color[3]) .. "]"
end

function lib.filter_whitelist(list, func)
    -- These can be handled as sets also, but here's the non-sets version.
    local t = {}
    for _, v in pairs(list) do
        if func(v) then
            table.insert(t, v)
        end
    end
    return t
end

function lib.filter_blacklist(list, func)
    -- These can be handled as sets also, but here's the non-sets version.
    local t = {}
    for _, v in pairs(list) do
        if not func(v) then
            table.insert(t, v)
        end
    end
    return t
end

function lib.get_direction_name(d)
    if d == 1 then
        return "north"
    elseif d == 2 then
        return "east"
    elseif d == 3 then
        return "south"
    elseif d == 4 then
        return "west"
    end
    lib.log_error("Invalid direction: " .. d)
    return "north"
end

function lib.hsv_to_rgb(h, s, v)
    -- Normalize h to 0-1 range (in case it's outside that range)
    h = h - math.floor(h)

    -- If saturation is 0, the color is a shade of gray
    if s <= 0.0 then
        return v, v, v
    end

    -- Convert hue to 0-6 range
    h = h * 6.0
    local i = math.floor(h)
    local f = h - i  -- Fractional part

    -- Calculate RGB components
    local p = v * (1.0 - s)
    local q = v * (1.0 - s * f)
    local t = v * (1.0 - s * (1.0 - f))

    -- Return RGB based on the sector of the color wheel
    if i == 0 then
        return v, t, p
    elseif i == 1 then
        return q, v, p
    elseif i == 2 then
        return p, v, t
    elseif i == 3 then
        return p, q, v
    elseif i == 4 then
        return t, p, v
    else  -- i == 5
        return v, p, q
    end
end

---Try to insert a single item stack into the player's inventory.  If not all items can fit, the remaining items are put on the ground at their position.
---@param player LuaPlayer
---@param item_stack ItemStackIdentification
---@return boolean
function lib.safe_insert(player, item_stack)
    local inserted = player.insert(item_stack)
    if inserted >= item_stack.count then
        return true
    end

    if item_stack.quality then
        player.print {"hextorio.no-room-for-item", "[item=" .. item_stack.name .. ",quality=" .. item_stack.quality .. "]", inserted, item_stack.count}
    else
        player.print {"hextorio.no-room-for-item", "[item=" .. item_stack.name .. "]", inserted, item_stack.count}
    end

    player.surface.spill_item_stack{position=player.position, stack={name = item_stack.name, count = item_stack.count - inserted, quality = item_stack.quality}}

    return false
end

-- Check if two tables are equal.
-- NOTE: Unsafe for circularly referencing tables
function lib.tables_equal(tab1, tab2)
    -- If one or both arguments are not tables, compare them directly
    if type(tab1) ~= "table" or type(tab2) ~= "table" then
        return tab1 == tab2
    end

    -- Check if tables have the same number of keys
    local count1 = 0
    for _ in pairs(tab1) do
        count1 = count1 + 1
    end

    local count2 = 0
    for _ in pairs(tab2) do
        count2 = count2 + 1
    end

    if count1 ~= count2 then
        return false
    end

    -- Recursively check each key-value pair
    for k, v1 in pairs(tab1) do
        local v2 = tab2[k]
        -- If key doesn't exist in tab2 or values aren't equal (recursively)
        if v2 == nil or not lib.tables_equal(v1, v2) then
            return false
        end
    end

    -- All checks passed, tables are equal
    return true
end

---@param surface_name string
---@return boolean
function lib.is_space_platform(surface_name)
    return surface_name:sub(1, 9) == "platform-"
end

function lib.sum_mgs(mgs, target, keys)
    local sum = 0
    for _, key in pairs(keys) do
        if not mgs[key] then
            lib.log_error("lib.sum_mgs: key \"" .. key .. "\" not found in " .. serpent.line(mgs))
        elseif not mgs[key][target] then
            lib.log_error("lib.sum_mgs: target \"" .. target .. "\" not found in " .. serpent.line(mgs[key]))
        else
            sum = sum + lib.remap_map_gen_setting(mgs[key][target])
        end
    end
    return sum
end

---Flattened a 2D array of positions that are indexed by x and y coordinates.
---@param arr MapPositionSet
---@return MapPosition[]
function lib.flattened_position_array(arr)
    local flat = {}
    for x, Y in pairs(arr) do
        for y, _ in pairs(Y) do
            table.insert(flat, {x = x, y = y})
        end
    end
    return flat
end

---Convert a list of positions to a 2D array indexed by x and y coordinates.
---@param arr MapPosition[]
---@return MapPositionSet
function lib.indexed_position_array(arr)
    local set = {}
    for _, pos in pairs(arr) do
        if not set[pos.x] then
            set[pos.x] = {}
        end
        set[pos.x][pos.y] = true
    end
    return set
end

function lib.is_t2_planet(surface_name)
    return surface_name == "vulcanus" or surface_name == "fulgora" or surface_name == "gleba"
end

function lib.is_t3_planet(surface_name)
    return surface_name == "aquilo"
end

function lib.update_table(t_base, t_update)
    for k, v in pairs(t_update) do
        t_base[k] = v
    end
end

function lib.shallow_copy(t)
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

---@param items {[int]: table}
---@return string
function lib.tostring_trade_items(items)
    local s = "["
    for i, item in ipairs(items) do
        if i > 1 then
            s = s .. " + "
        end
        s = s .. item.name .. " x" .. item.count
    end
    return s .. "]"
end

---@param trade table
---@return string
function lib.tostring_trade(trade)
    local s = "[Trade (ID " .. trade.id .. ")"
    s = s .. " | [" .. lib.tostring_trade_items(trade.input_items)
    s = s .. " >> " .. lib.tostring_trade_items(trade.output_items) .. "]"
    return s .. "]"
end

---@param trades {[int]: table}
---@return string
function lib.tostring_trades_array(trades)
    local s = "["
    for i, trade in ipairs(trades) do
        s = s .. "\n\t" .. i .. ": " .. lib.tostring_trade(trade)
    end
    return s .. "\n]"
end

---@param filter table
function lib.tostring_trade_filter(filter)
    local s = "[Trade Filter"
    if filter.input_items then
        s = s .. " | Inputs: [" .. table.concat(filter.input_items, ", ") .. "]"
    end
    if filter.output_items then
        s = s .. " | Outputs: [" .. table.concat(filter.output_items, ", ") .. "]"
    end
    -- TODO: show planet filter
    return s .. "]"
end

---@return LuaQualityPrototype|nil
function lib.get_tier6_quality()
    local leg = prototypes.quality.legendary
    if not leg then
        lib.log_error("lib.get_tier6_quality_name: Legendary doesn't exist?")
        return
    end
    if not leg.next then
        lib.log_error("lib.get_tier6_quality_name: Tier 6 quality doesn't exist?")
    end
    return leg.next
end

function lib.is_hextreme_enabled()
    local q = lib.get_tier6_quality()
    if not q then return false end
    return q.name == "hextreme"
end

function lib.data.is_hextreme_enabled()
    return not lib.startup_setting_value "disable-hextreme-quality"
end

---@return LuaQualityPrototype
function lib.get_hextreme_or_next_highest_quality()
    local q = lib.get_tier6_quality()
    if not q then
        if prototypes.quality.legendary then
            return prototypes.quality.legendary
        end
        return next(prototypes.quality)[2] -- probably never going to see this, but it's here just in case
    end
    return q
end

---@param quality string
function lib.get_quality_tier(quality)
    if not storage.quality_tiers then storage.quality_tiers = {} end
    local tier = storage.quality_tiers[quality]
    if tier then return tier end

    tier = 1
    local prot = prototypes.quality.normal
    while prot.name ~= quality do
        prot = prot.next
        if not prot then
            lib.log_error("lib.get_quality_tier: quality " .. quality .. " doesn't exist")
            break
        end
        tier = tier + 1
    end

    storage.quality_tiers[quality] = tier
    return tier
end

---@param quality_tier int
---@return string
function lib.get_quality_at_tier(quality_tier)
    if not storage.quality_by_tier then storage.quality_by_tier = {} end
    local quality = storage.quality_by_tier[quality_tier]
    if quality then return quality end

    local prot = prototypes.quality.normal
    for i = 1, quality_tier - 1 do
        if not prot.next then
            lib.log_error("lib.get_quality_at_tier: tier " .. quality_tier .. " doesn't exist")
            break
        end
        prot = prot.next
    end

    quality = prot.name
    storage.quality_by_tier[quality_tier] = quality
    return quality
end

---@return {[string]: number}
function lib.get_quality_cost_multipliers()
    local mults = {normal = 1}
    local mult = tonumber(lib.runtime_setting_value "quality-cost-multiplier")
    for quality_name, _ in pairs(prototypes.quality) do
        if quality_name == "normal" then
            mults[quality_name] = 1
        else
            mults[quality_name] = mult
        end
    end
    return mults
end

---@param quality string
---@return number
function lib.get_quality_cost_multiplier(quality)
    if quality == "normal" then return 1 end
    return tonumber(lib.runtime_setting_value "quality-cost-multiplier") or 1
end

---@param quality LuaQualityPrototype
---@return boolean
function lib.is_tier6_quality(quality)
    if prototypes.quality.legendary then
        return prototypes.quality.legendary.next == quality
    end
    return false
end

function lib.reservoir_sample_index(t)
    local m = math.huge
    local K
    for k, v in pairs(t) do
        local r = math.random()
        if r < m then
            m = r
            K = k
        end
    end
    return K
end

function lib.reservoir_sample(t)
    return t[lib.reservoir_sample_index(t)]
end

function lib.get_tier_of_coin_name(coin_name)
    if coin_name == "hex-coin" then
        return 1
    elseif coin_name == "gravity-coin" then
        return 2
    elseif coin_name == "meteor-coin" then
        return 3
    elseif coin_name == "hexaprism-coin" then
        return 4
    end
    lib.log_error("lib.get_tier_of_coin_name: Cannot determine the tier of " .. coin_name)
    return  1
end

---Get the name of a coin from its tier, defaulting to the lowest tier name if the tier is unrecognized.
---@param coin_tier int
---@return string
function lib.get_coin_name_of_tier(coin_tier)
    if coin_tier == 1 then
        return "hex-coin"
    elseif coin_tier == 2 then
        return "gravity-coin"
    elseif coin_tier == 3 then
        return "meteor-coin"
    elseif coin_tier == 4 then
        return "hexaprism-coin"
    else
        return "hex-coin"
    end
end

---@param quality string
---@return number
function lib.get_quality_value_scale(quality)
    return 9 ^ (lib.get_quality_tier(quality) - 1)
end

function lib.is_quality_tier_unlocked(quality_tier)
    local quality = lib.get_quality_at_tier(quality_tier)
    if not quality then return false end
    return game.forces.player.is_quality_unlocked(quality)
end

---@param item_name string
---@return boolean
function lib.is_spoilable(item_name)
    local prot = prototypes.item[item_name]
    if not prot then return false end
    return prot.get_spoil_ticks() > 0
end

function lib.get_stack_size(item_name)
    local prot = prototypes.item[item_name]
    if not prot then return 1 end
    return prot.stack_size
end

function lib.is_player_editor_like(player)
    return player.controller_type == defines.controllers.god or player.controller_type == defines.controllers.editor
end

function lib.player_is_in_remote_view(player)
    return player.controller_type == defines.controllers.remote
end

---@param item_name string
---@param prototype_category string|nil
---@param localization_prefix string|nil
---@return LocalisedString
function lib.get_true_localized_name(item_name, prototype_category, localization_prefix)
    if not prototype_category then prototype_category = "item" end
    if not localization_prefix then localization_prefix = prototype_category .. "-name" end
    local prots = prototypes[prototype_category] or prototypes["item"]
    local prot = prots[item_name]
    if prot and prot.localised_name then
        return prot.localised_name
    end
    return {localization_prefix .. "." .. item_name}
end

---Get the lowest available quality in the game.
---@return LuaQualityPrototype
function lib.get_lowest_quality()
    local lowest_quality

    for _, q in pairs(prototypes.quality) do
        if not lowest_quality then
            lowest_quality = q
        else
            if q.level < lowest_quality.level then
                lowest_quality = q
                break
            end
        end
    end

    return lowest_quality
end

---@return LuaQualityPrototype
function lib.get_highest_unlocked_quality()
    local q = prototypes.quality.normal
    while q.next and game.forces.player.is_quality_unlocked(q.next) do
        q = q.next
    end
    return q
end

---@return LuaQualityPrototype[]
function lib.get_all_unlocked_qualities()
    local unlocked = {}
    local q = prototypes.quality.normal
    while q.next do
        table.insert(unlocked, q)
        q = q.next
    end
    return unlocked
end

---@return string[]
function lib.get_all_unlocked_quality_names()
    local unlocked = {}
    local q = prototypes.quality.normal
    while q.next do
        table.insert(unlocked, q.name)
        q = q.next
    end
    return unlocked
end

---Return whether the given entity should not be destroyed when a hex core spawns on top of or underneath it.
---@param entity LuaEntity
---@return boolean
function lib.is_entity_immune_to_hex_core_clearing(entity)
    return immune_to_hex_core_clearing[entity.type] == true
end

---@param entity LuaEntity
---@return string[]
function lib.get_entity_ammo_categories(entity)
    local prot = prototypes["entity"][entity.name]
    if not prot then return {} end
    if not prot.attack_parameters then return {} end
    return prot.attack_parameters.ammo_categories or {}
end

---@param items QualityItemCounts
---@param show_none boolean|nil Whether to return "none" if no items exist. Defaults to `true`.
---@return LocalisedString
function lib.get_quality_item_counts_str(items, show_none)
    if show_none == nil then show_none = true end

    local strs = {}
    for quality, t in pairs(items) do
        for item_name, count in pairs(t) do
            table.insert(strs, "[item=" .. item_name .. ",quality=" .. quality .. "]x" .. count)
        end
    end

    if show_none and not next(strs) then
        return {"hextorio.none"}
    end
    return table.concat(strs, " ")
end

---Add a quality item counts table to another, modifying the first one passed.
---@param quality_item_counts_to_modify QualityItemCounts
---@param quality_item_counts_to_add QualityItemCounts
function lib.add_to_quality_item_counts(quality_item_counts_to_modify, quality_item_counts_to_add)
    for quality, t_add in pairs(quality_item_counts_to_add) do
        local t_modify = quality_item_counts_to_modify[quality]
        if not t_modify then
            t_modify = {}
            quality_item_counts_to_modify[quality] = t_modify
        end

        for item_name, count in pairs(t_add) do
            t_modify[item_name] = (t_modify[item_name] or 0) + count
        end
    end
    lib.normalize_quality_item_counts(quality_item_counts_to_modify)
end

---@param quality_item_counts QualityItemCounts
function lib.normalize_quality_item_counts(quality_item_counts)
    for quality, t in pairs(quality_item_counts) do
        for item_name, count in pairs(t) do
            if count == 0 then
                t[item_name] = nil
            end
        end
        if not next(t) then
            quality_item_counts[quality] = nil
        end
    end
end

---@param stats HexCoreStats
---@return LocalisedString
function lib.get_str_from_hex_core_stats(stats)
    local str = {"",
        lib.color_localized_string({"hex-core-gui.total-produced"}, "white", "heading-2"),
    }

    local any = false
    if next(stats.total_items_produced) then
        table.insert(str, "\n" .. lib.get_quality_item_counts_str(stats.total_items_produced, false))
        any = true
    end
    if stats.total_coins_produced.values[1] ~= 0 or stats.total_coins_produced.values[2] ~= 0 or stats.total_coins_produced.values[3] ~= 0 or stats.total_coins_produced.values[4] ~= 0 then -- TODO: Break this file into down into multiple files so that circular dependency can be avoided while using coin_tiers.is_zero()
        table.insert(str, "\n" .. lib.get_str_from_coin(stats.total_coins_produced))
        any = true
    end
    if not any then
        table.insert(str, "\n")
        table.insert(str, {"hextorio.none"})
    end

    table.insert(str, "\n\n")
    table.insert(str, lib.color_localized_string({"hex-core-gui.total-consumed"}, "white", "heading-2"))

    any = false
    if next(stats.total_items_consumed) then
        table.insert(str, "\n" .. lib.get_quality_item_counts_str(stats.total_items_consumed, false))
        any = true
    end
    if stats.total_coins_consumed.values[1] ~= 0 or stats.total_coins_consumed.values[2] ~= 0 or stats.total_coins_consumed.values[3] ~= 0 or stats.total_coins_consumed.values[4] ~= 0 then -- TODO: Break this file into down into multiple files so that circular dependency can be avoided while using coin_tiers.is_zero()
        table.insert(str, "\n" .. lib.get_str_from_coin(stats.total_coins_consumed))
        any = true
    end
    if not any then
        table.insert(str, "\n")
        table.insert(str, {"hextorio.none"})
    end

    return str
end

---@param coin table
---@param show_leading_zeros boolean|nil
---@param sigfigs int|nil
---@return string
function lib.get_str_from_coin(coin, show_leading_zeros, sigfigs)
    if show_leading_zeros == nil then show_leading_zeros = false end
    local p = 10 ^ (sigfigs or 4)
    local function format(value)
        if not sigfigs then
            return tostring(math.floor(0.5 + value))
        end
        if value ~= math.floor(value) and value < p then
            return lib.tostring_sigfigs(value, sigfigs)
        end
        if value > p then
            return tostring(math.floor(0.5 + value))
        end
        return tostring(value)
    end

    if show_leading_zeros then
        return "[img=hex-coin]x" .. format(coin.values[1]) .. " [img=gravity-coin]x" .. format(coin.values[2]) .. " [img=meteor-coin]x" .. format(coin.values[3]) .. " [img=hexaprism-coin]x" .. format(coin.values[4])
    end

    local text = ""
    local visible = false
    if coin.values[4] > 0 then visible = true end
    if visible then
        if text ~= "" then text = text .. " " end
        text = text .. "[img=hexaprism-coin]x" .. format(coin.values[4])
    end

    if coin.values[3] > 0 then visible = true end
    if visible then
        if text ~= "" then text = text .. " " end
        text = text .. "[img=meteor-coin]x" .. format(coin.values[3])
    end

    if coin.values[2] > 0 then visible = true end
    if visible then
        if text ~= "" then text = text .. " " end
        text = text .. "[img=gravity-coin]x" .. format(coin.values[2])
    end

    -- Don't show leading zeroes, but show intermediate zeroes, and always show hex coin even if total cost is zero.
    if text ~= "" then text = text .. " " end
    text = text .. "[img=hex-coin]x" .. format(coin.values[1])

    return text
end

---@param player LuaPlayer
---@param object_name string
function lib.open_factoriopedia_gui(player, object_name, prototype_category)
    local prot
    if prototype_category then
        prot = prototypes[prototype_category][object_name]
    else
        prot = prototypes.item[object_name] or prototypes.fluid[object_name] or prototypes.entity[object_name] or prototypes.recipe[object_name]
    end
    if not prot then
        lib.log_error("lib.open_factoriopedia_gui: Cannot find prototype for " .. object_name)
        return
    end
    player.open_factoriopedia_gui(prot)
end

function lib.get_at_multi_index(t, ...)
    local current = t
    for _, index in ipairs({...}) do
        if type(current) ~= "table" then return end
        current = current[index]
    end
    return current
end

function lib.set_at_multi_index(t, value, ...)
    local args = {...}
    local last = table.remove(args)
    local current = t

    for _, index in ipairs(args) do
        if type(current[index]) ~= "table" then
            current[index] = {}
        end
        current = current[index]
    end

    current[last] = value
    return t
end

function lib.remove_at_multi_index(t, ...)
    lib.set_at_multi_index(t, nil, ...)
end

---Reload the given turrets.
---@param entities LuaEntity[]
---@param params AmmoReloadParameters | nil
function lib.reload_turrets(entities, params)
    if not params then params = {} end
    if not params.bullet_type then
        params.bullet_type = "uranium-rounds-magazine"
    end
    if not params.flamethrower_type then
        params.flamethrower_type = "light-oil"
    end
    if not params.rocket_type then
        params.rocket_type = "rocket"
    end
    if not params.railgun_type then
        params.railgun_type = "railgun-ammo"
    end
    local stack_sizes = {
        [params.bullet_type] = params.bullet_count or prototypes["item"][params.bullet_type].stack_size,
        [params.flamethrower_type] = params.flamethrower_count or 1000,
        [params.rocket_type] = params.rocket_count or prototypes["item"][params.rocket_type].stack_size,
        [params.railgun_type] = params.railgun_count or prototypes["item"][params.railgun_type].stack_size,
    }
    for _, e in pairs(entities) do
        lib.reload_entity(e, params, stack_sizes)
    end
end

---Reload an entity (typically an ammo turret).
---@param entity LuaEntity
---@param params AmmoReloadParameters
---@param stack_sizes {[string]: integer}
function lib.reload_entity(entity, params, stack_sizes)
    if not entity.valid then return end

    local prot = entity.prototype
    local attack_params = prot.attack_parameters
    if not attack_params then return end

    local ammo_categories = attack_params.ammo_categories
    if not ammo_categories then return end

    local ammo_type = storage.ammo_type_per_entity[entity.name]
    if not ammo_type then return end

    local ammo_name = params[ammo_type] --[[@as string|nil]]
    if ammo_name then
        if ammo_type == "flamethrower_type" then
            entity.insert_fluid {name = ammo_name, amount = stack_sizes[ammo_name]}
            return
        else
            entity.insert {name = ammo_name, count = stack_sizes[ammo_name]}
            return
        end
    end
end

---Print a notification in chat.
---@param notification_id NotificationID
---@param message any
function lib.print_notification(notification_id, message)
    for _, player in pairs(game.connected_players) do
        if lib.player_setting_value(player, "notifications-" .. notification_id) then
            player.print(message)
        end
    end
end

---Return a hex core entity from a hex core's loader. If the entity is the hex core entity, it is returned.
---@param entity LuaEntity
---@return LuaEntity|nil
function lib.get_hex_core_from_entity(entity)
    if not entity.surface or not entity.position then
        lib.log_error("lib.get_hex_core_from_entity: parameter passed is not a LuaEntity")
        return
    end
    local entities = entity.surface.find_entities_filtered {
        name = "hex-core",
        area = {{entity.position.x - 2, entity.position.y - 2}, {entity.position.x + 3, entity.position.y + 3}},
    }
    return entities[1]
end

---Get an entity that is opened by a player.
---@param player LuaPlayer
---@return LuaEntity|nil
function lib.get_player_opened_entity(player)
    local entity = player.opened
    if not entity or not entity.valid or not entity.surface or not entity.position then return end
    ---@cast entity LuaEntity
    return entity
end

-- ---Get the required tiles for placement of an entity prototype.
-- ---@param prot LuaEntityPrototype
-- function lib.entity_required_tiles(prot)

-- end

---Return whether the given player's cooldown under the category `cooldown_name` is ready for retriggering.
---@param player_index int
---@param cooldown_name string
---@return boolean
function lib.is_player_cooldown_ready(player_index, cooldown_name)
    local cooldowns = storage.cooldowns[player_index]
    if not cooldowns or cooldowns[cooldown_name] == nil then
        return true
    end
    return game.tick >= cooldowns[cooldown_name]
end

---Return the given player's remaining cooldown under the category `cooldown_name`.
---@param player_index int
---@param cooldown_name string
---@return int
function lib.get_player_cooldown_remaining(player_index, cooldown_name)
    local cooldowns = storage.cooldowns[player_index]
    if not cooldowns or cooldowns[cooldown_name] == nil then
        return 0
    end
    return cooldowns[cooldown_name] - game.tick
end

---Trigger the given player's cooldown under the category `cooldown_name`.
---@param player_index int
---@param cooldown_name string
---@param cooldown_time int
function lib.trigger_player_cooldown(player_index, cooldown_name, cooldown_time)
    local cooldowns = storage.cooldowns[player_index]
    if not cooldowns then
        cooldowns = {}
        storage.cooldowns[player_index] = cooldowns
    end
    cooldowns[cooldown_name] = game.tick + cooldown_time
end

---@param train LuaTrain
---@param train_stop LuaEntity
---@return LuaEntity[]
function lib.get_cargo_wagons_nearest_to_stop(train, train_stop)
    local front = train.locomotives.front_movers[1]
    if not front or not front.valid then return {} end
    if not train_stop.valid then return train.cargo_wagons end

    if lib.square_distance(front.position, train_stop.position) < 13.2 then -- Comparing distance is the best way I can come up with for correctly distinguishing this.
        return train.cargo_wagons
    end

    return lib.table_reversed(train.cargo_wagons)
end

---@param cargo_wagons LuaEntity[]
---@param stack ItemStackIdentification
---@param wagon_limit int
---@return int inserted How many items were successfully inserted
function lib.insert_into_train(cargo_wagons, stack, wagon_limit)
    -- This function is supposed to be LuaTrain.insert(stack), but that function does not return how many items were successfully inserted like LuaInventory.insert()
    local quality = stack.quality or "normal"
    local count = stack.count or 1

    local remaining_count = count

    -- First try to insert into wagons that already contain this item
    for i, cargo_wagon in ipairs(cargo_wagons) do
        if remaining_count < 1 or i > wagon_limit then break end

        if cargo_wagon.get_item_count(stack.name) > 0 then
            remaining_count = remaining_count - cargo_wagon.insert {
                name = stack.name,
                count = remaining_count,
                quality = quality,
            }
        end
    end

    -- Then try to insert into wagons with remaining space
    for i, cargo_wagon in ipairs(cargo_wagons) do
        if remaining_count < 1 or i > wagon_limit then break end

        remaining_count = remaining_count - cargo_wagon.insert {
            name = stack.name,
            count = remaining_count,
            quality = quality,
        }
    end

    return count - remaining_count
end

---@param cargo_wagons LuaEntity[]
---@param stack ItemStackIdentification
---@param wagon_limit int
---@return int removed How many items were successfully removed
function lib.remove_from_train(cargo_wagons, stack, wagon_limit)
    -- This function is supposed to be LuaTrain.remove_item(stack), but that function does not always go in the correct order of cargo wagons.
    local quality = stack.quality or "normal"
    local count = stack.count or 1

    local remaining_count = count
    for i, cargo_wagon in ipairs(cargo_wagons) do
        if remaining_count < 1 or i > wagon_limit then break end

        remaining_count = remaining_count - cargo_wagon.remove_item {
            name = stack.name,
            count = remaining_count,
            quality = quality,
        }
    end

    return count - remaining_count
end

---Return a lookup table of names of items (and not fluids) that are only obtainable from planets without recipes.
---@return {[string]: boolean}
function lib.get_raw_items()
    return raw_items
end



return lib
