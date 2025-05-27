
local hexaprism = table.deepcopy(data.raw["resource"]["uranium-ore"])
hexaprism.name = "hexaprism"
hexaprism.icon = "__hextorio__/graphics/icons/hexaprism-ore.png"
hexaprism.order = "a-b-c"
hexaprism.map_color = {0.22, 0.28, 0.44}
hexaprism.mining_visualisation_tint = {0.22, 0.28, 0.44} -- color of dust as drill mines resource
hexaprism.minable.mining_time = 10
hexaprism.minable.fluid_amount = 5
hexaprism.minable.required_fluid = "fluoroketone-hot"
hexaprism.minable.result = "hexaprism"
hexaprism.stages.sheet.filename = "__hextorio__/graphics/entity/hexaprism/hexaprism.png"
hexaprism.stages_effect.sheet.filename = "__hextorio__/graphics/entity/hexaprism/hexaprism.png"
hexaprism.factoriopedia_simulation.init = [[
game.simulation.camera_position = {0, -0.5}
game.surfaces[1].create_entity{name = "hexaprism", position = {-2.5, -2.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-1.5, -2.5}, amount = 100}
game.surfaces[1].create_entity{name = "hexaprism", position = {-0.5, -2.5}, amount = 500}
game.surfaces[1].create_entity{name = "hexaprism", position = {1.5, -2.5}, amount = 150}
game.surfaces[1].create_entity{name = "hexaprism", position = {0.5, -2.5}, amount = 200}
game.surfaces[1].create_entity{name = "hexaprism", position = {2.5, -2.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-4.5, -0.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-3.5, -1.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-3.5, -0.5}, amount = 150}
game.surfaces[1].create_entity{name = "hexaprism", position = {-2.5, -1.5}, amount = 150}
game.surfaces[1].create_entity{name = "hexaprism", position = {-2.5, -0.5}, amount = 650}
game.surfaces[1].create_entity{name = "hexaprism", position = {-0.5, -0.5}, amount = 1000}
game.surfaces[1].create_entity{name = "hexaprism", position = {-1.5, -0.5}, amount = 850}
game.surfaces[1].create_entity{name = "hexaprism", position = {-0.5, -1.5}, amount = 800}
game.surfaces[1].create_entity{name = "hexaprism", position = {-1.5, -1.5}, amount = 650}
game.surfaces[1].create_entity{name = "hexaprism", position = {1.5, -1.5}, amount = 450}
game.surfaces[1].create_entity{name = "hexaprism", position = {1.5, -0.5}, amount = 1000}
game.surfaces[1].create_entity{name = "hexaprism", position = {0.5, -0.5}, amount = 1050}
game.surfaces[1].create_entity{name = "hexaprism", position = {0.5, -1.5}, amount = 850}
game.surfaces[1].create_entity{name = "hexaprism", position = {3.5, -1.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {3.5, -0.5}, amount = 250}
game.surfaces[1].create_entity{name = "hexaprism", position = {2.5, -1.5}, amount = 250}
game.surfaces[1].create_entity{name = "hexaprism", position = {2.5, -0.5}, amount = 500}
game.surfaces[1].create_entity{name = "hexaprism", position = {4.5, -0.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-2.5, 1.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-3.5, 0.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-2.5, 0.5}, amount = 200}
game.surfaces[1].create_entity{name = "hexaprism", position = {-1.5, 1.5}, amount = 150}
game.surfaces[1].create_entity{name = "hexaprism", position = {-0.5, 1.5}, amount = 550}
game.surfaces[1].create_entity{name = "hexaprism", position = {-0.5, 0.5}, amount = 850}
game.surfaces[1].create_entity{name = "hexaprism", position = {-1.5, 0.5}, amount = 700}
game.surfaces[1].create_entity{name = "hexaprism", position = {1.5, 1.5}, amount = 250}
game.surfaces[1].create_entity{name = "hexaprism", position = {0.5, 1.5}, amount = 300}
game.surfaces[1].create_entity{name = "hexaprism", position = {1.5, 0.5}, amount = 550}
game.surfaces[1].create_entity{name = "hexaprism", position = {0.5, 0.5}, amount = 1000}
game.surfaces[1].create_entity{name = "hexaprism", position = {3.5, 1.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {2.5, 1.5}, amount = 150}
game.surfaces[1].create_entity{name = "hexaprism", position = {3.5, 0.5}, amount = 150}
game.surfaces[1].create_entity{name = "hexaprism", position = {2.5, 0.5}, amount = 300}
game.surfaces[1].create_entity{name = "hexaprism", position = {4.5, 0.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {-0.5, 2.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {1.5, 2.5}, amount = 50}
game.surfaces[1].create_entity{name = "hexaprism", position = {2.5, 2.5}, amount = 50}
]]

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({hexaprism})
