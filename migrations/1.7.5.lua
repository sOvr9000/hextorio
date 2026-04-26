
local lib = require "api.lib"

return function()
    storage.trades.trade_complexity = lib.runtime_setting_value_as_string "trade-complexity"
end
