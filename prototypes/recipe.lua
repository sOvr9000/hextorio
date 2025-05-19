
local hexic_transport_belt = table.deepcopy(data.raw["recipe"]["turbo-transport-belt"])
hexic_transport_belt.name = "hexic-transport-belt"
hexic_transport_belt.icon = "__hextorio__/graphics/icons/hexic-transport-belt.png"
hexic_transport_belt.enabled = false
hexic_transport_belt.ingredients = {
    {type = "item", name = "turbo-transport-belt", amount = 25},
    {type = "item", name = "lithium-plate", amount = 5},
    {type = "item", name = "tungsten-plate", amount = 100},
    {type = "item", name = "holmium-plate", amount = 40},
    {type = "item", name = "carbon-fiber", amount = 50},
    {type = "fluid", name = "sulfuric-acid", amount = 1000},
    {type = "fluid", name = "lubricant", amount = 500},
}
hexic_transport_belt.results = {
    {type = "item", name = "hexic-transport-belt", amount = 25},
}
hexic_transport_belt.energy_required = 15

local hexic_underground_belt = table.deepcopy(data.raw["recipe"]["turbo-underground-belt"])
hexic_underground_belt.name = "hexic-underground-belt"
hexic_underground_belt.icon = "__hextorio__/graphics/icons/hexic-underground-belt.png"
hexic_underground_belt.enabled = false
hexic_underground_belt.ingredients = {
    {type = "item", name = "turbo-underground-belt", amount = 8},
    {type = "item", name = "lithium-plate", amount = 10},
    {type = "item", name = "tungsten-plate", amount = 200},
    {type = "item", name = "holmium-plate", amount = 16},
    {type = "item", name = "carbon-fiber", amount = 20},
    {type = "fluid", name = "sulfuric-acid", amount = 320},
    {type = "fluid", name = "lubricant", amount = 160},
}
hexic_underground_belt.results = {
    {type = "item", name = "hexic-underground-belt", amount = 8},
}
hexic_underground_belt.energy_required = 8

local hexic_splitter = table.deepcopy(data.raw["recipe"]["turbo-splitter"]) --[[@as data.RecipePrototype]]
hexic_splitter.name = "hexic-splitter"
hexic_splitter.icon = "__hextorio__/graphics/icons/hexic-splitter.png"
hexic_splitter.enabled = false
hexic_splitter.ingredients = {
    {type = "item", name = "turbo-splitter", amount = 1},
    {type = "item", name = "tungsten-plate", amount = 20},
    {type = "item", name = "holmium-plate", amount = 4},
    {type = "item", name = "carbon-fiber", amount = 5},
    {type = "item", name = "quantum-processor", amount = 1},
    {type = "fluid", name = "sulfuric-acid", amount = 160},
    {type = "fluid", name = "lubricant", amount = 80},
}
hexic_splitter.results = {
    {type = "item", name = "hexic-splitter", amount = 1},
}
hexic_splitter.energy_required = 8


local module_recipes = {}
for _, module_type in pairs {"speed", "productivity", "efficiency", "quality"} do
    local r = table.deepcopy(data.raw["recipe"][module_type .. "-module-3"])
    r.name = "hexa-" .. module_type .. "-module"
    -- r.icon = "__hextorio__/graphics/icons/hexa-" .. module_type .. "-module.png"
    r.enabled = false
    local amount = {[module_type] = 9}
    r.ingredients = {
        {type = "item", name = "speed-module-3", amount = amount["speed"] or 3},
        {type = "item", name = "productivity-module-3", amount = amount["productivity"] or 3},
        {type = "item", name = "efficiency-module-3", amount = amount["efficiency"] or 3},
        {type = "item", name = "quality-module-3", amount = amount["quality"] or 3},
    }
    r.results = {
        {type = "item", name = "hexa-" .. module_type .. "-module", amount = 1},
    }
    r.energy_required = 120
    table.insert(module_recipes, r)
end
data:extend(module_recipes)


---@diagnostic disable-next-line: assign-type-mismatch
data:extend({hexic_transport_belt, hexic_underground_belt, hexic_splitter})
