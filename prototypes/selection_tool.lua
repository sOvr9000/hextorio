
local claim_tool = {
    type = "selection-tool",
    name = "claim-tool",
    icons = {
        {
            icon = "__hextorio__/graphics/icons/claim-tool-x64.png",
            icon_size = 64,
        },
    },

    flags = {"only-in-cursor", "spawnable"},
    stack_size = 1,
    hidden = true,

    select = {
        border_color = {1, 1, 1},
        mode = {"any-entity"},
        cursor_box_type = "copy",
        entity_filters = {"hex-core"},
    },
}
claim_tool.alt_select = claim_tool.select -- no intuitive alt selection behavior needed yet

local delete_core_tool = {
    type = "selection-tool",
    name = "delete-core-tool",
    icons = {
        {
            icon = "__hextorio__/graphics/icons/delete-core-tool-x64.png",
            icon_size = 64,
        },
    },

    flags = {"only-in-cursor", "spawnable"},
    stack_size = 1,
    hidden = true,

    select = {
        border_color = {1, 0, 0},
        mode = {"any-entity"},
        cursor_box_type = "copy",
        entity_filters = {"hex-core"},
    },
}
delete_core_tool.alt_select = delete_core_tool.select -- no intuitive alt selection behavior needed yet



data:extend({claim_tool, delete_core_tool})
