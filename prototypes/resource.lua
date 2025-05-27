
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

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({hexaprism})
