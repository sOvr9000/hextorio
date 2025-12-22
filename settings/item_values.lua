
data:extend({
    {
        type = "double-setting",
        name = "hextorio-interplanetary-mult",
        setting_type = "runtime-global",
        default_value = 5,
        minimum_value = 0.001,
        maximum_value = 1000,
        order = "v[item-values]-s[interplanetary-multiplier]-p[other]",
    },
    {
        type = "double-setting",
        name = "hextorio-interplanetary-mult-aquilo",
        setting_type = "runtime-global",
        default_value = 10,
        minimum_value = 0.001,
        maximum_value = 1000,
        order = "v[item-values]-s[interplanetary-multiplier]-r[aquilo]",
    },
})
