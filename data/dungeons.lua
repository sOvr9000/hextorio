
return {
    defs = {
        -- Nauvis
        {
            surface_name = "nauvis",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-flamethrower-turret"] = {2},
                ["dungeon-laser-turret"] = {5},
                ["dungeon-gun-turret"] = {7},
            },
            loot_value = 10000,
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

        -- Vulcanus
        {
            surface_name = "vulcanus",
            wall_entities = {
                ["dungeon-wall"] = {1, 8},
                ["dungeon-flamethrower-turret"] = {2, 8},
                ["dungeon-laser-turret"] = {10},
                ["dungeon-gun-turret"] = {12},
            },
            loot_value = 7500000,
            rolls = 50,
            chests = 3,
            amount_scaling = 3,
            qualities = {"uncommon", "rare"},
            tile_type = "black-refined-concrete",
            ammo = {
                bullet_type = "magmatic-rounds-magazine",
                flamethrower_type = "light-oil",
            },
        },

        -- Fulgora
        {
            surface_name = "fulgora",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-tesla-turret"] = {3},
            },
            loot_value = 12500000,
            rolls = 72,
            chests = 3,
            amount_scaling = 2,
            qualities = {"uncommon", "rare", "epic"},
            tile_type = "red-refined-concrete",
            ammo = {},
        },

        -- Gleba
        {
            surface_name = "gleba",
            wall_entities = {
                ["dungeon-wall"] = {1},
                ["dungeon-laser-turret"] = {3},
                ["dungeon-rocket-turret"] = {6},
            },
            loot_value = 625000000,
            rolls = 98,
            chests = 4,
            amount_scaling = 2,
            qualities = {"rare", "epic"},
            tile_type = "green-refined-concrete",
            ammo = {
                rocket_type = "plague-rocket",
            },
        },

        -- Aquilo
        {
            surface_name = "aquilo",
            wall_entities = {
                ["dungeon-railgun-turret"] = {3},
                ["dungeon-tesla-turret"] = {11},
                ["dungeon-rocket-turret"] = {15, 19},
                ["dungeon-gun-turret"] = {22, 24},
            },
            loot_value = 1000000000000,
            rolls = 128,
            chests = 2,
            amount_scaling = 1,
            qualities = {"epic", "legendary", "hextreme"},
            tile_type = "refined-hazard-concrete-left",
            ammo = {
                bullet_type = "uranium-rounds-magazine",
                rocket_type = "plague-rocket",
                railgun_type = "railgun-ammo",
            },
        },
    },
}
