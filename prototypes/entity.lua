
local hex_core = table.deepcopy(data.raw.container["steel-chest"])

hex_core.name = "hex-core"
hex_core.impact_category = "stone"
hex_core.inventory_size = 89
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
        }
    }
}
hex_core.icon = "__hextorio__/graphics/icons/hex-core.png"
hex_core.inventory_type = "with_filters_and_bar"
hex_core.map_color = {0.9, 0.9, 0.9}

hex_core.resistances = {
    {
        type = "electric",
        percent = 100,
    },
}





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

hidden_loader.resistances = {
    {
        type = "electric",
        percent = 100,
    },
}

hidden_loader.selection_priority = 51 -- Not so hidden anymore.



-- BELTS
local hexic_transport_belt = table.deepcopy(data.raw["transport-belt"]["turbo-transport-belt"])
hexic_transport_belt.name = "hexic-transport-belt"
hexic_transport_belt.speed = hexic_transport_belt.speed * 1.5
hexic_transport_belt.belt_animation_set.animation_set.filename = "__hextorio__/graphics/entity/hexic-transport-belt/hexic-transport-belt.png"
hexic_transport_belt.belt_animation_set.frozen_patch.filename = "__hextorio__/graphics/entity/hexic-transport-belt/hexic-transport-belt-frozen.png"
hexic_transport_belt.corpse = "turbo-transport-belt-remnants" -- TODO
hexic_transport_belt.minable.result = "hexic-transport-belt"
hexic_transport_belt.max_health = 200
hexic_transport_belt.icon = "__hextorio__/graphics/icons/hexic-transport-belt.png"
hexic_transport_belt.related_underground_belt = "hexic-underground-belt"
data.raw["transport-belt"]["turbo-transport-belt"].next_upgrade = "hexic-transport-belt"

local hexic_underground_belt = table.deepcopy(data.raw["underground-belt"]["turbo-underground-belt"])
hexic_underground_belt.name = "hexic-underground-belt"
hexic_underground_belt.speed = hexic_transport_belt.speed
hexic_underground_belt.belt_animation_set.animation_set.filename = "__hextorio__/graphics/entity/hexic-transport-belt/hexic-transport-belt.png"
hexic_underground_belt.belt_animation_set.frozen_patch.filename = "__hextorio__/graphics/entity/hexic-transport-belt/hexic-transport-belt-frozen.png"
hexic_underground_belt.corpse = "turbo-underground-belt-remnants" -- TODO
hexic_underground_belt.minable.result = "hexic-underground-belt"
hexic_underground_belt.max_health = 200
hexic_underground_belt.icon = "__hextorio__/graphics/icons/hexic-underground-belt.png"
hexic_underground_belt.max_distance = 15
hexic_underground_belt.structure.back_patch.sheet.filename = "__hextorio__/graphics/entity/hexic-underground-belt/hexic-underground-belt-structure-back-patch.png"
hexic_underground_belt.structure.front_patch.sheet.filename = "__hextorio__/graphics/entity/hexic-underground-belt/hexic-underground-belt-structure-front-patch.png"
hexic_underground_belt.structure.direction_in.sheet.filename = "__hextorio__/graphics/entity/hexic-underground-belt/hexic-underground-belt-structure.png"
hexic_underground_belt.structure.direction_out.sheet.filename = "__hextorio__/graphics/entity/hexic-underground-belt/hexic-underground-belt-structure.png"
hexic_underground_belt.structure.direction_in_side_loading.sheet.filename = "__hextorio__/graphics/entity/hexic-underground-belt/hexic-underground-belt-structure.png"
hexic_underground_belt.structure.direction_out_side_loading.sheet.filename = "__hextorio__/graphics/entity/hexic-underground-belt/hexic-underground-belt-structure.png"
hexic_underground_belt.localised_description = data.raw["underground-belt"]["underground-belt"].localised_description
hexic_underground_belt.factoriopedia_simulation.init = [[
game.simulation.camera_position = {0, 0.5}
game.simulation.camera_zoom = 1.5
game.surfaces[1].create_entities_from_blueprint_string {
    string = "0eNqVkM8KgzAMxt8l5ypMrFhfZYzhn+ACmkpthyK++1I97LDDtlOar8n3S7JBMwScHLGHagNqLc9QXTeYqed6iBrXI0IFD1yoTQJ36HpnJSYNDh52BSTaAtVlvylA9uQJT48jWe8cxgadFKgvXgomO0u75cgVy8SkWsEqD51qIXXksD3/cwV+naIZ8RTiHB+87G+e/gFngz94six5HEV5X1DBE918NOgiM7kxuigzcynzfX8B0UF4kg==",
    position = {0, 0}
}
]]
data.raw["underground-belt"]["turbo-underground-belt"].next_upgrade = "hexic-underground-belt"

local hexic_splitter = table.deepcopy(data.raw["splitter"]["turbo-splitter"])
hexic_splitter.name = "hexic-splitter"
hexic_splitter.speed = hexic_transport_belt.speed
hexic_splitter.belt_animation_set.animation_set.filename = "__hextorio__/graphics/entity/hexic-transport-belt/hexic-transport-belt.png"
hexic_splitter.belt_animation_set.frozen_patch.filename = "__hextorio__/graphics/entity/hexic-transport-belt/hexic-transport-belt-frozen.png"
hexic_splitter.corpse = "turbo-splitter-remnants" -- TODO
hexic_splitter.minable.result = "hexic-splitter"
hexic_splitter.max_health = 200
hexic_splitter.icon = "__hextorio__/graphics/icons/hexic-splitter.png"
hexic_splitter.related_transport_belt = "hexic-transport-belt"
hexic_splitter.structure.east.filename = "__hextorio__/graphics/entity/hexic-splitter/hexic-splitter-east.png"
hexic_splitter.structure.north.filename = "__hextorio__/graphics/entity/hexic-splitter/hexic-splitter-north.png"
hexic_splitter.structure.south.filename = "__hextorio__/graphics/entity/hexic-splitter/hexic-splitter-south.png"
hexic_splitter.structure.west.filename = "__hextorio__/graphics/entity/hexic-splitter/hexic-splitter-west.png"
hexic_splitter.structure_patch.east.filename = "__hextorio__/graphics/entity/hexic-splitter/hexic-splitter-east-top_patch.png"
hexic_splitter.structure_patch.west.filename = "__hextorio__/graphics/entity/hexic-splitter/hexic-splitter-west-top_patch.png"
hexic_splitter.localised_description = data.raw["splitter"]["splitter"].localised_description
data.raw["splitter"]["turbo-splitter"].next_upgrade = "hexic-splitter"


local sentient_spider = table.deepcopy(data.raw["spider-vehicle"]["spidertron"])
sentient_spider.name = "sentient-spider"
sentient_spider.guns = {"sentient-spider-teslagun"}
sentient_spider.equipment_grid = "sentient-spider-equipment-grid"


---@diagnostic disable-next-line: assign-type-mismatch
data:extend({hex_core, hidden_loader, hexic_transport_belt, hexic_underground_belt, hexic_splitter, sentient_spider})
