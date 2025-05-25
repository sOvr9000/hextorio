
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
demolisher.order = "e-a-d"
demolisher.range_from_player = 15
demolisher.localised_name = nil
demolisher.localised_description = nil




data:extend({demolisher})
