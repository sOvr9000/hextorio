
local BASE_HEX_RES_CHANCE = {
    NAUVIS = 0.5,
    VULCANUS = 0.7,
    FULGORA = 0.8,
    GLEBA = 0.9,
    AQUILO = 1.5,
}

return {
    queued_reloads = {},
    queued_reload_dungeon_indices = {},

    defs = {
        -- Nauvis
        { -- Hard
            surface_name = "nauvis",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-flamethrower-turret"] = {2},
                ["dungeon-laser-turret"] = {5},
                ["dungeon-gun-turret"] = {7},
            },
            loot_value = 30000,
            rolls = 6,
            chests = 2,
            amount_scaling = 1,
            qualities = {"normal", "uncommon"},
            tile_type = "brown-refined-concrete",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
                flamethrower_type = "light-oil",
            },
            item_rolls = {
                ["hexadic-resonator-tier-1"] = BASE_HEX_RES_CHANCE.NAUVIS,
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.5,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.25,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.125,
            },
        },
        { -- Medium
            surface_name = "nauvis",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
                ["dungeon-gun-turret"] = {4},
            },
            loot_value = 10000,
            rolls = 5,
            chests = 2,
            amount_scaling = 1,
            qualities = {"normal", "uncommon"},
            tile_type = "brown-refined-concrete",
            ammo = {
                bullet_type = "piercing-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-1"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.5,
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.25,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.125,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.0625,
            },
        },
        { -- Easy
            surface_name = "nauvis",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
            },
            loot_value = 4000,
            rolls = 4,
            chests = 1,
            amount_scaling = 1,
            qualities = {"normal"},
            tile_type = "brown-refined-concrete",
            ammo = {},
            item_rolls = {
                ["hexadic-resonator-tier-1"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.25,
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.125,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.0625,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.NAUVIS * 0.03625,
            },
        },

        -- Vulcanus
        { -- Hard
            surface_name = "vulcanus",
            wall_entities = {
                ["dungeon-wall"] = {1, 8},
                ["dungeon-flamethrower-turret"] = {2, 8},
                ["dungeon-laser-turret"] = {10},
                ["dungeon-gun-turret"] = {12},
            },
            loot_value = 30000000,
            rolls = 8,
            chests = 3,
            amount_scaling = 1,
            qualities = {"rare"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                flamethrower_type = "light-oil",
            },
            item_rolls = {
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.VULCANUS,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.5,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.25,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.125,
            },
        },
        { -- Medium
            surface_name = "vulcanus",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-flamethrower-turret"] = {2},
                ["dungeon-gun-turret"] = {6},
            },
            loot_value = 10000000,
            rolls = 6,
            chests = 3,
            amount_scaling = 1,
            qualities = {"uncommon", "rare"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                flamethrower_type = "light-oil",
            },
            item_rolls = {
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.5,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.25,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.125,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.0625,
            },
        },
        { -- Easy
            surface_name = "vulcanus",
            wall_entities = {
                ["dungeon-wall"] = {1, 2, 3},
                ["dungeon-laser-turret"] = {4, 6},
            },
            loot_value = 4000000,
            rolls = 6,
            chests = 2,
            amount_scaling = 1,
            qualities = {"uncommon"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.25,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.125,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.0625,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.VULCANUS * 0.03625,
            },
        },

        -- Fulgora
        { -- Hard
            surface_name = "fulgora",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-tesla-turret"] = {3},
                ["dungeon-laser-turret"] = {7},
                ["dungeon-gun-turret"] = {9},
            },
            loot_value = 60000000,
            rolls = 10,
            chests = 3,
            amount_scaling = 1,
            qualities = {"rare", "epic"},
            tile_type = "red-refined-concrete",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.FULGORA,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.FULGORA * 0.5,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.FULGORA * 0.25,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.FULGORA * 0.125,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.FULGORA * 0.0625,
            },
        },
        { -- Medium
            surface_name = "fulgora",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2, 6},
                ["dungeon-gun-turret"] = {4, 8},
            },
            loot_value = 20000000,
            rolls = 10,
            chests = 2,
            amount_scaling = 1,
            qualities = {"rare", "epic"},
            tile_type = "red-refined-concrete",
            ammo = {
                bullet_type = "piercing-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.FULGORA * 0.5,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.FULGORA * 0.25,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.FULGORA * 0.125,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.FULGORA * 0.0625,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.FULGORA * 0.03625,
            },
        },
        { -- Easy
            surface_name = "fulgora",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
                ["dungeon-gun-turret"] = {4},
            },
            loot_value = 8000000,
            rolls = 6,
            chests = 2,
            amount_scaling = 1,
            qualities = {"rare"},
            tile_type = "red-refined-concrete",
            ammo = {
                bullet_type = "piercing-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-2"] = BASE_HEX_RES_CHANCE.FULGORA * 0.5,
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.FULGORA * 0.25,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.FULGORA * 0.125,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.FULGORA * 0.0625,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.FULGORA * 0.03625,
            },
        },

        -- Gleba
        { -- Hard
            surface_name = "gleba",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
                ["dungeon-rocket-turret"] = {5},
                ["dungeon-gun-turret"] = {7},
            },
            loot_value = 120000000,
            rolls = 12,
            chests = 4,
            amount_scaling = 1,
            qualities = {"epic", "legendary"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "plague-rocket",
                bullet_type = "uranium-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.GLEBA,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.GLEBA * 0.5,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.GLEBA * 0.25,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.GLEBA * 0.125,
            },
        },
        { -- Medium
            surface_name = "gleba",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-rocket-turret"] = {5},
                ["dungeon-gun-turret"] = {7, 9},
            },
            loot_value = 40000000,
            rolls = 11,
            chests = 3,
            amount_scaling = 1,
            qualities = {"epic"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "rocket",
                bullet_type = "uranium-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.GLEBA * 0.5,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.GLEBA * 0.25,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.GLEBA * 0.125,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.GLEBA * 0.0625,
            },
        },
        { -- Easy
            surface_name = "gleba",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-rocket-turret"] = {5},
                ["dungeon-gun-turret"] = {7},
            },
            loot_value = 16000000,
            rolls = 10,
            chests = 3,
            amount_scaling = 1,
            qualities = {"rare", "epic"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "explosive-rocket",
                bullet_type = "piercing-rounds-magazine",
            },
            item_rolls = {
                ["hexadic-resonator-tier-3"] = BASE_HEX_RES_CHANCE.GLEBA * 0.25,
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.GLEBA * 0.125,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.GLEBA * 0.0625,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.GLEBA * 0.03625,
            },
        },

        -- Aquilo
        { -- Hard
            surface_name = "aquilo",
            wall_entities = {
                ["dungeon-railgun-turret"] = {3},
                ["dungeon-tesla-turret"] = {11},
                ["dungeon-rocket-turret"] = {15, 19},
                ["dungeon-gun-turret"] = {22, 24},
            },
            loot_value = 2000000000000,
            rolls = 15,
            chests = 3,
            amount_scaling = 1,
            qualities = {"legendary", "hextreme"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                rocket_type = "plague-rocket",
                railgun_type = "railgun-ammo",
            },
            item_rolls = {
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.AQUILO,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.AQUILO * 0.5,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.AQUILO * 0.25,
            },
        },
        { -- Medium
            surface_name = "aquilo",
            wall_entities = {
                ["dungeon-tesla-turret"] = {4},
                ["dungeon-rocket-turret"] = {8, 12},
                ["dungeon-gun-turret"] = {15, 17},
            },
            loot_value = 600000000000,
            rolls = 12,
            chests = 2,
            amount_scaling = 1,
            qualities = {"legendary"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                rocket_type = "plague-rocket",
            },
            item_rolls = {
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.AQUILO * 0.5,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.AQUILO * 0.25,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.AQUILO * 0.125,
            },
        },
        { -- Easy
            surface_name = "aquilo",
            wall_entities = {
                ["dungeon-rocket-turret"] = {3, 7},
                ["dungeon-laser-turret"] = {10},
                ["dungeon-gun-turret"] = {12},
            },
            loot_value = 240000000000,
            rolls = 10,
            chests = 2,
            amount_scaling = 1,
            qualities = {"epic", "legendary"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
                rocket_type = "rocket",
            },
            item_rolls = {
                ["hexadic-resonator-tier-4"] = BASE_HEX_RES_CHANCE.AQUILO * 0.25,
                ["hexadic-resonator-tier-5"] = BASE_HEX_RES_CHANCE.AQUILO * 0.125,
                ["hexadic-resonator-tier-6"] = BASE_HEX_RES_CHANCE.AQUILO * 0.0625,
            },
        },
    },
}
