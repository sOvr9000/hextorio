
data:extend({
    {
        type = "double-setting",
        name = "hextorio-item-buff-cost-base",
        setting_type = "runtime-global",
        default_value = 4,
        minimum_value = 0,
        order = "q[buffs]-c[cost]-s[base]",
    },
    {
        type = "double-setting",
        name = "hextorio-item-buff-cost-scale",
        setting_type = "runtime-global",
        default_value = 2000,
        minimum_value = 0,
        order = "q[buffs]-c[cost]-s[scale]",
    },
})
