
local plague_rocket = table.deepcopy(data.raw["ammo"]["rocket"])
plague_rocket.name = "plague-rocket"
plague_rocket.ammo_type.action.action_delivery.projectile = "plague-rocket"
plague_rocket.order = "d[rocket-launcher]-d[plague]"
plague_rocket.icon = "__hextorio__/graphics/icons/plague-rocket.png"

data.raw["ammo"]["capture-robot-rocket"].order = "d[rocket-launcher]-e[capture]"

data:extend({plague_rocket})
