
local lib = require "api.lib"

return function()
    storage.train_trading.allow_two_headed_trains = lib.runtime_setting_value_as_boolean "allow-two-headed-trains"
end
