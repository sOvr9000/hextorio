
local hex_core = table.deepcopy(data.raw.container["steel-chest"])

hex_core.name = "hex-core"
hex_core.impact_category = "stone"
hex_core.inventory_size = 49
hex_core.collision_box = {
    {-2.35, -2.35},
    {2.35, 2.35},
}
hex_core.selection_box = {
    {-2.5, -2.5},
    {2.5, 2.5},
}
hex_core.fast_replaceable_group = nil
hex_core.minable = nil
hex_core.picture = {
    layers = {
        {
            filename = "__hextorio__/graphics/entity/hex-core.png",
            width = 416,
            height = 474,
            scale = 0.4,
            -- offset = {}
        }
    }
}
hex_core.icon = "__hextorio__/graphics/icons/hex-core.png"
hex_core.inventory_type = "with_filters_and_bar"
hex_core.map_color = {0.9, 0.9, 0.9}



local hidden_loader = table.deepcopy(data.raw["loader-1x1"]["loader-1x1"])
hidden_loader.name = "hex-core-loader"
-- hidden_loader.speed = 0.03125 * 4 -- 15/sec x4 = turbo belt
hidden_loader.speed = 0.03125 * 20 -- ultimate belts support
hidden_loader.belt_animation_set = nil
hidden_loader.minable = nil
hidden_loader.structure = nil
hidden_loader.filter_count = 2
hidden_loader.per_lane_filters = true
hidden_loader.max_belt_stack_size = 4
hidden_loader.adjustable_belt_stack_size = true



-- data:extend({hex_core, hidden_loader, hex_core_output_chest})
data:extend({hex_core, hidden_loader})
-- data:extend({hex_core, hex_core_output_chest})
