local lib = require "api.lib"

local strongboxes = {}



local strongbox_base = table.deepcopy(data.raw["container"]["steel-chest"])
strongbox_base.is_military_target = true
strongbox_base.inventory_type = "normal"
strongbox_base.icon = "__hextorio__/graphics/icons/strongbox.png"
strongbox_base.picture.layers[1].filename = "__hextorio__/graphics/entity/strongbox/strongbox.png"
strongbox_base.hidden = true
strongbox_base.hidden_in_factoriopedia = true
strongbox_base.enemy_map_color = {1, 0.5, 0}
-- strongbox_base.overkill_fraction = 0.1 -- TODO: determine what this should be
strongbox_base.hide_resistances = true
strongbox_base.resistances = {}
strongbox_base.minable = nil
strongbox_base.inventory_size = 10
strongbox_base.localised_description = {"entity-description.strongbox"}
strongbox_base.flags = {"breaths-air"} -- Don't give immunity to poison / plague rockets
strongbox_base.surface_conditions = nil

-- e ^ (3 + scaling_rate * (sb_tier - 1)) = max_sb_health
-- ln(max_sb_health) = 3 + scaling_rate * (sb_tier - 1)
-- (ln(max_sb_health) - 3) / scaling_rate + 1 = sb_tier

local max_sb_health = 2000000000
local scaling_rate = 0.5
local max_tier = math.floor((math.log(max_sb_health) - 3) / scaling_rate - 0.5)

lib.log("Creating " .. max_tier .. " tiers of strongboxes.")
for sb_tier = 1, max_tier do
    local strongbox = table.deepcopy(strongbox_base)
    strongbox.name = "strongbox-tier-" .. sb_tier
    strongbox.localised_name = {"entity-name.strongbox", tostring(sb_tier)}

    strongbox.max_health = math.floor(0.5 + math.min(max_sb_health, math.exp(3 + scaling_rate * (sb_tier - 1))))

    table.insert(strongboxes, strongbox)
end
lib.log("Finished creating strongbox tiers.")



data:extend(strongboxes)
