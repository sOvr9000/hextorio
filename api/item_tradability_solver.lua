
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
local solver_util = require "api.solver_util"

local item_tradability_solver = {}



---@class ItemTradabilitySolver.RecipeData
---@field ingredients ItemTradabilitySolver.ItemAmount[] Input items and amounts
---@field products ItemTradabilitySolver.ItemAmount[] Output items and expected (average) amounts
---@field category string|nil Recipe category (e.g. "recycling"), nil for pseudo-recipes like burnt or spoil products
---@field surface_conditions SurfaceCondition[]|nil Surface conditions from the recipe prototype

---@class ItemTradabilitySolver.ItemAmount
---@field name string Item or fluid prototype name
---@field amount number Quantity (expected value if probabilistic)



---Science packs mapped to their planet of origin.
---TODO: automate this based on surface conditions of science pack recipes (better for mod compatibility)
local SCIENCE_PACK_PLANET = {
    ["automation-science-pack"] = "nauvis",
    ["logistic-science-pack"] = "nauvis",
    ["chemical-science-pack"] = "nauvis",
    ["military-science-pack"] = "nauvis",
    ["production-science-pack"] = "nauvis",
    ["utility-science-pack"] = "nauvis",
    ["metallurgic-science-pack"] = "vulcanus",
    ["electromagnetic-science-pack"] = "fulgora",
    ["agricultural-science-pack"] = "gleba",
    ["cryogenic-science-pack"] = "aquilo",
}

---Planet depth in the progression hierarchy.
---TODO: automate this based on tech tree
local PLANET_DEPTH = {
    nauvis = 0,
    vulcanus = 1,
    fulgora = 1,
    gleba = 1,
    aquilo = 2,
}

---Tiebreaker ordering for planets at the same depth.
---TODO: automate
local PLANET_TIEBREAK = {
    vulcanus = 1,
    fulgora = 2,
    gleba = 3,
}



---Pick the deeper of two planet origins, using tiebreak for same-depth.
---@param a string
---@param b string
---@return string
local function deeper_origin(a, b)
    local da, db = PLANET_DEPTH[a] or 0, PLANET_DEPTH[b] or 0
    if da > db then return a end
    if db > da then return b end
    local ta, tb = PLANET_TIEBREAK[a] or 0, PLANET_TIEBREAK[b] or 0
    return ta >= tb and a or b
end

---Determine the origin planet for a technology based on its science pack requirements.
---Returns the planet with the deepest (hardest) non-Nauvis science pack.
---@param research_unit_ingredients Ingredient[]
---@return string planet_name
local function get_science_origin(research_unit_ingredients)
    local best = "nauvis"
    for _, ingredient in pairs(research_unit_ingredients) do
        local planet = SCIENCE_PACK_PLANET[ingredient.name]
        if planet then
            best = deeper_origin(best, planet)
        end
    end
    return best
end

---Planet discovery technologies that act as gateway markers.
local PLANET_DISCOVERY_TECH = {
    ["planet-discovery-vulcanus"] = "vulcanus",
    ["planet-discovery-fulgora"] = "fulgora",
    ["planet-discovery-gleba"] = "gleba",
    ["planet-discovery-aquilo"] = "aquilo",
}

---Build a table mapping tech_name -> effective origin planet.
---A tech's effective origin is the deepest among its own science pack origin,
---any planet discovery tech in its prerequisite chain, and all its
---prerequisites' effective origins.
---@return {[string]: string} tech_name -> origin planet
local function build_tech_origins()
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
        local origin = PLANET_DISCOVERY_TECH[name]
            or science_origins[name] or "nauvis"
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
            if has_proto then
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
