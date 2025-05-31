
local sets = require "api.sets"

return {
    surface_hexes = {},
    surface_transformations = {},
    hex_span = {},
    mgs = {},
    resource_weighted_choice = {},
    gleba_ignore_tiles = sets.new {
        "wetland-yumako",
        "natural-yumako-soil",
        "wetland-jellynut",
        "natural-jellynut-soil",

        "wetland-dead-skin",
        "wetland-light-dead-skin",
        "wetland-green-slime",
        "wetland-light-green-slime",
        "wetland-red-tentacle",
        "wetland-pink-tentacle",
        "wetland-blue-slime",
    },

    pool_size = 50,
}
