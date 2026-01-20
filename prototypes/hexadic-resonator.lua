
local items = {}



for i = 1, 6 do
    local hexadic_resonator = table.deepcopy(data.raw["capsule"]["raw-fish"])
    hexadic_resonator.name = "hexadic-resonator-tier-" .. i
    hexadic_resonator.localised_name = {"item-name.hexadic-resonator", i .. "/6"}
    hexadic_resonator.localised_description = {"item-description.hexadic-resonator", tostring(2^(i-1))}
    hexadic_resonator.capsule_action.attack_parameters.ammo_type.action = nil
    hexadic_resonator.icon = "__hextorio__/graphics/icons/hexadic-resonator-" .. i .. ".png"
    hexadic_resonator.subgroup = nil
    hexadic_resonator.spoil_result = nil
    hexadic_resonator.spoil_ticks = nil
    hexadic_resonator.weight = 10000
    hexadic_resonator.stack_size = 10
    hexadic_resonator.send_to_orbit_mode = "not-sendable"
    hexadic_resonator.order = "x[hexadic-resonator]-t[tier-" .. i .. "]"

    items[i] = hexadic_resonator
end



data:extend(items)
