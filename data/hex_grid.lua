
return {
    surface_hexes = {},
    surface_transformations = {},
    hex_span = {},
    mgs = {},
    resource_weighted_choice = {},

    pool_size = 50,

    directions = { -- adjacency offsets
        {q = 1, r = 0}, {q = 1, r = -1}, {q = 0, r = -1},
        {q = -1, r = 0}, {q = -1, r = 1}, {q = 0, r = 1},
    },
}
