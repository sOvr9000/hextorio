
data:extend({
    {
        type = "double-setting",
        name = "hextorio-rank-2-prod-requirement",
        setting_type = "runtime-global",
        default_value = 0.3,
        minimum_value = -10,
        maximum_value = 10,
        order = "t[ranks]-j[prod-req-2]",
    },
    {
        type = "double-setting",
        name = "hextorio-rank-3-prod-requirement",
        setting_type = "runtime-global",
        default_value = 0.7,
        minimum_value = -10,
        maximum_value = 10,
        order = "t[ranks]-j[prod-req-3]",
    },
    {
        type = "double-setting",
        name = "hextorio-rank-4-prod-requirement",
        setting_type = "runtime-global",
        default_value = 1.2,
        minimum_value = -10,
        maximum_value = 10,
        order = "t[ranks]-j[prod-req-4]",
    },

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
