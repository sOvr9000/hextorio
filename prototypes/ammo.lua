
local plague_rocket = table.deepcopy(data.raw["ammo"]["rocket"])
plague_rocket.name = "plague-rocket"
plague_rocket.ammo_type.action.action_delivery.projectile = "plague-rocket"
plague_rocket.order = "d[rocket-launcher]-d[plague]"
plague_rocket.icon = "__hextorio__/graphics/icons/plague-rocket.png"

data.raw["ammo"]["capture-robot-rocket"].order = "d[rocket-launcher]-e[capture]"

local magmatic_rounds_magazine = table.deepcopy(data.raw["ammo"]["piercing-rounds-magazine"])
magmatic_rounds_magazine.name = "magmatic-rounds-magazine"
magmatic_rounds_magazine.icon = "__hextorio__/graphics/icons/magmatic-rounds-magazine.png"
magmatic_rounds_magazine.order = "a[basic-clips]-d[magmatic-rounds-magazine]"
local explosive_rocket = table.deepcopy(data.raw["projectile"]["explosive-rocket"])
local explosive_aoe = explosive_rocket.action.action_delivery.target_effects[6]
explosive_aoe.action.action_delivery.target_effects[1].damage.amount = 4 -- AOE explosive damage
explosive_aoe.action.radius = 3 -- AOE radius
local explosive_direct = explosive_rocket.action.action_delivery.target_effects[2]
explosive_direct.damage.amount = 5 -- Direct explosive damage
magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects[1] = explosive_rocket.action.action_delivery.target_effects[1] -- Explosion graphic
magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects[2].damage.amount = 20 -- Direct physical damage
table.insert(magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects, explosive_direct)
table.insert(magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects, explosive_rocket.action.action_delivery.target_effects[3])
table.insert(magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects, explosive_rocket.action.action_delivery.target_effects[4])
table.insert(magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects, explosive_rocket.action.action_delivery.target_effects[5])
table.insert(magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects, explosive_aoe)
table.insert(magmatic_rounds_magazine.ammo_type.action.action_delivery.target_effects, {
    type = "create-fire",
    entity_name = "magmatic-flame",
})

local electromagnetic_penetrator_cell = table.deepcopy(data.raw["ammo"]["railgun-ammo"])
electromagnetic_penetrator_cell.name = "electromagnetic-penetrator-cell"
electromagnetic_penetrator_cell.order = "e[railgun-ammo]-b[electromagnetic-penetrator-cell]"
electromagnetic_penetrator_cell.ammo_category = "electromagnetic-penetrator"
electromagnetic_penetrator_cell.weight = 100000
electromagnetic_penetrator_cell.stack_size = 1
electromagnetic_penetrator_cell.icon = "__hextorio__/graphics/icons/electromagnetic-penetrator-cell.png"
electromagnetic_penetrator_cell.ammo_type.target_type = "entity"
electromagnetic_penetrator_cell.ammo_type.action.range = 65
electromagnetic_penetrator_cell.ammo_type.action.width = 2
electromagnetic_penetrator_cell.ammo_type.action.force = "enemy"
electromagnetic_penetrator_cell.ammo_type.action.action_delivery.target_effects = {
    {
        type = "nested-result",
        action = {
            type = "direct",
            action_delivery = {
                type = "chain",
                chain = "chain-electromagnetic-penetrator-chain",
                destroy_with_source_or_target = false,
            },
        },
    },
    {
        type = "damage",
        damage = {type = "electric-hv", amount = 1000},
    },
    -- {
    --     type = "nested-result",
    --     action = {
    --         type = "direct",
    --         action_delivery = {
    --             type = "beam",
    --             beam = "chain-electromagnetic-penetrator-beam-start",
    --             destroy_with_source_or_target = false,
    --             add_to_shooter = false,
    --             duration = 20,
    --             max_length = 65,
    --             source_offset = {0, -1.31439},
    --         },
    --     },
    -- },
}



data:extend({plague_rocket, magmatic_rounds_magazine, electromagnetic_penetrator_cell})
