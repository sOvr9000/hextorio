
--[[
Determines which items are tradable on each planet.
Generally, an item is tradable on a planet if it can be produced from the planet's raw resources (local producibility).
Other constraints are applied based on which technologies unlock which recipes and where.
(e.g. nutrients can be produced on Nauvis but are only tradable on Gleba)

Each recipe gets an "origin planet" derived from the techs that unlock them.
Nauvis-origin recipes are available everywhere, minus those that just aren't usable.
Other recipes only exist on their original planet (e.g. productivity module 3 only tradable on Gleba, not Aquilo).
Surface conditions and machine restrictions filter further.
(e.g. captive biter spawner locks biter egg recipe to Nauvis, but that recipe is unlocked on Gleba, so biter eggs are completely untradable)

Initially, the tradable set for each planet is the result of processing all usable recipes on raw resources and the subsequent products.
(e.g. Fulgora: scrap -> iron gear wheel -> iron plate -> iron stick -> ...)

TWO-PHASE PROPAGATION handles a complicated edge case.
Some planet-origin recipes need to be traversed even when their ingredients aren't locally reachable.
(e.g. biter eggs from Nauvis being used to make productivity mode 3, so that prod 3 modules can be tradable on Gleba)

But how do we prevent recycling recipes on Aquilo from processing on imported items?

PHASE 1 lets everything propagate naturally from raw resources and usable recipes on each planet, with recycling recipes included.
(e.g. Fulgora's necessary recycling, or Aquilo's ammoniacal solution -> rocket fuel chain)

PHASE 2 traverses the remaining planet-origin recipes with imports allowed but ignoring recycling recipes.
(e.g. Aquilo receives holmium plates and processes only the lithium recipe, not also EM plants with other imported items)

Overall, this whole system prevents weird edge cases from occurring like nutrients on Nauvis, biter eggs on Gleba, nuclear reactors on Aquilo, etc.
]]



local lib = require "api.lib"
local item_values = require "api.item_values"
local solver_util = require "api.solver_util"
local event_system = require "api.event_system"

local item_tradability_solver = {}



---@class ItemTradabilitySolver.RecipeData
---@field ingredients ItemTradabilitySolver.ItemAmount[] Input items and amounts
---@field products ItemTradabilitySolver.ItemAmount[] Output items and expected (average) amounts
---@field category string|nil Recipe category (e.g. "recycling"), nil for pseudo-recipes like burnt or spoil products
---@field surface_conditions SurfaceCondition[]|nil Surface conditions from the recipe prototype

---@class ItemTradabilitySolver.ItemAmount
---@field name string Item or fluid prototype name
---@field amount number Quantity (expected value if probabilistic)



---@return StringSet item_name -> true for all science pack items
local function build_science_pack_set()
    local science_packs = {}
    for _, entity in pairs(prototypes.entity) do
        local inputs = entity.lab_inputs
        if inputs then
            for _, item_name in pairs(inputs) do
                science_packs[item_name] = true
            end
        end
    end
    return science_packs
end

---@return {[string]: string[]} tech_name -> successor tech names
local function build_tech_successors()
    local successors = {}
    for name in pairs(prototypes.technology) do successors[name] = {} end
    for name, tech in pairs(prototypes.technology) do
        for _, prereq in pairs(tech.prerequisites or {}) do
            local list = successors[prereq.name]
            if list then table.insert(list, name) end
        end
    end
    return successors
end

---Find technologies that unlock a planet surface via "unlock-space-location" effects.
---@return {[string]: string} tech_name -> planet_name
local function find_planet_discovery_techs()
    local result = {}
    for name, tech in pairs(prototypes.technology) do
        for _, effect in pairs(tech.effects or {}) do
            if effect.type == "unlock-space-location" then
                local loc_name = effect.space_location
                local loc = loc_name and prototypes.space_location[loc_name]
                if loc and loc.surface_properties then
                    result[name] = loc_name
                    break
                end
            end
        end
    end
    return result
end

---Find tech names not in visited whose all prerequisites are in visited.
---@param visited StringSet
---@param successors {[string]: string[]}
---@return string[]
local function find_frontier_techs(visited, successors)
    local frontier = {}
    local seen = {}
    for tech_name in pairs(visited) do
        for _, succ in ipairs(successors[tech_name] or {}) do
            if not visited[succ] and not seen[succ] then
                seen[succ] = true
                local all_v = true
                for _, prereq in pairs(prototypes.technology[succ].prerequisites or {}) do
                    if not visited[prereq.name] then all_v = false; break end
                end
                if all_v then table.insert(frontier, succ) end
            end
        end
    end
    return frontier
end

---BFS one level from start_names, treating visited_in as already-visited (not mutated).
---Stops at planet discovery tech boundaries; records them but does not traverse past them.
---@param start_names string[]
---@param visited_in StringSet
---@param successors {[string]: string[]}
---@param pd_techs {[string]: string}
---@param recipe_produces_sp {[string]: string[]}
---@return StringSet found_sp
---@return {[string]: string} found_pd  -- tech_name -> planet_name for each boundary hit
---@return StringSet visited_out  -- visited_in union newly visited
local function bfs_layer(start_names, visited_in, successors, pd_techs, recipe_produces_sp)
    local visited = {}
    for k in pairs(visited_in) do visited[k] = true end

    local queue = {}
    for _, name in ipairs(start_names) do
        if not visited[name] then
            visited[name] = true
            table.insert(queue, name)
        end
    end

    local found_sp = {}
    local found_pd = {}
    local i = 1
    while i <= #queue do
        local tech_name = queue[i]
        i = i + 1
        if pd_techs[tech_name] then
            found_pd[tech_name] = pd_techs[tech_name]
        else
            local tech = prototypes.technology[tech_name]
            for _, effect in pairs(tech.effects or {}) do
                if effect.type == "unlock-recipe" then
                    local sp_items = recipe_produces_sp[effect.recipe]
                    if sp_items then
                        for _, item_name in ipairs(sp_items) do found_sp[item_name] = true end
                    end
                end
            end
            for _, succ in ipairs(successors[tech_name] or {}) do
                if not visited[succ] then
                    local all_v = true
                    for _, prereq in pairs(prototypes.technology[succ].prerequisites or {}) do
                        if not visited[prereq.name] then all_v = false; break end
                    end
                    if all_v then visited[succ] = true; table.insert(queue, succ) end
                end
            end
        end
    end

    return found_sp, found_pd, visited
end

---Auto-detect science pack planet origins, planet depths, planet tiebreaks, and planet
---discovery technologies from entity and technology prototypes.
---Science packs are detected via lab entity lab_inputs.
---Planet depths and science pack origins are determined by BFS from root technologies,
---stopping at planet-discovery tech boundaries, then recursing per planet.
---Results are written into storage.item_values.
local function auto_detect_planet_data()
    local science_pack_set = build_science_pack_set()
    local pd_techs = find_planet_discovery_techs()
    local successors = build_tech_successors()

    local recipe_produces_sp = {} ---@type {[string]: string[]}
    for name, recipe in pairs(prototypes.recipe) do
        for _, product in pairs(recipe.products or {}) do
            if science_pack_set[product.name] then
                recipe_produces_sp[name] = recipe_produces_sp[name] or {}
                table.insert(recipe_produces_sp[name], product.name)
            end
        end
    end

    local sp_planet = {}
    local planet_d = {nauvis = 0}
    local planet_tb = {}
    local tiebreak_counter = 1

    -- Science packs from start-enabled recipes (no unlock required) belong to Nauvis
    for _, recipe in pairs(prototypes.recipe) do
        if recipe.enabled then
            for _, product in pairs(recipe.products or {}) do
                if science_pack_set[product.name] then
                    sp_planet[product.name] = "nauvis"
                end
            end
        end
    end

    local roots = {}
    for name, tech in pairs(prototypes.technology) do
        if not next(tech.prerequisites or {}) then table.insert(roots, name) end
    end

    local sp_0, boundaries, visited = bfs_layer(roots, {}, successors, pd_techs, recipe_produces_sp)
    for sp in pairs(sp_0) do
        if not sp_planet[sp] then sp_planet[sp] = "nauvis" end
    end

    local depth = 1
    while next(boundaries) do
        local sorted = {}
        for tech_name, planet_name in pairs(boundaries) do
            table.insert(sorted, {tech = tech_name, planet = planet_name})
        end
        table.sort(sorted, function(a, b) return a.planet < b.planet end)

        local visited_base = visited
        local next_boundaries = {}
        local merged_new = {}

        for _, entry in ipairs(sorted) do
            if not planet_d[entry.planet] then
                planet_d[entry.planet] = depth
                planet_tb[entry.planet] = tiebreak_counter
                tiebreak_counter = tiebreak_counter + 1
            end
            local sp, child_pd, v_out = bfs_layer({entry.tech}, visited_base, successors, pd_techs, recipe_produces_sp)
            for sp_name in pairs(sp) do
                if not sp_planet[sp_name] then sp_planet[sp_name] = entry.planet end
            end
            for t, p in pairs(child_pd) do next_boundaries[t] = next_boundaries[t] or p end
            for k in pairs(v_out) do merged_new[k] = true end
        end

        for k in pairs(merged_new) do visited[k] = true end

        -- Gap-fill: find boundaries now reachable from the merged visited set.
        -- Handles planets whose discovery tech requires prerequisites across multiple siblings.
        local frontier = find_frontier_techs(visited, successors)
        if #frontier > 0 then
            local _, gap_pd, gap_v = bfs_layer(frontier, visited, successors, pd_techs, recipe_produces_sp)
            for t, p in pairs(gap_pd) do next_boundaries[t] = next_boundaries[t] or p end
            for k in pairs(gap_v) do visited[k] = true end
        end

        boundaries = next_boundaries
        depth = depth + 1
    end

    storage.item_values.science_pack_planet = sp_planet
    storage.item_values.planet_depth = planet_d
    storage.item_values.planet_tiebreak = planet_tb
    storage.item_values.planet_discovery_tech = pd_techs
end



---Pick the deeper of two planet origins, using tiebreak for same-depth.
---@param a string
---@param b string
---@return string
local function deeper_origin(a, b)
    local depth = storage.item_values.planet_depth
    local da, db = depth[a] or 0, depth[b] or 0
    if da > db then return a end
    if db > da then return b end
    local tiebreak = storage.item_values.planet_tiebreak
    local ta, tb = tiebreak[a] or 0, tiebreak[b] or 0
    return ta >= tb and a or b
end

---Determine the origin planet for a technology based on its science pack requirements.
---Returns the planet with the deepest (hardest) non-Nauvis science pack.
---@param research_unit_ingredients Ingredient[]
---@return string planet_name
local function get_science_origin(research_unit_ingredients)
    local sp_planet = storage.item_values.science_pack_planet
    local best = "nauvis"
    for _, ingredient in pairs(research_unit_ingredients) do
        local planet = sp_planet[ingredient.name]
        if planet then
            best = deeper_origin(best, planet)
        end
    end
    return best
end

---Build a table mapping tech_name -> effective origin planet.
---A tech's effective origin is the deepest among its own science pack origin,
---any planet discovery tech in its prerequisite chain, and all its
---prerequisites' effective origins.
---@return {[string]: string} tech_name -> origin planet
local function build_tech_origins()
    local pd_tech = storage.item_values.planet_discovery_tech
    local science_origins = {}
    local prerequisites = {} ---@type {[string]: string[]}
    for name, tech in pairs(prototypes.technology) do
        science_origins[name] = get_science_origin(tech.research_unit_ingredients)
        local prereq_names = {}
        for _, prereq in pairs(tech.prerequisites or {}) do
            table.insert(prereq_names, prereq.name)
        end
        prerequisites[name] = prereq_names
    end

    local cache = {}
    local function resolve(name)
        if cache[name] then return cache[name] end
        local origin = pd_tech[name] or science_origins[name] or "nauvis"
        for _, prereq_name in pairs(prerequisites[name] or {}) do
            origin = deeper_origin(origin, resolve(prereq_name))
        end
        cache[name] = origin
        return origin
    end

    local result = {}
    for name in pairs(science_origins) do
        result[name] = resolve(name)
    end
    return result
end

---Collect all recipes and determine their origin planet.
---@return {[string]: ItemTradabilitySolver.RecipeData} recipes Normalized recipe data keyed by name
---@return {[string]: string} recipe_origin Recipe name -> origin planet
---@return {[string]: {[string]: boolean}|nil} recipe_valid_planets Recipe name -> set of valid planets (nil = all)
local function collect_recipes_and_origins()
    local recipes = {}
    local recipe_origin = {}
    local recipe_valid_planets = {}

    -- Build tech_name -> effective origin planet (considering prerequisites)
    local tech_origin = build_tech_origins()
    local tech_unlocks_recipes = {} ---@type {[string]: string[]}
    for name, tech in pairs(prototypes.technology) do
        tech_unlocks_recipes[name] = {}
        for _, effect in pairs(tech.effects) do
            if effect.type == "unlock-recipe" then
                table.insert(tech_unlocks_recipes[name], effect.recipe)
            end
        end
    end

    -- Build recipe_name -> tech_name mapping (first tech that unlocks it)
    local recipe_to_tech = {}
    for tech_name, recipe_names in pairs(tech_unlocks_recipes) do
        for _, recipe_name in pairs(recipe_names) do
            if not recipe_to_tech[recipe_name] then
                recipe_to_tech[recipe_name] = tech_name
            end
        end
    end

    -- Build category -> valid planets from crafting machine surface conditions
    local categories = {}
    for name, recipe in pairs(prototypes.recipe) do
        if not recipe.hidden or recipe.category == "recycling" then
            categories[recipe.category] = true
        end
    end
    local category_vp = solver_util.build_category_valid_planets(categories)

    -- Collect recipes
    for name, recipe in pairs(prototypes.recipe) do
        if not recipe.hidden or recipe.category == "recycling" then
            local data = solver_util.extract_recipe_data(recipe)
            if data and #data.ingredients > 0 and #data.products > 0 then
                recipes[name] = data

                local tech_name = recipe_to_tech[name]
                if tech_name then
                    recipe_origin[name] = tech_origin[tech_name]
                elseif recipe.enabled then
                    recipe_origin[name] = "nauvis"
                else
                    -- Hidden behind a tech we didn't find; skip
                    recipe_origin[name] = nil
                end

                local recipe_vp = solver_util.get_valid_planets(data.surface_conditions)
                local cat_vp = category_vp[data.category]
                recipe_valid_planets[name] = solver_util.intersect_valid_planets(recipe_vp, cat_vp)
            end
        end
    end

    -- Add spoil and burnt_result pseudo-recipes (1:1, no surface restrictions).
    local seed_items = {}
    for _, data in pairs(recipes) do
        for _, prod in pairs(data.products) do seed_items[prod.name] = true end
        for _, ing in pairs(data.ingredients) do seed_items[ing.name] = true end
    end
    for _, planet_raws in pairs(storage.item_values.raw_values) do
        for item_name in pairs(planet_raws) do seed_items[item_name] = true end
    end
    for _, p in pairs(solver_util.collect_spoil_burnt_chains(seed_items)) do
        recipes[p.label] = {
            ingredients = {{name = p.source, amount = 1}},
            products = {{name = p.result, amount = 1}},
        }
    end

    return recipes, recipe_origin, recipe_valid_planets
end

---Build the set of candidate recipes for a given planet.
---A recipe is a candidate if its origin is "nauvis" (universal) or this planet,
---and its surface/entity conditions allow it here. Recipes without a known origin
---(pseudo-recipes, some recycling) are always included.
---@param planet string
---@param recipes {[string]: ItemTradabilitySolver.RecipeData}
---@param recipe_origin {[string]: string}
---@param recipe_valid_planets {[string]: {[string]: boolean}|nil}
---@return {[string]: boolean} candidate_set Recipe names that can run on this planet
local function get_candidate_recipes(planet, recipes, recipe_origin, recipe_valid_planets)
    local candidates = {}
    for recipe_name in pairs(recipes) do
        local origin = recipe_origin[recipe_name]
        if not origin or origin == "nauvis" or origin == planet then
            local vp = recipe_valid_planets[recipe_name]
            if not vp or vp[planet] then
                candidates[recipe_name] = true
            end
        end
    end
    return candidates
end

---Forward-propagate from raw resources through candidate recipes to find all
---producible items on a planet.
---
---Runs in two phases:
---  1. Propagate naturally from raw resources — all candidates participate.
---  2. Force-fire remaining planet-origin recipes, but recycling only fires on
---     items from Phase 1 (prevents decomposition cascades).
---@param planet string
---@param candidates {[string]: boolean} Candidate recipe names for this planet
---@param recipes {[string]: ItemTradabilitySolver.RecipeData}
---@param always_fire {[string]: boolean} Planet-origin recipes that fire unconditionally in Phase 2
---@return {[string]: boolean} available_items Set of all producible item names
local function forward_propagate(planet, candidates, recipes, always_fire)
    local available = {}
    local raw = storage.item_values.raw_values[planet] or {}
    for item_name in pairs(raw) do
        available[item_name] = true
    end

    local fired = {}

    -- Phase 1: propagate naturally from raw resources, checking ingredients.
    -- All candidates (including planet-origin) participate, but must earn their
    -- way through the ingredient chain. This captures Fulgora's scrap→recycling
    -- chains as locally produced.
    local changed = true
    while changed do
        changed = false
        for recipe_name in pairs(candidates) do
            if not fired[recipe_name] then
                local data = recipes[recipe_name]
                local can_fire = true
                for _, ing in pairs(data.ingredients) do
                    if not available[ing.name] then
                        can_fire = false
                        break
                    end
                end
                if can_fire then
                    fired[recipe_name] = true
                    for _, prod in pairs(data.products) do
                        if not available[prod.name] then
                            available[prod.name] = true
                            changed = true
                        end
                    end
                end
            end
        end
    end

    local locally_produced = {}
    for item_name in pairs(available) do
        locally_produced[item_name] = true
    end

    -- Phase 2: fire always_fire recipes unconditionally (for planet-origin recipes
    -- whose ingredients aren't locally available). Recycling only fires on items
    -- from Phase 1 to prevent decomposition cascades from unconditional products.
    changed = true
    while changed do
        changed = false
        for recipe_name in pairs(candidates) do
            if not fired[recipe_name] then
                local data = recipes[recipe_name]
                local is_recycling = data.category == "recycling"
                local can_fire = always_fire[recipe_name]
                if not can_fire then
                    can_fire = true
                    for _, ing in pairs(data.ingredients) do
                        local pool = is_recycling and locally_produced or available
                        if not pool[ing.name] then
                            can_fire = false
                            break
                        end
                    end
                end
                if can_fire then
                    fired[recipe_name] = true
                    for _, prod in pairs(data.products) do
                        if not available[prod.name] then
                            available[prod.name] = true
                            changed = true
                        end
                    end
                end
            end
        end
    end

    return available
end

function item_tradability_solver.init()
    auto_detect_planet_data()
    item_tradability_solver.solve()
end

function item_tradability_solver.register_events()
    event_system.register("item-values-recalculated", item_tradability_solver.solve)
end

---Solve tradability for all planets and populate storage.item_values.is_tradable.
function item_tradability_solver.solve()
    lib.log("Tradability solver: starting")

    local recipes, recipe_origin, recipe_valid_planets = collect_recipes_and_origins()

    local is_tradable = {}
    for planet, _ in pairs(storage.SUPPORTED_PLANETS) do
        local candidates = get_candidate_recipes(planet, recipes, recipe_origin, recipe_valid_planets)

        -- Planet-origin recipes always fire (their products belong here by tech tree).
        -- Nauvis-origin recipes must earn their way through forward propagation.
        local always_fire = {}
        for recipe_name in pairs(candidates) do
            if recipe_origin[recipe_name] == planet and planet ~= "nauvis" then
                always_fire[recipe_name] = true
            end
        end

        local available = forward_propagate(planet, candidates, recipes, always_fire)

        local planet_tradable = {}
        local count = 0
        for item_name in pairs(available) do
            local has_proto = prototypes.item[item_name] or prototypes.fluid[item_name]
            if has_proto and item_values.has_item_value(planet, item_name) then
                planet_tradable[item_name] = true
                count = count + 1
            end
        end

        is_tradable[planet] = planet_tradable
        lib.log("Tradability solver: " .. planet .. " — " .. count .. " tradable items")
    end

    storage.item_values.is_tradable = is_tradable

    lib.log("Tradability solver: complete")
end



return item_tradability_solver
