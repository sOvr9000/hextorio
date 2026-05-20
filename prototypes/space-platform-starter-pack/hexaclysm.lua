
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



local SHIP_NAME = "hexaclysm"

local cost = require("data.blueprints." .. SHIP_NAME .. "-cost")
local hexaclysm_foundation = make_tile_rows(require("data.blueprints." .. SHIP_NAME .. "-foundations"))



local ingredients = {}
for _, t in pairs(cost) do
    ingredients[#ingredients+1] = {
        type = "item",
        name = t[1],
        amount = t[2],
    }
end

-- Add vanilla space platform starter pack cost.
local vanilla_starter_pack = data.raw["recipe"]["space-platform-starter-pack"]
for _, item in pairs(vanilla_starter_pack.ingredients) do
    if item.name ~= "space-platform-foundation" then
        ingredients[#ingredients+1] = item
    end
end

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
    ingredients = ingredients,
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
