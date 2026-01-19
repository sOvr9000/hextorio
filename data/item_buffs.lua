
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
                values = {"tungsten-plate", 5},
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
                values = {"scrap-recycling", 10},
                level_scaling = 1.13,
            },
        },
        ["holmium-plate"] = {
            {
                type = "recipe-productivity",
                values = {"holmium-plate", 5},
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
                value = 0.15,
                level_scaling = 1.04,
            },
        },
        ["fast-inserter"] = {
            {
                type = "inserter-capacity",
                value = 1,
                level_scaling = 1.04,
            },
        },
        ["bulk-inserter"] = {
            {
                type = "bulk-inserter-capacity",
                value = 1,
                level_scaling = 1.04,
            },
        },
        ["stack-inserter"] = {
            {
                type = "belt-stack-size",
                value = 1,
                level_scaling = 1.05,
            },
        },
        ["yumako"] = {
            {
                type = "health",
                value = 5,
                level_scaling = 1.04,
            },
        },
        ["jellynut"] = {
            {
                type = "health",
                value = 5,
                level_scaling = 1.04,
            },
        },
        ["yumako-seed"] = {
            {
                type = "health",
                value = 10,
                level_scaling = 1.2,
            },
        },
        ["jellynut-seed"] = {
            {
                type = "health",
                value = 10,
                level_scaling = 1.2,
            },
        },
        ["carbon-fiber"] = {
            {
                type = "recipe-productivity",
                values = {"carbon-fiber", 5},
                level_scaling = 1.07,
            },
        },
        ["automation-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"automation-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["logistic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"logistic-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["military-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"military-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["chemical-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"chemical-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["production-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"production-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["utility-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"utility-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        -- No way to level up space sci; it's untradable
        ["metallurgic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"metallurgic-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["electromagnetic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"electromagnetic-science-pack", 5},
                level_scaling = 1.08,
            },
        },
        ["agricultural-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"agricultural-science-pack", 5},
                level_scaling = 1.09,
            },
        },
        ["cryogenic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"cryogenic-science-pack", 5},
                level_scaling = 1.1,
            },
        },
        ["promethium-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"promethium-science-pack", 5},
                level_scaling = 1.1,
            },
        },
        ["lithium"] = {
            {
                type = "recipe-productivity",
                values = {"lithium", 5},
                level_scaling = 1.1,
            },
        },
        ["biter-egg"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.05,
                level_scaling = 0.025,
            },
        },
        ["pentapod-egg"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.05,
                level_scaling = 0.025,
            },
        },
        ["lab"] = {
            {
                type = "research-productivity",
                value = 0.06,
                level_scaling = 1.05,
            },
        },
        ["biolab"] = {
            {
                type = "research-speed",
                value = 0.5,
                level_scaling = 1.3,
            },
        },
        ["lightning-rod"] = {
            {
                type = "passive-coins",
                value = 0.02,
                level_scaling = 1.08,
            },
        },
        ["lightning-collector"] = {
            {
                type = "passive-coins",
                value = 0.03,
                level_scaling = 1.08,
            },
        },
        ["wooden-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["iron-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.1,
                level_scaling = 0.1,
            },
        },
        ["steel-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.15,
                level_scaling = 0.15,
            },
        },
        ["requester-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["buffer-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["storage-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["passive-provider-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["active-provider-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["defender-capsule"] = {
            {
                type = "combat-robot-count",
                value = 5,
                level_scaling = 1.1,
            },
        },
        ["distractor-capsule"] = {
            {
                type = "combat-robot-count",
                value = 5,
                level_scaling = 1.1,
            },
        },
        ["destroyer-capsule"] = {
            {
                type = "combat-robot-lifetime",
                value = 0.1,
                level_scaling = 1.05,
            },
        },
        ["demolisher-capsule"] = {
            {
                type = "combat-robot-lifetime",
                value = 0.1,
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
                level_scaling = 1.1,
            },
        },
        ["big-mining-drill"] = {
            {
                type = "mining-productivity",
                value = 0.10,
                level_scaling = 1.2,
            },
        },
        ["stone-brick"] = {
            {
                type = "moving-speed",
                value = 0.04,
                level_scaling = 1.08,
            },
        },
        ["concrete"] = {
            {
                type = "moving-speed",
                value = 0.05,
                level_scaling = 1.08,
            },
        },
        ["refined-concrete"] = {
            {
                type = "moving-speed",
                value = 0.06,
                level_scaling = 1.08,
            },
        },
        ["refined-hazard-concrete"] = {
            {
                type = "moving-speed",
                value = 0.07,
                level_scaling = 1.08,
            },
        },
        ["foundation"] = {
            {
                type = "moving-speed",
                value = 0.08,
                level_scaling = 1.08,
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
                type = "bullet-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["piercing-rounds-magazine"] = {
            {
                type = "bullet-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["uranium-rounds-magazine"] = {
            {
                type = "bullet-damage",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["magmatic-rounds-magazine"] = {
            {
                type = "bullet-damage",
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
                values = {"firearm-magazine", 5},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"piercing-rounds-magazine", 5},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"uranium-rounds-magazine", 5},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"magmatic-rounds-magazine", 15},
                level_scaling = 1.05,
            },
        },
        ["rocket-turret"] = {
            {
                type = "recipe-productivity",
                values = {"rocket", 5},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"explosive-rocket", 5},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"plague-rocket", 5},
                level_scaling = 1.05,
            },
            {
                type = "recipe-productivity",
                values = {"atomic-bomb", 5},
                level_scaling = 1.05,
            },
            {
                type = "explosion-damage",
                value = 0.08,
                level_scaling = 1.1,
            },
        },
        ["plague-rocket"] = {
            {
                type = "recipe-productivity",
                values = {"bioflux", 5},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"nutrients-from-bioflux", 5},
                level_scaling = 1.1,
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
                values = {"heavy-oil-cracking", 5},
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
        ["rocket-launcher"] = {
            {
                type = "rocket-shooting-speed",
                value = 0.04,
                level_scaling = 1.1,
            },
        },
        ["electronic-circuit"] = {
            {
                type = "recipe-productivity",
                values = {"electronic-circuit", 8},
                level_scaling = 1.07,
            },
        },
        ["quality-module"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module", 10},
                level_scaling = 1.1,
            },
        },
        ["quality-module-2"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module-2", 10},
                level_scaling = 1.1,
            },
        },
        ["quality-module-3"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module-3", 10},
                level_scaling = 1.1,
            },
        },
        ["hexa-quality-module"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module", 25},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"quality-module-2", 25},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"quality-module-3", 25},
                level_scaling = 1.1,
            },
        },
        ["productivity-module"] = {
            {
                type = "trade-productivity",
                value = 0.02,
                level_scaling = 1.07,
            },
        },
        ["productivity-module-2"] = {
            {
                type = "trade-productivity",
                value = 0.02,
                level_scaling = 1.07,
            },
        },
        ["productivity-module-3"] = {
            {
                type = "trade-productivity",
                value = 0.04,
                level_scaling = 1.07,
            },
        },
        ["hexa-productivity-module"] = {
            {
                type = "trade-productivity",
                value = 0.08,
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
                values = {"electronic-circuit", 8},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 0.02,
            },
        },
        ["efficiency-module-2"] = {
            {
                type = "recipe-productivity",
                values = {"advanced-circuit", 8},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.03,
                level_scaling = 0.03,
            },
        },
        ["efficiency-module-3"] = {
            {
                type = "recipe-productivity",
                values = {"processing-unit", 8},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["hexa-efficiency-module"] = {
            {
                type = "recipe-productivity",
                values = {"quantum-processor", 8},
                level_scaling = 1.07,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.1,
                level_scaling = 0.1,
            },
        },
        ["logistic-robot"] = {
            {
                type = "robot-cargo-size",
                value = 1,
                level_scaling = 1.05,
            },
        },
        ["construction-robot"] = {
            {
                type = "robot-speed",
                value = 0.10,
                level_scaling = 1.07,
            },
        },
        ["roboport"] = {
            {
                type = "robot-battery",
                value = 0.10,
                level_scaling = 1.05,
            },
        },
        ["spidertron"] = {
            {
                type = "trade-productivity",
                value = 0.05,
                level_scaling = 1.03,
            },
        },
        ["rocket-silo"] = {
            {
                type = "recipe-productivity",
                values = {"rocket-part", 5},
                level_scaling = 1.04,
            },
        },
        ["advanced-circuit"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.02,
                level_scaling = 0.02,
            },
        },
        ["processing-unit"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.03,
                level_scaling = 0.03,
            },
        },
        ["lithium-plate"] = {
            {
                type = "inventory-size",
                value = 5,
                level_scaling = 1.15,
            },
        },
        ["raw-fish"] = {
            {
                type = "all-buffs-level",
                value = 1,
                level_scaling = 0.25,
            },
        },
        ["hexaprism"] = {
            {
                type = "all-buffs-level",
                value = 1,
                level_scaling = 0.25,
            },
        },
        ["sentient-spider"] = {
            {
                type = "all-buffs-level",
                value = 1,
                level_scaling = 0.25,
            },
            {
                type = "all-buffs-cost-reduced",
                value = 0.25,
                level_scaling = 0.25,
            },
        },
        ["locomotive"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 1.1,
            },
            {
                type = "train-trading-capacity",
                value = 2,
                level_scaling = 1.1,
            },
        },
        ["cargo-wagon"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 1.1,
            },
            {
                type = "train-trading-capacity",
                value = 1,
                level_scaling = 1.1,
            },
        },
        ["fluid-wagon"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 1.1,
            },
        },
        ["artillery-wagon"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 1.1,
            },
        },
        ["assembling-machine-1"] = {
            {
                type = "recipe-productivity",
                values = {"iron-gear-wheel", 5},
                level_scaling = 1.08,
            },
            {
                type = "recipe-productivity",
                values = {"casting-iron-gear-wheel", 6},
                level_scaling = 1.08,
            },
        },
        ["assembling-machine-2"] = {
            {
                type = "recipe-productivity",
                values = {"copper-cable", 5},
                level_scaling = 1.09,
            },
            {
                type = "recipe-productivity",
                values = {"casting-copper-cable", 6},
                level_scaling = 1.09,
            },
        },
        ["assembling-machine-3"] = {
            {
                type = "recipe-productivity",
                values = {"engine-unit", 5},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"electric-engine-unit", 5},
                level_scaling = 1.1,
            },
        },
        ["chemical-plant"] = {
            {
                type = "recipe-productivity",
                values = {"lubricant", 7.5},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"pump", 7.5},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"storage-tank", 7.5},
                level_scaling = 1.1,
            },
        },
        ["oil-refinery"] = {
            {
                type = "recipe-productivity",
                values = {"advanced-oil-processing", 10},
                level_scaling = 1.1,
            },
        },
        ["cryogenic-plant"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.1,
                level_scaling = 0.1,
            },
        },
        ["foundry"] = {
            {
                type = "recipe-productivity",
                values = {"molten-copper", 5},
                level_scaling = 1.1,
            },
            {
                type = "recipe-productivity",
                values = {"molten-iron", 5},
                level_scaling = 1.1,
            },
        },
        ["electromagnetic-plant"] = {
            {
                type = "all-buffs-level",
                value = 1,
                level_scaling = 0.25,
            },
        },
        ["biochamber"] = {
            {
                type = "trade-productivity",
                value = 0.05,
                level_scaling = 1.03,
            },
        },
    },

    show_as_linear = { -- Numbers aren't displayed as percentages for these buff types
        ["reach-distance"] = true,
        ["build-distance"] = true,
        ["inventory-size"] = true,
        ["all-buffs-level"] = true,
        ["belt-stack-size"] = true,
        ["bulk-inserter-capacity"] = true,
        ["inserter-capacity"] = true,
        ["combat-robot-count"] = true,
        ["robot-cargo-size"] = true,
        ["health"] = true,
        ["train-trading-capacity"] = true,
    },

    has_description = {
        ["all-buffs-level"] = true,
        ["all-buffs-cost-reduced"] = true,
        ["passive-coins"] = true,
        ["train-trading-capacity"] = true,
        ["strongbox-loot"] = true,
    },

    is_fractional = { -- Some bonuses like inventory slots must be integers, so the fractional bonuses are combined here to then be rounded before applying.
        ["reach-distance"] = true,
        ["build-distance"] = true,
        ["inventory-size"] = true,
        ["all-buffs-level"] = true,
        ["belt-stack-size"] = true,
        ["bulk-inserter-capacity"] = true,
        ["inserter-capacity"] = true,
        ["combat-robot-count"] = true,
        ["robot-cargo-size"] = true,
        ["recipe-productivity"] = true, -- Recipe productivity is rounded to two decimal places by the engine, so assume integers representing percentage values, and scale down when applying
        ["health"] = true, -- might not be necessary but it's here just in case
        ["train-trading-capacity"] = true,
    },

    is_nonlinear = { -- Bonuses themselves are typically multipliers, and those multipliers grow exponentially (although slower than cost), but those multiplying factors are incremented linearly, as seen in the item_buffs API.  It's bonuses like cost reduction, compounding for each separate bonus, that are truly nonlinear.
        ["all-buffs-cost-reduced"] = true,
        ["strongbox-loot"] = true,
    },

    has_linear_effect_scaling = { -- These buff types give buffs that scale linearly rather than exponentially.
        ["all-buffs-level"] = true,
        ["all-buffs-cost-reduced"] = true,
        ["strongbox-loot"] = true,
    },

    unlocked = {},
    enabled = {},
    levels = {},
    cost = {},

    fetch_settings = true, -- Flag used to determine whether it's safe and necessary to retrieve the settings on the fly.  When mass-upgrading, all item costs are calculated and must fetch settings values, which would be very slow in that case.

    fractional_bonuses = {},
    enhance_all = {processing = false}, -- Cross-tick data for enhancing all item buffs

    strongbox_loot= 1,
    cost_multiplier = 1,
    level_bonus = 0,
    passive_coins_rate = 0,
    passive_coins_interval = 30,
    train_trading_capacity = 10,
}
