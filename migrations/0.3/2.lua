
local data_trades = require "data.trades"
local data_item_values = require "data.item_values"

return function()
    game.forces.player.technologies["planet-discovery-fulgora"].enabled = true
    storage.trades.starting_trades.fulgora = data_trades.starting_trades.fulgora
    storage.item_values.values.vulcanus = data_item_values.values.vulcanus -- fixes crude oil barrel bug
    storage.item_values.values.fulgora = data_item_values.values.fulgora
    storage.hex_grid.pool_size = 50
end
