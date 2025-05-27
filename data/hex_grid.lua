
return {
    surface_hexes = {},
    surface_transformations = {},
    hex_span = {},
    mgs = {},
    resource_weighted_choice = {},
    gleba_ignore_tiles = {
        ["wetland-yumako"] = true,
        ["natural-yumako-soil"] = true,
        ["wetland-jellynut"] = true,
        ["natural-jellynut-soil"] = true,
    },

    pool_size = 50,

    directions = { -- adjacency offsets
        {q = 1, r = 0}, {q = 1, r = -1}, {q = 0, r = -1},
        {q = -1, r = 0}, {q = -1, r = 1}, {q = 0, r = 1},
    },
}
