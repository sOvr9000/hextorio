
return {
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
            loot_value = 15000,
            rolls = 32,
            chests = 2,
            amount_scaling = 3,
            qualities = {"normal", "uncommon"},
            tile_type = "brown-refined-concrete",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
                flamethrower_type = "light-oil",
            },
        },
        { -- Medium
            surface_name = "nauvis",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
                ["dungeon-gun-turret"] = {4},
            },
            loot_value = 5000,
            rolls = 24,
            chests = 2,
            amount_scaling = 3,
            qualities = {"normal", "uncommon"},
            tile_type = "brown-refined-concrete",
            ammo = {
                bullet_type = "piercing-rounds-magazine",
            },
        },
        { -- Easy
            surface_name = "nauvis",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
            },
            loot_value = 2000,
            rolls = 20,
            chests = 1,
            amount_scaling = 3,
            qualities = {"normal"},
            tile_type = "brown-refined-concrete",
            ammo = {},
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
            loot_value = 15000000,
            rolls = 50,
            chests = 3,
            amount_scaling = 2,
            qualities = {"rare"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                flamethrower_type = "light-oil",
            },
        },
        { -- Medium
            surface_name = "vulcanus",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-flamethrower-turret"] = {2},
                ["dungeon-gun-turret"] = {6},
            },
            loot_value = 5000000,
            rolls = 40,
            chests = 3,
            amount_scaling = 3,
            qualities = {"uncommon", "rare"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                flamethrower_type = "light-oil",
            },
        },
        { -- Easy
            surface_name = "vulcanus",
            wall_entities = {
                ["dungeon-wall"] = {1, 2, 3},
                ["dungeon-laser-turret"] = {4, 6},
            },
            loot_value = 2000000,
            rolls = 36,
            chests = 2,
            amount_scaling = 3,
            qualities = {"uncommon"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
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
            loot_value = 30000000,
            rolls = 72,
            chests = 3,
            amount_scaling = 1.5,
            qualities = {"rare", "epic"},
            tile_type = "red-refined-concrete",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
            },
        },
        { -- Medium
            surface_name = "fulgora",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2, 6},
                ["dungeon-gun-turret"] = {4, 8},
            },
            loot_value = 10000000,
            rolls = 60,
            chests = 2,
            amount_scaling = 2,
            qualities = {"rare", "epic"},
            tile_type = "red-refined-concrete",
            ammo = {
                bullet_type = "piercing-rounds-magazine",
            },
        },
        { -- Easy
            surface_name = "fulgora",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {2},
                ["dungeon-gun-turret"] = {4},
            },
            loot_value = 4000000,
            rolls = 50,
            chests = 2,
            amount_scaling = 2,
            qualities = {"rare"},
            tile_type = "red-refined-concrete",
            ammo = {
                bullet_type = "piercing-rounds-magazine",
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
            loot_value = 60000000,
            rolls = 98,
            chests = 4,
            amount_scaling = 1,
            qualities = {"epic", "legendary"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "plague-rocket",
                bullet_type = "uranium-rounds-magazine",
            },
        },
        { -- Medium
            surface_name = "gleba",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-rocket-turret"] = {5},
                ["dungeon-gun-turret"] = {7, 9},
            },
            loot_value = 20000000,
            rolls = 80,
            chests = 3,
            amount_scaling = 1.5,
            qualities = {"epic"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "rocket",
                bullet_type = "uranium-rounds-magazine",
            },
        },
        { -- Easy
            surface_name = "gleba",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-rocket-turret"] = {5},
                ["dungeon-gun-turret"] = {7},
            },
            loot_value = 8000000,
            rolls = 72,
            chests = 3,
            amount_scaling = 1.8,
            qualities = {"rare", "epic"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "explosive-rocket",
                bullet_type = "piercing-rounds-magazine",
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
            loot_value = 1000000000000,
            rolls = 128,
            chests = 3,
            amount_scaling = 1,
            qualities = {"legendary", "hextreme"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                rocket_type = "plague-rocket",
                railgun_type = "railgun-ammo",
            },
        },
        { -- Medium
            surface_name = "aquilo",
            wall_entities = {
                ["dungeon-tesla-turret"] = {4},
                ["dungeon-rocket-turret"] = {8, 12},
                ["dungeon-gun-turret"] = {15, 17},
            },
            loot_value = 300000000000,
            rolls = 108,
            chests = 2,
            amount_scaling = 1.2,
            qualities = {"legendary"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                rocket_type = "plague-rocket",
            },
        },
        { -- Easy
            surface_name = "aquilo",
            wall_entities = {
                ["dungeon-rocket-turret"] = {3, 7},
                ["dungeon-laser-turret"] = {10},
                ["dungeon-gun-turret"] = {12},
            },
            loot_value = 120000000000,
            rolls = 96,
            chests = 2,
            amount_scaling = 1.4,
            qualities = {"epic", "legendary"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
                rocket_type = "rocket",
            },
        },
    },
}
