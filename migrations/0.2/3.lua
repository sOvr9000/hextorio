
local hex_grid = require "api.hex_grid"

return function()
    for _, quest in pairs(storage.quests.quests) do
        if quest.complete then
            for _, reward in pairs(quest.rewards) do
                if reward.type == "claim-free-hexes" then
                    hex_grid.add_free_hex_claims(reward.value[1], reward.value[2])
                end
            end
        end
    end
end
