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
local non_land_tile_name_lookup = {}
for _, name in pairs(non_land_tile_names) do
    non_land_tile_name_lookup[name] = true
end



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
    if not player.character then
        lib.log_error("unstuck_player: player has no character after teleport")
    end
end

function lib.teleport_player(player, position, surface)
    if not player then
        lib.log_error("teleport_player: player is nil")
        return
    end
    if not player.character then
        lib.log_error("teleport_player: player has no character")
        return
    end
    if not position then
        lib.log_error("teleport_player: position is nil")
        return
    end
    if not surface then
        surface = player.surface
    end
    if not position.x then position.x = position[1] end
    if not position.y then position.y = position[2] end
    lib.log("Teleporting player to " .. position.x .. ", " .. position.y .. " on surface " .. surface.name)
    player.teleport(position, surface)
    lib.unstuck_player(player)
    if not player.character then
        lib.log_error("teleport_player: player has no character after teleport")
    end
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

function lib.get_rank_img_str(rank)
    if rank == 1 then
        -- return "[img=rank-1-alt]"
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
end

function lib.get_trade_img_str(trade)
    local s = ""
    for _, item in pairs(trade.input_items) do
        s = s .. "[img=item." .. item.name .. "]"
    end
    s = s .. "[img=trade-arrow]"
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

function lib.format_percentage(x, decimal_places, include_symbol)
    if include_symbol == nil then include_symbol = true end
    local p = 10 ^ decimal_places
    s = tostring(math.floor(x * 100 * p + 0.5) / p)
    if include_symbol then
        s = s .. "%"
    end
    return s
end

function lib.get_gps_str_from_hex_core(hex_core)
    return "[gps=" .. hex_core.position.x .. "," .. hex_core.position.y .. "," .. hex_core.surface.name .. "]"
end

function lib.insert_endgame_armor(player)
    player.get_inventory(5).clear()
    player.get_inventory(5).clear() -- has to be done twice IF the player inventory is too full

    local q = lib.get_hextreme_or_next_highest_quality()

    player.insert{name = "construction-robot", quality=q, count = 340}
    player.insert{name="mech-armor", quality=q, count = 1}

    local mech_armor = player.get_inventory(5)[1].grid
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

function lib.safe_insert(player, item_stack)
    if player.can_insert(item_stack) then
        player.insert(item_stack)
        return true
    else
        player.print {"hextorio.no-room-for-item", "[item=" .. item_stack.name .. "]"}
        player.surface.spill_item_stack{position=player.position, stack=item_stack}
        return false
    end
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

---@param surface LuaSurface|string
---@return boolean
function lib.is_space_platform(surface)
    if type(surface) ~= "string" then
        return lib.is_space_platform(surface.name)
    end
    return surface:sub(1, 9) == "platform-"
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

function lib.flattened_position_array(arr)
    local flat = {}
    for x, Y in pairs(arr) do
        for y, _ in pairs(Y) do
            table.insert(flat, {x = x, y = y})
        end
    end
    return flat
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



return lib
