
local plague_cloud = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud"])
plague_cloud.name = "plague-cloud"
plague_cloud.color = {0.439, 0.039, 0.769, 0.69}
plague_cloud.action_cooldown = 15
plague_cloud.duration = 1800
plague_cloud.action.action_delivery.target_effects.action.action_delivery.target_effects.damage.amount = 24
plague_cloud.created_effect[1].action_delivery.target_effects[1].entity_name = "plague-cloud-visual-dummy"
plague_cloud.created_effect[2].action_delivery.target_effects[1].entity_name = "plague-cloud-visual-dummy"

local plague_cloud_visual_dummy = table.deepcopy(data.raw["smoke-with-trigger"]["poison-cloud-visual-dummy"])
plague_cloud_visual_dummy.name = "plague-cloud-visual-dummy"
plague_cloud_visual_dummy.color = {0.439, 0.039, 0.769, 0.69}

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({plague_cloud, plague_cloud_visual_dummy})
