
local electromagnetic_penetrator = table.deepcopy(data.raw["gun"]["railgun"])
electromagnetic_penetrator.name = "electromagnetic-penetrator"
electromagnetic_penetrator.weight = 200000
electromagnetic_penetrator.order = "a[basic-clips]-i[electromagnetic-penetrator]"
electromagnetic_penetrator.attack_parameters = {
    type = "projectile",
    ammo_category = "electromagnetic-penetrator",
    ammo_consumption_modifier = 0,
    cooldown = 120,
    range = 50,
    movement_slow_down_cooldown = 0.25,
    projectile_creation_distance = 1.125,
}

local sentient_spider_emp = table.deepcopy(electromagnetic_penetrator)
sentient_spider_emp.name = "sentient-spider-emp"
sentient_spider_emp.order = nil
sentient_spider_emp.subgroup = nil
sentient_spider_emp.attack_parameters.projectile_creation_distance = 2.5



data:extend({
    electromagnetic_penetrator,
    sentient_spider_emp,
})
