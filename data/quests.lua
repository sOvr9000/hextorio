
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
            rewards = {{type = "unlock-feature", value = "trade-overview"}, {type = "claim-free-hexes", value = {"nauvis", 2}}},
            notes = {"trades-randomized"},
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "biter-rammer",
            conditions = {{type = "biter-ramming", show_progress_bar = false}},
            rewards = {{type = "reduce-biters", value = 25}, {type = "claim-free-hexes", value = {"nauvis", 2}}},
            prerequisites = {"ground-zero"},
        },
        {
            name = "exploration",
            conditions = {{type = "claimed-hexes", progress_requirement = 15}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "modular-armor", count = 1},
                        {name = "solar-panel-equipment", count = 15},
                        {name = "personal-roboport-equipment", count = 1},
                        {name = "battery-equipment", count = 3},
                        {name = "construction-robot", count = 10},
                    },
                },
                {type = "claim-free-hexes", value = {"nauvis", 3}},
            },
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "catalog-initiate",
            conditions = {{type = "total-item-rank", progress_requirement = 20}},
            rewards = {{type = "all-trades-productivity", value = 10}, {type = "claim-free-hexes", value = {"nauvis", 5}}},
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "sprawling-base",
            conditions = {{type = "hex-span", progress_requirement = 30}},
            rewards = {{type = "unlock-feature", value = "teleportation"}, {type = "claim-free-hexes", value = {"nauvis", 5}}},
            prerequisites = {"exploration"},
            has_img = false,
        },
        {
            name = "too-many-hex-cores",
            conditions = {{type = "claimed-hexes", progress_requirement = 50}},
            rewards = {{type = "unlock-feature", value = "hex-core-deletion"}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"exploration"},
            has_img = false,
        },
        {
            name = "half-a-gravity",
            conditions = {{type = "coins-in-inventory", progress_requirement = 50000}},
            rewards = {{type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"getting-somewhere"},
            has_img = false,
        },
        {
            name = "getting-somewhere",
            conditions = {{type = "coins-in-inventory", progress_requirement = 10000}},
            rewards = {{type = "unlock-feature", value = "generator-mode"}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"find-some-trades"},
            has_img = false,
        },
        {
            name = "trades-galore",
            conditions = {{type = "trades-found", progress_requirement = 200}},
            rewards = {{type = "unlock-feature", value = "sink-mode"}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"find-some-trades"},
            has_img = false,
        },

        -- Vulcanus
        {
            name = "this-is-fine",
            conditions = {{type = "claimed-hexes-on", value = "vulcanus", progress_requirement = 40}},
            rewards = {{type = "claim-free-hexes", value = {"vulcanus", 10}}},
            prerequisites = {"too-many-hex-cores"},
            has_img = false,
        },
        {
            name = "stepping-on-ants",
            conditions = {{type = "kill-entity", value = "small-demolisher", progress_requirement = 3}},
            rewards = {{type = "unlock-feature", value = "supercharging"}},
            prerequisites = {"biter-rammer"},
            has_img = false,
        },

        -- Fulgora
        {
            name = "my-hair-feels-funny",
            conditions = {{type = "claimed-hexes-on", value = "fulgora", progress_requirement = 40}},
            rewards = {{type = "claim-free-hexes", value = {"fulgora", 10}}},
            prerequisites = {"too-many-hex-cores"},
            has_img = false,
        },
        {
            name = "you-are-the-destroyer",
            conditions = {{type = "use-capsule", value = "destroyer-capsule", progress_requirement = 5}},
            rewards = {{type = "claim-free-hexes", value = {"fulgora", 5}}},
            prerequisites = {"biter-rammer"},
            has_img = false,
        },
        {
            name = "tesla-freak",
            conditions = {{type = "kill-with-damage-type", value = "electric", progress_requirement = 50}},
            rewards = {{type = "claim-free-hexes", value = {"fulgora", 5}}},
            prerequisites = {"biter-rammer"},
            has_img = false,
        },

        -- Gleba
        {
            name = "yummy-co",
            conditions = {{type = "claimed-hexes-on", value = "gleba", progress_requirement = 40}},
            rewards = {{type = "claim-free-hexes", value = {"gleba", 10}}},
            prerequisites = {"too-many-hex-cores"},
            has_img = false,
        },
        {
            name = "five-legs-werent-enough",
            conditions = {{type = "kill-entity", value = "small-stomper-pentapod", progress_requirement = 10}},
            rewards = {{type = "claim-free-hexes", value = {"gleba", 5}}},
            prerequisites = {"biter-rammer"},
            has_img = false,
        },
        {
            name = "farm-fresh",
            conditions = {{type = "mine-entity", value = "medium-stomper-shell", progress_requirement = 3}},
            rewards = {{type = "claim-free-hexes", value = {"gleba", 5}}},
            prerequisites = {"five-legs-werent-enough"},
            has_img = false,
        },

        -- Aquilo
        {
            name = "i-am-the-demolisher",
            conditions = {{type = "use-capsule", value = "demolisher-capsule", progress_requirement = 5}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"you-are-the-destroyer"},
            has_img = false,
        },
        {
            name = "collateral-damage",
            conditions = {{type = "die-to-railgun", progress_requirement = 1}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"this-is-fine", "my-hair-feels-funny", "yummy-co"},
        },
        {
            name = "pond-filler",
            conditions = {{type = "place-tile", value = "foundation", progress_requirement = 100}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"this-is-fine", "my-hair-feels-funny", "yummy-co"},
            has_img = false,
        },
        {
            name = "world-paver",
            conditions = {{type = "place-tile", value = "foundation", progress_requirement = 2000}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"pond-filler"},
            has_img = false,
        },

        -- Post-Aquilo
        {
            name = "its-just-a-scratch",
            conditions = {{type = "items-at-rank", value = 5, progress_requirement = 1}},
            rewards = {{type = "unlock-feature", value = "quantum-bazaar"}},
            prerequisites = {"catalog-initiate"},
            notes = {"multiple-rank-ups"},
            has_img = false,
        },
        {
            name = "it-wasnt-good-enough",
            conditions = {{type = "sell-item-of-quality", value = "hextreme", progress_requirement = 1}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"catalog-initiate"},
            has_img = false,
        },
        {
            name = "the-factory-must-grow",
            conditions = {{type = "place-entity", value = "sentient-spider", progress_requirement = 1}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"five-legs-werent-enough"},
            has_img = false,
        },
    },
}
