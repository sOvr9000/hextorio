
local belt_subgroup = data.raw["item-subgroup"]["belt"]

data:extend({
    {
        type = "item-subgroup",
        name = "underground-belt",
        group = belt_subgroup.group,
        order = belt_subgroup.order .. "-2",
    },
    {
        type = "item-subgroup",
        name = "splitter",
        group = belt_subgroup.group,
        order = belt_subgroup.order .. "-3",
    },
    {
        type = "item-subgroup",
        name = "loader",
        group = belt_subgroup.group,
        order = belt_subgroup.order .. "-4",
    },
    {
        type = "item-subgroup",
        name = "loader-1x1",
        group = belt_subgroup.group,
        order = belt_subgroup.order .. "-5",
    },
})
