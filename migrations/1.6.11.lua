
local item_value_solver = require "api.item_value_solver"
local item_tradability_solver = require "api.item_tradability_solver"

return function()
    storage.SUPPORTED_PLANETS = {
        nauvis = true,
        vulcanus = true,
        fulgora = true,
        gleba = true,
        aquilo = true,
    }

    storage.item_values = {
        values = {nauvis = {}, vulcanus = {}, fulgora = {}, aquilo = {}},
        awaiting_solver = true,
        base_coin_value = 10,
    }

    item_tradability_solver.solve()
    item_value_solver.init()
end
