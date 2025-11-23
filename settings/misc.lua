
data:extend({
    {
        type = "string-setting",
        name = "hextorio-title-screen-music",
        setting_type = "startup",
        allowed_values = {"vanilla", "a-soul-one-billion-years-from-now"},
        default_value = "a-soul-one-billion-years-from-now",
        order = "a",
    },

    {
        type = "double-setting",
        setting_type = "startup",
        name = "hextorio-atomic-bomb-damage-multiplier",
        default_value = 0.01,
        order = "zzy",
    },
    {
        type = "bool-setting",
        setting_type = "runtime-per-user",
        name = "hextorio-trade-flying-text",
        default_value = true,
        order = "z",
    },

    {
        type = "bool-setting",
        setting_type = "startup",
        name = "hextorio-disable-hextreme-quality",
        default_value = false,
        order = "zzz",
    },
})
