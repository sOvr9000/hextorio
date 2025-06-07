
local lib = require "api.lib"

if lib.data.is_hextreme_enabled() then
    local hextreme = {
        type = "quality",
        name = "hextreme",
        color = {128, 32, 16},
        icon = "__hextorio__/graphics/icons/hextreme.png",
        level = 8,
        mining_drill_resource_drain_multiplier = 0.08333333333333333333333,
        science_pack_drain_multiplier = 0.90,
        beacon_power_usage_multiplier = 1/9,
        subgroup = "qualities",
        order = "e0", -- right after legendary, even if other mods add more qualities
    }

    -- Other mods might be adding more qualities.
    -- Insert hextreme before the first one that other mods have added after legendary.
    hextreme.next = data.raw.quality.legendary.next

    data.raw.quality.legendary.next = "hextreme"
    data.raw.quality["legendary"].next_probability = 0.1

    data:extend({hextreme})
end
