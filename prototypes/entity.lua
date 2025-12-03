local lib = require "api.lib"

local hex_core = { -- Direct copy of original game data.  Switched from table.deepcopy to avoid crashes with some mods that alter that significantly alter this data. (such as AAI containers)
  circuit_connector = {
    points = {
      shadow = {
        green = {
          0.671875,
          0.546875
        },
        red = {
          0.859375,
          0.546875
        }
      },
      wire = {
        green = {
          0.40625,
          0.421875
        },
        red = {
          0.34375,
          0.203125
        }
      }
    },
    sprites = {
      blue_led_light_offset = {
        0.09375,
        0.453125
      },
      connector_main = {
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04a-base-sequence.png",
        height = 50,
        priority = "low",
        scale = 0.5,
        shift = {
          0.09375,
          0.203125
        },
        width = 52,
        x = 104,
        y = 150
      },
      connector_shadow = {
        draw_as_shadow = true,
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04b-base-shadow-sequence.png",
        height = 46,
        priority = "low",
        scale = 0.5,
        shift = {
          0.3125,
          0.3125
        },
        width = 60,
        x = 120,
        y = 138
      },
      led_blue = {
        draw_as_glow = true,
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04e-blue-LED-on-sequence.png",
        height = 60,
        priority = "low",
        scale = 0.5,
        shift = {
          0.09375,
          0.171875
        },
        width = 60,
        x = 120,
        y = 180
      },
      led_blue_off = {
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04f-blue-LED-off-sequence.png",
        height = 44,
        priority = "low",
        scale = 0.5,
        shift = {
          0.09375,
          0.171875
        },
        width = 46,
        x = 92,
        y = 132
      },
      led_green = {
        draw_as_glow = true,
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04h-green-LED-sequence.png",
        height = 46,
        priority = "low",
        scale = 0.5,
        shift = {
          0.09375,
          0.171875
        },
        width = 48,
        x = 96,
        y = 138
      },
      led_light = {
        intensity = 0,
        size = 0.9
      },
      led_red = {
        draw_as_glow = true,
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04i-red-LED-sequence.png",
        height = 46,
        priority = "low",
        scale = 0.5,
        shift = {
          0.09375,
          0.171875
        },
        width = 48,
        x = 96,
        y = 138
      },
      red_green_led_light_offset = {
        0.09375,
        0.359375
      },
      wire_pins = {
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04c-wire-sequence.png",
        height = 58,
        priority = "low",
        scale = 0.5,
        shift = {
          0.09375,
          0.203125
        },
        width = 62,
        x = 124,
        y = 174
      },
      wire_pins_shadow = {
        draw_as_shadow = true,
        filename = "__base__/graphics/entity/circuit-connector/ccm-universal-04d-wire-shadow-sequence.png",
        height = 54,
        priority = "low",
        scale = 0.5,
        shift = {
          0.390625,
          0.34375
        },
        width = 68,
        x = 136,
        y = 162
      }
    }
  },
  circuit_wire_max_distance = 9,
  close_sound = {
    filename = "__base__/sound/metallic-chest-close.ogg",
    volume = 0.3
  },
  collision_box = {
    {
      -0.35,
      -0.35
    },
    {
      0.35,
      0.35
    }
  },
  corpse = "steel-chest-remnants",
  damaged_trigger_effect = {
    damage_type_filters = "fire",
    entity_name = "spark-explosion",
    offset_deviation = {
      {
        -0.5,
        -0.5
      },
      {
        0.5,
        0.5
      }
    },
    offsets = {
      {
        0,
        1
      }
    },
    type = "create-entity"
  },
  dying_explosion = "steel-chest-explosion",
  fast_replaceable_group = "container",
  flags = {
    "placeable-neutral",
    "player-creation"
  },
  icon = "__base__/graphics/icons/steel-chest.png",
  icon_draw_specification = {
    scale = 0.7
  },
  impact_category = "metal",
  inventory_size = 48,
  max_health = 350,
  minable = {
    mining_time = 0.2,
    result = "steel-chest"
  },
  name = "steel-chest",
  open_sound = {
    filename = "__base__/sound/metallic-chest-open.ogg",
    volume = 0.43
  },
  picture = {
    layers = {
      {
        filename = "__base__/graphics/entity/steel-chest/steel-chest.png",
        height = 80,
        priority = "extra-high",
        scale = 0.5,
        shift = {
          -0.0078125,
          -0.015625
        },
        width = 64
      },
      {
        draw_as_shadow = true,
        filename = "__base__/graphics/entity/steel-chest/steel-chest-shadow.png",
        height = 46,
        priority = "extra-high",
        scale = 0.5,
        shift = {
          0.3828125,
          0.25
        },
        width = 110
      }
    }
  },
  resistances = {
    {
      percent = 90,
      type = "fire"
    },
    {
      percent = 60,
      type = "impact"
    }
  },
  selection_box = {
    {
      -0.5,
      -0.5
    },
    {
      0.5,
      0.5
    }
  },
  type = "container"
}



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

local shift_y = 1.8
hex_core.circuit_connector.points.wire.red[2] = hex_core.circuit_connector.points.wire.red[2] + shift_y
hex_core.circuit_connector.points.wire.green[2] = hex_core.circuit_connector.points.wire.green[2] + shift_y
hex_core.circuit_connector.points.shadow.red[2] = hex_core.circuit_connector.points.shadow.red[2] + shift_y
hex_core.circuit_connector.points.shadow.green[2] = hex_core.circuit_connector.points.shadow.green[2] + shift_y

for _, pos in pairs {
    hex_core.circuit_connector.sprites.blue_led_light_offset,
    hex_core.circuit_connector.sprites.red_green_led_light_offset,
    hex_core.circuit_connector.sprites.connector_main.shift,
    hex_core.circuit_connector.sprites.connector_shadow.shift,
    hex_core.circuit_connector.sprites.led_blue.shift,
    hex_core.circuit_connector.sprites.led_blue_off.shift,
    hex_core.circuit_connector.sprites.led_green.shift,
    hex_core.circuit_connector.sprites.led_red.shift,
    hex_core.circuit_connector.sprites.wire_pins.shift,
    hex_core.circuit_connector.sprites.wire_pins_shadow.shift,
} do
    pos[2] = pos[2] + shift_y
end




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
sentient_spider.guns = {"sentient-spider-emp", "sentient-spider-emp", "sentient-spider-emp", "sentient-spider-emp", "sentient-spider-emp", "sentient-spider-emp"}
sentient_spider.equipment_grid = "sentient-spider-equipment-grid"
sentient_spider.inventory_size = 120
sentient_spider.minable.result = "sentient-spider"
sentient_spider.max_health = 10000
sentient_spider.chain_shooting_cooldown_modifier = 3 / 20
-- sentient_spider.healing_per_tick = 2.4 -- This appears to be bugged, doesn't affect the entity
sentient_spider.chunk_exploration_radius = 4
table.insert(sentient_spider.resistances, {type = "electric-hv", percent = 100})
table.insert(sentient_spider.resistances, {type = "electric", percent = 100})


for _, surface_name in pairs {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"} do
    local hex_size = lib.startup_setting_value("hex-size-" .. surface_name)
    ---@cast hex_size number

    local hexport = table.deepcopy(data.raw["roboport"]["roboport"])
    hexport.name = "hexport-" .. surface_name
    hexport.charging_station_count = 6
    hexport.max_logistic_slots = 0
    hexport.robot_slots_count = 0
    hexport.minable = nil
    hexport.collision_box = {{-0.5, -0.5}, {0.5, 0.5}}
    hexport.base_animation = nil
    hexport.door_animation_down = nil
    hexport.door_animation_up = nil
    hexport.allow_copy_paste = false
    hexport.hidden_in_factoriopedia = true
    hexport.base_patch = nil
    hexport.base = nil
    hexport.map_color = hex_core.map_color
    hexport.enemy_map_color = hex_core.map_color
    hexport.friendly_map_color = hex_core.map_color
    hexport.selection_box = nil
    hexport.selectable_in_game = false
    hexport.selection_priority = 0
    hexport.charging_station_count_affected_by_quality = false
    hexport.charging_distance = 3
    hexport.resistances = {
      {
        type = "electric",
        percent = 100,
      },
    }
    hexport.energy_usage = "0kJ"
    hexport.energy_source = {
        type = "void",
        render_no_power_icon = false,
        render_no_network_icon = false,
        emissions_per_minute = {},
    }
    hexport.heating_energy = "0kJ"
    hexport.construction_radius = math.floor(hex_size * 1.5)
    hexport.logistics_radius = hex_size
    hexport.radar_range = math.floor(hex_size / 32 + 0.5) + 1

    local hexlight = table.deepcopy(data.raw["lamp"]["small-lamp"])
    hexlight.name = "hexlight-" .. surface_name
    hexlight.hidden_in_factoriopedia = true
    hexlight.minable = nil
    hexlight.collision_box = {{-0.25, -0.25}, {0.25, 0.25}}
    hexlight.selection_box = nil
    hexlight.selectable_in_game = false
    hexlight.picture_off = nil
    hexlight.picture_on = nil
    hexlight.map_color = hex_core.map_color
    hexlight.enemy_map_color = hex_core.map_color
    hexlight.friendly_map_color = hex_core.map_color
    hexlight.resistances = {
      {
        type = "electric",
        percent = 100,
      },
    }
    hexlight.energy_source = {
        type = "void",
        render_no_power_icon = false,
        render_no_network_icon = false,
        emissions_per_minute = {},
    }
    hexlight.heating_energy = "0kJ"
    hexlight.glow_color_intensity = 0.625

    local r = hex_size * 2.5
    hexlight.glow_size = r
    hexlight.light.size = r
    hexlight.light_when_colored.size = r

    data:extend({hexport, hexlight})
end



---@diagnostic disable-next-line: assign-type-mismatch
data:extend({hex_core, hidden_loader, hexic_transport_belt, hexic_underground_belt, hexic_splitter, sentient_spider})
