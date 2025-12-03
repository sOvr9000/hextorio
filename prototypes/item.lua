
-- COINS
local hex_coin = table.deepcopy(data.raw["item"]["coin"])
hex_coin.name = "hex-coin"
hex_coin.icon = "__hextorio__/graphics/icons/hex-coin.png"
hex_coin.order = "ya"
hex_coin.stack_size = 99999
hex_coin.auto_recycle = false
hex_coin.subgroup = "other"
hex_coin.hidden = false
hex_coin.weight = 1000000 / hex_coin.stack_size

local gravity_coin = table.deepcopy(hex_coin)
gravity_coin.name = "gravity-coin"
gravity_coin.icon = "__hextorio__/graphics/icons/gravity-coin.png"
gravity_coin.order = "yb"
gravity_coin.auto_recycle = false
gravity_coin.subgroup = "other"
gravity_coin.hidden = false
gravity_coin.weight = 1000000 / gravity_coin.stack_size

local meteor_coin = table.deepcopy(hex_coin)
meteor_coin.name = "meteor-coin"
meteor_coin.icon = "__hextorio__/graphics/icons/meteor-coin.png"
meteor_coin.order = "yc"
meteor_coin.auto_recycle = false
meteor_coin.subgroup = "other"
meteor_coin.hidden = false
meteor_coin.weight = 1000000 / meteor_coin.stack_size

local hexaprism_coin = table.deepcopy(hex_coin)
hexaprism_coin.name = "hexaprism-coin"
hexaprism_coin.icon = "__hextorio__/graphics/icons/hexaprism-coin.png"
hexaprism_coin.order = "yd"
hexaprism_coin.stack_size = 100000
hexaprism_coin.auto_recycle = false
hexaprism_coin.subgroup = "other"
hexaprism_coin.hidden = false
hexaprism_coin.weight = 1000000 / hexaprism_coin.stack_size


-- BELTS
local hexic_transport_belt = table.deepcopy(data.raw["item"]["transport-belt"])
hexic_transport_belt.name = "hexic-transport-belt"
hexic_transport_belt.default_import_location = "aquilo"
hexic_transport_belt.color_hint.text = "5"
hexic_transport_belt.icon = "__hextorio__/graphics/icons/hexic-transport-belt.png"
hexic_transport_belt.order = "a[transport-belt]-e[hexic-transport-belt]"
hexic_transport_belt.place_result = "hexic-transport-belt"
hexic_transport_belt.weight = 20000

local hexic_underground_belt = table.deepcopy(data.raw["item"]["underground-belt"])
hexic_underground_belt.name = "hexic-underground-belt"
hexic_underground_belt.default_import_location = "aquilo"
hexic_underground_belt.color_hint.text = "5"
hexic_underground_belt.icon = "__hextorio__/graphics/icons/hexic-underground-belt.png"
hexic_underground_belt.order = "b[underground-belt]-e[hexic-underground-belt]"
hexic_underground_belt.place_result = "hexic-underground-belt"
hexic_underground_belt.weight = 40000

local hexic_splitter = table.deepcopy(data.raw["item"]["splitter"])
hexic_splitter.name = "hexic-splitter"
hexic_splitter.default_import_location = "aquilo"
hexic_splitter.color_hint.text = "5"
hexic_splitter.icon = "__hextorio__/graphics/icons/hexic-splitter.png"
hexic_splitter.order = "c[splitter]-e[hexic-splitter]"
hexic_splitter.place_result = "hexic-splitter"
hexic_splitter.weight = 20000


-- MODULES
local module_effects = {
    speed = {consumption = 1.0, quality = -0.35, speed = 1.0},
    productivity = {consumption = 1.2, pollution = 0.15, productivity = 0.16, speed = -0.25},
    efficiency = {consumption = -0.80},
    quality = {quality = 0.40, speed = -0.08},
}

local modules = {}
for _, module_type in pairs {{"a", "speed"}, {"c", "productivity"}, {"c", "efficiency"}, {"d", "quality"}} do
    local m = table.deepcopy(data.raw["module"][module_type[2] .. "-module-3"])
    m.name = "hexa-" .. module_type[2] .. "-module"
    -- m.icon = "__hextorio__/graphics/icons/hexa-" .. module_type[2] .. "-module.png"
    m.order = module_type[1] .. "[" .. module_type[2] .. "]-c[" .. module_type[2] .. "-module-4]"
    m.tier = 4
    m.effect = module_effects[module_type[2]]
    table.insert(modules, m)
end
data:extend(modules)



local sentient_spider = table.deepcopy(data.raw["item-with-entity-data"]["spidertron"])
sentient_spider.name = "sentient-spider"
sentient_spider.place_result = "sentient-spider"
sentient_spider.order = "b[personal-transport]-d[sentient-spider]-a[spider]"

-- Combat robot capsules
-- local disintegrator_capsule = table.deepcopy(data.raw["capsule"]["destroyer-capsule"])
-- disintegrator_capsule.name = "disintegrator-capsule"
-- disintegrator_capsule.capsule_action.attack_parameters.ammo_type.action[1].action_delivery.projectile = "disintegrator-capsule"
-- disintegrator_capsule.order = "g[disintegrator-capsule]"
-- disintegrator_capsule.localised_name = nil
-- disintegrator_capsule.localised_description = nil

-- local detonator_capsule = table.deepcopy(data.raw["capsule"]["destroyer-capsule"])
-- detonator_capsule.name = "detonator-capsule"
-- detonator_capsule.capsule_action.attack_parameters.ammo_type.action[1].action_delivery.projectile = "detonator-capsule"
-- detonator_capsule.order = "g[detonator-capsule]"
-- detonator_capsule.localised_name = nil
-- detonator_capsule.localised_description = nil

local demolisher_capsule = table.deepcopy(data.raw["capsule"]["destroyer-capsule"])
demolisher_capsule.name = "demolisher-capsule"
demolisher_capsule.capsule_action.attack_parameters.ammo_type.action[1].action_delivery.projectile = "demolisher-capsule"
demolisher_capsule.order = "g[demolisher-capsule]"
demolisher_capsule.localised_name = nil
demolisher_capsule.localised_description = nil

-- Items
local hexaprism = table.deepcopy(data.raw["item"]["calcite"])
hexaprism.name = "hexaprism"
hexaprism.icon = "__hextorio__/graphics/icons/hexaprism.png"
hexaprism.pictures = nil
hexaprism.order = "h[hexaprism]"
hexaprism.subgroup = "raw-resource"
hexaprism.stack_size = 10
hexaprism.default_import_location = "nauvis"
hexaprism.weight = 100000

local crystalline_fuel = table.deepcopy(data.raw["item"]["nuclear-fuel"])
crystalline_fuel.name = "crystalline-fuel"
crystalline_fuel.icon = "__hextorio__/graphics/icons/crystalline-fuel.png"
crystalline_fuel.pictures.layers[1].filename = "__hextorio__/graphics/icons/crystalline-fuel.png"
crystalline_fuel.order = "r[uranium-processing]-f[crystalline-fuel]"
crystalline_fuel.default_import_location = "nauvis"
crystalline_fuel.fuel_value = "6GJ"
crystalline_fuel.fuel_acceleration_multiplier = 3
crystalline_fuel.fuel_top_speed_multiplier = 1.36

-- Dungeons
local dungeon_chest = table.deepcopy(data.raw["item"]["steel-chest"])
dungeon_chest.name = "dungeon-chest"
dungeon_chest.icon = "__hextorio__/graphics/icons/dungeon-chest.png"
dungeon_chest.order = "a[items]-d[dungeon-chest]"
dungeon_chest.place_result = "dungeon-chest"

---@diagnostic disable: assign-type-mismatch
data:extend({
    hex_coin,
    gravity_coin,
    meteor_coin,
    hexaprism_coin,
    hexic_transport_belt,
    hexic_underground_belt,
    hexic_splitter,
    -- disintegrator_capsule,
    -- detonator_capsule,
    demolisher_capsule,
    sentient_spider,
    hexaprism,
    crystalline_fuel,
    dungeon_chest,
})
