
local hex_grid = require "api.hex_grid"

return function()
    hex_grid.regenerate_all_hex_core_loaders()
    hex_grid.update_all_trades()
end
