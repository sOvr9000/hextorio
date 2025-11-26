
return {
    item_ranks = {},

    rank_up_requirements = {1, 1, 1, 1},
    productivity_requirements = {
        [2] = 0.3, -- Bronze -> Silver
        [3] = 0.7, -- Silver -> Gold
        [4] = 1.2 -- Gold -> Red
    },

    rank_colors = {
        {102, 102, 102}, -- gray
        {221, 127, 33}, -- orange
        {204, 204, 204}, -- white
        {212, 169, 19}, -- yellow
        {207, 6, 0} -- red
    },

    rank_star_sprites = {
        "star-silhouette",
        "bronze-star",
        "silver-star",
        "gold-star",
        "red-star",
    },
}
