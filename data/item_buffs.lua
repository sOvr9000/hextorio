
return {
    item_buffs = {
        ["copper-cable"] = {
            {
                type = "crafting-speed",
                value = 0.05,
                level_scaling = 1.1,
            },
        },
        ["iron-ore"] = {
            {
                type = "mining-speed",
                value = 0.05,
                level_scaling = 1.1,
            },
        },
        ["stone"] = {
            {
                type = "mining-speed",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["copper-ore"] = {
            {
                type = "mining-speed",
                value = 0.06,
                level_scaling = 1.1,
            },
        },
        ["coal"] = {
            {
                type = "mining-speed",
                value = 0.07,
                level_scaling = 1.1,
            },
        },
        ["iron-plate"] = {
            {
                type = "inventory-size",
                value = 0.05,
                level_scaling = 1.1,
            },
        },
        ["transport-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["underground-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["splitter"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["fast-transport-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["fast-underground-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["fast-splitter"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["express-transport-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["express-underground-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["express-splitter"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["turbo-transport-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["turbo-underground-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["turbo-splitter"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["hexic-transport-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["hexic-underground-belt"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["hexic-splitter"] = {
            {
                type = "build-distance",
                value = 0.5,
                level_scaling = 1.2,
            },
        },
        ["electric-mining-drill"] = {
            {
                type = "mining-productivity",
                value = 0.05,
                level_scaling = 1.2,
            },
        },
        ["big-mining-drill"] = {
            {
                type = "mining-productivity",
                value = 0.10,
                level_scaling = 1.5,
            },
        },
        ["stone-brick"] = {
            {
                type = "moving-speed",
                value = 0.05,
                level_scaling = 1.4,
            },
        },
        ["concrete"] = {
            {
                type = "moving-speed",
                value = 0.06,
                level_scaling = 1.4,
            },
        },
        ["refined-concrete"] = {
            {
                type = "moving-speed",
                value = 0.07,
                level_scaling = 1.4,
            },
        },
        ["refined-hazard-concrete"] = {
            {
                type = "moving-speed",
                value = 0.08,
                level_scaling = 1.4,
            },
        },
        ["foundation"] = {
            {
                type = "moving-speed",
                value = 0.05,
                level_scaling = 1.1,
            },
        },
        ["iron-gear-wheel"] = {
            {
                type = "crafting-speed",
                value = 0.05,
                level_scaling = 1.1,
            },
        },
        ["iron-stick"] = {
            {
                type = "crafting-speed",
                value = 0.05,
                level_scaling = 1.1,
            },
        },
        ["logistic-robot"] = {
            {
                type = "robot-battery",
                value = 0.10,
                level_scaling = 1.1,
            },
        },
        ["construction-robot"] = {
            {
                type = "robot-speed",
                value = 0.10,
                level_scaling = 1.1,
            },
        },
        ["roboport"] = {
            {
                type = "robot-speed",
                value = 0.10,
                level_scaling = 1.1,
            },
            {
                type = "robot-battery",
                value = 0.10,
                level_scaling = 1.1,
            },
        },
        ["advanced-circuit"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 1.1,
            },
        },
        ["processing-unit"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 1.1,
            },
        },
    },

    show_as_linear = { -- Numbers aren't percentages for these buff types
        ["reach-distance"] = true,
        ["inventory-size"] = true,
    },

    unlocked = {},
    enabled = {},
    levels = {},
    cost = {},

    global_cost_reduction = 0,
    global_amplifier = 0,
}
