
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
        ["loot-dungeons-on"] = {"dungeon-loot-condition"},
        ["favorite-trade"] = {"favorite-trade"},
    },

    quest_defs = {
        {
            name = "ground-zero",
            conditions = {
                {type = "claimed-hexes", progress_requirement = 2},
                {type = "make-trades", progress_requirement = 1, notes = {"trades-require-claim"}},
            },
            rewards = {
                {type = "unlock-feature", value = "catalog"},
                {type = "unlock-feature", value = "trade-configuration"},
            },
            notes = {"remote-view-to-claim"},
        },
        {
            name = "check-this-out",
            conditions = {
                {type = "ping-trade", progress_requirement = 1, show_progress_bar = true},
                {type = "create-trade-map-tag", progress_requirement = 1, show_progress_bar = true},
            },
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "electric-mining-drill", count = 3},
                        {name = "pipe", count = 10},
                    },
                },
            },
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "find-some-trades",
            conditions = {{type = "trades-found", progress_requirement = 40}},
            rewards = {{type = "unlock-feature", value = "trade-overview"}, {type = "claim-free-hexes", value = {"nauvis", 2}}},
            notes = {"trades-randomized"},
            prerequisites = {"ground-zero"},
        },
        {
            name = "too-many-belts",
            conditions = {{type = "trades-found", progress_requirement = 2000}},
            rewards = {{type = "unlock-feature", value = "locomotive-trading"}, {type = "claim-free-hexes", value = {"nauvis", 10}}},
            prerequisites = {"find-some-trades"},
        },
        {
            name = "remind-me-later",
            conditions = {{type = "favorite-trade", progress_requirement = 1, show_progress_bar = true}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "submachine-gun", count = 1, quality = "uncommon"},
                    },
                },
            },
            prerequisites = {"find-some-trades"},
        },
        {
            name = "biter-rammer",
            conditions = {{type = "biter-ramming", show_progress_bar = false}},
            rewards = {
                {type = "reduce-biters", value = 25},
                {type = "claim-free-hexes", value = {"nauvis", 2}},
                {
                    type = "receive-items",
                    value = {
                        {name = "magmatic-rounds-magazine", count = 50},
                    },
                },
            },
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
                        {name = "personal-roboport-equipment", count = 2},
                        {name = "battery-equipment", count = 5},
                        {name = "construction-robot", count = 20},
                    },
                },
                {type = "claim-free-hexes", value = {"nauvis", 3}},
            },
            notes = {"use-claim-tool"},
            prerequisites = {"check-this-out"},
        },
        {
            name = "first-bronze-star",
            conditions = {{type = "items-at-rank", value = 2, progress_requirement = 1}},
            rewards = {
                {type = "unlock-feature", value = "item-buffs"},
                {
                    type = "receive-items",
                    value = {
                        {name = "hex-coin", count = 50},
                    },
                },
            },
            prerequisites = {"ground-zero"},
            has_img = false,
        },
        {
            name = "first-silver-star",
            conditions = {{type = "items-at-rank", value = 3, progress_requirement = 1}},
            rewards = {
                {type = "unlock-feature", value = "quick-trading"},
                {
                    type = "receive-items",
                    value = {
                        {name = "bulk-inserter", count = 10, quality = "rare"},
                    },
                },
            },
            prerequisites = {"first-bronze-star", "check-this-out"},
            has_img = false,
        },
        {
            name = "catalog-initiate",
            conditions = {{type = "total-item-rank", progress_requirement = 20}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"nauvis", 5}}},
            prerequisites = {"first-bronze-star"},
        },
        {
            name = "catalog-professional",
            conditions = {{type = "total-item-rank", progress_requirement = 120}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "boiler", count = 20, quality = "epic"},
                        {name = "steam-engine", count = 40, quality = "epic"},
                    },
                },
            },
            prerequisites = {"catalog-initiate"},
            has_img = false,
        },
        {
            name = "sprawling-base",
            conditions = {{type = "hex-span", progress_requirement = 30}},
            rewards = {{type = "unlock-feature", value = "teleportation"}, {type = "claim-free-hexes", value = {"nauvis", 5}}},
            prerequisites = {"exploration"},
        },
        {
            name = "too-many-hex-cores",
            conditions = {{type = "claimed-hexes", progress_requirement = 50}},
            rewards = {{type = "unlock-feature", value = "hex-core-deletion"}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"exploration"},
        },
        {
            name = "cracking-the-vault",
            conditions = {{type = "total-strongbox-level", progress_requirement = 10}, {type = "items-at-rank", value = 2, progress_requirement = 5}},
            rewards = {{type = "unlock-feature", value = "item-buff-enhancement"}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"exploration", "first-bronze-star"},
            notes = {"strongbox-chance"},
        },
        {
            name = "lockbreaker",
            conditions = {{type = "total-strongbox-level", progress_requirement = 50}, {type = "items-at-rank", value = 2, progress_requirement = 30}},
            rewards = {{type = "unlock-feature", value = "enhance-all"}, {type = "claim-free-hexes", value = {"nauvis", 5}}},
            prerequisites = {"cracking-the-vault"},
        },
        {
            name = "automated-clearing",
            conditions = {{type = "total-strongbox-level", progress_requirement = 150}, {type = "visit-planet", value = "vulcanus", show_progress_bar = false}, {type = "visit-planet", value = "fulgora", show_progress_bar = false}, {type = "visit-planet", value = "gleba", show_progress_bar = false}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"vulcanus", 5}}, {type = "claim-free-hexes", value = {"fulgora", 5}}, {type = "claim-free-hexes", value = {"gleba", 5}}},
            prerequisites = {"lockbreaker"},
        },
        {
            name = "half-a-gravity",
            conditions = {{type = "coins-in-inventory", progress_requirement = 50000}},
            rewards = {{type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"getting-somewhere"},
        },
        {
            name = "getting-somewhere",
            conditions = {{type = "coins-in-inventory", progress_requirement = 10000}},
            rewards = {{type = "unlock-feature", value = "generator-mode", notes = {"irreversible-action", "low-efficiency"}}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"find-some-trades"},
        },
        {
            name = "trades-galore",
            conditions = {{type = "trades-found", progress_requirement = 200}},
            rewards = {{type = "unlock-feature", value = "sink-mode", notes = {"irreversible-action", "low-efficiency"}}, {type = "claim-free-hexes", value = {"nauvis", 3}}},
            prerequisites = {"find-some-trades"},
        },
        {
            name = "i-really-need-that",
            conditions = {{type = "hex-cores-in-mode", value = "generator", progress_requirement = 1}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "substation", count = 4, quality = "epic"},
                    },
                },
                {type = "claim-free-hexes", value = {"nauvis", 3}},
            },
            prerequisites = {"getting-somewhere"},
        },
        {
            name = "i-really-dont-need-that",
            conditions = {{type = "hex-cores-in-mode", value = "sink", progress_requirement = 1}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "recycler", count = 1},
                    },
                },
                {type = "claim-free-hexes", value = {"nauvis", 3}},
            },
            prerequisites = {"trades-galore"},
        },
        {
            name = "dark-factorian-dungeon",
            conditions = {{type = "loot-dungeons-on", value = "nauvis", progress_requirement = 1}},
            rewards = {
                {type = "all-trades-productivity", value = 5},
                {type = "claim-free-hexes", value = {"nauvis", 10}},
            },
            prerequisites = {"getting-somewhere"},
            notes = {"dungeon-location"},
        },
        {
            name = "lazy-looter",
            conditions = {{type = "loot-dungeons-off-planet", progress_requirement = 1}},
            rewards = {
                {type = "all-trades-productivity", value = 5},
                {
                    type = "receive-items",
                    value = {
                        {name = "spidertron", count = 1, quality = "rare"},
                        {name = "personal-roboport-mk2-equipment", count = 3, quality = "rare"},
                        {name = "discharge-defense-equipment", count = 2, quality = "rare"},
                        {name = "energy-shield-mk2-equipment", count = 1, quality = "rare"},
                        {name = "exoskeleton-equipment", count = 4, quality = "rare"},
                        {name = "battery-mk3-equipment", count = 4, quality = "rare"},
                        {name = "fission-reactor-equipment", count = 2, quality = "rare"},
                        {name = "construction-robot", count = 120, quality = "rare"},
                    },
                    notes = {"first-spidertron"},
                },
                {type = "claim-free-hexes", value = {"nauvis", 20}}
            },
            prerequisites = {"dark-factorian-dungeon"},
        },
        {
            name = "trades-in-circuitry",
            conditions = {{type = "hex-core-trades-read", progress_requirement = 1}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "hexadic-resonator-tier-2", count = 1},
                    },
                },
            },
            prerequisites = {"exploration"},
        },

        -- Post-Nauvis
        {
            name = "first-gold-star",
            conditions = {{type = "items-at-rank", value = 4, progress_requirement = 1}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "construction-robot", count = 50, quality = "epic"},
                    },
                },
            },
            prerequisites = {"first-silver-star"},
            has_img = false,
        },
        {
            name = "catalog-master",
            conditions = {{type = "total-item-rank", progress_requirement = 160}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "steam-turbine", count = 20, quality = "legendary"},
                    },
                },
            },
            prerequisites = {"catalog-professional"},
            has_img = false,
        },
        {
            name = "catalog-obsession",
            conditions = {{type = "total-item-rank", progress_requirement = 200}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "nuclear-reactor", count = 4, quality = "hextreme"},
                        {name = "heat-exchanger", count = 12, quality = "hextreme"},
                        {name = "steam-turbine", count = 21, quality = "hextreme"},
                    },
                },
            },
            prerequisites = {"catalog-master"},
            has_img = false,
        },
        {
            name = "catalog-completionist",
            conditions = {{type = "items-at-rank", value = 5, progress_requirement = 290}},
            rewards = {
                {type = "all-trades-productivity", value = 100},
                {
                    type = "receive-items",
                    value = {
                        {name = "hexic-transport-belt", count = 400},
                        {name = "hexic-underground-belt", count = 400},
                        {name = "hexic-splitter", count = 100},
                    },
                },
            },
            prerequisites = {"catalog-obsession"},
        },

        -- Vulcanus
        {
            name = "visit-vulcanus",
            conditions = {{type = "visit-planet", value = "vulcanus", show_progress_bar = false}},
            rewards = {},
            prerequisites = {"too-many-hex-cores"},
        },
        {
            name = "copper-flavored-lava",
            conditions = {{type = "place-entity-on-planet", value = {"offshore-pump", "vulcanus"}, progress_requirement = 1}},
            rewards = {
                {type = "claim-free-hexes", value = {"vulcanus", 4}},
                {
                    type = "receive-items",
                    value = {
                        {name = "big-mining-drill", count = 1, quality = "rare"},
                        {name = "efficiency-module-2", count = 1, quality = "rare"},
                        {name = "gravity-coin", count = 2},
                        {name = "tungsten-ore", count = 50},
                    },
                },
            },
            prerequisites = {"visit-vulcanus"},
        },
        {
            name = "vulcanus-101",
            conditions = {{type = "cover-ores-on", value = "vulcanus", progress_requirement = 200}},
            rewards = {
                {type = "claim-free-hexes", value = {"vulcanus", 5}},
                {
                    type = "receive-items",
                    value = {
                        {name = "big-mining-drill", count = 2, quality = "epic"},
                        {name = "speed-module-2", count = 3, quality = "epic"},
                        {name = "tungsten-ore", count = 250},
                    },
                },
            },
            prerequisites = {"copper-flavored-lava"},
        },
        {
            name = "this-is-fine",
            conditions = {{type = "claimed-hexes-on", value = "vulcanus", progress_requirement = 40}},
            rewards = {{type = "claim-free-hexes", value = {"vulcanus", 10}}},
            prerequisites = {"copper-flavored-lava"},
        },
        {
            name = "stepping-on-ants",
            conditions = {{type = "kill-entity", value = "small-demolisher", progress_requirement = 3}},
            rewards = {
                {type = "unlock-feature", value = "supercharging"},
                {type = "receive-spaceship", value = "starter-ship"},
                {type = "claim-free-hexes", value = {"vulcanus", 5},
            }},
            prerequisites = {"biter-rammer", "visit-vulcanus"},
        },
        {
            name = "stepping-on-beetles",
            conditions = {{type = "kill-entity", value = "medium-demolisher", progress_requirement = 3}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"vulcanus", 10}}},
            prerequisites = {"stepping-on-ants"},
        },
        {
            name = "cant-step-on-that",
            conditions = {{type = "kill-entity", value = "big-demolisher", progress_requirement = 1}},
            rewards = {
                {type = "unlock-feature", value = "teleportation-cross-planet", notes = {"empty-inventories"}},
                {type = "all-trades-productivity", value = 5},
                {type = "claim-free-hexes", value = {"vulcanus", 15},
            }},
            prerequisites = {"stepping-on-beetles"},
        },
        {
            name = "metallurgic-dungeon",
            conditions = {{type = "loot-dungeons-on", value = "vulcanus", progress_requirement = 1}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"vulcanus", 10}}},
            prerequisites = {"dark-factorian-dungeon", "visit-vulcanus"},
        },

        -- Fulgora
        {
            name = "visit-fulgora",
            conditions = {{type = "visit-planet", value = "fulgora", show_progress_bar = false}},
            rewards = {},
            prerequisites = {"too-many-hex-cores"},
        },
        {
            name = "my-hair-feels-funny",
            conditions = {{type = "claimed-hexes-on", value = "fulgora", progress_requirement = 40}},
            rewards = {{type = "claim-free-hexes", value = {"fulgora", 10}}},
            prerequisites = {"visit-fulgora"},
        },
        {
            name = "electrocution",
            conditions = {{type = "die-to-damage-type", value = "electric", progress_requirement = 1}},
            rewards = {
                {type = "unlock-feature", value = "resource-conversion"},
                {type = "claim-free-hexes", value = {"fulgora", 5}},
                {
                    type = "receive-items",
                    value = {
                        {name = "recycler", count = 1, quality = "rare"},
                        {name = "efficiency-module-2", count = 1, quality = "rare"},
                        {name = "gravity-coin", count = 2},
                    },
                },
            },
            prerequisites = {"visit-fulgora"},
        },
        {
            name = "you-are-the-destroyer",
            conditions = {{type = "use-capsule", value = "destroyer-capsule", progress_requirement = 5}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"fulgora", 5}}},
            prerequisites = {"biter-rammer", "visit-fulgora"},
        },
        {
            name = "tesla-freak",
            conditions = {{type = "kill-with-damage-type", value = "electric", progress_requirement = 50}},
            rewards = {{type = "claim-free-hexes", value = {"fulgora", 5}}},
            prerequisites = {"biter-rammer", "visit-fulgora"},
        },
        {
            name = "lazy-bastard",
            conditions = {{type = "place-entity-on-planet", value = {"roboport", "fulgora"}, progress_requirement = 80}},
            rewards = {{type = "unlock-feature", value = "hexports", notes = {"no-robot-slots", "use-hexport-tool"}}},
            prerequisites = {"visit-fulgora"},
            has_img = false,
        },
        {
            name = "electromagnetic-dungeon",
            conditions = {{type = "loot-dungeons-on", value = "fulgora", progress_requirement = 1}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"fulgora", 10}}},
            prerequisites = {"dark-factorian-dungeon", "visit-fulgora"},
        },

        -- Gleba
        {
            name = "visit-gleba",
            conditions = {{type = "visit-planet", value = "gleba", show_progress_bar = false}},
            rewards = {},
            prerequisites = {"too-many-hex-cores"},
        },
        {
            name = "yummy-co",
            conditions = {{type = "claimed-hexes-on", value = "gleba", progress_requirement = 40}},
            rewards = {{type = "claim-free-hexes", value = {"gleba", 10}}},
            prerequisites = {"visit-gleba"},
        },
        {
            name = "five-legs-werent-enough",
            conditions = {{type = "kill-entity", value = "small-stomper-pentapod", progress_requirement = 10}},
            rewards = {{type = "claim-free-hexes", value = {"gleba", 5}}},
            prerequisites = {"biter-rammer", "visit-gleba"},
        },
        {
            name = "farm-fresh-eggs",
            conditions = {{type = "mine-entity", value = "medium-stomper-shell", progress_requirement = 3}},
            rewards = {{type = "claim-free-hexes", value = {"gleba", 5}}},
            prerequisites = {"five-legs-werent-enough"},
        },
        {
            name = "farm-fresh-produce",
            conditions = {
                {type = "mine-entity", value = "yumako-tree", progress_requirement = 2},
                {type = "mine-entity", value = "jellystem", progress_requirement = 2},
                {type = "mine-entity", value = "boompuff", progress_requirement = 1},
                {type = "mine-entity", value = "stingfrond", progress_requirement = 1},
                {type = "mine-entity", value = "lickmaw", progress_requirement = 1},
            },
            rewards = {
                {type = "claim-free-hexes", value = {"gleba", 6}},
                {
                    type = "receive-items",
                    value = {
                        {name = "biochamber", count = 1, quality = "epic"},
                        {name = "efficiency-module-2", count = 1, quality = "epic"},
                        {name = "gravity-coin", count = 2},
                    },
                },
            },
            prerequisites = {"too-many-hex-cores", "visit-gleba"},
            has_img = false,
        },
        {
            name = "industrial-garden",
            conditions = {
                {type = "place-entity-on-planet", value = {"biochamber", "gleba"}, progress_requirement = 50},
                {type = "cover-ores-on", value = "gleba", progress_requirement = 360},
                {type = "place-tile", value = "landfill", progress_requirement = 5000},
                {type = "mine-entity", value = "yumako-tree", progress_requirement = 20},
                {type = "mine-entity", value = "jellystem", progress_requirement = 20},
                {type = "kill-with-damage-type", value = "poison", progress_requirement = 200},
            },
            rewards = {{type = "unlock-feature", value = "piggy-bank"}},
            prerequisites = {"farm-fresh-produce"},
        },
        {
            name = "biochemical-dungeon",
            conditions = {{type = "loot-dungeons-on", value = "gleba", progress_requirement = 1}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"gleba", 10}}},
            prerequisites = {"dark-factorian-dungeon", "visit-gleba"},
        },
        {
            name = "first-red-star",
            conditions = {{type = "items-at-rank", value = 5, progress_requirement = 1}},
            rewards = {
                {type = "unlock-feature", value = "quantum-bazaar"},
            },
            prerequisites = {"first-gold-star"},
            has_img = false,
        },

        -- Aquilo
        {
            name = "visit-aquilo",
            conditions = {{type = "visit-planet", value = "aquilo", show_progress_bar = false}},
            rewards = {},
            prerequisites = {"visit-vulcanus", "visit-fulgora", "visit-gleba"},
        },
        {
            name = "i-am-the-demolisher",
            conditions = {{type = "use-capsule", value = "demolisher-capsule", progress_requirement = 5}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"you-are-the-destroyer", "visit-aquilo"},
        },
        {
            name = "collateral-damage",
            conditions = {{type = "die-to-railgun", progress_requirement = 1}},
            rewards = {{type = "claim-free-hexes", value = {"aquilo", 5}}},
            prerequisites = {"visit-aquilo"},
        },
        {
            name = "pond-filler",
            conditions = {{type = "place-tile", value = "foundation", progress_requirement = 100}},
            rewards = {
                {type = "claim-free-hexes", value = {"aquilo", 5}},
                {
                    type = "receive-items",
                    value = {
                        {name = "cryogenic-plant", count = 1, quality = "legendary"},
                        {name = "productivity-module-3", count = 1, quality = "legendary"},
                        {name = "meteor-coin", count = 1},
                    },
                },
            },
            prerequisites = {"visit-aquilo"},
        },
        {
            name = "world-paver",
            conditions = {{type = "place-tile", value = "foundation", progress_requirement = 2000}},
            rewards = {
                {type = "claim-free-hexes", value = {"aquilo", 5}},
                {
                    type = "receive-items",
                    value = {
                        {name = "fusion-reactor", count = 1, quality = "legendary"},
                        {name = "fusion-generator", count = 2, quality = "legendary"},
                        {name = "hexa-productivity-module", count = 1, quality = "legendary"},
                    },
                },
            },
            prerequisites = {"pond-filler"},
        },
        {
            name = "overwatch-dungeon",
            conditions = {{type = "loot-dungeons-on", value = "aquilo", progress_requirement = 1}},
            rewards = {{type = "all-trades-productivity", value = 5}, {type = "claim-free-hexes", value = {"aquilo", 10}}},
            prerequisites = {"metallurgic-dungeon", "electromagnetic-dungeon", "biochemical-dungeon", "visit-aquilo"},
        },
        {
            name = "dungeon-mastery",
            conditions = {
                {type = "loot-dungeons-on", value = "nauvis", progress_requirement = 3},
                {type = "loot-dungeons-on", value = "vulcanus", progress_requirement = 3},
                {type = "loot-dungeons-on", value = "fulgora", progress_requirement = 3},
                {type = "loot-dungeons-on", value = "gleba", progress_requirement = 3},
                {type = "loot-dungeons-on", value = "aquilo", progress_requirement = 3},
            },
            rewards = {
                {type = "all-trades-productivity", value = 10},
                {type = "claim-free-hexes", value = {"aquilo", 10}},
                {
                    type = "receive-items",
                    value = {
                        {name = "mech-armor", count = 1, quality = "hextreme"},
                    },
                },
            },
            prerequisites = {"overwatch-dungeon"},
            has_img = false,
        },

        -- Post-Aquilo
        -- {
        --     name = "its-just-a-scratch",
        --     conditions = {{type = "items-at-rank", value = 5, progress_requirement = 1}},
        --     rewards = {
        --         {type = "unlock-feature", value = "quantum-bazaar"},
        --         {
        --             type = "receive-items",
        --             value = {
        --                 {name = "meteor-coin", count = 1000},
        --             },
        --         },
        --         {type = "claim-free-hexes", value = {"nauvis", 40}},
        --         {type = "claim-free-hexes", value = {"vulcanus", 30}},
        --         {type = "claim-free-hexes", value = {"fulgora", 30}},
        --         {type = "claim-free-hexes", value = {"gleba", 30}},
        --         {type = "claim-free-hexes", value = {"aquilo", 20}},
        --     },
        --     prerequisites = {"it-wasnt-good-enough"},
        --     notes = {"multiple-rank-ups"},
        --     has_img = false,
        -- },
        {
            name = "it-wasnt-good-enough",
            conditions = {{type = "sell-item-of-quality", value = "hextreme", progress_requirement = 1}},
            rewards = {
                {
                    type = "receive-items",
                    value = {
                        {name = "big-mining-drill", count = 2, quality = "hextreme"},
                        {name = "recycler", count = 2, quality = "hextreme"},
                        {name = "hexa-quality-module", count = 16, quality = "hextreme"},
                    },
                },
            },
            prerequisites = {"catalog-initiate", "visit-aquilo"},
        },
        {
            name = "the-factory-must-grow",
            conditions = {{type = "place-entity", value = "sentient-spider", progress_requirement = 1}},
            rewards = {
                {type = "claim-free-hexes", value = {"aquilo", 10}},
                {type = "reduce-biters", value = 90},
                {
                    type = "receive-items",
                    value = {
                        {name = "personal-roboport-mk2-equipment", count = 1, quality = "hextreme"},
                    },
                },
            },
            prerequisites = {"five-legs-werent-enough", "cant-step-on-that", "visit-aquilo"},
        },
    },
}
