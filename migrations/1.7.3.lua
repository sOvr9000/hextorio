
local item_tradability_solver = require "api.item_tradability_solver"

return function()
    item_tradability_solver.solve()
end
