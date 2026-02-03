
local api = {}



for _, api_name in pairs{
    "gui.catalog_gui",
    "gui.coin_tier_gui",
    "gui.core_gui",
    "gui.gui_stack",
    "gui.hex_core_gui",
    "gui.item_buffs_gui",
    "gui.piggy_bank_gui",
    "gui.questbook_gui",
    "gui.trade_overview_gui",
    "gui.trades_gui",

    "axial",
    "blueprints",
    "coin_tiers",
    "core_math",
    "dungeons",
    "entity_util",
    "event_system",
    "gameplay_statistics",
    "gameplay_statistics_recalculators",
    "hex_grid",
    "hex_island",
    "hex_maze",
    "hex_rank",
    "hex_sets",
    "hex_state_manager",
    "initialization",
    "inventories",
    "item_buffs",
    "item_ranks",
    "item_values",
    "lib",
    "loot_tables",
    "passive_coin_buff",
    "piggy_bank",
    "quests",
    "sets",
    "space_platforms",
    "spiders",
    "strongboxes",
    "terrain",
    "tile_names",
    "toasts",
    "trade_loop_finder",
    "trades",
    "train_trading",
    "weighted_choice",
} do
    api[api_name] = require("api." .. api_name)
end



for api_name, api_funcs in pairs(api) do
    local interface = {}
    for func_name, func in pairs(api_funcs) do
        if type(func) == "function" then
            interface[func_name] = func
        end
    end
    remote.add_interface("hextorio_" .. api_name, interface)
end


