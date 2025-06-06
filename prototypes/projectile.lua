
local demolisher_capsule = table.deepcopy(data.raw["projectile"]["destroyer-capsule"])
demolisher_capsule.name = "demolisher-capsule"
demolisher_capsule.action.action_delivery.target_effects.entity_name = "demolisher"

local poison_capsule = data.raw["projectile"]["poison-capsule"]
local poison_rocket = table.deepcopy(data.raw["projectile"]["rocket"])
poison_rocket.name = "poison-rocket"
table.insert(poison_rocket.action.action_delivery.target_effects, poison_capsule.action[1].action_delivery.target_effects[1])
table.insert(poison_rocket.action.action_delivery.target_effects, poison_capsule.action[1].action_delivery.target_effects[2])

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({demolisher_capsule, poison_rocket})
