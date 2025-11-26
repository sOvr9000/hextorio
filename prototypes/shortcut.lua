
local claim_tool = {
    type = "shortcut",
    name = "claim-tool",
    action = "spawn-item",
    item_to_spawn = "claim-tool",
    order = "z[hextorio]-c[claim-tool]",
    icon_size = 32,
    icon = "__hextorio__/graphics/icons/claim-tool-x32.png",
    small_icon_size = 24,
    small_icon = "__hextorio__/graphics/icons/claim-tool-x24.png",
}

local delete_core_tool = {
    type = "shortcut",
    name = "delete-core-tool",
    action = "spawn-item",
    item_to_spawn = "delete-core-tool",
    order = "z[hextorio]-c[delete-core-tool]",
    icon_size = 32,
    icon = "__hextorio__/graphics/icons/delete-core-tool-x32.png",
    small_icon_size = 24,
    small_icon = "__hextorio__/graphics/icons/delete-core-tool-x24.png",
}

local hexport_tool = {
    type = "shortcut",
    name = "hexport-tool",
    action = "spawn-item",
    item_to_spawn = "hexport-tool",
    order = "z[hextorio]-c[hexport-tool]",
    icon_size = 32,
    icon = "__hextorio__/graphics/icons/hexport-tool-x32.png",
    small_icon_size = 24,
    small_icon = "__hextorio__/graphics/icons/hexport-tool-x24.png",
}



data:extend({claim_tool, delete_core_tool, hexport_tool})
