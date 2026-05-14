
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

    alt_select = {
        border_color = {1, 1, 0},
        mode = {"nothing"},
        cursor_box_type = "copy",
    },
}

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

local hexport_tool = {
    type = "selection-tool",
    name = "hexport-tool",
    icons = {
        {
            icon = "__hextorio__/graphics/icons/hexport-tool-x64.png",
            icon_size = 64,
        },
    },

    flags = {"only-in-cursor", "spawnable"},
    stack_size = 1,
    hidden = true,

    select = {
        border_color = {1, 0.5, 0},
        mode = {"any-entity"},
        cursor_box_type = "copy",
        entity_filters = {"hex-core"},
    },
}
hexport_tool.alt_select = hexport_tool.select -- no intuitive alt selection behavior needed yet

local spider_network_tool = {
    type = "selection-tool",
    name = "spider-network-tool",
    icons = {
        {
            icon = "__hextorio__/graphics/icons/spider-network-tool-x64.png",
            icon_size = 64,
        },
    },

    flags = {"only-in-cursor", "spawnable"},
    stack_size = 1,
    hidden = true,

    select = {
        border_color = {0.25, 0.55, 1.0},
        mode = {"any-entity"},
        cursor_box_type = "copy",
        entity_filters = {"hex-core"},
    },

    reverse_select = {
        border_color = {1.0, 0.4, 0.2},
        mode = {"any-entity"},
        cursor_box_type = "not-allowed",
        entity_filters = {"hex-core"},
    },
}
spider_network_tool.alt_select = spider_network_tool.select
spider_network_tool.alt_reverse_select = spider_network_tool.reverse_select



data:extend({claim_tool, delete_core_tool, hexport_tool, spider_network_tool})
