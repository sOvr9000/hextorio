
local sets = require "api.sets"

return {
    allowed_condition_types = sets.new {
        "claimed-hexes", -- the more hexes you claim, the higher your score
        "trading-rate", -- the faster (and more) you make trades, the higher your score (counts multi-batch trades as well)
        "researched-technologies", -- the more technologies you research, the higher your score
        "cumulative-claimed-hex-dist", -- the higher the sum of distances from spawn for each of your hexes, the higher your score
        "max-claimed-hex-dist", -- the farther away from spawn you claim a hex, the higher your score
        "obtain-item", -- the more you have of a certain item, the higher your score
        "obtain-coins", -- the more coins you have in your inventory, the higher your score
        "coin-production-rate", -- the better your coin farming, the higher your score
        "spawner-kill-rate", -- the faster you can kill spawners, the higher your score
        "biter-kill-rate", -- the faster you can kill biters, the higher your score
        "planets-reached", -- the more planets you reach, the higher your score
        "space-platform-trips-completed", -- the more trips completed by space platforms, the higher your score
        "depleted-resources", -- the more individual resource tiles you fully mine, the higher your score
        "quests-completed", -- the more quests you complete, the higher your score
        "max-dist-between-trades", -- the farther apart you're making trades from each other, the higher your score
        "rockets-launched", -- the more rockets you launch into space, the higher your score
        "turret-diversity", -- the more types of turrets you place within a 10x10 tile range of each other, the higher your score
        "achievements-unlocked", -- the more achievements you unlock, the higher your score
        "fastest-ship-speed", -- the higher your space platform's top speed, the higher your score

        "biter-spawner-ram", -- destroy a vehicle by ramming it into a biter spawner
        "slippery-drive", -- drive a vehicle on the oceans of Fulgora
        "destroy-item", -- shoot and destroy a chest with a specific item in it
    },

    allowed_reward_types = sets.new {
        "hex-core-input-preservation",
        "hex-core-warp-level-1",
        "hex-core-warp-level-2",
        "automated-hex-claiming-level-1",
        "automated-hex-claiming-level-2",
        "trade-productivity-bonus",
        "resource-conversion",
        "resource-removal",
        "hex-core-removal",
        "trade-reversal",
        "resource-anchoring", -- makes resources infinite in a hex
        "free-space-platform",
        "unlock-t4-modules",
        "unlock-t6-quality",
        "infinite-robot-batteries",
        "spawn-death-spiders",
        "claim-free-hexes",
        "spawn-power-poles",
        "spawn-roboports",
        "trade-overview",
        "trade-loop-finder",
        "megaclaim-hexes",
        "more-trades",
        "unlock-feature",
        "reduce-biters",
    },

    quests = {},
    quests_by_condition_type = {},
    unlocked_features = {},
    players_rewarded = {},
    players_quest_selected = {},

    notes_per_reward_type = {
        ["receive-items"] = {"new-players-receive"},
    },

    notes_per_condition_type = {
        ["trades-found"] = {"finding-counts-unclaimed"},
        ["hex-span"] = {"hex-span-simplified"},
        ["coins-in-inventory"] = {"does-not-consume"},
    },

    quest_defs = {
        {
            name = "ground-zero",
            conditions = {{type = "claimed-hexes", progress_requirement = 2}},
            rewards = {{type = "unlock-feature", value = "catalog"}},
            notes = {"remote-view-to-claim"},
        },
        {
            name = "find-some-trades",
            conditions = {{type = "trades-found", progress_requirement = 40}},
            rewards = {{type = "unlock-feature", value = "trade-overview"}},
            notes = {"trades-randomized"},
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "biter-rammer",
            conditions = {{type = "biter-ramming"}},
            rewards = {{type = "reduce-biters", value = 50}},
            prerequisites = {"ground-zero"},
            show_progress_bar = false,
        },
        {
            name = "exploration",
            conditions = {{type = "claimed-hexes", progress_requirement = 15}},
            rewards = {{type = "receive-items", value = {
                {name = "modular-armor", count = 1},
                {name = "solar-panel-equipment", count = 15},
                {name = "personal-roboport-equipment", count = 1},
                {name = "battery-equipment", count = 3},
                {name = "construction-robot", count = 10},
            }}},
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "sprawling-base",
            conditions = {{type = "hex-span", progress_requirement = 30}},
            rewards = {{type = "unlock-feature", value = "teleportation"}},
            prerequisites = {"exploration"},
            has_img = false,
        },
        {
            name = "too-many-hex-cores",
            conditions = {{type = "claimed-hexes", progress_requirement = 50}},
            rewards = {{type = "unlock-feature", value = "hex-core-deletion"}},
            prerequisites = {"exploration"},
            has_img = false,
        },
        {
            name = "half-a-gravity",
            conditions = {{type = "coins-in-inventory", progress_requirement = 50000}},
            rewards = {{type = "unlock-feature", value = "supercharging"}},
            prerequisites = {"getting-somewhere"},
            has_img = false,
        },
        {
            name = "getting-somewhere",
            conditions = {{type = "coins-in-inventory", progress_requirement = 10000}},
            rewards = {{type = "unlock-feature", value = "generator-mode"}},
            prerequisites = {"find-some-trades"},
            has_img = false,
        },
        {
            name = "trades-galore",
            conditions = {{type = "trades-found", progress_requirement = 200}},
            rewards = {{type = "unlock-feature", value = "sink-mode"}},
            prerequisites = {"find-some-trades"},
            has_img = false,
        },
    },
}
