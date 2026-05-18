
local quests = require "api.quests"
local gui = require "api.gui"
local dungeons = require "api.dungeons"
local gameplay_statistics = require "api.gameplay_statistics"

local data_dungeons = require "data.dungeons"

return function()
    gui.questbook.reinitialize()
    gameplay_statistics.recalculate "total-strongbox-level"
    gameplay_statistics.recalculate("items-at-rank", 2)

    gameplay_statistics.recalculate("cover-ores-on", "vulcanus")

    -- Fix possible issue
    gameplay_statistics.recalculate("visit-planet", "vulcanus")
    gameplay_statistics.recalculate("visit-planet", "fulgora")
    gameplay_statistics.recalculate("visit-planet", "gleba")

    storage.item_buffs.free_buffs_remaining = 0
    storage.item_buffs.unresearched_penalty_multiplier = 1

    dungeons.migrate_old_data(data_dungeons)
end
