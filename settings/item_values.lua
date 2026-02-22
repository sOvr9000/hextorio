local lib = require "api.lib"

local setting_prots = {}
for surface_name, surface_prot_data in pairs {
    nauvis = {
        {name = "wood",                default_value = 0.5},
        {name = "raw-fish",            default_value = 2.5},
        {name = "iron-ore",            default_value = 0.1},
        {name = "copper-ore",          default_value = 0.08},
        {name = "stone",               default_value = 0.06},
        {name = "coal",                default_value = 0.12},
        {name = "uranium-ore",         default_value = 0.4},
        {name = "hexaprism",           default_value = 5000000},
        {name = "water",               default_value = 0.001},
        {name = "crude-oil",           default_value = 0.01},
    },
    vulcanus = {
        {name = "coal",                default_value = 0.06},
        {name = "calcite",             default_value = 0.2},
        {name = "tungsten-ore",        default_value = 8.1},
        {name = "lava",                default_value = 0.002},
        {name = "sulfuric-acid",       default_value = 0.05},
    },
    fulgora = {
        {name = "heavy-oil",           default_value = 0.006},
        {name = "scrap",               default_value = 0.1},
    },
    gleba = {
        {name = "wood",                default_value = 0.5},
        {name = "stone",               default_value = 0.1},
        {name = "yumako",              default_value = 1.2},
        {name = "jellynut",            default_value = 1.8},
        {name = "pentapod-egg",        default_value = 6.4},
        {name = "water",               default_value = 0.001},
    },
    aquilo = {
        {name = "ammoniacal-solution", default_value = 0.001},
        {name = "crude-oil",           default_value = 0.1},
        {name = "fluorine",            default_value = 1},
        {name = "lithium-brine",       default_value = 10},
    },
} do
    local order_category = lib.get_planet_order_category(surface_name)
    for _, prot_data in pairs(surface_prot_data) do
        local item_name = prot_data.name
        local default_value = prot_data.default_value

        setting_prots[#setting_prots+1] = {
            type = "double-setting",
            setting_type = "runtime-global",
            name = "hextorio-raw-value-" .. surface_name .. "-" .. item_name,
            order = "v[item-values]-r[raw-values]-" .. order_category .. "[" .. surface_name .. "]-n[" .. item_name .. "]",
            default_value = default_value,
            minimum_value = 0.0000001,
        }
    end
end

for surface_name, config_data in pairs {
    nauvis   = {energy_coefficient = 0.06, complexity_coefficient = 0.15, raw_multiplier = 1.50, spoilable_coefficient = 0.75},
    vulcanus = {energy_coefficient = 0.03, complexity_coefficient = 0.13, raw_multiplier = 1.60, spoilable_coefficient = 0.75},
    fulgora  = {energy_coefficient = 0.08, complexity_coefficient = 0.18, raw_multiplier = 1.65, spoilable_coefficient = 0.75},
    gleba    = {energy_coefficient = 0.07, complexity_coefficient = 0.17, raw_multiplier = 1.70, spoilable_coefficient = 0.30},
    aquilo   = {energy_coefficient = 0.03, complexity_coefficient = 0.50, raw_multiplier = 2.00, spoilable_coefficient = 1.25},
} do
    local order_category = lib.get_planet_order_category(surface_name)
    for config_name, default_value in pairs(config_data) do
        local min_value = 0
        local max_value = 2

        if config_name == "raw_multiplier" then
            min_value = 1
        end
        if config_name == "energy_coefficient" then
            max_value = 0.5
        end

        setting_prots[#setting_prots+1] = {
            type = "double-setting",
            setting_type = "runtime-global",
            name = "hextorio-planet-config-" .. surface_name .. "-" .. config_name:gsub("_", "-"),
            order = "v[item-values]-q[planet-configs]-" .. order_category .. "[" .. surface_name .. "]-" .. order_category .. "[" .. config_name:gsub("_", "-") .. "]",
            default_value = default_value,
            minimum_value = min_value,
            maximum_value = max_value,
        }
    end
end

data:extend(setting_prots)
