
local demolisher_capsule = table.deepcopy(data.raw["projectile"]["destroyer-capsule"])
demolisher_capsule.name = "demolisher-capsule"
demolisher_capsule.action.action_delivery.target_effects.entity_name = "demolisher"

data:extend({demolisher_capsule})
