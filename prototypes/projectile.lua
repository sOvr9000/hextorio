
local demolisher_capsule = table.deepcopy(data.raw["projectile"]["destroyer-capsule"])
demolisher_capsule.name = "demolisher-capsule"
demolisher_capsule.action.action_delivery.target_effects.entity_name = "demolisher"

local poison_capsule = table.deepcopy(data.raw["projectile"]["poison-capsule"])
local plague_rocket = table.deepcopy(data.raw["projectile"]["rocket"])
plague_rocket.name = "plague-rocket"
plague_rocket.acceleration = plague_rocket.acceleration * 2.5
plague_rocket.action.action_delivery.target_effects[2].damage.amount = 240

local create_smoke = poison_capsule.action[1].action_delivery.target_effects[1]
create_smoke.entity_name = "plague-cloud"
table.insert(plague_rocket.action.action_delivery.target_effects, create_smoke)
table.insert(plague_rocket.action.action_delivery.target_effects, poison_capsule.action[1].action_delivery.target_effects[2])

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({demolisher_capsule, plague_rocket})
