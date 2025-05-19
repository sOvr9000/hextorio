
local lib = require "api.lib"

-- Sort all belt, splitter, and underground belt recipes by their belt speed and put them into new subcategories
local progression = {}
for _, recipe in pairs(data.raw.recipe) do
    for _, result in pairs(recipe.results or {}) do
        if data.raw["transport-belt"][result.name] or data.raw["underground-belt"][result.name] or data.raw["splitter"][result.name] then
            table.insert(progression, result.name)
            break
        end
    end
end

table.sort(progression, function(a, b)
    local a_prot = data.raw["transport-belt"][a] or data.raw["underground-belt"][a] or data.raw["splitter"][a]
    local b_prot = data.raw["transport-belt"][b] or data.raw["underground-belt"][b] or data.raw["splitter"][b]
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
    else
        lib.log_error("data-updates.lua: Unrecognized belt type: " .. item_name)
    end
    if subgroup then
        local prot = data.raw["item"][item_name]
        prot.subgroup = subgroup
        lib.log("Set subgroup of item prototype " .. prot.name .. " to " .. subgroup)
    end
end
