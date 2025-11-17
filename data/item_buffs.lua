
return {
    item_buffs = {
        ["iron-ore"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 1.1,
            },
            {
                type = "all-buffs-amplified",
                value = 0.02,
                level_scaling = 1.1,
            },
        },
        ["copper-ore"] = {
            {
                type = "mining-speed",
                value = 0.10,
                level_scaling = 1.1,
            },
        },
        ["coal"] = {
            {
                type = "mining-speed",
                value = 0.15,
                level_scaling = 1.1,
            },
        },
    },

    show_as_linear = { -- Numbers aren't percentages for these buff types
        ["reach-distance"] = true,
    },

    unlocked = {},
    enabled = {},
    levels = {},
    cost = {},

    global_cost_reduction = 0,
    global_amplifier = 0,
}
