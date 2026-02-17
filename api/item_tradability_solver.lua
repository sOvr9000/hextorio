
local lib = require "api.lib"
local sets = require "api.sets"
-- local item_values = require "api.item_values"
local event_system = require "api.event_system"

local item_tradability_solver = {}



---Science packs mapped to their planet of origin.
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
local PLANET_DEPTH = {
    nauvis = 0,
    vulcanus = 1,
    fulgora = 1,
    gleba = 1,
    aquilo = 2,
}

---Tiebreaker ordering for planets at the same depth.
local PLANET_TIEBREAK = {
    vulcanus = 1,
    fulgora = 2,
    gleba = 3,
}

---Items that are raw resources on each planet (used as forward propagation seeds).
local RAW_ITEMS = {
    nauvis = sets.new {
        "wood", "iron-ore", "copper-ore", "stone", "coal",
        "uranium-ore", "water", "crude-oil", "raw-fish",
    },
    vulcanus = sets.new {
        "coal", "calcite", "tungsten-ore", "sulfuric-acid", "lava",
    },
    fulgora = sets.new {
        "heavy-oil", "scrap",
    },
    gleba = sets.new {
        "stone", "water", "yumako", "jellynut",
        "wood", "pentapod-egg", "spoilage",
    },
    aquilo = sets.new {
        "ammoniacal-solution", "fluorine", "lithium-brine", "crude-oil",
    },
}



---Determine the origin planet for a technology based on its science pack requirements.
---Returns the planet with the deepest (hardest) non-Nauvis science pack.
---@param research_unit_ingredients Ingredient[]
---@return string planet_name
local function get_tech_origin(research_unit_ingredients)
    local best_planet = "nauvis"
    local best_depth = 0
    local best_tiebreak = 0

    for _, ingredient in pairs(research_unit_ingredients) do
        local planet = SCIENCE_PACK_PLANET[ingredient.name]
        if planet then
            local depth = PLANET_DEPTH[planet] or 0
            local tiebreak = PLANET_TIEBREAK[planet] or 0
            if depth > best_depth or (depth == best_depth and tiebreak > best_tiebreak) then
                best_planet = planet
                best_depth = depth
                best_tiebreak = tiebreak
            end
        end
    end

    return best_planet
end

---Collect all recipes and determine their origin planet.
---Returns:
---  recipes: table of normalized recipe data keyed by name
---  recipe_origin: maps recipe_name -> planet of origin
---  recipe_valid_planets: maps recipe_name -> valid planet set (from surface conditions), or nil
---@return table, table<string, string>, table<string, table<string, boolean>|nil>
local function collect_recipes_and_origins()
    local recipes = {}
    local recipe_origin = {}
    local recipe_valid_planets = {}

    -- Build tech_name -> origin planet mapping
    local tech_origin = {}
    local tech_unlocks_recipes = {} ---@type table<string, string[]>
    for name, tech in pairs(prototypes.technology) do
        tech_origin[name] = get_tech_origin(tech.research_unit_ingredients)
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
    local category_vp = lib.build_category_valid_planets(categories)

    -- Collect recipes
    for name, recipe in pairs(prototypes.recipe) do
        if not recipe.hidden or recipe.category == "recycling" then
            local ok, data = pcall(lib.extract_recipe_data, recipe)
            if ok and data and #data.ingredients > 0 and #data.products > 0 then
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

                local recipe_vp = lib.get_valid_planets(data.surface_conditions)
                local cat_vp = category_vp[data.category]
                recipe_valid_planets[name] = lib.intersect_valid_planets(recipe_vp, cat_vp)
            end
        end
    end

    -- Add spoil and burnt_result pseudo-recipes (1:1, no surface restrictions).
    local seed_items = {}
    for _, data in pairs(recipes) do
        for _, prod in pairs(data.products) do seed_items[prod.name] = true end
        for _, ing in pairs(data.ingredients) do seed_items[ing.name] = true end
    end
    for _, planet_raws in pairs(RAW_ITEMS) do
        for item_name in pairs(planet_raws) do seed_items[item_name] = true end
    end
    for _, p in pairs(lib.collect_spoil_burnt_chains(seed_items)) do
        recipes[p.label] = {
            ingredients = {{name = p.source, amount = 1}},
            products = {{name = p.result, amount = 1}},
        }
    end

    return recipes, recipe_origin, recipe_valid_planets
end

---Build the set of candidate recipes for a given planet.
---A recipe is a candidate if its surface conditions (and crafting machine conditions)
---allow it on this planet, regardless of tech origin. Forward propagation handles
---balance: only items whose full ingredient chain is locally satisfiable become tradable.
---@param planet string
---@param recipes table
---@param recipe_valid_planets table<string, table<string, boolean>|nil>
---@return table<string, boolean>
local function get_candidate_recipes(planet, recipes, recipe_valid_planets)
    local candidates = {}
    for recipe_name in pairs(recipes) do
        local vp = recipe_valid_planets[recipe_name]
        if not vp or vp[planet] then
            candidates[recipe_name] = true
        end
    end
    return candidates
end

---Forward-propagate from raw resources through candidate recipes to find all
---producible items on a planet.
---
---Runs in two phases:
---  1. Propagate without always_fire to find locally producible items.
---  2. Propagate with always_fire, but recycling recipes only fire on
---     locally produced inputs (not items sourced from interplanetary recipes).
---@param planet string
---@param candidates table<string, boolean>
---@param recipes table
---@param always_fire table<string, boolean> Planet-origin recipes that fire unconditionally
---@return table<string, boolean> available_items
local function forward_propagate(planet, candidates, recipes, always_fire)
    local available = {}
    local raw = RAW_ITEMS[planet] or {}
    for item_name in pairs(raw) do
        available[item_name] = true
    end

    local fired = {}

    -- Phase 1: propagate without always_fire to find locally producible items.
    local changed = true
    while changed do
        changed = false
        for recipe_name in pairs(candidates) do
            if not fired[recipe_name] and not always_fire[recipe_name] then
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

    -- Phase 2: add always_fire recipes, but recycling only fires on local items.
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
        local candidates = get_candidate_recipes(planet, recipes, recipe_valid_planets)

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

    for surface_name, surface_tradable_items in pairs(is_tradable) do
        log("tradable items on surface " .. surface_name .. ":\n" .. serpent.block(surface_tradable_items))
    end

    lib.log("Tradability solver: complete")
end

function item_tradability_solver.register_events()
    -- event_system.register("post-solve-item-values", function()
    --     tradability.solve()
    -- end)
end



return item_tradability_solver
