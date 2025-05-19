
local transport_belt_capacity_3 = table.deepcopy(data.raw["technology"]["transport-belt-capacity-1"])
transport_belt_capacity_3.name = "transport-belt-capacity-3"
transport_belt_capacity_3.prerequisites = {"transport-belt-capacity-2"}
transport_belt_capacity_3.unit = {
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
}

data:extend({transport_belt_capacity_3})
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
        name = "hextreme-quality",
        icon = "__hextorio__/graphics/technology/hextreme-quality.png",
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
                type  = "unlock-quality",
                quality = "hextreme",
            },
        },
    },

    {
        type = "technology",
        name = "hexa-modules",
        icon = "__hextorio__/graphics/technology/hexa-modules.png",
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
})
