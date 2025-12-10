
return function()
    storage.quests.players_rewarded = {}
    storage.quests.players_quest_selected = {}
    storage.quests.notes_per_reward_type = {
        ["receive-items"] = {"new-players-receive"},
    }
    storage.quests.notes_per_condition_type = {
        ["trades-found"] = {"finding-counts-unclaimed"},
    }
    storage.hex_grid.hex_span = {}
end
