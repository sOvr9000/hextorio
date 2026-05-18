
local dungeons = require "api.dungeons"

local data_dungeons = require "data.dungeons"

return function()
    dungeons.migrate_old_data(data_dungeons)
end
