
data:extend({
    {
        type = "chain-active-trigger",
        name = "chain-electromagnetic-penetrator-chain",
        fork_chance = 1,
        fork_chance_increase_per_quality_level = 0,
        jump_delay_ticks = 2,
        max_jumps = 8,
        max_range_per_jump = 15,
        action = {
            type = "direct",
            action_delivery = {
                type = "beam",
                add_to_shooter = false,
                beam = "chain-electromagnetic-penetrator-beam-bounce",
                destroy_with_source_or_target = false,
                duration = 20,
                max_length = 15.5,
                source_offset = {0, 0},
            },
        },
    }
})
