
local emp_beam_bounce = table.deepcopy(data.raw["beam"]["chain-tesla-turret-beam-bounce"])
emp_beam_bounce.name = "chain-electromagnetic-penetrator-beam-bounce"
emp_beam_bounce.action.action_delivery.target_effects = {
    type = "damage",
    damage = {
        type = "electric-hv",
        amount = 300,
    },
}

data:extend({
    emp_beam_bounce,
})
