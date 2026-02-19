
local item_value_solver = require "api.item_value_solver"
local item_tradability_solver = require "api.item_tradability_solver"

local data_item_values = require "data.item_values"

return function()
    storage.SUPPORTED_PLANETS = {
        nauvis = true,
        vulcanus = true,
        fulgora = true,
        gleba = true,
        aquilo = true,
    }

    storage.item_values = data_item_values

    game.print("Migrating Hextorio version [color=blue]1.6.11[.color] to [color=blue]1.7.0[.color].  [color=pink]Significant changes have been made.[.color]")
    item_tradability_solver.init()
    item_value_solver.init()
end
