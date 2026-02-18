
--[[
Determines a coin value for every item on every planet.
Runs as a tick-based state machine to avoid freezing the game.
Triggered by `/solve-item-values` and automatically at the start of the game.

Every item's value comes from the cheapest way to produce it.
All values start at infinity, then we repeatedly scan recipes.
If a recipe's input cost leads to a cheaper value for any product, update it.
Input cost = ingredient values scaled by a multiplier for craft time and complexity.
Values only go down, so convergence is guaranteed (was an issue with past iterations of this solver).

Items that can't be produced locally take values from other planets.
Ingredient import cost considers rocket part value, rocket parts per launch, rocket capacity, spaceship flight distance, and stack sizes.
Recycling recipes are considered on planets to determine cheapest item acquisition routes.
(e.g. Fulgoran scrap -> Gleba -> recycle -> red & blue circuits -> recycle -> green circuits -> modules)

Phases:
  Collect:
    - read recipe prototypes
  Build:
    - preprocess recipe data
    - expand fuel-burning recipes into per-fuel pseudo-recipes
    - add spoil/burnt pseudo-recipes
    - classify items as local vs interplanetary per planet
    - compute shortest spaceship flight routes
    - initialize all item values (as infinity)
  Solve:
    - minimum-cost propagation
    - check imports at the boundaries of iteration, until a full iteration changes nothing
  Finalize:
    - copy resulting values to storage
    - log statistics
    - trigger event on solver termination
]]



local lib = require "api.lib"
local solver_util = require "api.solver_util"
local event_system = require "api.event_system"
local item_values = require "api.item_values"
local data_item_values = require "data.item_values"

local solver = {}



---@alias ItemValueSourceType
---| "raw"       Item is a raw resource with a fixed value
---| "recipe"    Item value comes from the input cost of a recipe
---| "import"    Item is cheaper to import from another planet

---@alias ItemValueSolver.Phase
---| "collect"   Batch-reading recipe prototypes
---| "build"     Preprocessing recipes, computing routes, initializing values
---| "solve"     Iterating minimum-cost propagation
---| "finalize"  Writing results and logging diagnostics

---@class ItemValueSource
---@field type ItemValueSourceType How this item got its value
---@field recipe_name string|nil Recipe that produced the cheapest value, if type == "recipe"
---@field import_path string[]|nil Planet sequence for the cheapest import route, if type == "import"
---@field distance number|nil Total flight distance in kilometers, if type == "import"

---@class ItemValueSolver.State
---@field active boolean Whether the solver is currently running
---@field ticks_elapsed integer Number of ticks passed since solver start
---@field phase ItemValueSolver.Phase Current phase of the solver
---@field collect ItemValueSolver.CollectState|nil Collect phase working data (nil after collect completes)
---@field recipes ItemValueSolver.SolverRecipe[]|nil Preprocessed recipe list
---@field values {[string]: {[string]: number}}|nil Per-planet item values
---@field sources {[string]: {[string]: ItemValueSource}}|nil Per-planet value provenance, indicating how items got their values
---@field is_raw {[string]: {[string]: boolean}}|nil Per-planet sets of raw items
---@field is_interplanetary {[string]: {[string]: boolean}}|nil Per-planet sets of interplanetary items, indicating which items require imports from other planets to be obtained
---@field rocket_parts_per_launch number|nil Rocket parts needed per launch for any planet (TODO: make it per-planet based on modded rocket silos and rocket part recipes and their surface conditions for building and using them)
---@field rocket_capacities {[string]: number}|nil Rocket launch capacity of items
---@field stack_sizes {[string]: number}|nil Stack sizes of items
---@field distances {[string]: {[string]: number}}|nil Shortest flight distances between planets
---@field via {[string]: {[string]: string}}|nil Planet graph for spaceship flight path reconstruction
---@field nt_cache {[string]: boolean}|nil Set of non-transportable items
---@field recipe_idx integer|nil Current recipe index within a solve pass
---@field pass_updates integer|nil Number of value updates in the current pass, moving the solver to the "finalize" state when calculated to be zero
---@field iteration integer|nil Number of completed solve passes

---@class ItemValueSolver.CollectState
---@field recipe_names string[] All recipe prototype names to process
---@field recipes {[string]: ItemValueSolver.CollectedRecipe} Recipe data indexed by name
---@field recipe_idx integer Next index to process in recipe_names

---@class ItemValueSolver.CollectedRecipe
---@field energy number Crafting time in seconds
---@field category string Recipe category (e.g. "crafting", "smelting", "recycling")
---@field ingredients ItemValueSolver.ItemAmount[] Input items and amounts
---@field products ItemValueSolver.ItemAmount[] Output items and expected amounts
---@field surface_conditions SurfaceCondition[]|nil Surface conditions from the recipe prototype

---@class ItemValueSolver.SolverRecipe
---@field label string Display name for logging (recipe name or pseudo-recipe description)
---@field ingredients ItemValueSolver.ItemAmount[] Input items and amounts
---@field products ItemValueSolver.ItemAmount[] Output items and expected (average) amounts
---@field multipliers {[string]: number} Per-planet cost multiplier (craft time, complexity, spoilables)
---@field valid_planets {[string]: boolean}|nil Planets where this recipe can run (nil = all planets)

---@class ItemValueSolver.ItemAmount
---@field name string Item or fluid prototype name
---@field amount number Quantity (average value if probabilistic)

---@class ItemValueSolver.FuelInfo
---@field fuel_items {name: string, fuel_value: number}[] Available fuel items and their energy content
---@field energy_usage number Machine power draw
---@field effectivity number Burner effectivity multiplier
---@field surface_conditions SurfaceCondition[]|nil Surface conditions from the crafting entity



--- Multiplier to item value per km traveled between planets. The multiplier is `1 + distance * DISTANCE_FACTOR`, where distance is measured in kilometers.
local DISTANCE_FACTOR = 0.0002

--- Multiplier to item value from stack sizes on space ships, where smaller stack sizes result in greater multipliers. The multiplier is `1 + STACK_SIZE_FACTOR / stack_size`.
local STACK_SIZE_FACTOR = 4

local INITIAL_VALUE = math.huge
local MAX_TICKS = 10000
local COLLECT_BATCH = 100
local SOLVE_BATCH = 200



---@return boolean
local function is_active()
    return storage.solver and storage.solver.active
end

---Non-transportable: fluids (barrel items handle fluid transport via recipes),
---missing item prototypes, or items too heavy for rockets.
---@param item_name string
---@param cache table
---@return boolean
local function is_non_transportable(item_name, cache)
    if cache[item_name] ~= nil then return cache[item_name] end
    if prototypes.fluid[item_name] then
        cache[item_name] = true
        return true
    end
    local proto = prototypes.item[item_name]
    if not proto then
        cache[item_name] = true
        return true
    end
    if proto.weight > 1000000 then
        cache[item_name] = true
        return true
    end
    cache[item_name] = false
    return false
end

---Cancel common items between ingredients and products to prevent feedback loops.
---@param recipe ItemValueSolver.CollectedRecipe
local function cancel_common_items(recipe)
    for i = #recipe.ingredients, 1, -1 do
        local ing = recipe.ingredients[i]
        for j = #recipe.products, 1, -1 do
            local prod = recipe.products[j]
            if ing.name == prod.name then
                if ing.amount > prod.amount then
                    ing.amount = ing.amount - prod.amount
                    table.remove(recipe.products, j)
                elseif ing.amount < prod.amount then
                    prod.amount = prod.amount - ing.amount
                    table.remove(recipe.ingredients, i)
                else
                    table.remove(recipe.products, j)
                    table.remove(recipe.ingredients, i)
                end
                break
            end
        end
    end
end

---Compute the cost of importing one unit of an item from a source planet.
---Cost = (source_value + rocket_launch_cost) * (1 + distance * DISTANCE_FACTOR)
---@param s ItemValueSolver.State
---@param src_planet string
---@param dst_planet string
---@param item_name string
---@param src_val number
---@return number
local function import_cost(s, src_planet, dst_planet, item_name, src_val)
    local capacity = s.rocket_capacities[item_name]
    if not capacity then return INITIAL_VALUE end
    local rp_val = s.values[src_planet]["rocket-part"]
    if not rp_val or rp_val >= INITIAL_VALUE then return INITIAL_VALUE end
    local dist = s.distances[src_planet] and s.distances[src_planet][dst_planet]
    if not dist or dist >= math.huge then return INITIAL_VALUE end
    local launch_cost = s.rocket_parts_per_launch * rp_val / capacity
    local stack_size = s.stack_sizes[item_name] or 1
    return (src_val + launch_cost) * (1 + dist * DISTANCE_FACTOR) * (1 + STACK_SIZE_FACTOR / stack_size)
end

---Find the cheapest cost for an item on a planet.
---Local items use only their local value. Interplanetary items also consider imports.
---@param s ItemValueSolver.State
---@param planet string
---@param item_name string
---@return number
local function get_best_cost(s, planet, item_name)
    local best = s.values[planet][item_name] or INITIAL_VALUE
    if not s.is_interplanetary[planet][item_name] then return best end
    if is_non_transportable(item_name, s.nt_cache) then return best end
    for src, _ in pairs(storage.SUPPORTED_PLANETS) do
        if src ~= planet then
            local src_val = s.values[src][item_name]
            if src_val and src_val < INITIAL_VALUE then
                local imported = import_cost(s, src, planet, item_name, src_val)
                if imported < best then best = imported end
            end
        end
    end
    return best
end



---Phase 0: Batch-collect recipe data from prototypes.
---@param s ItemValueSolver.State
local function phase_collect(s)
    if not s.collect then
        s.collect = {
            recipe_names = {},
            recipe_idx = 1,
            recipes = {},
        }

        for name in pairs(prototypes.recipe) do
            table.insert(s.collect.recipe_names, name)
        end

        lib.log("Solver: collecting " .. #s.collect.recipe_names .. " recipes")
        return
    end

    local c = s.collect ---@type ItemValueSolver.CollectState
    for _ = 1, COLLECT_BATCH do
        if c.recipe_idx > #c.recipe_names then
            lib.log("Solver: collected " .. table_size(c.recipes) .. " valid recipes")
            s.phase = "build"
            return
        end

        local name = c.recipe_names[c.recipe_idx]
        local recipe = prototypes.recipe[name]
        c.recipe_idx = c.recipe_idx + 1

        if recipe and (not recipe.hidden or recipe.category == "recycling") then
            local data = solver_util.extract_recipe_data(recipe)
            if data then
                c.recipes[recipe.name] = data
            end
        end
    end
end

---Compute per-planet multipliers for a recipe.
---@param energy number
---@param ingredient_count number
---@param spoilable_count number
---@return {[string]: number} planet_name -> multiplier
local function compute_multipliers(energy, ingredient_count, spoilable_count)
    local planet_configs = storage.item_values.planet_configs

    local mults = {}
    for planet, _ in pairs(storage.SUPPORTED_PLANETS) do
        local c = planet_configs[planet]

        local mult = 1 + c.energy_coefficient * energy
        mult = mult * (1 + c.complexity_coefficient * ingredient_count)
        mult = mult * (1 + c.spoilable_coefficient * spoilable_count)
        mult = mult * (1 + c.raw_multiplier)

        mults[planet] = mult
    end

    return mults
end

---Find fuel-consuming recipe categories (e.g. captive-spawner-process) and
---the fuel items that power them. Returns a mapping from recipe category to
---fuel info: the available fuel items, machine energy usage, and burner effectivity.
---@return {[string]: ItemValueSolver.FuelInfo}
local function find_fuel_categories(collected_recipes)
    -- Identify categories with 0-ingredient recipes
    local zero_cats = {}
    for _, data in pairs(collected_recipes) do
        if #data.ingredients == 0 and data.category then
            zero_cats[data.category] = true
        end
    end

    -- For each such category, find the crafting entity and its fuel requirements
    local result = {}
    for category in pairs(zero_cats) do
        local entities = prototypes.get_entity_filtered(
            {{filter = "crafting-category", crafting_category = category}})

        for _, entity in pairs(entities) do
            local bp = entity.burner_prototype
            if bp and entity.energy_usage and entity.energy_usage > 0 then
                for fuel_cat in pairs(bp.fuel_categories) do
                    local fuel_items = {}
                    for name, proto in pairs(prototypes.item) do
                        if proto.fuel_category == fuel_cat
                        and proto.fuel_value and proto.fuel_value > 0 then
                            table.insert(fuel_items, {
                                name = name, fuel_value = proto.fuel_value,
                            })
                        end
                    end
                    if #fuel_items > 0 then
                        local sc = entity.object_name == "LuaEntityPrototype" and entity.surface_conditions or nil
                        result[category] = {
                            fuel_items = fuel_items,
                            energy_usage = entity.energy_usage,
                            effectivity = bp.effectivity or 1,
                            surface_conditions = sc,
                        }
                        break
                    end
                end
                if result[category] then break end
            end
        end
    end
    return result
end

local intersect_valid_planets = solver_util.intersect_valid_planets

---Phase 1: Process recipes, add spoil/burnt/fuel pseudo-recipes, compute multipliers, initialize values.
---@param s ItemValueSolver.State
local function phase_build(s)
    local recipes = {}
    local all_items = {}

    local all_planets = storage.SUPPORTED_PLANETS
    local raw_values = storage.item_values.raw_values
    local fuel_categories = find_fuel_categories(s.collect.recipes)

    local categories = {}
    for _, data in pairs(s.collect.recipes) do
        if data.category then categories[data.category] = true end
    end
    local category_valid_planets = solver_util.build_category_valid_planets(categories)

    for recipe_name, data in pairs(s.collect.recipes) do
        local fuel_info = #data.ingredients == 0 and fuel_categories[data.category] or nil
        local recipe_vp = solver_util.get_valid_planets(data.surface_conditions)
        local cat_vp = category_valid_planets[data.category]

        if fuel_info then
            -- Fuel-consuming recipe (e.g. captive-spawner-process): expand into one
            -- recipe per fuel type, with fuel as the sole ingredient. The amount of
            -- fuel consumed = (machine_power * craft_time) / (fuel_value * effectivity).
            -- Valid planets = intersection of recipe and entity surface conditions.
            for _, prod in pairs(data.products) do all_items[prod.name] = true end

            local entity_vp = solver_util.get_valid_planets(fuel_info.surface_conditions)
            local valid_planets = intersect_valid_planets(
                intersect_valid_planets(recipe_vp, entity_vp), cat_vp)

            for _, fuel in pairs(fuel_info.fuel_items) do
                local fuel_amount = (fuel_info.energy_usage * data.energy * 60)
                    / (fuel.fuel_value * fuel_info.effectivity)
                if fuel_amount <= 0 then fuel_amount = 1 end
                all_items[fuel.name] = true

                local spoilable_count = lib.is_spoilable(fuel.name) and 1 or 0
                table.insert(recipes, {
                    label = recipe_name .. " (fuel: " .. fuel.name .. ")",
                    ingredients = {{name = fuel.name, amount = fuel_amount}},
                    products = data.products,
                    multipliers = compute_multipliers(data.energy, 1, spoilable_count),
                    valid_planets = valid_planets,
                })
            end
        else
            cancel_common_items(data)
            if #data.ingredients > 0 and #data.products > 0 then
                for _, ing in pairs(data.ingredients) do all_items[ing.name] = true end
                for _, prod in pairs(data.products) do all_items[prod.name] = true end

                local spoilable_count = 0
                for _, ing in pairs(data.ingredients) do
                    if lib.is_spoilable(ing.name) then spoilable_count = spoilable_count + 1 end
                end

                local vps = intersect_valid_planets(recipe_vp, cat_vp)
                table.insert(recipes, {
                    label = recipe_name,
                    ingredients = data.ingredients,
                    products = data.products,
                    multipliers = compute_multipliers(data.energy, #data.ingredients, spoilable_count),
                    valid_planets = vps,
                })
            end
        end
    end

    -- Add raw items to the item set
    for _, planet_raw in pairs(raw_values) do
        for item_name in pairs(planet_raw) do
            all_items[item_name] = true
        end
    end

    -- Add spoil and burnt_result pseudo-recipes (1:1, multiplier 1.0)
    local identity_mults = {}
    for planet, _ in pairs(all_planets) do identity_mults[planet] = 1.0 end

    local spoil_burnt = solver_util.collect_spoil_burnt_chains(all_items)
    for _, p in pairs(spoil_burnt) do
        all_items[p.result] = true
        table.insert(recipes, {
            label = p.label,
            ingredients = {{name = p.source, amount = 1}},
            products = {{name = p.result, amount = 1}},
            multipliers = identity_mults,
        })
    end
    local pseudo_count = #spoil_burnt

    -- Remove hidden items from the solver, but keep items that are produced by
    -- non-hidden recipes (e.g. rocket-part: item is hidden, but the recipe is not).
    local produced_by_recipe = {}
    for _, recipe in pairs(recipes) do
        for _, prod in pairs(recipe.products) do
            produced_by_recipe[prod.name] = true
        end
    end

    local hidden_items = {}
    for item_name in pairs(all_items) do
        local proto = prototypes.item[item_name]
        if proto and proto.hidden and not produced_by_recipe[item_name] then
            hidden_items[item_name] = true
            all_items[item_name] = nil
        end
    end

    if next(hidden_items) then
        -- Filter recipes: strip hidden items from both ingredients and products.
        -- Hidden ingredients are treated as free (removed), not as blockers.
        local filtered = {}
        for _, recipe in pairs(recipes) do
            local clean_ingredients = {}
            for _, ing in pairs(recipe.ingredients) do
                if not hidden_items[ing.name] then
                    table.insert(clean_ingredients, ing)
                end
            end
            local clean_products = {}
            for _, prod in pairs(recipe.products) do
                if not hidden_items[prod.name] then
                    table.insert(clean_products, prod)
                end
            end
            if #clean_ingredients > 0 and #clean_products > 0 then
                recipe.ingredients = clean_ingredients
                recipe.products = clean_products
                table.insert(filtered, recipe)
            end
        end
        recipes = filtered
        lib.log("Solver: excluded " .. table_size(hidden_items) .. " hidden items")
    end

    -- Determine rocket parts required per launch by scanning entities that can
    -- craft the "rocket-building" category. Takes the minimum across all such entities.
    local rocket_parts_per_launch = 50
    local rp_entities = prototypes.get_entity_filtered(
        {{filter = "crafting-category", crafting_category = "rocket-building"}})
    for _, entity in pairs(rp_entities) do
        if entity.rocket_parts_required and entity.rocket_parts_required > 0 then
            rocket_parts_per_launch = math.min(rocket_parts_per_launch, entity.rocket_parts_required)
        end
    end
    lib.log("Solver: rocket_parts_per_launch = " .. rocket_parts_per_launch)

    -- Compute rocket capacities and stack sizes from item prototypes.
    -- Fluids are excluded: barrel items (if they exist) handle fluid transport.
    local rocket_capacities = {}
    local stack_sizes = {}
    for item_name in pairs(all_items) do
        if not prototypes.fluid[item_name] then
            local proto = prototypes.item[item_name]
            if proto then
                if proto.weight and proto.weight > 0 and proto.weight <= 1000000 then
                    rocket_capacities[item_name] = 1000000 / proto.weight
                end
                stack_sizes[item_name] = proto.stack_size or 1
            end
        end
    end

    -- Compute shortest paths between all planets via Floyd-Warshall
    local distances, via = {}, {}
    for a, _ in pairs(all_planets) do
        distances[a] = {}
        via[a] = {}
        for b, _ in pairs(all_planets) do
            distances[a][b] = a == b and 0 or math.huge
        end
    end
    for _, conn in pairs(prototypes.space_connection) do
        local a, b = conn.from.name, conn.to.name
        if distances[a] and distances[b] and conn.length < distances[a][b] then
            distances[a][b] = conn.length
            distances[b][a] = conn.length
            via[a][b] = b
            via[b][a] = a
        end
    end
    for k, _ in pairs(all_planets) do
        for i, _ in pairs(all_planets) do
            for j, _ in pairs(all_planets) do
                local d = distances[i][k] + distances[k][j]
                if d < distances[i][j] then
                    distances[i][j] = d
                    via[i][j] = via[i][k]
                end
            end
        end
    end

    -- Log discovered routes
    for a, _ in pairs(all_planets) do
        for b, _ in pairs(all_planets) do
            if a < b and distances[a][b] < math.huge then
                local path = {a}
                local cur = a
                while cur ~= b do cur = via[cur][b]; table.insert(path, cur) end
                lib.log("Solver: route " .. table.concat(path, " → ")
                    .. " (" .. distances[a][b] .. " km)")
            end
        end
    end

    -- Determine locally produceable items per planet via forward propagation.
    -- Starting from each planet's raw resources, iteratively fire recipes whose
    -- ingredients are all available. Items never reached are interplanetary.
    local is_interplanetary = {}
    for planet, _ in pairs(all_planets) do
        local available = {}
        for item_name in pairs(raw_values[planet] or {}) do
            available[item_name] = true
        end

        local changed = true
        while changed do
            changed = false
            for _, recipe in pairs(recipes) do
                if not recipe.valid_planets or recipe.valid_planets[planet] then
                    local can_fire = true
                    for _, ing in pairs(recipe.ingredients) do
                        if not available[ing.name] then
                            can_fire = false
                            break
                        end
                    end
                    if can_fire then
                        for _, prod in pairs(recipe.products) do
                            if not available[prod.name] then
                                available[prod.name] = true
                                changed = true
                            end
                        end
                    end
                end
            end
        end

        is_interplanetary[planet] = {}
        local ip_count = 0
        for item_name in pairs(all_items) do
            if not available[item_name] then
                is_interplanetary[planet][item_name] = true
                ip_count = ip_count + 1
            end
        end
        lib.log("Solver: " .. planet .. " — "
            .. table_size(available) .. " local, " .. ip_count .. " interplanetary")
    end

    -- Initialize per-planet values: raw = fixed, everything else = INITIAL_VALUE
    local values = {}
    local sources = {}
    local is_raw = {}
    for planet, _ in pairs(all_planets) do
        values[planet] = {}
        sources[planet] = {}
        is_raw[planet] = {}
        for item_name, val in pairs(raw_values[planet] or {}) do
            values[planet][item_name] = val
            sources[planet][item_name] = {type = "raw"}
            is_raw[planet][item_name] = true
        end
        for item_name in pairs(all_items) do
            if not values[planet][item_name] then
                values[planet][item_name] = INITIAL_VALUE
            end
        end
    end

    s.recipes = recipes
    s.values = values
    s.sources = sources
    s.is_raw = is_raw
    s.is_interplanetary = is_interplanetary
    s.rocket_capacities = rocket_capacities
    s.rocket_parts_per_launch = rocket_parts_per_launch
    s.stack_sizes = stack_sizes
    s.distances = distances
    s.via = via
    s.nt_cache = {}
    s.recipe_idx = 1
    s.pass_updates = 0
    s.iteration = 0
    s.collect = nil

    local recipe_count = #recipes - pseudo_count
    lib.log("Solver: " .. recipe_count .. " recipes + "
        .. pseudo_count .. " pseudo (spoil/burnt), "
        .. table_size(all_items) .. " items, "
        .. table_size(rocket_capacities) .. " transportable")

    -- Diagnostic: dump producing recipes and interplanetary status for key items
    local diag_items = {
        -- "rocket-part",
        -- "holmium-plate",
        -- "lithium",
        -- "mech-armor",
        -- "spidertron",
    }
    for _, diag_name in pairs(diag_items) do
        if all_items[diag_name] then
            local producing = {}
            for _, recipe in pairs(recipes) do
                for _, prod in pairs(recipe.products) do
                    if prod.name == diag_name then
                        local ings = {}
                        for _, ing in pairs(recipe.ingredients) do
                            table.insert(ings, ing.name .. "x" .. ing.amount)
                        end
                        local vp = recipe.valid_planets
                        local vp_str = vp and table.concat((function()
                            local t = {}; for p in pairs(vp) do table.insert(t, p) end; return t
                        end)(), ",") or "all"
                        table.insert(producing, recipe.label .. " [" .. table.concat(ings, " + ")
                            .. "] planets=" .. vp_str)
                        break
                    end
                end
            end
            local ip_on = {}
            for planet, _ in pairs(all_planets) do
                if is_interplanetary[planet][diag_name] then
                    table.insert(ip_on, planet)
                end
            end
            lib.log("Solver: [diag] " .. diag_name
                .. " | IP on: " .. (#ip_on > 0 and table.concat(ip_on, ",") or "none")
                .. " | capacity: " .. tostring(rocket_capacities[diag_name] or "nil"))
            for _, r in pairs(producing) do
                lib.log("  recipe: " .. r)
            end
        end
    end

    s.phase = "solve"
end

---Phase 2: Minimum-cost propagation. Values can only decrease, preventing divergence.
---Each tick processes a batch of recipes. At pass boundaries, also checks direct imports.
---Converges when zero values change during a full pass (true fixed point).
---@param s ItemValueSolver.State
local function phase_solve(s)
    local recipes = s.recipes ---@type ItemValueSolver.SolverRecipe[]
    local values = s.values ---@type {[string]: {[string]: number}}
    local sources = s.sources ---@type {[string]: {[string]: ItemValueSource}}
    local is_raw = s.is_raw ---@type {[string]: {[string]: boolean}}
    local count = 0

    local all_planets = storage.SUPPORTED_PLANETS

    while count < SOLVE_BATCH and s.recipe_idx <= #recipes do
        local recipe = recipes[s.recipe_idx]

        for planet, _ in pairs(all_planets) do
            if not recipe.valid_planets or recipe.valid_planets[planet] then
                local total_input = 0
                local can_fire = true
                for _, ing in pairs(recipe.ingredients) do
                    local cost = get_best_cost(s, planet, ing.name)
                    if cost >= INITIAL_VALUE then
                        can_fire = false
                        break
                    end
                    total_input = total_input + cost * ing.amount
                end

                if can_fire then
                    local total_output = total_input * recipe.multipliers[planet]

                    local num_non_raw = 0
                    for _, prod in pairs(recipe.products) do
                        if is_raw[planet][prod.name] then
                            total_output = total_output - values[planet][prod.name] * prod.amount
                        else
                            num_non_raw = num_non_raw + 1
                        end
                    end

                    if num_non_raw > 0 and total_output > 0 then
                        local per_product = total_output / num_non_raw
                        for _, prod in pairs(recipe.products) do
                            if not is_raw[planet][prod.name] then
                                local implied = per_product / prod.amount
                                if implied < values[planet][prod.name] then
                                    values[planet][prod.name] = implied
                                    sources[planet][prod.name] = {type = "recipe", recipe_name = recipe.label}
                                    s.pass_updates = s.pass_updates + 1
                                end
                            end
                        end
                    end
                end
            end
        end

        s.recipe_idx = s.recipe_idx + 1
        count = count + 1
    end

    -- Pass complete: check direct imports for interplanetary items and convergence
    if s.recipe_idx > #recipes then
        for planet, _ in pairs(all_planets) do
            for item_name in pairs(s.is_interplanetary[planet]) do
                if not is_non_transportable(item_name, s.nt_cache) then
                    local val = values[planet][item_name]
                    for src, _ in pairs(all_planets) do
                        if src ~= planet then
                            local src_val = values[src][item_name]
                            if src_val and src_val < INITIAL_VALUE then
                                local imported = import_cost(s, src, planet, item_name, src_val)
                                if imported < val then
                                    values[planet][item_name] = imported
                                    val = imported
                                    s.pass_updates = s.pass_updates + 1

                                    local path = {src}
                                    local cur = src
                                    while cur ~= planet do
                                        cur = s.via[cur][planet]
                                        table.insert(path, cur)
                                    end
                                    local dist = s.distances[src][planet]
                                    sources[planet][item_name] = {type = "import", import_path = path, distance = dist}
                                end
                            end
                        end
                    end
                end
            end
        end

        s.iteration = s.iteration + 1

        -- Diagnostic: track key items per pass (first 10 passes only)
        if s.iteration <= 10 then
            local diag = {
                -- "rocket-part",
                -- "holmium-plate",
                -- "lithium",
                -- "mech-armor",
            }
            for _, dname in pairs(diag) do
                local parts = {}
                for planet, _ in pairs(all_planets) do
                    local v = values[planet][dname]
                    if v and v < INITIAL_VALUE then
                        table.insert(parts, planet .. "=" .. string.format("%.1f", v))
                    end
                end
                if #parts > 0 then
                    lib.log("Solver: [diag] pass " .. s.iteration .. " " .. dname
                        .. ": " .. table.concat(parts, ", "))
                end
            end
        end

        if s.iteration % 10 == 0 then
            lib.log("Solver: pass " .. s.iteration .. " | updates=" .. s.pass_updates)
        end

        if s.pass_updates == 0 then
            lib.log("Solver: converged after " .. s.iteration .. " passes")
            s.phase = "finalize"
            return
        end

        s.recipe_idx = 1
        s.pass_updates = 0
    end
end

---Phase 3: Write solved values, compute interplanetary data, log provenance.
---@param s ItemValueSolver.State
local function phase_finalize(s)
    local values = s.values ---@type {[string]: {[string]: number}}
    local sources = s.sources ---@type {[string]: {[string]: ItemValueSource}}

    local all_planets = storage.SUPPORTED_PLANETS

    -- Build source planet strings for interplanetary items (cheapest import source)
    local is_interplanetary = s.is_interplanetary ---@type {[string]: {[string]: boolean}}
    local interplanetary = {}
    for planet, _ in pairs(all_planets) do
        interplanetary[planet] = {}
        for item_name in pairs(is_interplanetary[planet]) do
            if not is_non_transportable(item_name, s.nt_cache) then
                local best_src, best_cost = nil, INITIAL_VALUE
                for src, _ in pairs(all_planets) do
                    if src ~= planet then
                        local src_val = values[src][item_name]
                        if src_val and src_val < INITIAL_VALUE then
                            local cost = import_cost(s, src, planet, item_name, src_val)
                            if cost < best_cost then
                                best_cost = cost
                                best_src = src
                            end
                        end
                    end
                end
                if best_src then
                    interplanetary[planet][item_name] = best_src
                end
            end
        end
    end

    -- Write to storage
    local new_item_values = {}
    for planet, _ in pairs(all_planets) do
        local planet_values = {}
        for item_name, val in pairs(values[planet]) do
            if val < INITIAL_VALUE then
                planet_values[item_name] = val
            end
        end
        new_item_values[planet] = planet_values
        item_values.init_coin_values(planet_values)
    end

    storage.item_values.interplanetary = interplanetary
    storage.item_values.is_interplanetary = s.is_interplanetary
    storage.item_values.sources = s.sources
    item_values.set_item_values(new_item_values)

    ---Only used in logging
    ---@param source ItemValueSource|nil
    ---@return string
    local function source_string(source)
        if not source then return "unknown" end
        if source.type == "raw" then return "raw" end
        if source.type == "recipe" then return "recipe: " .. (source.recipe_name or "unknown") end
        if source.type == "import" then
            return "import: " .. table.concat(source.import_path or {}, " → ")
                .. " (" .. (source.distance or 0) .. " km)"
        end
        return "unknown"
    end

    -- Log final values with provenance per planet
    local total = 0
    local unresolved = {}
    for planet, _ in pairs(all_planets) do
        local planet_values = storage.item_values.values[planet]
        local ip_count = table_size(interplanetary[planet])
        local count = table_size(planet_values)
        total = total + count

        -- Sort items by value for readable output
        local sorted = {}
        for item_name, val in pairs(planet_values) do
            if not lib.is_coin(item_name) then
                table.insert(sorted, {name = item_name, value = val})
            end
        end
        table.sort(sorted, function(a, b) return a.value < b.value end)

        local str = "Solver: --- " .. planet .. " (" .. count .. " items, " .. ip_count .. " interplanetary) ---"
        for _, entry in pairs(sorted) do
            str = str .. string.format("\n  %-48s %20.3f | %s", entry.name, entry.value, source_string(sources[planet][entry.name]))
        end
        lib.log(str)
    end

    -- Collect unresolved items (no value on any planet)
    for item_name in pairs(values.nauvis) do
        if not lib.is_coin(item_name) then
            local has_value = false
            for planet, _ in pairs(all_planets) do
                if values[planet][item_name] and values[planet][item_name] < INITIAL_VALUE then
                    has_value = true
                    break
                end
            end
            if not has_value then table.insert(unresolved, item_name) end
        end
    end

    lib.log("Solver: complete! " .. total .. " item-planet pairs, "
        .. s.iteration .. " passes, " .. #unresolved .. " unresolved")
    if #unresolved > 0 then
        table.sort(unresolved)
        lib.log("Solver: unresolved: " .. table.concat(unresolved, ", "))

        -- For each unresolved item, find what's blocking it: which recipes produce it
        -- and which ingredients are missing values?
        local unresolved_set = {}
        for _, name in pairs(unresolved) do unresolved_set[name] = true end
        for _, name in pairs(unresolved) do
            local producing_recipes = {}
            for _, recipe in pairs(s.recipes) do
                for _, prod in pairs(recipe.products) do
                    if prod.name == name then
                        table.insert(producing_recipes, recipe)
                        break
                    end
                end
            end
            if #producing_recipes == 0 then
                lib.log("  " .. name .. ": no recipes")
            else
                for _, recipe in pairs(producing_recipes) do
                    local missing = {}
                    for _, ing in pairs(recipe.ingredients) do
                        local has_any = false
                        for planet, _ in pairs(all_planets) do
                            if values[planet][ing.name]
                            and values[planet][ing.name] < INITIAL_VALUE then
                                has_any = true
                                break
                            end
                        end
                        if not has_any then table.insert(missing, ing.name) end
                    end
                    if #missing > 0 then
                        lib.log("  " .. name .. " [" .. recipe.label .. "]: missing "
                            .. table.concat(missing, ", "))
                    else
                        -- All ingredients have values globally, but item is unresolved.
                        -- Show per-planet get_best_cost to find the blocker.
                        lib.log("  " .. name .. " [" .. recipe.label .. "]: all ingredients have values globally! Per-planet:")
                        for planet, _ in pairs(all_planets) do
                            if not recipe.valid_planets or recipe.valid_planets[planet] then
                                local blocked_ings = {}
                                for _, ing in pairs(recipe.ingredients) do
                                    local cost = get_best_cost(s, planet, ing.name)
                                    if cost >= INITIAL_VALUE then
                                        local ip = s.is_interplanetary[planet][ing.name] and "IP" or "local"
                                        local nt = is_non_transportable(ing.name, s.nt_cache) and "+NT" or ""
                                        table.insert(blocked_ings, ing.name .. "(" .. ip .. nt .. ")")
                                    end
                                end
                                if #blocked_ings > 0 then
                                    lib.log("    " .. planet .. ": blocked by " .. table.concat(blocked_ings, ", "))
                                else
                                    lib.log("    " .. planet .. ": ALL ingredients accessible — should have fired!")
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    storage.solver = nil
    game.print {"hextorio.solver-complete"}
    event_system.trigger "item-values-recalculated"
    event_system.trigger "post-item-values-recalculated"
end



function solver.process_step()
    if not is_active() then return end

    local s = storage.solver
    s.ticks_elapsed = s.ticks_elapsed + 1

    if s.ticks_elapsed > MAX_TICKS then
        lib.log("Solver: ABORTED after " .. MAX_TICKS .. " ticks (safety timeout)")
        game.print {"hextorio.solver-timeout"}
        storage.solver = nil
        return
    end

    if s.phase == "collect" then
        phase_collect(s)
    elseif s.phase == "build" then
        phase_build(s)
    elseif s.phase == "solve" then
        phase_solve(s)
    elseif s.phase == "finalize" then
        phase_finalize(s)
    end
end

function solver.run()
    if is_active() then return end

    game.print {"hextorio.solver-started"}
    storage.solver = {
        active = true,
        phase = "collect",
        ticks_elapsed = 0,
    }
end

function solver.init()
    for surface_name, raw_vals in pairs(storage.item_values.raw_values) do
        for resource, _ in pairs(raw_vals) do
            storage.item_values.raw_values[surface_name][resource] = lib.runtime_setting_value_as_number("raw-value-" .. surface_name .. "-" .. resource) * storage.item_values.base_coin_value
        end
    end

    solver.run()
end

function solver.register_events()
    event_system.register("command-solve-item-values", function(player)
        if is_active() then
            player.print {"hextorio.solver-already-running"}
            return
        end

        solver.run()
    end)

    local function create_handler(surface_name, resource)
        return function()
            storage.item_values.raw_values[surface_name][resource] = lib.runtime_setting_value_as_number("raw-value-" .. surface_name .. "-" .. resource) * storage.item_values.base_coin_value
            solver.run()
        end
    end

    for surface_name, raw_vals in pairs(data_item_values.raw_values) do
        for resource, _ in pairs(raw_vals) do
            event_system.register("runtime-setting-changed-raw-value-" .. surface_name .. "-" .. resource, create_handler(surface_name, resource))
        end
    end
end



return solver
