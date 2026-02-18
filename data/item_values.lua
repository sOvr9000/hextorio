
return {
    values = {nauvis = {}, vulcanus = {}, fulgora = {}, aquilo = {}}, -- wait for solver to calculate item values
    awaiting_solver = true, -- gets set to nil once the item value solver finishes on new game start
    base_coin_value = 10,

    planet_configs = {
        nauvis = {
            energy_coefficient = 0.06,
            complexity_coefficient = 0.15,
            raw_multiplier = 0.5,
            spoilable_coefficient = 0.75,
        },
        vulcanus = {
            energy_coefficient = 0.03,
            complexity_coefficient = 0.13,
            raw_multiplier = 0.6,
            spoilable_coefficient = 0.75,
        },
        fulgora = {
            energy_coefficient = 0.08,
            complexity_coefficient = 0.18,
            raw_multiplier = 0.65,
            spoilable_coefficient = 0.75,
        },
        gleba = {
            energy_coefficient = 0.07,
            complexity_coefficient = 0.17,
            raw_multiplier = 0.7,
            spoilable_coefficient = 0.3,
        },
        aquilo = {
            energy_coefficient = 0.03, -- fusion power becomes available
            complexity_coefficient = 0.5, -- heat pipes complicate logistics massively
            raw_multiplier = 1.0, -- endgame scaling
            spoilable_coefficient = 1.25,
        },
    },

    raw_values = {
        nauvis = {
            ["wood"] = 5,
            ["raw-fish"] = 25,
            ["iron-ore"] = 1,
            ["copper-ore"] = 0.8,
            ["stone"] = 0.6,
            ["coal"] = 1.2,
            ["uranium-ore"] = 4,
            ["hexaprism"] = 5000000,
            ["water"] = 0.01,
            ["crude-oil"] = 0.1,
        },
        vulcanus = {
            ["coal"] = 0.6,
            ["calcite"] = 2,
            ["tungsten-ore"] = 81,
            ["lava"] = 0.02,
            ["sulfuric-acid"] = 0.5,
        },
        fulgora = {
            ["heavy-oil"] = 0.06, ["scrap"] = 1,
        },
        gleba = {
            ["wood"] = 5,
            ["stone"] = 1,
            ["yumako"] = 12,
            ["jellynut"] = 18,
            ["pentapod-egg"] = 64,
            ["water"] = 0.01,
        },
        aquilo = {
            ["ammoniacal-solution"] = 0.01,
            ["crude-oil"] = 1,
            ["fluorine"] = 10,
            ["lithium-brine"] = 100,
        },
    },
}
