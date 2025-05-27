
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
    r.category = "electromagnetics"
    local amount = {[module_type] = 3}
    r.ingredients = {
        {type = "item", name = "speed-module-3", amount = amount["speed"] or 1},
        {type = "item", name = "productivity-module-3", amount = amount["productivity"] or 1},
        {type = "item", name = "efficiency-module-3", amount = amount["efficiency"] or 1},
        {type = "item", name = "quality-module-3", amount = amount["quality"] or 1},
        {type = "item", name = "hexaprism", amount = 1},
        {type = "fluid", name = "fluoroketone-cold", amount = 200},
    }
    local product_name = "hexa-" .. module_type .. "-module"
    r.results = {
        {type = "item", name = product_name, amount = 1},
        {type = "fluid", name = "fluoroketone-hot", amount = 100, temperature = 180},
    }
    r.main_product = product_name
    r.always_show_made_in = true
    r.energy_required = 120
    table.insert(module_recipes, r)
end
data:extend(module_recipes)


local demolisher_recipe = {
    type = "recipe",
    name = "demolisher-capsule",
    category = "metallurgy",
    ingredients = {
        {type = "item", name = "destroyer-capsule", amount = 6},
        {type = "item", name = "quantum-processor", amount = 10},
        {type = "item", name = "railgun-ammo", amount = 20},
        {type = "item", name = "railgun", amount = 1},
        {type = "fluid", name = "molten-copper", amount = 1000},
        {type = "fluid", name = "molten-iron", amount = 1000},
    },
    results = {
        {type = "item", name = "demolisher-capsule", amount = 1},
    },
    energy_required = 1,
    enabled = false,
}

local sentient_spider_recipe = {
    type = "recipe",
    name = "sentient-spider",
    category = "cryogenics",
    ingredients = {
        {type = "item", name = "fusion-reactor", amount = 1},
        {type = "item", name = "fusion-generator", amount = 2},
        {type = "item", name = "quantum-processor", amount = 50},
        {type = "item", name = "spidertron", amount = 1},
        {type = "item", name = "raw-fish", amount = 100},
        {type = "item", name = "hexaprism", amount = 10},
        {type = "fluid", name = "fluoroketone-cold", amount = 1000},
        {type = "fluid", name = "lubricant", amount = 1000},
    },
    results = {
        {type = "item", name = "sentient-spider", amount = 1},
        {type = "fluid", name = "fluoroketone-hot", amount = 500, temperature = 180},
    },
    main_product = "sentient-spider",
    energy_required = 240,
    enabled = false,
}

local energized_thruster_fuel = table.deepcopy(data.raw["recipe"]["advanced-thruster-fuel"])
energized_thruster_fuel.name = "energized-thruster-fuel"
energized_thruster_fuel.enabled = false
energized_thruster_fuel.category = "chemistry-or-cryogenics"
energized_thruster_fuel.icon = "__hextorio__/graphics/icons/energized-thruster-fuel.png"
energized_thruster_fuel.ingredients = {
    {type = "item", name = "carbon", amount = 10},
    {type = "item", name = "calcite", amount = 5},
    {type = "item", name = "hexaprism", amount = 1},
    {type = "fluid", name = "water", amount = 1000},
}
energized_thruster_fuel.results = {
    {type = "fluid", name = "thruster-fuel", amount = 15000},
}
energized_thruster_fuel.energy_required = 15
energized_thruster_fuel.localised_name = nil

local energized_thruster_oxidizer = table.deepcopy(data.raw["recipe"]["advanced-thruster-oxidizer"])
energized_thruster_oxidizer.name = "energized-thruster-oxidizer"
energized_thruster_oxidizer.enabled = false
energized_thruster_oxidizer.category = "chemistry-or-cryogenics"
energized_thruster_oxidizer.icon = "__hextorio__/graphics/icons/energized-thruster-oxidizer.png"
energized_thruster_oxidizer.ingredients = {
    {type = "item", name = "iron-ore", amount = 10},
    {type = "item", name = "calcite", amount = 5},
    {type = "item", name = "hexaprism", amount = 1},
    {type = "fluid", name = "water", amount = 1000},
}
energized_thruster_oxidizer.results = {
    {type = "fluid", name = "thruster-oxidizer", amount = 15000},
}
energized_thruster_oxidizer.energy_required = 15
energized_thruster_oxidizer.localised_name = nil

local crystalline_fuel = table.deepcopy(data.raw["recipe"]["nuclear-fuel"])
crystalline_fuel.name = "crystalline-fuel"
crystalline_fuel.enabled = false
crystalline_fuel.category = "cryogenics"
crystalline_fuel.icon = "__hextorio__/graphics/icons/crystalline-fuel.png"
crystalline_fuel.ingredients = {
    {type = "item", name = "nuclear-fuel", amount = 1},
    {type = "item", name = "hexaprism", amount = 2},
    {type = "fluid", name = "fluoroketone-cold", amount = 100},
}
crystalline_fuel.results = {
    {type = "fluid", name = "crystalline-fuel", amount = 1},
    {type = "fluid", name = "fluoroketone-hot", amount = 50, temperature = 180},
}
crystalline_fuel.energy_required = 120

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({hexic_transport_belt, hexic_underground_belt, hexic_splitter, demolisher_recipe, sentient_spider_recipe, energized_thruster_fuel, energized_thruster_oxidizer, crystalline_fuel})
