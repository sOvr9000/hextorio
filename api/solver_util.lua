
-- Shared helpers for the item value solver and item tradability solver.
-- Handles recipe extraction, surface condition checks, and pseudo-recipe generation.

local solver_util = {}



---@param recipe LuaRecipePrototype
---@return string[]
function solver_util.extract_recipe_categories(recipe)
    local categories = {}
    for _, category in pairs(recipe.categories or {}) do
        table.insert(categories, category)
    end
    return categories
end

---@param categories string[]|nil
---@param category string
---@return boolean
function solver_util.categories_include(categories, category)
    for _, candidate in pairs(categories or {}) do
        if candidate == category then return true end
    end
    return false
end

---@param recipe LuaRecipePrototype
---@param category string
---@return boolean
function solver_util.recipe_has_category(recipe, category)
    return solver_util.categories_include(solver_util.extract_recipe_categories(recipe), category)
end

---@param categories string[]|nil
---@param category_valid_planets {[string]: {[string]: boolean}}
---@return {[string]: boolean}|nil
function solver_util.get_categories_valid_planets(categories, category_valid_planets)
    local valid_planets = {}
    local has_restriction = false
    for _, category in pairs(categories or {}) do
        local category_vp = category_valid_planets[category]
        if not category_vp then return nil end
        has_restriction = true
        for planet in pairs(category_vp) do
            valid_planets[planet] = true
        end
    end
    if not has_restriction then return nil end
    return valid_planets
end

---Extract normalized recipe data from a LuaRecipePrototype.
---@param recipe LuaRecipePrototype
---@return ItemValueSolver.CollectedRecipe|nil
function solver_util.extract_recipe_data(recipe)
    local ingredients = {}
    for _, ing in pairs(recipe.ingredients) do
        table.insert(ingredients, {name = ing.name, amount = ing.amount})
    end
    local products = {}
    for i, prod in pairs(recipe.products) do
        local expected = recipe.get_product_amount(i, 0) -- TODO: Account for base productivity like +50% from foundries if the recipe can only be produced in such a building
        if expected > 0 then
            table.insert(products, {name = prod.name, amount = expected})
        end
    end
    if #products == 0 then return nil end

    local categories = solver_util.extract_recipe_categories(recipe)
    return {
        energy = recipe.energy,
        category = categories[1],
        categories = categories,
        ingredients = ingredients,
        products = products,
        surface_conditions = recipe.surface_conditions,
    }
end

---Determine which planets a recipe/entity can be used on based on surface conditions.
---Returns nil if unrestricted (usable everywhere).
---@param surface_conditions SurfaceCondition[]|nil
---@return {[string]: boolean}|nil
function solver_util.get_valid_planets(surface_conditions)
    if not surface_conditions or #surface_conditions == 0 then return nil end

    local valid = {}
    for planet_name, _ in pairs(storage.SUPPORTED_PLANETS) do
        local planet_proto = prototypes.space_location[planet_name]
        local props = planet_proto and planet_proto.surface_properties or {}
        local all_met = true
        for _, cond in pairs(surface_conditions) do
            local val = props[cond.property]
            if val == nil then
                local sp = prototypes.surface_property[cond.property]
                if sp then val = sp.default_value end
            end
            if val == nil then
                all_met = false
                break
            end
            local cmin = cond.min or 0
            local cmax = cond.max or math.huge
            if val < cmin or val > cmax then
                all_met = false
                break
            end
        end
        if all_met then valid[planet_name] = true end
    end

    return valid
end

---Build a map from recipe category to valid planets based on crafting machine surface conditions.
---For each category, find all entities that can craft it, and union their valid planets.
---If no entity restricts the category, returns nil for that category (meaning all planets).
---@param categories {[string]: boolean}
---@return {[string]: {[string]: boolean}}
function solver_util.build_category_valid_planets(categories)
    local result = {}
    for category in pairs(categories) do
        local entities = prototypes.get_entity_filtered(
            {{filter = "crafting-category", crafting_category = category}})

        local has_entities = false
        local union = {}
        for _, entity in pairs(entities) do
            has_entities = true
            local sc = entity.object_name == "LuaEntityPrototype" and entity.surface_conditions or nil
            local entity_vp = solver_util.get_valid_planets(sc)
            if not entity_vp then
                union = nil
                break
            end
            for p in pairs(entity_vp) do union[p] = true end
        end

        if has_entities and union then
            result[category] = union
        end
    end
    return result
end

---Intersect two "valid planet" sets. nil means "all planets".
---@param a {[string]: boolean}|nil
---@param b {[string]: boolean}|nil
---@return {[string]: boolean}|nil
function solver_util.intersect_valid_planets(a, b)
    if not a then return b end
    if not b then return a end
    local result = {}
    for p in pairs(a) do
        if b[p] then result[p] = true end
    end
    return result
end

---Collect spoil and burnt_result pseudo-recipes starting from a set of seed items.
---Follows chains so A -> B -> C are all discovered.
---@param seed_items {[string]: boolean} Set of item names to start from
---@return {source: string, result: string, label: string}[]
function solver_util.collect_spoil_burnt_chains(seed_items)
    local pseudo_recipes = {}
    local queue = {}
    for item_name in pairs(seed_items) do
        table.insert(queue, item_name)
    end

    local visited = {}
    local idx = 1
    while idx <= #queue do
        local item_name = queue[idx]
        if not visited[item_name] then
            visited[item_name] = true
            local proto = prototypes.item[item_name]
            if proto and not proto.hidden then
                if proto.spoil_result then
                    local result = proto.spoil_result.name
                    table.insert(pseudo_recipes, {
                        source = item_name, result = result,
                        label = item_name .. " spoil",
                    })
                    if not visited[result] then
                        table.insert(queue, result)
                    end
                end
                if proto.burnt_result then
                    local result = proto.burnt_result.name
                    table.insert(pseudo_recipes, {
                        source = item_name, result = result,
                        label = item_name .. " burnt",
                    })
                    if not visited[result] then
                        table.insert(queue, result)
                    end
                end
            end
        end
        idx = idx + 1
    end

    return pseudo_recipes
end



return solver_util
