
local lib = require "api.lib"

-- Buff recipes
data.raw["recipe"]["rocket"].category = "organic-or-assembling"
data.raw["recipe"]["explosive-rocket"].category = "organic-or-assembling"

-- Custom recipes
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


-- local disintegrator_capsule = {
--     type = "recipe",
--     name = "disintegrator-capsule",
--     category = "metallurgy",
--     ingredients = {
--         {type = "item", name = "destroyer-capsule", amount = 6},
--         {type = "item", name = "processing-unit", amount = 10},
--         {type = "item", name = "tungsten-plate", amount = 50},
--         {type = "item", name = "flamethrower", amount = 1},
--         {type = "fluid", name = "lava", amount = 1000},
--     },
--     results = {
--         {type = "item", name = "disintegrator-capsule", amount = 1},
--     },
--     energy_required = 20,
--     enabled = false,
-- }

-- local detonator_capsule = {
--     type = "recipe",
--     name = "detonator-capsule",
--     category = "organic",
--     ingredients = {
--         {type = "item", name = "destroyer-capsule", amount = 6},
--         {type = "item", name = "processing-unit", amount = 10},
--         {type = "item", name = "plague-rocket", amount = 20},
--         {type = "item", name = "rocket-launcher", amount = 1},
--         {type = "fluid", name = "bioflux", amount = 10},
--     },
--     results = {
--         {type = "item", name = "detonator-capsule", amount = 1},
--     },
--     energy_required = 20,
--     enabled = false,
-- }

local demolisher_capsule = {
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
    energy_required = 20,
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
        {type = "item", name = "electromagnetic-penetrator", amount = 6},
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
    {type = "item", name = "crystalline-fuel", amount = 1},
    {type = "fluid", name = "fluoroketone-hot", amount = 50, temperature = 180},
}
crystalline_fuel.energy_required = 120
crystalline_fuel.main_product = "crystalline-fuel"

local plague_rocket = {
    type = "recipe",
    name = "plague-rocket",
    category = "organic",
    energy_required = 8,
    enabled = false,
    ingredients = {
        {type = "item", name = "rocket", amount = 1},
        {type = "item", name = "poison-capsule", amount = 1},
        {type = "item", name = "nutrients", amount = 10},
    },
    results = {
        {type = "item", name = "plague-rocket", amount = 1},
    },
}

local magmatic_rounds_magazine = {
    type = "recipe",
    name = "magmatic-rounds-magazine",
    category = "metallurgy",
    energy_required = 12,
    enabled = false,
    ingredients = {
        {type = "item", name = "piercing-rounds-magazine", amount = 1},
        {type = "item", name = "tungsten-plate", amount = 4},
        {type = "item", name = "tungsten-carbide", amount = 3},
        {type = "fluid", name = "lava", amount = 100},
    },
    results = {
        {type = "item", name = "magmatic-rounds-magazine", amount = 1},
    },
}

local casting_piercing_rounds_magazine = {
    type = "recipe",
    name = "casting-piercing-rounds-magazine",
    category = "metallurgy",
    energy_required = 3,
    enabled = false,
    ingredients = {
        {type = "item", name = "firearm-magazine", amount = 1},
        {type = "fluid", name = "molten-iron", amount = 10},
        {type = "fluid", name = "molten-copper", amount = 10},
    },
    results = {
        {type = "item", name = "piercing-rounds-magazine", amount = 1},
    },
}

local casting_firearm_magazine = {
    type = "recipe",
    name = "casting-firearm-magazine",
    category = "metallurgy",
    energy_required = 1,
    enabled = false,
    ingredients = {
        {type = "fluid", name = "molten-iron", amount = 25},
    },
    results = {
        {type = "item", name = "firearm-magazine", amount = 1},
    },
}

local electromagnetic_penetrator = {
    type = "recipe",
    name = "electromagnetic-penetrator",
    category = "cryogenics",
    energy_required = 20,
    enabled = false,
    ingredients = {
        {type = "item", name = "railgun", amount = 1},
        {type = "item", name = "teslagun", amount = 1},
        {type = "item", name = "hexaprism", amount = 8},
        {type = "item", name = "quantum-processor", amount = 25},
        {type = "fluid", name = "fluoroketone-cold", amount = 400},
    },
    results = {
        {type = "item", name = "electromagnetic-penetrator", amount = 1},
        {type = "fluid", name = "fluoroketone-hot", amount = 200, temperature = 180},
    },
    main_product = "electromagnetic-penetrator",
    icon = "__hextorio__/graphics/icons/electromagnetic-penetrator.png",
}

local electromagnetic_penetrator_cell = {
    type = "recipe",
    name = "electromagnetic-penetrator-cell",
    category = "cryogenics",
    energy_required = 50,
    enabled = false,
    ingredients = {
        {type = "item", name = "railgun-ammo", amount = 1},
        {type = "item", name = "tesla-ammo", amount = 10},
        {type = "item", name = "hexaprism", amount = 4},
    },
    results = {
        {type = "item", name = "electromagnetic-penetrator-cell", amount = 1},
    },
    icon = "__hextorio__/graphics/icons/electromagnetic-penetrator-cell.png",
}



---@diagnostic disable: assign-type-mismatch
data:extend({
    hexic_transport_belt,
    hexic_underground_belt,
    hexic_splitter,
    -- disintegrator_capsule,
    -- detonator_capsule,
    demolisher_capsule,
    electromagnetic_penetrator,
    electromagnetic_penetrator_cell,
    sentient_spider_recipe,
    energized_thruster_fuel,
    energized_thruster_oxidizer,
    crystalline_fuel,
    plague_rocket,
    magmatic_rounds_magazine,
    casting_piercing_rounds_magazine,
    casting_firearm_magazine,
})



-- SOVR Enrichment Process

local recipes = {}
for i = 2, 6 do
    local degrade_chance = (7 - i) * 0.02
    local sovr_enrichment_process = {
        type = "recipe",
        name = "sovr-enrichment-process-tier-" .. i,
        localised_name = {"recipe-name.sovr-enrichment-process", i .. "/6"},
        localised_description = {"", {"technology-description.sovr-enrichment-process"}, "\n", lib.color_localized_string({"recipe-description-extra.productivity-only-affects"}, "yellow", "default-semibold")},
        category = "organic",
        energy_required = 24,
        enabled = false,
        allow_productivity = true,
        allow_quality = false,
        auto_recycle = false,
        allow_decomposition = false,
        allow_as_intermediate = false,
        allow_intermediates = false,
        show_amount_in_title = false,
        unlock_results = false,
        always_show_products = true,
        hide_from_signal_gui = false,

        ingredients = {
            {type = "item", name = "hexadic-resonator-tier-" .. i, amount = 1},
            {type = "item", name = "hexaprism", amount = i * 6},
            {type = "item", name = "tungsten-ore", amount = i * 100},
            {type = "item", name = "raw-fish", amount = i},
        },
        results = {
            -- Chance of not degrading
            {type = "item", name = "hexadic-resonator-tier-" .. i, amount = 1, probability = 1 - degrade_chance, ignored_by_productivity = 1},

            -- Chance of degrading
            {type = "item", name = "hexadic-resonator-tier-" .. (i - 1), amount = 1, probability = degrade_chance, ignored_by_productivity = 1},

            -- Byproduct (what we want)
            {type = "item", name = "hexadic-resonator-tier-1", amount = 1, probability = i * 0.1},
        },
        icons = {
            {
                icon = "__hextorio__/graphics/icons/hexadic-resonator-" .. i .. ".png",
                icon_size = 64,
            },
            {
                icon = "__hextorio__/graphics/icons/cyclic-arrow.png",
                icon_size = 64,
            },
        },
        surface_conditions = {
            {
                property = "gravity",
                min = 0,
                max = 0,
            },
        },
        order = "r[recipe]-e[sovr-enrichment-process-" .. i .. "]",
    }
    table.insert(recipes, sovr_enrichment_process)
end
data:extend(recipes)

