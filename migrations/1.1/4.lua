
local item_ranks = require "api.item_ranks"

return function()
    item_ranks.recalculate_items_at_rank_quests()
end
