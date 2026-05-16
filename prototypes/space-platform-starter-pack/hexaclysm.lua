
---@param rows int[][]
---@return data.SpacePlatformTileDefinition[]
local function make_tile_rows(rows)
    local tiles = {}
    for _, row in pairs(rows) do
        local y = row[1]
        for x = row[2], row[3] do
            table.insert(tiles, {tile = "space-platform-foundation", position = {x, y}})
        end
    end
    return tiles
end

local hexaclysm_foundation = make_tile_rows({
    {-24, -1, 0},
    {-23, -2, 1},
    {-22, -5, 4},
    {-21, -5, 4},
    {-20, -6, 5},
    {-19, -7, 6},
    {-18, -9, 8},
    {-17, -11, 10},
    {-16, -11, 10},
    {-15, -13, 12},
    {-14, -14, 13},
    {-13, -15, 14},
    {-12, -16, 15},
    {-11, -16, 15},
    {-10, -19, 18},
    {-9, -19, 18},
    {-8, -19, 18},
    {-7, -19, 18},
    {-6, -19, 18},
    {-5, -19, 18},
    {-4, -19, 18},
    {-3, -19, 18},
    {-2, -19, 18},
    {-1, -19, 18},
    {0, -19, 18},
    {1, -19, 18},
    {2, -19, 18},
    {3, -19, 18},
    {4, -19, 18},
    {5, -19, 18},
    {6, -19, 18},
    {7, -18, 18},
    {8, -18, 18},
    {9, -19, 18},
    {10, -19, 18},
    {11, -19, 18},
    {12, -19, 18},
    {13, -19, 18},
    {14, -15, 14},
    {15, -15, 14},
    {16, -11, 10},
    {17, -11, 10},
    {18, -7, 6},
    {19, -7, 6},
    {20, -6, 5},
    {21, -6, 5},
    {22, -2, 1},
    {23, -2, 1},
})

local hexaclysm_starter_pack = table.deepcopy(data.raw["space-platform-starter-pack"]["space-platform-starter-pack"])
hexaclysm_starter_pack.name = "starter-pack-hexaclysm"
hexaclysm_starter_pack.order = "b[space-platform-starter-pack]-b[hexaclysm]"
hexaclysm_starter_pack.trigger[1].action_delivery.source_effects[1].trigger_created_entity = true
hexaclysm_starter_pack.tiles = hexaclysm_foundation
hexaclysm_starter_pack.initial_items = nil

local hexaclysm_starter_pack_recipe = {
    type = "recipe",
    name = "starter-pack-hexaclysm",
    enabled = false,
    allow_quality = false,
    ingredients = {
        -- Hub cost (vanilla)
        {type = "item", name = "steel-plate", amount = 20},
        {type = "item", name = "processing-unit", amount = 20},

        -- Vessel cost
        {type = "item", name = "accumulator", amount = 12},
        {type = "item", name = "assembling-machine-3", amount = 2},
        {type = "item", name = "asteroid-collector", amount = 4},
        {type = "item", name = "cargo-bay", amount = 6},
        {type = "item", name = "chemical-plant", amount = 7},
        {type = "item", name = "crusher", amount = 4},
        {type = "item", name = "decider-combinator", amount = 4},
        {type = "item", name = "display-panel", amount = 3},
        {type = "item", name = "efficiency-module-2", amount = 19},
        {type = "item", name = "electric-furnace", amount = 6},
        {type = "item", name = "express-splitter", amount = 5},
        {type = "item", name = "express-transport-belt", amount = 127},
        {type = "item", name = "express-underground-belt", amount = 86},
        {type = "item", name = "fast-inserter", amount = 33},
        {type = "item", name = "fast-underground-belt", amount = 6},
        {type = "item", name = "gun-turret", amount = 18},
        {type = "item", name = "inserter", amount = 26},
        {type = "item", name = "long-handed-inserter", amount = 12},
        {type = "item", name = "pipe", amount = 57},
        {type = "item", name = "pipe-to-ground", amount = 20},
        {type = "item", name = "small-lamp", amount = 8},
        {type = "item", name = "solar-panel", amount = 17},
        {type = "item", name = "space-platform-foundation", amount = 1336},
        {type = "item", name = "speed-module", amount = 1},
        {type = "item", name = "speed-module-2", amount = 7},
        {type = "item", name = "speed-module-3", amount = 6},
        {type = "item", name = "stone-wall", amount = 32},
        {type = "item", name = "storage-tank", amount = 3},
        {type = "item", name = "thruster", amount = 9},
    },
    energy_required = 120,
    results = {{type = "item", name = "starter-pack-hexaclysm", amount = 1}},
}

local starter_pack_tech = {
    type = "technology",
    name = "starter-pack-hexaclysm",
    prerequisites = {"speed-module-3", "quality-module"},
    icon = "__space-age__/graphics/technology/space-platform.png",
    icon_size = 256,
    effects = {
        {
            type = "unlock-recipe",
            recipe = "starter-pack-hexaclysm",
        },
    },
    unit = {
        count = 2500,
        time = 60,
        ingredients = {
            {"automation-science-pack", 1},
            {"logistic-science-pack", 1},
            {"chemical-science-pack", 1},
            {"space-science-pack", 1},
            {"metallurgic-science-pack", 1},
        },
    },
}

data:extend({starter_pack_tech, hexaclysm_starter_pack, hexaclysm_starter_pack_recipe})
