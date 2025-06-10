


-- local flamethrower = table.deepcopy(data.raw["gun"]["flamethrower"])
-- local disintegrator = table.deepcopy(data.raw["combat-robot"]["destroyer"])
-- disintegrator.attack_parameters = flamethrower.attack_parameters
-- disintegrator.attack_parameters.ammo_type = {
--     action = {
--         type = "line",
--         range = 40,
--         width = 0.5,
--         range_effects = {
--             type = "create-explosion",
--             entity_name = "railgun-beam"
--         },
--         action_delivery = {
--             type = "instant",
--             target_effects = {
--                 type = "damage",
--                 damage = {amount = 750, type = "physical"},
--             },
--         },
--     },
--     cooldown = 120,
-- }
-- disintegrator.name = "disintegrator"
-- disintegrator.order = "e-a-e"
-- disintegrator.range_from_player = 8
-- disintegrator.localised_name = nil
-- disintegrator.localised_description = nil

-- local rocket_launcher = table.deepcopy(data.raw["gun"]["rocket-launcher"])
-- local detonator = table.deepcopy(data.raw["combat-robot"]["destroyer"])
-- detonator.attack_parameters = rocket_launcher.attack_parameters
-- detonator.name = "detonator"
-- detonator.order = "e-a-f"
-- detonator.range_from_player = 12
-- detonator.localised_name = nil
-- detonator.localised_description = nil

local railgun = table.deepcopy(data.raw["gun"]["railgun"])
local demolisher = table.deepcopy(data.raw["combat-robot"]["destroyer"])
demolisher.name = "demolisher" -- why, yes, it is for demolishing demolishers on Vulcanus
demolisher.attack_parameters = railgun.attack_parameters
demolisher.attack_parameters.ammo_type = {
    action = {
        type = "line",
        range = 40,
        width = 0.5,
        range_effects = {
            type = "create-explosion",
            entity_name = "railgun-beam"
        },
        action_delivery = {
            type = "instant",
            target_effects = {
                type = "damage",
                damage = {amount = 750, type = "physical"},
            },
        },
    },
    cooldown = 120,
}
demolisher.order = "e-a-g"
demolisher.range_from_player = 15
demolisher.localised_name = nil
demolisher.localised_description = nil



data:extend({
    -- disintegrator,
    -- detonator,
    demolisher,
})
