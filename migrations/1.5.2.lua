
local quests = require "api.quests"

return function()
    quests.recalculate_condition_progress_of_type "total-strongbox-level"
    quests.recalculate_condition_progress_of_type("items-at-rank", 2)
end
