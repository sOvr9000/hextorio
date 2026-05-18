
local data_trades = require "data.trades"
local data_item_values = require "data.item_values"

return function()
    game.forces.player.technologies["planet-discovery-gleba"].enabled = true
    storage.trades.starting_trades.gleba = data_trades.starting_trades.gleba
    storage.item_values.values = data_item_values.values
end
