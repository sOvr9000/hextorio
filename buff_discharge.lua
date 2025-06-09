
-- Buff discharge defense equipment
local discharge = data.raw["active-defense-equipment"]["discharge-defense-equipment"]
discharge.attack_parameters = table.deepcopy(data.raw["electric-turret"]["tesla-turret"].attack_parameters)
discharge.attack_parameters.ammo_type.energy_consumption = "75kJ" -- 50% more than personal laser shots
discharge.attack_parameters.damage_modifier = 0.25
discharge.attack_parameters.range = 12
discharge.attack_parameters.cooldown = 60
discharge.automatic = true
discharge.localised_name = {"item-name.tesla-discharge-defense-equipment"}
discharge.localised_description = {"item-description.tesla-discharge-defense-equipment"}

-- Adjust recipe
local recipe = data.raw["recipe"]["discharge-defense-equipment"]
for _, ingredient in pairs(recipe.ingredients) do
    if ingredient.name == "laser-turret" then
        ingredient.name = "tesla-turret"
    end
end
recipe.category = "electromagnetics"

-- Rebalance tech
local tech = data.raw["technology"]["discharge-defense-equipment"]
local tesla_tech = data.raw["technology"]["tesla-weapons"]
tech.unit = {
    count = 2000,
    ingredients = tesla_tech.unit.ingredients,
    time = tesla_tech.unit.time,
}
table.insert(tech.prerequisites, "tesla-weapons")
tech.localised_name = {"item-name.tesla-discharge-defense-equipment"}
tech.localised_description = {"item-description.tesla-discharge-defense-equipment"}
