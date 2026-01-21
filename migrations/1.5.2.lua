
local quests = require "api.quests"
local gui = require "api.gui"

return function()
    gui.questbook.reinitialize()
    quests.recalculate_condition_progress_of_type "total-strongbox-level"
    quests.recalculate_condition_progress_of_type("items-at-rank", 2)

    storage.item_buffs.free_buffs_remaining = 0
end
