
data:extend({
    {
        type = "int-setting",
        name = "hextorio-trades-per-hex",
        setting_type = "runtime-global",
        default_value = 2,
        minimum_value = 0,
        maximum_value = 10,
    },
    {
        type = "double-setting",
        name = "hextorio-coin-trade-chance",
        setting_type = "runtime-global",
        default_value = 0.3,
        minimum_value = 0,
        maximum_value = 1.0,
    },
    {
        type = "double-setting",
        name = "hextorio-sell-trade-chance",
        setting_type = "runtime-global",
        default_value = 0.4,
        minimum_value = 0,
        maximum_value = 1.0,
    },
    {
        type = "double-setting",
        setting_type = "runtime-global",
        name = "hextorio-quality-cost-multiplier",
        default_value = 1.5,
        minimum_value = 0.1,
    },
    {
        type = "double-setting",
        name = "hextorio-trade-volume-per-dist-exp",
        setting_type = "runtime-global",
        default_value = 1.2345, -- looks like an arbitrary number, but it's precisely what it should be by default because 10*1.2345^40 is close to the value of the atomic bomb
        minimum_value = 1,
        maximum_value = 2,
    },
})
