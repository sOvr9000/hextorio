
local sets = require "api.sets"
local quests = require "api.quests"
local trades = require "api.trades"
local hex_grid = require "api.hex_grid"

local data_hex_grid = require "data.hex_grid"

return function()
    storage.hex_grid.gleba_ignore_tiles = data_hex_grid.gleba_ignore_tiles
    storage.quests.quest_ids_by_name = {}
    storage.quests.quests_by_condition_type = {}

    local quest_id = 0
    local quest_names = sets.to_array(storage.quests.quests)
    for _, quest_name in pairs(quest_names) do
        local quest = storage.quests.quests[quest_name]
        quest_id = quest_id + 1
        storage.quests.quest_ids_by_name[quest_name] = quest_id
        storage.quests.quests[quest_name] = nil
        storage.quests.quests[quest_id] = quest
        quest.id = quest_id
        quests.index_by_condition_types(quest)
    end

    for _, surface_name in pairs {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"} do
        if game.get_surface(surface_name) then
            trades.generate_interplanetary_trade_locations(surface_name)
        end
    end

    for _, trade in pairs(trades.get_all_trades(false)) do
        local cpv = trade.current_prod_value --[[@as number]]
        trade.current_prod_value = {}
        for _, q in pairs(prototypes.quality) do
            if q.name == "normal" then
                trade.current_prod_value[q.name] = cpv
            else
                trade.current_prod_value[q.name] = 0
            end
        end
    end

    for _, pool in pairs(storage.hex_grid.pool) do
        for _, params in pairs(pool) do
            params.hex_pos = {q = params.q, r = params.r}
            params.q = nil
            params.r = nil
        end
    end
    hex_grid.set_pool_size(data_hex_grid.pool_size)
end
