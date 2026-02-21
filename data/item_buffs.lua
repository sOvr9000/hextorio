
return {
    item_buffs = {
        ["iron-ore"] = {
            {
                type = "mining-speed",
                value = 0.05,
                level_scaling = 0.01,
            },
        },
        ["stone"] = {
            {
                type = "mining-speed",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["copper-ore"] = {
            {
                type = "mining-speed",
                value = 0.06,
                level_scaling = 0.01,
            },
        },
        ["coal"] = {
            {
                type = "mining-speed",
                value = 0.07,
                level_scaling = 0.01,
            },
        },
        ["uranium-ore"] = {
            {
                type = "mining-speed",
                value = 0.08,
                level_scaling = 0.01,
            },
        },
        ["tungsten-ore"] = {
            {
                type = "mining-speed",
                value = 0.10,
                level_scaling = 0.02,
            },
        },
        ["tungsten-plate"] = {
            {
                type = "recipe-productivity",
                values = {"tungsten-plate", 5},
                level_scaling = 1,
            },
        },
        ["scrap"] = {
            {
                type = "mining-productivity",
                value = 0.05,
                level_scaling = 0.01,
            },
        },
        ["holmium-ore"] = {
            {
                type = "recipe-productivity",
                values = {"scrap-recycling", 10},
                level_scaling = 2,
            },
        },
        ["holmium-plate"] = {
            {
                type = "recipe-productivity",
                values = {"holmium-plate", 5},
                level_scaling = 1,
            },
        },
        ["iron-plate"] = {
            {
                type = "inventory-size",
                value = 1,
                level_scaling = 1,
            },
        },
        ["copper-plate"] = {
            {
                type = "inventory-size",
                value = 1,
                level_scaling = 1,
            },
        },
        ["steel-plate"] = {
            {
                type = "inventory-size",
                value = 1,
                level_scaling = 1,
            },
        },
        ["uranium-238"] = {
            {
                type = "unresearched-penalty-reduced",
                value = 0.03,
                level_scaling = 0.03,
            },
        },
        ["uranium-235"] = {
            {
                type = "unresearched-penalty-reduced",
                value = 0.04,
                level_scaling = 0.04,
            },
        },
        ["beacon"] = {
            {
                type = "beacon-efficiency",
                value = 0.15,
                level_scaling = 0.01,
            },
        },
        ["fast-inserter"] = {
            {
                type = "inserter-capacity",
                value = 1,
                level_scaling = 0.1,
            },
        },
        ["bulk-inserter"] = {
            {
                type = "bulk-inserter-capacity",
                value = 1,
                level_scaling = 0.25,
            },
        },
        ["stack-inserter"] = {
            {
                type = "belt-stack-size",
                value = 1,
                level_scaling = 0.125,
            },
        },
        ["spoilage"] = {
            {
                type = "recipe-productivity",
                values = {"poison-capsule", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"slowdown-capsule", 5},
                level_scaling = 1,
            },
        },
        ["nutrients"] = {
            {
                type = "recipe-productivity",
                values = {"nutrients-from-spoilage", 5},
                level_scaling = 1,
            },
        },
        ["yumako"] = {
            {
                type = "health",
                value = 5,
                level_scaling = 5,
            },
        },
        ["jellynut"] = {
            {
                type = "health",
                value = 5,
                level_scaling = 5,
            },
        },
        ["yumako-seed"] = {
            {
                type = "health",
                value = 10,
                level_scaling = 10,
            },
        },
        ["jellynut-seed"] = {
            {
                type = "health",
                value = 10,
                level_scaling = 10,
            },
        },
        ["carbon-fiber"] = {
            {
                type = "recipe-productivity",
                values = {"carbon-fiber", 5},
                level_scaling = 1,
            },
        },
        ["automation-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"automation-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["logistic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"logistic-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["military-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"military-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["chemical-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"chemical-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["production-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"production-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["utility-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"utility-science-pack", 5},
                level_scaling = 1,
            },
        },
        -- No way to level up space sci; it's untradable
        ["metallurgic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"metallurgic-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["electromagnetic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"electromagnetic-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["agricultural-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"agricultural-science-pack", 5},
                level_scaling = 1,
            },
        },
        ["cryogenic-science-pack"] = {
            {
                type = "recipe-productivity",
                values = {"cryogenic-science-pack", 5},
                level_scaling = 1,
            },
        },
        -- Untradable in 1.7.0+
        -- ["promethium-science-pack"] = {
        --     {
        --         type = "recipe-productivity",
        --         values = {"promethium-science-pack", 5},
        --         level_scaling = 1,
        --     },
        -- },
        ["lithium"] = {
            {
                type = "recipe-productivity",
                values = {"lithium", 5},
                level_scaling = 1,
            },
        },
        ["biter-egg"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["pentapod-egg"] = {
            {
                type = "all-buffs-cost-reduced",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["lab"] = {
            {
                type = "research-productivity",
                value = 0.10,
                level_scaling = 0.01,
            },
        },
        ["biolab"] = {
            {
                type = "research-speed",
                value = 0.5,
                level_scaling = 0.1,
            },
        },
        ["lightning-rod"] = {
            {
                type = "passive-coins",
                value = 0.02,
                level_scaling = 0.005,
            },
        },
        ["lightning-collector"] = {
            {
                type = "passive-coins",
                value = 0.03,
                level_scaling = 0.005,
            },
        },
        ["wooden-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.025,
                level_scaling = 0.025,
            },
        },
        ["iron-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.03,
                level_scaling = 0.03,
            },
        },
        ["steel-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.04,
                level_scaling = 0.04,
            },
        },
        ["requester-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.015,
                level_scaling = 0.015,
            },
        },
        ["buffer-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.015,
                level_scaling = 0.015,
            },
        },
        ["storage-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.015,
                level_scaling = 0.015,
            },
        },
        ["passive-provider-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.015,
                level_scaling = 0.015,
            },
        },
        ["active-provider-chest"] = {
            {
                type = "strongbox-loot",
                value = 0.015,
                level_scaling = 0.015,
            },
        },
        ["defender-capsule"] = {
            {
                type = "combat-robot-count",
                value = 5,
                level_scaling = 1,
            },
        },
        ["distractor-capsule"] = {
            {
                type = "combat-robot-count",
                value = 5,
                level_scaling = 1,
            },
        },
        ["destroyer-capsule"] = {
            {
                type = "combat-robot-lifetime",
                value = 0.1,
                level_scaling = 0.01,
            },
        },
        ["demolisher-capsule"] = {
            {
                type = "combat-robot-lifetime",
                value = 0.1,
                level_scaling = 0.01,
            },
        },
        ["transport-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["underground-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["splitter"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["fast-transport-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["fast-underground-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["fast-splitter"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["express-transport-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["express-underground-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["express-splitter"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["turbo-transport-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["turbo-underground-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["turbo-splitter"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["hexic-transport-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["hexic-underground-belt"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["hexic-splitter"] = {
            {
                type = "build-distance",
                value = 1,
                level_scaling = 0.5,
            },
        },
        ["burner-mining-drill"] = {
            {
                type = "mining-productivity",
                value = 0.05,
                level_scaling = 0.01,
            },
        },
        ["electric-mining-drill"] = {
            {
                type = "mining-productivity",
                value = 0.10,
                level_scaling = 0.025,
            },
        },
        ["big-mining-drill"] = {
            {
                type = "mining-productivity",
                value = 0.20,
                level_scaling = 0.025,
            },
        },
        ["stone-brick"] = {
            {
                type = "moving-speed",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["concrete"] = {
            {
                type = "moving-speed",
                value = 0.05,
                level_scaling = 0.01,
            },
        },
        ["hazard-concrete"] = {
            {
                type = "moving-speed",
                value = 0.05,
                level_scaling = 0.01,
            },
        },
        ["refined-concrete"] = {
            {
                type = "moving-speed",
                value = 0.06,
                level_scaling = 0.01,
            },
        },
        ["refined-hazard-concrete"] = {
            {
                type = "moving-speed",
                value = 0.07,
                level_scaling = 0.01,
            },
        },
        ["foundation"] = {
            {
                type = "moving-speed",
                value = 0.08,
                level_scaling = 0.02,
            },
        },
        ["iron-gear-wheel"] = {
            {
                type = "crafting-speed",
                value = 0.06,
                level_scaling = 0.01,
            },
        },
        ["iron-stick"] = {
            {
                type = "crafting-speed",
                value = 0.06,
                level_scaling = 0.01,
            },
        },
        ["copper-cable"] = {
            {
                type = "crafting-speed",
                value = 0.06,
                level_scaling = 0.01,
            },
        },
        ["firearm-magazine"] = {
            {
                type = "bullet-damage",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["piercing-rounds-magazine"] = {
            {
                type = "bullet-damage",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["uranium-rounds-magazine"] = {
            {
                type = "bullet-damage",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["magmatic-rounds-magazine"] = {
            {
                type = "bullet-damage",
                value = 0.08,
                level_scaling = 0.01,
            },
            {
                type = "fire-damage",
                value = 0.08,
                level_scaling = 0.01,
            },
        },
        ["gun-turret"] = {
            {
                type = "recipe-productivity",
                values = {"firearm-magazine", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"piercing-rounds-magazine", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"uranium-rounds-magazine", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"magmatic-rounds-magazine", 15},
                level_scaling = 1,
            },
        },
        ["rocket-turret"] = {
            {
                type = "recipe-productivity",
                values = {"rocket", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"explosive-rocket", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"plague-rocket", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"atomic-bomb", 5},
                level_scaling = 1,
            },
            {
                type = "explosion-damage",
                value = 0.08,
                level_scaling = 0.01,
            },
        },
        ["plague-rocket"] = {
            {
                type = "recipe-productivity",
                values = {"bioflux", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"nutrients-from-bioflux", 5},
                level_scaling = 1,
            },
        },
        ["laser-turret"] = {
            {
                type = "laser-damage",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["flamethrower-turret"] = {
            {
                type = "recipe-productivity",
                values = {"heavy-oil-cracking", 5},
                level_scaling = 1,
            },
        },
        ["tesla-turret"] = {
            {
                type = "electric-damage",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["teslagun"] = {
            {
                type = "electric-shooting-speed",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["submachine-gun"] = {
            {
                type = "bullet-shooting-speed",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["rocket-launcher"] = {
            {
                type = "rocket-shooting-speed",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["toolbelt-equipment"] = {
            {
                type = "unresearched-penalty-reduced",
                value = 0.05,
                level_scaling = 0.05,
            },
        },
        ["electronic-circuit"] = {
            {
                type = "recipe-productivity",
                values = {"electronic-circuit", 8},
                level_scaling = 1,
            },
        },
        ["quality-module"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module", 10},
                level_scaling = 1,
            },
        },
        ["quality-module-2"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module-2", 10},
                level_scaling = 1,
            },
        },
        ["quality-module-3"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module-3", 10},
                level_scaling = 1,
            },
        },
        ["hexa-quality-module"] = {
            {
                type = "recipe-productivity",
                values = {"quality-module", 25},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"quality-module-2", 25},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"quality-module-3", 25},
                level_scaling = 1,
            },
        },
        ["productivity-module"] = {
            {
                type = "trade-productivity",
                value = 0.02,
                level_scaling = 0.005,
            },
        },
        ["productivity-module-2"] = {
            {
                type = "trade-productivity",
                value = 0.02,
                level_scaling = 0.005,
            },
        },
        ["productivity-module-3"] = {
            {
                type = "trade-productivity",
                value = 0.04,
                level_scaling = 0.01,
            },
        },
        ["hexa-productivity-module"] = {
            {
                type = "trade-productivity",
                value = 0.08,
                level_scaling = 0.01,
            },
        },
        ["speed-module"] = {
            {
                type = "crafting-speed",
                value = 0.20,
                level_scaling = 0.03,
            },
        },
        ["speed-module-2"] = {
            {
                type = "crafting-speed",
                value = 0.25,
                level_scaling = 0.03,
            },
        },
        ["speed-module-3"] = {
            {
                type = "crafting-speed",
                value = 0.30,
                level_scaling = 0.04,
            },
        },
        ["hexa-speed-module"] = {
            {
                type = "crafting-speed",
                value = 0.50,
                level_scaling = 0.05,
            },
        },
        ["efficiency-module"] = {
            {
                type = "recipe-productivity",
                values = {"electronic-circuit", 8},
                level_scaling = 1,
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
                level_scaling = 1,
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
                level_scaling = 1,
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
                level_scaling = 1,
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
                level_scaling = 0.25,
            },
        },
        ["construction-robot"] = {
            {
                type = "robot-speed",
                value = 0.10,
                level_scaling = 0.025,
            },
        },
        ["roboport"] = {
            {
                type = "robot-battery",
                value = 0.10,
                level_scaling = 0.05,
            },
        },
        ["spidertron"] = {
            {
                type = "trade-productivity",
                value = 0.05,
                level_scaling = 0.01,
            },
        },
        ["rocket-silo"] = {
            {
                type = "recipe-productivity",
                values = {"rocket-part", 5},
                level_scaling = 1,
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
                level_scaling = 1,
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
                level_scaling = 0.05,
            },
            {
                type = "train-trading-capacity",
                value = 2,
                level_scaling = 0.25,
            },
        },
        ["cargo-wagon"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 0.05,
            },
            {
                type = "train-trading-capacity",
                value = 1.5,
                level_scaling = 0.2,
            },
        },
        ["fluid-wagon"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 0.05,
            },
        },
        ["artillery-wagon"] = {
            {
                type = "braking-force",
                value = 0.1,
                level_scaling = 0.05,
            },
        },
        ["assembling-machine-1"] = {
            {
                type = "recipe-productivity",
                values = {"iron-gear-wheel", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"casting-iron-gear-wheel", 6},
                level_scaling = 1,
            },
        },
        ["assembling-machine-2"] = {
            {
                type = "recipe-productivity",
                values = {"copper-cable", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"casting-copper-cable", 6},
                level_scaling = 1,
            },
        },
        ["assembling-machine-3"] = {
            {
                type = "recipe-productivity",
                values = {"engine-unit", 5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"electric-engine-unit", 5},
                level_scaling = 1,
            },
        },
        ["chemical-plant"] = {
            {
                type = "recipe-productivity",
                values = {"lubricant", 7.5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"pump", 7.5},
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"storage-tank", 7.5},
                level_scaling = 1,
            },
        },
        ["oil-refinery"] = {
            {
                type = "recipe-productivity",
                values = {"advanced-oil-processing", 10},
                level_scaling = 1,
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
                level_scaling = 1,
            },
            {
                type = "recipe-productivity",
                values = {"molten-iron", 5},
                level_scaling = 1,
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
                level_scaling = 0.01,
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
        ["unresearched-penalty-reduced"] = true,
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

    is_nonlinear = { -- These buff types give buffs that multiply across each other ("stacking" the effect), i.e. `total_effect(level) = effect1 * effect2 * ...`, as a product instead of a sum
        ["all-buffs-cost-reduced"] = true,
        ["strongbox-loot"] = true,
        ["unresearched-penalty-reduced"] = true,
    },

    has_linear_effect_scaling = { -- These buff types give buffs that scale linearly rather than exponentially, i.e. `effect(level) = effect_per_level * level`, as a multiplication instead of an exponentiation
        ["all-buffs-level"] = true,
        ["all-buffs-cost-reduced"] = true,
        ["strongbox-loot"] = true,
        ["unresearched-penalty-reduced"] = true,
        ["build-distance"] = true,
        ["reach-distance"] = true,
        ["mining-speed"] = true,
        ["inventory-size"] = true,
        ["beacon-efficiency"] = true,
        ["inserter-capacity"] = true,
        ["bulk-inserter-capacity"] = true,
        ["belt-stack-size"] = true,
        ["health"] = true,
        ["combat-robot-count"] = true,
        ["combat-robot-lifetime"] = true,
        ["mining-productivity"] = true,
        ["recipe-productivity"] = true,
        ["research-productivity"] = true,
        ["research-speed"] = true,
        ["moving-speed"] = true,
        ["crafting-speed"] = true,
        ["bullet-damage"] = true,
        ["fire-damage"] = true,
        ["laser-damage"] = true,
        ["explosion-damage"] = true,
        ["electric-damage"] = true,
        ["bullet-shooting-speed"] = true,
        ["laser-shooting-speed"] = true,
        ["rocket-shooting-speed"] = true,
        ["electric-shooting-speed"] = true,
        ["trade-productivity"] = true,
        ["robot-cargo-size"] = true,
        ["robot-speed"] = true,
        ["robot-battery"] = true,
        ["braking-force"] = true,
        ["train-trading-capacity"] = true,
        ["passive-coins"] = true,
    },

    unlocked = {},
    enabled = {},
    levels = {},
    cost = {},

    fetch_settings = true, -- Flag used to determine whether it's safe and necessary to retrieve the settings on the fly.  When mass-upgrading, all item costs are calculated and must fetch settings values, which would be very slow in that case.

    fractional_bonuses = {},

    enhance_all = {processing = false}, -- Cross-tick data for enhancing all item buffs
    free_buffs_remaining = 0,

    strongbox_loot= 1,
    cost_multiplier = 1,
    unresearched_penalty_multiplier = 1,
    level_bonus = 0,
    passive_coins_rate = 0,
    passive_coins_interval = 30,
    train_trading_capacity = 10,
}
