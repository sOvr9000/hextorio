
local emp_beam_bounce = table.deepcopy(data.raw["beam"]["chain-tesla-turret-beam-bounce"])
emp_beam_bounce.name = "chain-electromagnetic-penetrator-beam-bounce"
emp_beam_bounce.graphics_set.ground.body.tint = {0.75, 0.05, 0.05}
emp_beam_bounce.graphics_set.ground.head.tint = {0.75, 0.05, 0.05}
emp_beam_bounce.graphics_set.ground.tail.tint = {0.75, 0.05, 0.05}
emp_beam_bounce.action.action_delivery.target_effects = {
    {
        type = "damage",
        damage = {
            type = "electric-hv",
            amount = 300,
        },
    },
}

emp_beam_bounce.graphics_set.beam.start.filename = "__hextorio__/graphics/beam/chain-beam-START.png"
emp_beam_bounce.graphics_set.beam.ending.filename = "__hextorio__/graphics/beam/chain-beam-END.png"
emp_beam_bounce.graphics_set.beam.head.layers[1].filename = "__hextorio__/graphics/beam/chain-body-0.png"
emp_beam_bounce.graphics_set.beam.head.layers[2].filename = "__hextorio__/graphics/beam/chain-body-1.png"
emp_beam_bounce.graphics_set.beam.tail.layers[1].filename = "__hextorio__/graphics/beam/chain-body-0.png"
emp_beam_bounce.graphics_set.beam.tail.layers[2].filename = "__hextorio__/graphics/beam/chain-body-6.png"
for i = 1, 6 do
    emp_beam_bounce.graphics_set.beam.body[i].layers[1].filename = "__hextorio__/graphics/beam/chain-body-0.png"
    emp_beam_bounce.graphics_set.beam.body[i].layers[2].filename = "__hextorio__/graphics/beam/chain-body-" .. i .. ".png"
end

-- local emp_beam_start = table.deepcopy(data.raw["beam"]["chain-tesla-turret-beam-start"])
-- emp_beam_start.name = "chain-electromagnetic-penetrator-beam-start"
-- emp_beam_start.action.action_delivery.target_effects[1].damage.amount = 300

data:extend({
    emp_beam_bounce,
    -- emp_beam_start,
})
