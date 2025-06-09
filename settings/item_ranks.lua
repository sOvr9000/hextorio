
data:extend({
    {
        type = "double-setting",
        name = "hextorio-rank-2-effect",
        setting_type = "runtime-global",
        default_value = 0.01,
        minimum_value = 0,
        maximum_value = 1.0,
        order = "t[ranks]-k[effect-2]",
    },
    {
        type = "int-setting",
        name = "hextorio-rank-3-effect",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 100,
        order = "t[ranks]-k[effect-3]",
    },
})
