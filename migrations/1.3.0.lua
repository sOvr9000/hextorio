
local quests = require "api.quests"

return function()
    quests.recalculate_all_condition_progress()
end
