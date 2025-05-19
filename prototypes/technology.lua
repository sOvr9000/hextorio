
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
})
