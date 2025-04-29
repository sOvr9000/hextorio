
-- local trades = require "api.trades"


-- local nauvis_only = {1,0,0,0,0}
-- local vulcanus_only = {0,1,0,0,0}
-- local fulgora_only = {0,0,1,0,0}
-- local gleba_only = {0,0,0,1,0}
-- local aquilo_only = {0,0,0,0,1}
-- local not_aquilo = {1,1,1,1,0}



return {
    starting_trades = {
        {{"electronic-circuit", "stone-brick"}, {"hex-coin"}},
        {{"copper-cable", "boiler"}, {"wood", "raw-fish"}},
        {{"iron-plate", "copper-ore", "hex-coin"}, {"stone", "coal"}},
        {{"low-density-structure"}, {"hex-coin"}},
        {{"atomic-bomb"}, {"hex-coin"}},
    },

    discovered_items = {},

    total_items_traded = {},
    total_items_sold = {},
    total_items_bought = {},
}

