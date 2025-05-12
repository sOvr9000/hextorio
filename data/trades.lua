
-- local trades = require "api.trades"


-- local nauvis_only = {1,0,0,0,0}
-- local vulcanus_only = {0,1,0,0,0}
-- local fulgora_only = {0,0,1,0,0}
-- local gleba_only = {0,0,0,1,0}
-- local aquilo_only = {0,0,0,0,1}
-- local not_aquilo = {1,1,1,1,0}



return {
    starting_trades = {
        nauvis = {
            {{"electronic-circuit", "stone-brick"}, {"hex-coin"}},
            {{"copper-cable", "boiler"}, {"wood", "raw-fish"}},
            {{"iron-plate", "copper-ore", "hex-coin"}, {"stone", "coal"}},
            {{"low-density-structure"}, {"hex-coin"}},
            {{"atomic-bomb"}, {"hex-coin"}},
        },
        vulcanus = {
            {{"calcite", "coal"}, "hex-coin"},
            {{"metallurgic-science-pack", "cliff-explosives"}, "hex-coin"},
            {{"tungsten-ore", "advanced-circuit"}, {"tungsten-carbide", "processing-unit"}},
            {{"cargo-bay"}, {"thruster", "asteroid-collector"}},
        },
    },

    discovered_items = {},
    trade_volume_base = {},

    total_items_traded = {},
    total_items_sold = {},
    total_items_bought = {},
}

