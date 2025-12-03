
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

for i = 1, 6 do
    local sentient_spider_emp = table.deepcopy(electromagnetic_penetrator)
    sentient_spider_emp.name = "sentient-spider-emp-" .. i
    sentient_spider_emp.order = nil
    sentient_spider_emp.subgroup = nil
    sentient_spider_emp.localised_name = "item-name.sentient-spider-emp"
    sentient_spider_emp.attack_parameters.projectile_orientation_offset = (i - 2.5) / 6
    sentient_spider_emp.attack_parameters.projectile_creation_distance = 0.5
    data:extend({sentient_spider_emp})
end



data:extend({
    electromagnetic_penetrator,
})
