
data:extend({
    {
        type = "chain-active-trigger",
        name = "chain-electromagnetic-penetrator-chain",
        fork_chance = 0.4,
        fork_chance_increase_per_quality_level = 0.05,
        jump_delay_ticks = 2,
        max_jumps = 10,
        max_range_per_jump = 15,
        action = {
            type = "direct",
            force = "enemy",
            action_delivery = {
                type = "beam",
                add_to_shooter = false,
                beam = "chain-electromagnetic-penetrator-beam-bounce",
                destroy_with_source_or_target = false,
                duration = 18,
                max_length = 15.5,
                source_offset = {0, 0},
            },
        },
    }
})
