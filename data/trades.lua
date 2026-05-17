
-- local trades = require "api.trades"


-- local nauvis_only = {1,0,0,0,0}
-- local vulcanus_only = {0,1,0,0,0}
-- local fulgora_only = {0,0,1,0,0}
-- local gleba_only = {0,0,0,1,0}
-- local aquilo_only = {0,0,0,0,1}
-- local not_aquilo = {1,1,1,1,0}

local deprecated_trade_shape_weights_lookup_main = require "data.trades_legacy_main"


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
            {{"advanced-circuit"}, {"hex-coin"}},
            {{"spoilage", "raw-fish"}, {"hex-coin"}},
            {{"production-science-pack", "utility-science-pack"}, {"hex-coin"}},
            {{"hex-coin"}, {"plastic-bar"}},
            {{"hex-coin", "firearm-magazine"}, {"piercing-rounds-magazine"}},
        },
    },

    -- List of trade shape weights built in.  The actual used trade shape weights can be overridden by other mods.
    trade_shape_weights_lookup = {
        ["simple"] = {
            {num_inputs = 0, num_outputs = 1, weight = 0},
            {num_inputs = 1, num_outputs = 0, weight = 0},

            {num_inputs = 0, num_outputs = 2, weight = 0},
            {num_inputs = 0, num_outputs = 3, weight = 0},
            {num_inputs = 2, num_outputs = 0, weight = 0},
            {num_inputs = 3, num_outputs = 0, weight = 0},

            {num_inputs = 1, num_outputs = 1, weight = 660},
            {num_inputs = 1, num_outputs = 2, weight = 148},
            {num_inputs = 1, num_outputs = 3, weight = 50},
            {num_inputs = 2, num_outputs = 1, weight = 141},
            {num_inputs = 2, num_outputs = 2, weight = 95},
            {num_inputs = 2, num_outputs = 3, weight = 94},
            {num_inputs = 3, num_outputs = 1, weight = 51},
            {num_inputs = 3, num_outputs = 2, weight = 100},
            {num_inputs = 3, num_outputs = 3, weight = 161},
        },
        ["balanced"] = {
            {num_inputs = 0, num_outputs = 1, weight = 0},
            {num_inputs = 1, num_outputs = 0, weight = 0},

            {num_inputs = 0, num_outputs = 2, weight = 0},
            {num_inputs = 0, num_outputs = 3, weight = 0},
            {num_inputs = 2, num_outputs = 0, weight = 0},
            {num_inputs = 3, num_outputs = 0, weight = 0},

            {num_inputs = 1, num_outputs = 1, weight = 364},
            {num_inputs = 1, num_outputs = 2, weight = 160},
            {num_inputs = 1, num_outputs = 3, weight = 76},
            {num_inputs = 2, num_outputs = 1, weight = 128},
            {num_inputs = 2, num_outputs = 2, weight = 151},
            {num_inputs = 2, num_outputs = 3, weight = 151},
            {num_inputs = 3, num_outputs = 1, weight = 67},
            {num_inputs = 3, num_outputs = 2, weight = 152},
            {num_inputs = 3, num_outputs = 3, weight = 251},
        },
        ["complex"] = {
            {num_inputs = 0, num_outputs = 1, weight = 0},
            {num_inputs = 1, num_outputs = 0, weight = 0},

            {num_inputs = 0, num_outputs = 2, weight = 0},
            {num_inputs = 0, num_outputs = 3, weight = 0},
            {num_inputs = 2, num_outputs = 0, weight = 0},
            {num_inputs = 3, num_outputs = 0, weight = 0},
            
            {num_inputs = 1, num_outputs = 1, weight = 177},
            {num_inputs = 1, num_outputs = 2, weight = 124},
            {num_inputs = 1, num_outputs = 3, weight = 90},
            {num_inputs = 2, num_outputs = 1, weight = 119},
            {num_inputs = 2, num_outputs = 2, weight = 143},
            {num_inputs = 2, num_outputs = 3, weight = 178},
            {num_inputs = 3, num_outputs = 1, weight = 90},
            {num_inputs = 3, num_outputs = 2, weight = 181},
            {num_inputs = 3, num_outputs = 3, weight = 398},
        },
    },
    -- DEPRECATED: Legacy snapshot from `main` for temporary generator sampling/comparison.
    deprecated_trade_shape_weights_lookup_main = deprecated_trade_shape_weights_lookup_main,

    base_trade_productivity = {}, -- Planet-wide buffs/debuffs to trade productivity.
    base_productivity = 0, -- Universal buff to trade productivity, regardless of planet.

    unresearched_penalty = 0,

    guaranteed_trades = {},

    discovered_items = {},
    researched_items = {},
    trade_volume_base = {},

    total_items_traded = {},
    total_items_sold = {},
    total_items_bought = {},

    productivity_update_jobs = {}, ---@type TradeProductivityUpdateJob[]
    trade_collection_jobs = {}, ---@type TradeCollectionJob[]
    trade_filtering_jobs = {}, ---@type TradeFilteringJob[]
    trade_sorting_jobs = {}, ---@type TradeSortingJob[]
    trade_export_jobs = {}, ---@type TradeExportJob[]
}
