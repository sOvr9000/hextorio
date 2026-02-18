
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

    -- DUMMY VALUES
    -- Will be replaced by mod setting values.
    -- These exist to allow iteration over items expected to be considered "raw" during game start.
    raw_values = {
        nauvis = {
            ["wood"] = 1,
            ["raw-fish"] = 1,
            ["iron-ore"] = 1,
            ["copper-ore"] = 1,
            ["stone"] = 1,
            ["coal"] = 1,
            ["uranium-ore"] = 1,
            ["hexaprism"] = 1,
            ["water"] = 1,
            ["crude-oil"] = 1,
        },
        vulcanus = {
            ["coal"] = 1,
            ["calcite"] = 1,
            ["tungsten-ore"] = 1,
            ["lava"] = 1,
            ["sulfuric-acid"] = 1,
        },
        fulgora = {
            ["heavy-oil"] = 1,
            ["scrap"] = 1,
        },
        gleba = {
            ["wood"] = 1,
            ["stone"] = 1,
            ["yumako"] = 1,
            ["jellynut"] = 1,
            ["pentapod-egg"] = 1,
            ["water"] = 1,
        },
        aquilo = {
            ["ammoniacal-solution"] = 1,
            ["crude-oil"] = 1,
            ["fluorine"] = 1,
            ["lithium-brine"] = 1,
        },
    },
}
