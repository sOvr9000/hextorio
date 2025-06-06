
local magmatic_flame = table.deepcopy(data.raw["fire"]["fire-flame"])
magmatic_flame.name = "magmatic-flame"
magmatic_flame.damage_per_tick.amount = 12

---@diagnostic disable-next-line: assign-type-mismatch
data:extend({magmatic_flame})
