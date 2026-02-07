
require "prototypes.quality"
require "nerf_atomic_bomb"

local lib = require "api.lib"

-- Sort all belt, splitter, and underground belt recipes by their belt speed and put them into new subcategories
local progression = {}
for _, recipe in pairs(data.raw.recipe) do
    for _, result in pairs(recipe.results or {}) do
        if data.raw["transport-belt"][result.name] or data.raw["underground-belt"][result.name] or data.raw["splitter"][result.name] or data.raw["loader"][result.name] or data.raw["loader-1x1"][result.name] then
            table.insert(progression, result.name)
            break
        end
    end
end

table.sort(progression, function(a, b)
    local a_prot = data.raw["transport-belt"][a] or data.raw["underground-belt"][a] or data.raw["splitter"][a] or data.raw["loader"][a] or data.raw["loader-1x1"][a]
    local b_prot = data.raw["transport-belt"][b] or data.raw["underground-belt"][b] or data.raw["splitter"][b] or data.raw["loader"][b] or data.raw["loader-1x1"][b]
    return a_prot.speed > b_prot.speed
end)

for _, item_name in pairs(progression) do
    local subgroup
    if data.raw["transport-belt"][item_name] then
        subgroup = "belt"
    elseif data.raw["underground-belt"][item_name] then
        subgroup = "underground-belt"
    elseif data.raw["splitter"][item_name] then
        subgroup = "splitter"
    elseif data.raw["loader"][item_name] then
        subgroup = "loader"
    elseif data.raw["loader-1x1"][item_name] then
        subgroup = "loader-1x1"
    else
        lib.log_error("data-updates.lua: Unrecognized belt type: " .. item_name)
    end
    if subgroup then
        local prot = data.raw["item"][item_name]
        prot.subgroup = subgroup
        lib.log("Set subgroup of item prototype " .. prot.name .. " to " .. subgroup)
    end
end

data.raw["utility-constants"].default.max_belt_stack_size = math.max(5, data.raw["utility-constants"].default.max_belt_stack_size)
data.raw["utility-constants"].default.inserter_hand_stack_max_sprites = math.max(5, data.raw["utility-constants"].default.inserter_hand_stack_max_sprites)
for _, prot_type in pairs {"inserter", "loader", "loader-1x1"} do
    for _, prot in pairs(data.raw[prot_type]) do
        if (prot.max_belt_stack_size or 1) > 1 then
            prot.max_belt_stack_size = math.max(5, prot.max_belt_stack_size)
            log("set size of " .. prot.name .. " to " .. prot.max_belt_stack_size)
        end
    end
end

-- Define pseudo-signal item prototypes for selecting qualities in choose-elem buttons
-- This is a workaround for the problem that choose-elem buttons do not support filters when their element types are "signal": https://lua-api.factorio.com/latest/concepts/PrototypeFilter.html
local pseudo_signals = {}
for _, quality in pairs(data.raw["quality"]) do
    table.insert(pseudo_signals, {
        type = "item",
        name = "pseudo-signal-quality-" .. quality.name,
        stack_size = 1,
        localised_name = {"quality-name." .. quality.name},
        hidden_in_factoriopedia = true,
        hidden = false,
        order = "z-" .. quality.level,
        icon = quality.icon,
        icons = quality.icons,
        icon_size = quality.icon_size,
    })
end
data:extend(pseudo_signals)
