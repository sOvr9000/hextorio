
local lib = require "api.lib"

---@param prot data.AmmoTurretPrototype | data.ElectricTurretPrototype | data.ArtilleryTurretPrototype | data.FluidTurretPrototype | data.WallPrototype
---@param effect number
function boost_max_health(prot, effect)
    prot.max_health = prot.max_health * effect
end

---@param prot data.AmmoTurretPrototype | data.ElectricTurretPrototype | data.ArtilleryTurretPrototype | data.FluidTurretPrototype | data.WallPrototype
---@param damage_types string[]
---@param effect number
function boost_resistances(prot, damage_types, effect)
    local resistances = {} --[[@as {[string]: data.Resistance[]}]]
    for _, resistance in pairs(prot.resistances or {}) do
        resistances[resistance.type] = resistance
    end
    for _, damage_type in pairs(damage_types) do
        if not resistances[damage_type] then
            resistances[damage_type] = {type = damage_type}
        end
    end
    prot.resistances = {}

    -- Increment towards 100%
    -- For example with effect = 0.1:
    -- 0% -> 10%
    -- 10% -> 19%
    -- 20% -> 28%
    -- 30% -> 37%
    -- ...
    -- 90% -> 91%

    for damage_type, resistance in pairs(resistances) do
        if not resistance.percent then
            resistance.percent = 0
        end
        if lib.table_index(damage_types, damage_type) then
            resistance.percent = resistance.percent + effect * (100 - resistance.percent)
        end
        table.insert(prot.resistances, resistance)
    end
end

---@param prot data.AmmoTurretPrototype | data.ElectricTurretPrototype | data.FluidTurretPrototype
---@param effect number
function boost_range(prot, effect)
    prot.attack_parameters.range = prot.attack_parameters.range * effect
end

---@param prot data.AmmoTurretPrototype | data.ElectricTurretPrototype | data.FluidTurretPrototype
---@param effect number
function boost_damage(prot, effect)
    prot.attack_parameters.damage_modifier = (prot.attack_parameters.damage_modifier or 1) * effect
end

local void_source = {
    type = "void",
    render_no_power_icon = false,
    render_no_network_icon = false,
    emissions_per_minute = {},
} --[[@as data.VoidEnergySource]]

local max_health_boost = 1.20
local wall_max_health_boost = 2.00
local wall_physical_resistance_percentage_boost = 0.40
local resistance_percentage_boost = 0.10
local fire_resistance_percentage_boost = 0.5
local explosion_resistance_percentage_boost = 0.75
local range_boost = 1.25
local damage_boost = 1.0
local railgun_damage_boost = 0.25 -- It one-shots you if not nerfed.

local dungeon_laser_turret = table.deepcopy(data.raw["electric-turret"]["laser-turret"])
dungeon_laser_turret.name = "dungeon-laser-turret"
dungeon_laser_turret.energy_source = void_source
dungeon_laser_turret.healing_per_tick = 0.125
boost_max_health(dungeon_laser_turret, max_health_boost)
boost_resistances(dungeon_laser_turret, {"electric"}, resistance_percentage_boost)
boost_resistances(dungeon_laser_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_laser_turret, {"explosion"}, explosion_resistance_percentage_boost)
boost_range(dungeon_laser_turret, range_boost)
boost_damage(dungeon_laser_turret, damage_boost)

local dungeon_tesla_turret = table.deepcopy(data.raw["electric-turret"]["tesla-turret"])
dungeon_tesla_turret.name = "dungeon-tesla-turret"
dungeon_tesla_turret.energy_source = void_source
dungeon_tesla_turret.healing_per_tick = 0.25
boost_max_health(dungeon_tesla_turret, max_health_boost)
boost_resistances(dungeon_tesla_turret, {"physical", "electric"}, resistance_percentage_boost)
boost_resistances(dungeon_tesla_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_tesla_turret, {"explosion"}, explosion_resistance_percentage_boost)
boost_range(dungeon_tesla_turret, range_boost)
boost_damage(dungeon_tesla_turret, damage_boost)

local dungeon_railgun_turret = table.deepcopy(data.raw["ammo-turret"]["railgun-turret"])
dungeon_railgun_turret.name = "dungeon-railgun-turret"
dungeon_railgun_turret.energy_source = nil
dungeon_railgun_turret.energy_per_shot = nil
dungeon_railgun_turret.healing_per_tick = 1.25
boost_max_health(dungeon_railgun_turret, max_health_boost)
boost_resistances(dungeon_railgun_turret, {"physical", "electric"}, resistance_percentage_boost)
boost_resistances(dungeon_railgun_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_railgun_turret, {"explosion"}, explosion_resistance_percentage_boost)
boost_range(dungeon_railgun_turret, range_boost)
boost_damage(dungeon_railgun_turret, railgun_damage_boost)
dungeon_railgun_turret.heating_energy = "0J"

local dungeon_gun_turret = table.deepcopy(data.raw["ammo-turret"]["gun-turret"])
dungeon_gun_turret.name = "dungeon-gun-turret"
dungeon_gun_turret.healing_per_tick = 0.1
boost_max_health(dungeon_gun_turret, max_health_boost)
boost_resistances(dungeon_gun_turret, {"physical"}, resistance_percentage_boost)
boost_resistances(dungeon_gun_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_gun_turret, {"explosion"}, explosion_resistance_percentage_boost)
boost_range(dungeon_gun_turret, range_boost * 1.3)
boost_damage(dungeon_gun_turret, damage_boost)
dungeon_gun_turret.heating_energy = "0J"

local dungeon_flamethrower_turret = table.deepcopy(data.raw["fluid-turret"]["flamethrower-turret"])
dungeon_flamethrower_turret.name = "dungeon-flamethrower-turret"
dungeon_flamethrower_turret.healing_per_tick = 0.2
boost_max_health(dungeon_flamethrower_turret, max_health_boost)
boost_resistances(dungeon_flamethrower_turret, {"physical"}, resistance_percentage_boost)
boost_resistances(dungeon_flamethrower_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_flamethrower_turret, {"explosion"}, explosion_resistance_percentage_boost)
boost_range(dungeon_flamethrower_turret, range_boost * 0.9)
boost_damage(dungeon_flamethrower_turret, damage_boost)
dungeon_flamethrower_turret.heating_energy = "0J"

local dungeon_rocket_turret = table.deepcopy(data.raw["ammo-turret"]["rocket-turret"])
dungeon_rocket_turret.name = "dungeon-rocket-turret"
dungeon_rocket_turret.healing_per_tick = 0.5
boost_max_health(dungeon_rocket_turret, max_health_boost)
boost_resistances(dungeon_rocket_turret, {"physical", "electric"}, resistance_percentage_boost)
boost_resistances(dungeon_rocket_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_rocket_turret, {"explosion"}, explosion_resistance_percentage_boost)
boost_range(dungeon_rocket_turret, range_boost * 0.8)
boost_damage(dungeon_rocket_turret, damage_boost * 0.5)
dungeon_rocket_turret.heating_energy = "0J"

local dungeon_artillery_turret = table.deepcopy(data.raw["artillery-turret"]["artillery-turret"])
dungeon_artillery_turret.name = "dungeon-artillery-turret"
dungeon_artillery_turret.turret_rotation_speed = dungeon_artillery_turret.turret_rotation_speed * 4
dungeon_artillery_turret.healing_per_tick = 1
boost_max_health(dungeon_artillery_turret, max_health_boost)
boost_resistances(dungeon_artillery_turret, {"physical", "electric"}, resistance_percentage_boost)
boost_resistances(dungeon_artillery_turret, {"fire"}, fire_resistance_percentage_boost)
boost_resistances(dungeon_artillery_turret, {"explosion"}, explosion_resistance_percentage_boost)
dungeon_artillery_turret.heating_energy = "0J"

local dungeon_wall = table.deepcopy(data.raw["wall"]["stone-wall"])
dungeon_wall.name = "dungeon-wall"
dungeon_wall.healing_per_tick = 0.5
boost_max_health(dungeon_wall, wall_max_health_boost)
boost_resistances(dungeon_wall, {"physical"}, wall_physical_resistance_percentage_boost)
boost_resistances(dungeon_wall, {"electric"}, 1)

local dungeon_chest = table.deepcopy(data.raw["container"]["steel-chest"])
dungeon_chest.name = "dungeon-chest"
dungeon_chest.icon = "__hextorio__/graphics/icons/dungeon-chest.png"
dungeon_chest.picture.layers[1].filename = "__hextorio__/graphics/entity/dungeon-chest/dungeon-chest.png"
dungeon_chest.max_health = 9001 -- Functionally pointless, but it makes it seem cooler.
dungeon_chest.inventory_size = 1000
dungeon_chest.minable.result = "dungeon-chest"
dungeon_chest.minable.mining_time = 1

---@diagnostic disable-next-line assign-type-mismatch
data:extend({dungeon_laser_turret, dungeon_tesla_turret, dungeon_gun_turret, dungeon_flamethrower_turret, dungeon_rocket_turret, dungeon_artillery_turret, dungeon_railgun_turret, dungeon_wall, dungeon_chest})
