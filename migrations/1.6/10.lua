
local hex_grid = require "api.hex_grid"

return function()
    hex_grid.recalculate_pool_active_counts()
end
