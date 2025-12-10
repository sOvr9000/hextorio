
return function()
    game.forces.player.technologies["planet-discovery-vulcanus"].enabled = true

    for _, tab_name in pairs {"by_input", "by_output"} do
        local new_table = {}
        for item_name, trade_ids in pairs(storage.trades.tree[tab_name]) do
            new_table[item_name] = {}
            for _, trade_id in pairs(trade_ids) do
                new_table[item_name][trade_id] = true
            end
        end
        storage.trades.tree[tab_name] = new_table
    end
end
