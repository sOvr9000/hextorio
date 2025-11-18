
return {
    item_buffs = {
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
        ["uranium-ore"] = {
            {
                type = "mining-speed",
                value = 0.08,
                level_scaling = 1.1,
            },
        },
        ["tungsten-ore"] = {
            {
                type = "mining-speed",
                value = 0.10,
                level_scaling = 1.1,
            },
        },
        ["tungsten-plate"] = {
            {
                type = "recipe-productivity",
                values = {"tungsten-plate", 0.05},
                level_scaling = 1.05,
            },
        },
        ["scrap"] = {
            {
                type = "mining-productivity",
                value = 0.05,
                level_scaling = 1.05,
            },
        },
        ["holmium-ore"] = {
            {
                type = "recipe-productivity",
                values = {"scrap-recycling", 0.10},
                level_scaling = 1.13,
            },
        },
        ["holmium-plate"] = {
            {
                type = "recipe-productivity",
                values = {"holmium-plate", 0.05},
                level_scaling = 1.05,
            },
        },
        ["iron-plate"] = {
            {
                type = "inventory-size",
                value = 1,
                level_scaling = 1.2,
            },
        },
        ["copper-plate"] = {
            {
                type = "inventory-size",
                value = 1,
                level_scaling = 1.2,
            },
        },
        ["steel-plate"] = {
            {
                type = "inventory-size",
                value = 1,
                level_scaling = 1.2,
            },
        },
        ["beacon"] = {
            {
                type = "beacon-efficiency",
                value = 0.05,
                level_scaling = 1.03,
            },
        },
        ["stack-inserter"] = {
            {
                type = "belt-stack-size",
                value = 1,
                level_scaling = 1.05,
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
                value = 0.06,
                level_scaling = 1.1,
            },
        },
        ["iron-stick"] = {
            {
                type = "crafting-speed",
                value = 0.06,
                level_scaling = 1.1,
            },
        },
        ["copper-cable"] = {
            {
                type = "crafting-speed",
                value = 0.06,
                level_scaling = 1.1,
            },
        },
        ["firearm-magazine"] = {
            {
                type = "physical-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["piercing-rounds-magazine"] = {
            {
                type = "physical-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["uranium-rounds-magazine"] = {
            {
                type = "physical-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["magmatic-rounds-magazine"] = {
            {
                type = "physical-damage",
                value = 0.08,
                level_scaling = 1.1,
            },
            {
                type = "fire-damage",
                value = 0.08,
                level_scaling = 1.1,
            },
        },
        ["gun-turret"] = {
            {
                type = "recipe-productivity",
                values = {"firearm-magazine", 0.05},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"piercing-rounds-magazine", 0.05},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"uranium-rounds-magazine", 0.05},
                level_scaling = 1.05,
            },
        },
        ["rocket-turret"] = {
            {
                type = "recipe-productivity",
                values = {"rocket", 0.05},
                level_scaling = 1.05,
            },
        },
        ["laser-turret"] = {
            {
                type = "laser-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["flamethrower-turret"] = {
            {
                type = "recipe-productivity",
                values = {"heavy-oil-cracking-to-light-oil", 0.05},
                level_scaling = 1.05,
            },
        },
        ["tesla-turret"] = {
            {
                type = "electric-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["teslagun"] = {
            {
                type = "electric-shooting-speed",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["submachine-gun"] = {
            {
                type = "bullet-shooting-speed",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["electronic-circuit"] = {
            {
                type = "recipe-productivity",
                values = {"electronic-circuit", 0.08},
                level_scaling = 1.07,
            },
        },
        ["productivity-module"] = {
            {
                type = "trade-productivity",
                value = 0.01,
                level_scaling = 1.07,
            },
        },
        ["productivity-module-2"] = {
            {
                type = "trade-productivity",
                value = 0.01,
                level_scaling = 1.07,
            },
        },
        ["productivity-module-3"] = {
            {
                type = "trade-productivity",
                value = 0.02,
                level_scaling = 1.07,
            },
        },
        ["hexa-productivity-module"] = {
            {
                type = "trade-productivity",
                value = 0.04,
                level_scaling = 1.10,
            },
        },
        ["speed-module"] = {
            {
                type = "crafting-speed",
                value = 0.20,
                level_scaling = 1.11,
            },
        },
        ["speed-module-2"] = {
            {
                type = "crafting-speed",
                value = 0.25,
                level_scaling = 1.11,
            },
        },
        ["speed-module-3"] = {
            {
                type = "crafting-speed",
                value = 0.30,
                level_scaling = 1.12,
            },
        },
        ["hexa-speed-module"] = {
            {
                type = "crafting-speed",
                value = 0.50,
                level_scaling = 1.15,
            },
        },
        ["efficiency-module"] = {
            {
                type = "recipe-productivity",
                values = {"electronic-circuit", 0.08},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 1.05,
            },
        },
        ["efficiency-module-2"] = {
            {
                type = "recipe-productivity",
                values = {"advanced-circuit", 0.08},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 1.05,
            },
        },
        ["efficiency-module-3"] = {
            {
                type = "recipe-productivity",
                values = {"processing-unit", 0.08},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.03,
                level_scaling = 1.05,
            },
        },
        ["hexa-efficiency-module"] = {
            {
                type = "recipe-productivity",
                values = {"quantum-processor", 0.08},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.05,
                level_scaling = 1.05,
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
        ["lithium-plate"] = {
            {
                type = "inventory-size",
                value = 5,
                level_scaling = 1.2,
            },
        },
        ["hexaprism"] = {
            {
                type = "all-buffs-level",
                value = 1,
                level_scaling = 1.12,
            },
        },
        ["sentient-spider"] = {
            {
                type = "all-buffs-level",
                value = 1,
                level_scaling = 1.12,
            },
        },
    },

    show_as_linear = { -- Numbers aren't percentages for these buff types
        ["reach-distance"] = true,
        ["build-distance"] = true,
        ["inventory-size"] = true,
        ["all-buffs-level"] = true,
        ["belt-stack-size"] = true,
    },

    has_description = {
        ["all-buffs-level"] = true,
        ["all-buffs-cost-reduced"] = true,
    },

    is_fractional = { -- Some bonuses like inventory slots must be integers, so the fractional bonuses are combined here to then be rounded before applying.
        ["reach-distance"] = true,
        ["build-distance"] = true,
        ["inventory-size"] = true,
        ["all-buffs-level"] = true,
        ["belt-stack-size"] = true,
    },

    is_nonlinear = { -- Bonuses themselves are typically multipliers, and those multipliers grow exponentially (although slower than cost), but those multiplying factors are incremented linearly, as seen in the item_buffs API.  It's bonuses like cost reduction, compounding for each separate bonus, that are truly nonlinear.
        ["all-buffs-cost-reduced"] = true,
    },

    unlocked = {},
    enabled = {},
    levels = {},
    cost = {},

    fractional_bonuses = {},

    cost_multiplier = 1,
    level_bonus = 0,
}
