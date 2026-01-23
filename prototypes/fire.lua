
local magmatic_flame = table.deepcopy(data.raw["fire"]["fire-flame"])
magmatic_flame.name = "magmatic-flame"
magmatic_flame.damage_per_tick.amount = 12
magmatic_flame.initial_lifetime = 120
magmatic_flame.lifetime_increase_cooldown = 8
magmatic_flame.lifetime_increase_by = 24
magmatic_flame.maximum_lifetime = 240

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({magmatic_flame})
