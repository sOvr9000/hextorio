
data:extend({
    {
        type = "double-setting",
        setting_type = "runtime-global",
        name = "hextorio-strongbox-spawn-chance",
        default_value = 0.01,
        minimum_value = 0,
        maximum_value = 1,
        order = "m[strongboxes]-s[spawn-chance]",
    },
    {
        type = "double-setting",
        setting_type = "runtime-global",
        name = "hextorio-strongbox-loot-scale",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 100000,
        order = "m[strongboxes]-t[loot-scale]",
    },
})
