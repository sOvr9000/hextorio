
data:extend({
    {
        type = "double-setting",
        name = "hextorio-rank-2-effect",
        setting_type = "runtime-global",
        default_value = 0.01,
        minimum_value = 0,
        maximum_value = 1.0,
        order = "r[ranks]-e[effect]-t[bronze]",
    },
    {
        type = "int-setting",
        name = "hextorio-rank-3-effect",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 100,
        order = "r[ranks]-e[effect]-t[silver]",
    },

    {
        type = "double-setting",
        name = "hextorio-rank-2-prod-requirement",
        setting_type = "runtime-global",
        default_value = 0.35,
        minimum_value = -10,
        maximum_value = 10,
        order = "r[ranks]-p[productivity-requirement]-t[silver]",
    },
    {
        type = "double-setting",
        name = "hextorio-rank-3-prod-requirement",
        setting_type = "runtime-global",
        default_value = 0.85,
        minimum_value = -10,
        maximum_value = 10,
        order = "r[ranks]-p[productivity-requirement]-u[gold]",
    },
    {
        type = "double-setting",
        name = "hextorio-rank-4-prod-requirement",
        setting_type = "runtime-global",
        default_value = 1.3,
        minimum_value = -10,
        maximum_value = 10,
        order = "r[ranks]-p[productivity-requirement]-u[red]",
    },
})
