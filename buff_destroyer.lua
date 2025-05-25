
-- Buff destroyer bots
local destroyer = data.raw["combat-robot"]["destroyer"]
destroyer.attack_parameters = table.deepcopy(data.raw["electric-turret"]["tesla-turret"].attack_parameters)
destroyer.attack_parameters.damage_modifier = 0.125
destroyer.attack_parameters.cooldown = 10
-- destroyer.attack_parameters.range = 27 -- default 30 is fine
destroyer.time_to_live = 14400 -- 2 minutes, double vanilla flavor
destroyer.localised_name = {"item-name.tesla-destroyer"}
destroyer.speed = 0.05
destroyer.friction = 0.03

-- Adjust recipe
local recipe = data.raw["recipe"]["destroyer-capsule"]
recipe.category = "electromagnetics"
table.insert(recipe.ingredients, {type = "item", name = "tesla-ammo", amount = 4})

-- Rebalance tech
local tech = data.raw["technology"]["destroyer"]
local tesla_tech = data.raw["technology"]["tesla-weapons"]
tech.unit = {
    count = 2000,
    ingredients = tesla_tech.unit.ingredients,
    time = tesla_tech.unit.time,
}
table.insert(tech.prerequisites, "tesla-weapons")
tech.localised_name = {"item-name.tesla-destroyer"}
tech.localised_description = {"item-description.tesla-destroyer"}

-- Adjust other localization
local capsule = data.raw["capsule"]["destroyer-capsule"]
capsule.localised_name = {"item-name.tesla-destroyer-capsule"}
