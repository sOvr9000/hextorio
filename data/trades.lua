
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
            {{"atomic-bomb"}, {"hex-coin"}},
        },
        vulcanus = {
            {{"calcite", "coal"}, {"hex-coin"}},
            {{"metallurgic-science-pack", "cliff-explosives"}, {"hex-coin"}},
            {{"tungsten-ore", "advanced-circuit"}, {"tungsten-carbide", "processing-unit"}},
            {{"cargo-bay"}, {"thruster", "asteroid-collector"}},
        },
        fulgora = {
            {{"holmium-ore"}, {"hex-coin"}},
            {{"electromagnetic-science-pack", "tesla-ammo"}, {"hex-coin"}},
            {{"hex-coin", "scrap", "steel-plate"}, {"water-barrel"}}, -- S tier trade
        },
        gleba = {
            {{"copper-ore", "yumako-mash"}, {"hex-coin"}},
            {{"iron-ore", "jelly"}, {"hex-coin"}},
            {{"agricultural-science-pack", "carbon-fiber"}, {"hex-coin"}},
            {{"yumako-mash", "jelly", "hex-coin"}, {"carbon-fiber", "nutrients"}},
            {{"spidertron", "efficiency-module-3"}, {"productivity-module-3", "rocket-turret"}},
        },
        aquilo = {
            {{"cryogenic-science-pack", "quantum-processor"}, {"hex-coin"}},
        },
    },

    surrounding_trades = {
        nauvis = {
            {{"low-density-structure"}, {"hex-coin"}},
            {{"iron-plate", "copper-ore", "hex-coin"}, {"stone", "coal"}},
        },
    },

    guaranteed_trades = {},

    discovered_items = {},
    trade_volume_base = {},

    total_items_traded = {},
    total_items_sold = {},
    total_items_bought = {},

    productivity_update_jobs = {}, ---@type TradeProductivityUpdateJob[]
}

