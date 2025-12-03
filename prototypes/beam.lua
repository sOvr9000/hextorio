
local emp_beam_bounce = table.deepcopy(data.raw["beam"]["chain-tesla-turret-beam-bounce"])
emp_beam_bounce.name = "chain-electromagnetic-penetrator-beam-bounce"
emp_beam_bounce.action.action_delivery.target_effects = {
    type = "damage",
    damage = {
        type = "electric-hv",
        amount = 300,
    },
}

-- local emp_beam_start = table.deepcopy(data.raw["beam"]["chain-tesla-turret-beam-start"])
-- emp_beam_start.name = "chain-electromagnetic-penetrator-beam-start"
-- emp_beam_start.action.action_delivery.target_effects[1].damage.amount = 300

data:extend({
    emp_beam_bounce,
    -- emp_beam_start,
})
