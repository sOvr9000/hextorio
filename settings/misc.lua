
data:extend({
    -- STARTUP SETTINGS
    {
        type = "double-setting",
        setting_type = "startup",
        name = "hextorio-atomic-bomb-damage-multiplier",
        default_value = 0.01,
        order = "a[important]-b[balancing]-s[atomic-bomb-damage-multiplier]",
    },
    {
        type = "string-setting",
        name = "hextorio-title-screen-music",
        setting_type = "startup",
        allowed_values = {"vanilla", "a-soul-one-billion-years-from-now"},
        default_value = "a-soul-one-billion-years-from-now",
        order = "b[sounds]-s[title-screen-music]",
    },
    {
        type = "bool-setting",
        setting_type = "startup",
        name = "hextorio-disable-hextreme-quality",
        default_value = false,
        order = "x[misc]-t[disable-hextreme-quality]",
    },

    -- PLAYER SETTINGS
    {
        type = "bool-setting",
        setting_type = "runtime-per-user",
        name = "hextorio-trade-flying-text",
        default_value = true,
        order = "x[misc]-s[trade-flying-text]",
    },
    {
        type = "bool-setting",
        setting_type = "runtime-per-user",
        name = "hextorio-show-hex-rank-hud",
        default_value = true,
        order = "x[misc]-t[show-hex-rank-hud]",
    },
    {
        type = "string-setting",
        setting_type = "runtime-per-user",
        name = "hextorio-quest-completion-sound",

        allowed_values = {
            "none",
            "piano",

            -- TODO: Implement quest toasts and stop printing quests to console (enable this as an option when done)
            -- "console-message",

            "research-completed",
            "game-won",
            "game-lost",
            "alert",
        },

        default_value = "research-completed",
        order = "x[misc]-u[quest-completion-sound]",
    },
    {
        type = "bool-setting",
        setting_type = "runtime-per-user",
        name = "hextorio-show-intro",
        default_value = false,
        order = "x[misc]-u[show-intro]",
    },
})
