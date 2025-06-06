
local poison_rocket = table.deepcopy(data.raw["ammo"]["rocket"])
poison_rocket.name = "poison-rocket"
poison_rocket.ammo_type.action.action_delivery.projectile = "poison-rocket"
poison_rocket.order = "d[rocket-launcher]-d[poison]"
poison_rocket.icon = "__hextorio__/graphics/icons/poison-rocket.png"

data.raw["ammo"]["capture-robot-rocket"].order = "d[rocket-launcher]-e[capture]"

data:extend({poison_rocket})
