
local dungeons = require "api.dungeons"
local loot_tables = require "api.loot_tables"

local data_hex_grid = require "data.hex_grid"
local data_dungeons = require "data.dungeons"
local data_item_values = require "data.item_values"

return function()
    storage.cached = {}
    storage.hex_grid.chunk_generation_range_per_player = data_hex_grid.chunk_generation_range_per_player
    storage.item_values.values = data_item_values.values

    storage.dungeons = data_dungeons
    loot_tables.init()
    dungeons.init()
end
