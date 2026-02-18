
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
        {name = "hexaprism",           default_value = 500000},
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
    local order_category
    if surface_name == "nauvis" or surface_name == "vulcanus" then
        order_category = "p"
    elseif surface_name == "fulgora" or surface_name == "gleba" then
        order_category = "q"
    else
        order_category = "r"
    end

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

data:extend(setting_prots)
