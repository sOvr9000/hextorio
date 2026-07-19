
local api = {}



for _, api_name in pairs{
    "util.axial",
    "util.entity",
    "util.hex",
    "util.mgs",

    "gui.catalog_gui",
    "gui.coin_tier_gui",
    "gui.core_gui",
    "gui.hud_gui",
    "gui.gui_stack",
    "gui.hex_core_gui",
    "gui.hex_rank_gui",
    "gui.item_buffs_gui",
    "gui.piggy_bank_gui",
    "gui.questbook_gui",
    "gui.trade_overview_gui",
    "gui.trades_gui",
    "gui.solver_progress_gui",

    "bezier",
    "blueprints",
    "coin_tiers",
    "core_math",
    "dungeons",
    "event_system",
    "features",
    "gameplay_statistics",
    "gameplay_statistics_recalculators",
    "hex_grid",
    "hex_island",
    "hex_maze",
    "hex_pathfinding",
    "hex_rank",
    "hex_sets",
    "hex_state_manager",
    "initialization",
    "inventories",
    "item_buffs",
    "item_ranks",
    "item_tradability_solver",
    "item_value_solver",
    "item_values",
    "lib",
    "loot_tables",
    "passive_coin_buff",
    "piggy_bank",
    "quests",
    "sets",
    "space_platforms",
    "spider_control",
    "spider_network",
    "strongboxes",
    "terrain",
    "tile_names",
    "toasts",
    "trade_generator",
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
        if type(func) == "function" and func_name:sub(1,1) ~= "_" then
            interface[func_name] = func
        end
    end
    remote.add_interface("hextorio_" .. api_name, interface)
end


