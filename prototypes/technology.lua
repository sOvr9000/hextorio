
local lib = require "api.lib"



local transport_belt_capacity_3 = table.deepcopy(data.raw["technology"]["transport-belt-capacity-2"])
transport_belt_capacity_3.name = "transport-belt-capacity-3"
transport_belt_capacity_3.prerequisites = {"transport-belt-capacity-2", "hexic-logistics"}
transport_belt_capacity_3.unit = {
    count = 5000,
    time = 60,
    ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"promethium-science-pack", 1},
    },
}
table.insert(transport_belt_capacity_3.effects, {
    type = "bulk-inserter-capacity-bonus",
    modifier = 4,
})

local sentient_spider = table.deepcopy(data.raw["technology"]["spidertron"])
sentient_spider.name = "sentient-spider"
sentient_spider.prerequisites = {"spidertron", "promethium-science-pack"}
sentient_spider.unit = {
    count = 5000,
    time = 60,
    ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"cryogenic-science-pack", 1},
        {"promethium-science-pack", 1},
    },
}
sentient_spider.effects = {
    {
        type = "unlock-recipe",
        recipe = "sentient-spider",
    }
}

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({transport_belt_capacity_3, sentient_spider})


if lib.data.is_hextreme_enabled() then
    data:extend({
        {
            type = "technology",
            name = "hextreme-quality",
            icon = "__hextorio__/graphics/technology/hextreme-quality.png",
            icon_size = 256,
            prerequisites = {"promethium-science-pack", "legendary-quality"},
            unit = {
                count = 5000,
                time = 60,
                ingredients = {
                    {"automation-science-pack", 1},
                    {"logistic-science-pack", 1},
                    {"chemical-science-pack", 1},
                    {"production-science-pack", 1},
                    {"utility-science-pack", 1},
                    {"space-science-pack", 1},
                    {"metallurgic-science-pack", 1},
                    {"electromagnetic-science-pack", 1},
                    {"agricultural-science-pack", 1},
                    {"cryogenic-science-pack", 1},
                    {"promethium-science-pack", 1},
                },
            },
            effects = {
                {
                    type  = "unlock-quality",
                    quality = "hextreme",
                },
            },
        },
    })
end


local demolisher = table.deepcopy(data.raw["technology"]["destroyer"])
demolisher.name = "demolisher"
demolisher.unit = {
    count = 5000,
    time = 60,
    ingredients = {
        {"automation-science-pack", 1},
        {"logistic-science-pack", 1},
        {"military-science-pack", 1},
        {"chemical-science-pack", 1},
        {"production-science-pack", 1},
        {"utility-science-pack", 1},
        {"space-science-pack", 1},
        {"metallurgic-science-pack", 1},
        {"electromagnetic-science-pack", 1},
        {"agricultural-science-pack", 1},
        {"cryogenic-science-pack", 1},
    },
}
demolisher.prerequisites = {"destroyer", "railgun"}
demolisher.effects = {
    {
        type  = "unlock-recipe",
        recipe = "demolisher-capsule",
    },
}
demolisher.localised_name = nil
demolisher.localised_description = nil


---@diagnostic disable-next-line: assign-type-mismatch
data:extend({demolisher})



data:extend({
    {
        type = "technology",
        name = "hexic-logistics",
        icon = "__hextorio__/graphics/technology/hexic-logistics.png",
        icon_size = 256,
        prerequisites = {"turbo-transport-belt", "cryogenic-science-pack"},
        unit = {
            count = 2000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"metallurgic-science-pack", 1},
                {"electromagnetic-science-pack", 1},
                {"agricultural-science-pack", 1},
                {"cryogenic-science-pack", 1},
            },
        },
        effects = {
            {
                type  = "unlock-recipe",
                recipe = "hexic-transport-belt",
            },
            {
                type  = "unlock-recipe",
                recipe = "hexic-underground-belt",
            },
            {
                type  = "unlock-recipe",
                recipe = "hexic-splitter",
            },
        },
    },

    {
        type = "technology",
        name = "hexa-modules",
        icon = "__hextorio__/graphics/technology/hexa-modules.png",
        icon_size = 256,
        prerequisites = {"promethium-science-pack", "productivity-module-3", "speed-module-3", "efficiency-module-3", "quality-module-3"},
        unit = {
            count = 5000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"metallurgic-science-pack", 1},
                {"electromagnetic-science-pack", 1},
                {"agricultural-science-pack", 1},
                {"cryogenic-science-pack", 1},
                {"promethium-science-pack", 1},
            },
        },
        effects = {
            {
                type  = "unlock-recipe",
                recipe = "hexa-speed-module",
            },
            {
                type  = "unlock-recipe",
                recipe = "hexa-productivity-module",
            },
            {
                type  = "unlock-recipe",
                recipe = "hexa-efficiency-module",
            },
            {
                type  = "unlock-recipe",
                recipe = "hexa-quality-module",
            },
        },
    },

    {
        type = "technology",
        name = "energized-thruster-fuel",
        icon = "__hextorio__/graphics/technology/energized-thruster-fuel.png",
        icon_size = 256,
        prerequisites = {"promethium-science-pack"},
        unit = {
            count = 5000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"metallurgic-science-pack", 1},
                {"electromagnetic-science-pack", 1},
                {"agricultural-science-pack", 1},
                {"cryogenic-science-pack", 1},
                {"promethium-science-pack", 1},
            },
        },
        effects = {
            {
                type  = "unlock-recipe",
                recipe = "energized-thruster-fuel",
            },
            {
                type  = "unlock-recipe",
                recipe = "energized-thruster-oxidizer",
            },
            {
                type  = "change-recipe-productivity",
                recipe = "thruster-fuel",
                change = 0.2,
            },
            {
                type  = "change-recipe-productivity",
                recipe = "thruster-oxidizer",
                change = 0.2,
            },
            {
                type  = "change-recipe-productivity",
                recipe = "advanced-thruster-fuel",
                change = 0.15,
            },
            {
                type  = "change-recipe-productivity",
                recipe = "advanced-thruster-oxidizer",
                change = 0.15,
            },
            {
                type  = "change-recipe-productivity",
                recipe = "energized-thruster-fuel",
                change = 0.1,
            },
            {
                type  = "change-recipe-productivity",
                recipe = "energized-thruster-oxidizer",
                change = 0.1,
            },
        },
    },

    {
        type = "technology",
        name = "crystalline-fuel",
        icon = "__hextorio__/graphics/technology/crystalline-fuel.png",
        icon_size = 256,
        prerequisites = {"promethium-science-pack", "kovarex-enrichment-process"},
        unit = {
            count = 2000,
            time = 60,
            ingredients = {
                {"automation-science-pack", 1},
                {"logistic-science-pack", 1},
                {"chemical-science-pack", 1},
                {"production-science-pack", 1},
                {"utility-science-pack", 1},
                {"space-science-pack", 1},
                {"metallurgic-science-pack", 1},
                {"electromagnetic-science-pack", 1},
                {"agricultural-science-pack", 1},
                {"cryogenic-science-pack", 1},
                {"promethium-science-pack", 1},
            },
        },
        effects = {
            {
                type  = "unlock-recipe",
                recipe = "crystalline-fuel",
            },
        },
    },
})
