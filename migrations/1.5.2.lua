
local quests = require "api.quests"
local gui = require "api.gui"

return function()
    gui.questbook.reinitialize()
    quests.recalculate_condition_progress_of_type "total-strongbox-level"
    quests.recalculate_condition_progress_of_type("items-at-rank", 2)

    quests.recalculate_condition_progress_of_type("cover-ores-on", "vulcanus")

    -- Fix possible issue
    quests.recalculate_condition_progress_of_type("visit-planet", "vulcanus")
    quests.recalculate_condition_progress_of_type("visit-planet", "fulgora")
    quests.recalculate_condition_progress_of_type("visit-planet", "gleba")

    storage.item_buffs.free_buffs_remaining = 0
    storage.item_buffs.unresearched_penalty_multiplier = 1
end
