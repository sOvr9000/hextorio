
return {
    values = {nauvis = {}, vulcanus = {}, fulgora = {}, aquilo = {}}, -- wait for solver to calculate item values
    awaiting_solver = true, -- gets set to nil once the item value solver finishes on new game start
    base_coin_value = 10,

    -- DUMMY VALUES
    -- Will be replaced by mod setting values.
    -- These exist to allow the item value solver to iterate over the associated config types on game start.
    planet_configs = {
        nauvis = {
            energy_coefficient = 1,
            complexity_coefficient = 1,
            raw_multiplier = 1,
            spoilable_coefficient = 1,
        },
        vulcanus = {
            energy_coefficient = 1,
            complexity_coefficient = 1,
            raw_multiplier = 1,
            spoilable_coefficient = 1,
        },
        fulgora = {
            energy_coefficient = 1,
            complexity_coefficient = 1,
            raw_multiplier = 1,
            spoilable_coefficient = 1,
        },
        gleba = {
            energy_coefficient = 1,
            complexity_coefficient = 1,
            raw_multiplier = 1,
            spoilable_coefficient = 1,
        },
        aquilo = {
            energy_coefficient = 1,
            complexity_coefficient = 1,
            raw_multiplier = 1,
            spoilable_coefficient = 1,
        },
    },

    -- DUMMY VALUES
    -- Will be replaced by mod setting values.
    -- These exist to allow the item value solver to iterate over known "raw" items on game start.
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
