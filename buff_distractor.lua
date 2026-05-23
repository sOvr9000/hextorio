
local distractor_capsule = data.raw["capsule"]["distractor-capsule"]
distractor_capsule.capsule_action.attack_parameters.cooldown = 24 -- Vanilla is 30, normally making it have 1.5/s deployment speed

local distractor = data.raw["combat-robot"]["distractor"]
distractor.attack_parameters.range = 24 -- Vanilla is 15
distractor.attack_parameters.cooldown = 20 -- Vanilla is 40, normally making it have 1.5/s shooting speed
distractor.attack_parameters.damage_modifier = 1.5 -- Vanilla is 0.5, normally making it do 5 damage
distractor.max_health = 450 -- Vanilla is 180

table.insert(distractor.resistances, {
    type = "physical",
    percent = 10,
})

table.insert(distractor.resistances, {
    type = "laser",
    percent = 10,
})
