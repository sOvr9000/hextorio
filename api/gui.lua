local lib = require "api.lib"
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"
local coin_tiers  = require "api.coin_tiers"
local inventories = require "api.inventories"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local sets = require "api.sets"
local event_system = require "api.event_system"
local quests = require "api.quests"
local item_buffs = require "api.item_buffs"

local gui = {}



function gui.register_events()
    event_system.register_callback("post-rank-up-command", function(player, params)
        gui.close_all(player)
        local selection = gui.get_catalog_selection(player)
        gui.set_catalog_selection(player, "nauvis", params[1], selection.bazaar_quality)
        gui.show_catalog(player)
    end)
    event_system.register_callback("post-rank-up-all-command", function(player, params)
        gui.close_all(player)
        gui.show_catalog(player)
    end)
    event_system.register_callback("post-discover-all-command", function(player, params)
        gui.close_all(player)
        gui.show_catalog(player)
    end)
    event_system.register_callback("trade-processed", function(trade)
        if not trade.hex_core_state or not trade.hex_core_state.hex_core or not trade.hex_core_state.hex_core.valid then return end
        for _, player in pairs(game.connected_players) do
            if player.opened == trade.hex_core_state.hex_core then
                gui.update_hex_core(player)
            end
        end
    end)

    event_system.register_callback("quest-reward-received", function(reward_type, value)
        if reward_type == "unlock-feature" then
            if value == "catalog" then
                for _, player in pairs(game.players) do
                    gui.init_catalog_button(player)
                end
            elseif value == "trade-overview" then
                for _, player in pairs(game.players) do
                    gui.init_trade_overview_button(player)
                end
            end
        end
    end)

    event_system.register_callback("quest-revealed", function(quest)
        for _, player in pairs(game.connected_players) do
            gui.update_quest_lists(player, quest)
            gui.update_questbook(player)
        end
    end)

    event_system.register_callback("quest-completed", function(quest)
        for _, player in pairs(game.connected_players) do
            gui.update_quest_lists(player, quest)
            gui.update_questbook(player)
        end
    end)

    event_system.register_callback("hex-core-deleted", function(state)
        if not state then return end
        for _, player in pairs(game.connected_players) do
            if gui.is_trade_overview_open(player) then
                gui.update_trade_overview(player)
            end
        end
    end)

    event_system.register_callback("hex-claimed", function(surface, state)
        local hex_core = state.hex_core
        if not hex_core or not hex_core.valid then return end

        for _, player in pairs(game.connected_players) do
            if player.opened == hex_core then
                gui.update_hex_core(player)
            end
        end
    end)

    event_system.register_callback("item-buff-level-changed", function(item_name)
        for _, player in pairs(game.connected_players) do
            if gui.is_catalog_open(player) then
                local selection = gui.get_catalog_selection(player)
                if selection.item_name == item_name then
                    gui.update_catalog_inspect_frame(player)
                end
            end
        end
    end)

    event_system.register_callback("item-buffs-enhance-all-finished", function(player, total_cost, enhanced_items)
        gui.update_catalog_inspect_frame(player)
    end)

    event_system.register_callback("post-set-item-value-command", function(player, params)
        gui.reinitialize_everything()
    end)
    event_system.register_callback("post-import-item-values-command", function(player, params)
        gui.reinitialize_everything()
    end)
end

---Reinitialize the Hextorio GUIs for the given player, or all online players if no player is provided.
---@param player LuaPlayer|nil
function gui.reinitialize_everything(player)
    -- called during migration or for player joins

    if not player then
        for _, p in pairs(game.connected_players) do
            gui.reinitialize_everything(p)
        end
        return
    end

    local frame

    -- frame = player.gui.screen["hex-core"]
    -- if frame then frame.destroy() end
    -- gui.init_hex_core(player)

    frame = player.gui.screen["questbook"]
    if frame then frame.destroy() end

    frame = player.gui.screen["trade-overview"]
    if frame then frame.destroy() end

    frame = player.gui.screen["catalog"]
    if frame then frame.destroy() end

    local button

    button = player.gui.top["questbook-button"]
    if button then button.destroy() end

    button = player.gui.top["trade-overview-button"]
    if button then button.destroy() end

    button = player.gui.top["catalog-button"]
    if button then button.destroy() end

    gui.init_all_buttons(player)
    gui.init_all_frames(player)

    gui.repopulate_quest_lists(player)

    gui.hide_all_frames(player)
end

---Return whether the given player has the given frame open. Safely handles situations (and returns false) when the player's currently opened object is not a GUI.
---@param player LuaPlayer
---@param frame_name string
---@return boolean
function gui.is_frame_open(player, frame_name)
    return player.opened ~= nil and player.opened.object_name == "LuaGuiElement" and player.opened.name == frame_name
end

function gui.init_all_buttons(player)
    gui.init_questbook_button(player)
    gui.init_trade_overview_button(player)
    gui.init_catalog_button(player)
end

function gui.init_all_frames(player)
    gui.init_trade_overview(player)
    gui.init_questbook(player)
    gui.init_catalog(player)
end

function gui.init_questbook_button(player)
    if player.gui.top["questbook-button"] then return end
    local questbook_button = player.gui.top.add {
        type = "sprite-button",
        name = "questbook-button",
        sprite = "questbook",
        style = "side_menu_button",
    }
end

function gui.init_trade_overview_button(player)
    if not player.gui.top["trade-overview-button"] then
        local trade_overview_button = player.gui.top.add {
            type = "sprite-button",
            name = "trade-overview-button",
            sprite = "trade-overview",
        }
    end
    player.gui.top["trade-overview-button"].visible = quests.is_feature_unlocked "trade-overview"
end

function gui.init_catalog_button(player)
    if not player.gui.top["catalog-button"] then
        local catalog_button = player.gui.top.add {
            type = "sprite-button",
            name = "catalog-button",
            sprite = "catalog",
        }
    end
    player.gui.top["catalog-button"].visible = quests.is_feature_unlocked "catalog"
end

function gui.init_hex_core(player)
    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right,
    }
    local hex_core_gui = player.gui.relative.add {type = "frame", name = "hex-core", direction = "vertical", anchor = anchor}
    hex_core_gui.caption = {"hex-core-gui.title"}
    -- gui.add_titlebar(hex_core_gui, {"hex-core-gui.title"})
    -- hex_core_gui.style.size = {width = 444, height = 625}
    hex_core_gui.style.width = 380
    hex_core_gui.style.natural_height = 625
    hex_core_gui.style.vertically_stretchable = true

    -- Default to invisible in case the player opens a steel chest before a hex core (sometimes happens when loading up a save).
    hex_core_gui.visible = false

    local resources_header = hex_core_gui.add {type = "label", name = "resources-header", caption = {"hex-core-gui.initial-resources"}}
    resources_header.style.font = "heading-2"

    local resources_flow = hex_core_gui.add {type = "flow", name = "resources-flow", direction = "horizontal"}

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local claim_flow = hex_core_gui.add {type = "flow", name = "claim-flow", direction = "vertical"}
    local free_hexes_remaining = claim_flow.add {type = "label", name = "free-hexes-remaining"}
    local claim_price = gui.create_coin_tier(claim_flow, "claim-price")
    local claim_hex = claim_flow.add {type = "button", name = "claim-hex", caption = {"hex-core-gui.claim-hex"}, style = "confirm_button"}
    claim_hex.tooltip = {"hex-core-gui.claim-hex-tooltip"}

    local claimed_by = hex_core_gui.add {type = "label", name = "claimed-by", caption = {"hex-core-gui.claimed-by"}}
    claimed_by.style.font = "heading-2"

    local hex_control_flow = hex_core_gui.add {type = "flow", name = "hex-control-flow", direction = "horizontal"}
    hex_control_flow.visible = false

    local teleport = hex_control_flow.add {type = "sprite-button", name = "teleport", sprite = "virtual-signal/down-arrow"}
    teleport.tooltip = {"hex-core-gui.teleport-tooltip"}

    local toggle_hexport = hex_control_flow.add {type = "sprite-button", name = "toggle-hexport", sprite = "item/roboport"}
    toggle_hexport.tooltip = {"hex-core-gui.toggle-hexport-tooltip"}

    -- local unloader_filters = hex_control_flow.add {type = "sprite-button", name = "unloader-filters", sprite = "item/loader"}
    -- unloader_filters.tooltip = {"hex-core-gui.unloader-filters-tooltip"}

    local supercharge = hex_control_flow.add {type = "sprite-button", name = "supercharge", sprite = "item/electric-mining-drill"}

    local sink_mode = hex_control_flow.add {type = "sprite-button", name = "sink-mode", sprite = "virtual-signal/signal-input"}
    sink_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.sink-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.sink-mode-tooltip-body"}}

    local generator_mode = hex_control_flow.add {type = "sprite-button", name = "generator-mode", sprite = "virtual-signal/signal-output"}
    generator_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.generator-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.generator-mode-tooltip-body"}}

    local sink_mode_confirmation = hex_core_gui.add {type = "sprite-button", name = "sink-mode-confirmation", sprite = "check-mark-green"}
    sink_mode_confirmation.tooltip = {"hex-core-gui.sink-mode-confirmation-tooltip"}
    local generator_mode_confirmation = hex_core_gui.add {type = "sprite-button", name = "generator-mode-confirmation", sprite = "check-mark-green"}
    generator_mode_confirmation.tooltip = {"hex-core-gui.generator-mode-confirmation-tooltip"}

    local stats = hex_control_flow.add {type = "sprite-button", name = "stats", sprite = "utility/side_menu_production_icon"}

    local delete_core = hex_control_flow.add {type = "sprite-button", name = "delete-core", sprite = "utility/empty_trash_slot"}

    local upgrade_quality = hex_control_flow.add {type = "sprite-button", name = "upgrade-quality", sprite = "quality/uncommon"}

    local convert_resources = hex_control_flow.add {type = "sprite-button", name = "convert-resources", sprite = "virtual-signal.signal-recycle"}
    convert_resources.tooltip = {"", lib.color_localized_string({"hex-core-gui.convert-resources-tooltip-header"}, "blue", "heading-2"), "\n", {"hex-core-gui.convert-resources-tooltip-body"}}

    local delete_core_confirmation = hex_core_gui.add {type = "flow", name = "delete-core-confirmation", direction = "horizontal"}
    delete_core_confirmation.visible = false

    local delete_core_confirmation_button = delete_core_confirmation.add {type = "sprite-button", name = "confirmation-button", sprite = "utility/empty_trash_slot"}
    local delete_core_confirmation_label = delete_core_confirmation.add {type = "label", name = "confirmation-label", caption = lib.color_localized_string({"hex-core-gui.delete-core-confirmation"}, "red")}
    delete_core_confirmation_label.style.font = "heading-1"

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local trades_header_flow = hex_core_gui.add {type = "flow", name = "trades-header", direction = "horizontal"}
    local trades_header_label = trades_header_flow.add {type = "label", name = "label", caption = {"hex-core-gui.trades-header"}}
    trades_header_label.style.font = "heading-1"

    local quality_dropdown = gui.create_quality_dropdown(trades_header_flow)
    local quality_dropdown_info = trades_header_flow.add {type = "label", name = "info", caption = "[img=virtual-signal.signal-info]"}
    quality_dropdown_info.tooltip = {"hex-core-gui.quality-dropdown-info"}
    quality_dropdown_info.style.top_margin = 4

    local trades_scroll_pane = hex_core_gui.add {type = "scroll-pane", name = "trades", direction = "vertical"}
    trades_scroll_pane.style.horizontally_stretchable = true
    trades_scroll_pane.style.horizontally_squashable = true
    trades_scroll_pane.style.vertically_stretchable = true
    trades_scroll_pane.style.vertically_squashable = true
end

function gui.init_questbook(player)
    if player.gui.screen["questbook"] then return end
    local questbook = player.gui.screen.add {type = "frame", name = "questbook", direction = "vertical"}
    questbook.style.size = {width = 1200, height = 800}
    questbook.visible = false

    gui.add_titlebar(questbook, {"hextorio-questbook.questbook-title"})

    local lower_flow = questbook.add {type = "flow", name = "lower-flow", direction = "horizontal"}
    gui.auto_width_height(lower_flow)

    local list_frame = lower_flow.add {type = "frame", name = "list-frame", direction = "vertical"}
    list_frame.style.natural_width = 300 / 1.2
    list_frame.style.horizontally_stretchable = false
    list_frame.style.horizontally_squashable = false

    local quest_frame = lower_flow.add {type = "flow", name = "quest-frame", direction = "vertical"}
    gui.auto_width_height(quest_frame)



    local list_scroll_pane = list_frame.add {type = "scroll-pane", name = "scroll-pane", direction = "vertical"}
    gui.auto_height(list_scroll_pane)

    local incomplete_header = list_scroll_pane.add {type = "label", name = "incomplete-header", caption = {"hextorio-questbook.incomplete", 0}}
    incomplete_header.style.font = "heading-2"
    local incomplete_list = list_scroll_pane.add {type = "list-box", name = "incomplete-list"}
    gui.auto_width_height(incomplete_list)

    local complete_header = list_scroll_pane.add {type = "label", name = "complete-header", caption = {"hextorio-questbook.complete", 0}}
    complete_header.style.font = "heading-2"
    local complete_list = list_scroll_pane.add {type = "list-box", name = "complete-list"}
    gui.auto_width_height(complete_list)

    local quest_info_frame = quest_frame.add {type = "frame", name = "info-frame", direction = "horizontal"}
    quest_info_frame.style.natural_height = 300 / 1.2
    quest_info_frame.style.maximal_width = 1153 / 1.2
    quest_info_frame.style.natural_width = 1153 / 1.2

    local quest_info_main = quest_info_frame.add {type = "flow", name = "main", direction = "vertical"}
    local quest_info_img_frame = quest_info_frame.add {type = "frame", name = "img-frame"}
    local quest_info_img = quest_info_img_frame.add {type = "sprite", name = "img", sprite = "missing-quest-img"}
    quest_info_img.style.width = 256 / 1.2
    quest_info_img.style.height = 256 / 1.2

    local quest_title = quest_info_main.add {type = "label", name = "title", caption = "[Quest Title]"}
    quest_title.style.font = "heading-1"
    quest_info_main.add {type = "line", direction = "horizontal"}

    local quest_description = quest_info_main.add {type = "label", name = "description", caption = "[Quest Description]"}
    quest_description.style.single_line = false

    local quest_notes_flow = quest_info_main.add {type = "flow", name = "notes-flow", direction = "vertical"}

    local debug_complete_quest = quest_info_main.add {type = "button", name = "debug-complete-quest", caption = {"hextorio-debug.complete-quest"}}

    local quest_conditions_rewards = quest_frame.add {type = "flow", name = "conditions-rewards", direction = "horizontal"}
    gui.auto_width_height(quest_conditions_rewards)

    local quest_conditions_frame = quest_conditions_rewards.add {type = "frame", name = "conditions", direction = "vertical"}

    local quest_conditions_header = quest_conditions_frame.add {type = "label", name = "header", caption = {"hextorio-questbook.conditions"}}
    quest_conditions_header.style.font = "heading-1"
    -- quest_conditions_frame.add {type = "line", direction = "horizontal"}

    local quest_conditions_scroll_pane = quest_conditions_frame.add {type = "scroll-pane", name = "scroll-pane"}
    gui.auto_width_height(quest_conditions_scroll_pane)

    local quest_rewards_frame = quest_conditions_rewards.add {type = "frame", name = "rewards", direction = "vertical"}

    local quest_rewards_header = quest_rewards_frame.add {type = "label", name = "header", caption = {"hextorio-questbook.rewards"}}
    quest_rewards_header.style.font = "heading-1"
    -- quest_rewards_frame.add {type = "line", direction = "horizontal"}

    local quest_rewards_scroll_pane = quest_rewards_frame.add {type = "scroll-pane", name = "scroll-pane"}
    gui.auto_width_height(quest_rewards_scroll_pane)
end

function gui.init_trade_overview(player)
    local frame = player.gui.screen.add {
        type = "frame",
        name = "trade-overview",
        direction = "vertical",
    }
    frame.style.width = 900
    frame.style.height = 900
    frame.visible = false

    gui.add_titlebar(frame, {"hex-core-gui.trade-overview"})

    local filter_frame = frame.add {type = "flow", name = "filter-frame", direction = "horizontal"}
    -- filter_frame.style.natural_height = 200
    filter_frame.style.vertically_stretchable = false
    local left_frame = filter_frame.add {type = "frame", name = "left", direction = "vertical"}
    gui.auto_width_height(left_frame)
    local right_frame = filter_frame.add {type = "frame", name = "right", direction = "vertical"}
    gui.auto_width_height(right_frame)

    local left_frame_buttons_flow = left_frame.add {type = "flow", name = "buttons-flow", direction = "horizontal"}
    local clear_filters_button = left_frame_buttons_flow.add {type = "button", name = "clear-filters-button", caption = {"hextorio-gui.clear-filters"}}
    local export_json_button = left_frame_buttons_flow.add {type = "button", name = "export-json", caption = {"hextorio-gui.export-json"}}
    export_json_button.tooltip = {"hextorio-gui.export-json-tooltip"}

    local planet_flow = left_frame.add {type = "flow", name = "planet-flow", direction = "horizontal"}
    left_frame.add {type = "line", direction = "horizontal"}
    local trade_contents_flow = left_frame.add {type = "flow", name = "trade-contents-flow", direction = "vertical"}
    local trade_contents_label = trade_contents_flow.add {type = "label", name = "label", caption = {"hextorio-gui.trade-contents"}}
    local trade_contents_frame = trade_contents_flow.add {type = "frame", name = "frame", direction = "horizontal"}
    left_frame.add {type = "line", direction = "horizontal"}
    local processing_flow = left_frame.add {type = "flow", name = "processing-flow", direction = "horizontal"}
    local processing_label = processing_flow.add {type = "label", name = "label", caption = {"hextorio-gui.processing-finished"}}
    local processing_progress_bar = processing_flow.add {type = "progressbar", name = "progressbar", value = 0}

    local show_only_claimed_flow = right_frame.add {type = "flow", name = "show-only-claimed", direction = "horizontal"}
    local toggle_show_only_claimed = show_only_claimed_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_show_only_claimed.style.top_margin = 3
    local toggle_show_only_claimed_label = show_only_claimed_flow.add {type = "label", name = "label", caption = {"hextorio-gui.show-only-claimed"}}

    local exact_inputs_match_flow = right_frame.add {type = "flow", name = "exact-inputs-match", direction = "horizontal"}
    local toggle_exact_inputs_match = exact_inputs_match_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_exact_inputs_match.tooltip = {"hextorio-gui.exact-inputs-match-tooltip"}
    toggle_exact_inputs_match.style.top_margin = 3
    local toggle_exact_inputs_match_label = exact_inputs_match_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exact-inputs-match"}}
    toggle_exact_inputs_match_label.tooltip = {"hextorio-gui.exact-inputs-match-tooltip"}
    local exact_outputs_match_flow = right_frame.add {type = "flow", name = "exact-outputs-match", direction = "horizontal"}
    local toggle_exact_outputs_match = exact_outputs_match_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_exact_outputs_match.style.top_margin = 3
    toggle_exact_outputs_match.tooltip = {"hextorio-gui.exact-outputs-match-tooltip"}
    local toggle_exact_outputs_match_label = exact_outputs_match_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exact-outputs-match"}}
    toggle_exact_outputs_match_label.tooltip = {"hextorio-gui.exact-outputs-match-tooltip"}

    local max_input_items_flow = right_frame.add {type = "flow", name = "max-inputs-flow", direction = "horizontal"}
    local max_input_items_slider = max_input_items_flow.add {type = "slider", name = "slider", value = 3, minimum_value = 1, maximum_value = 3}
    max_input_items_slider.style.width = 80
    local max_input_items_label = max_input_items_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max-inputs", 3}}
    max_input_items_label.style.top_margin = -4
    gui.auto_width(max_input_items_label)

    local max_output_items_flow = right_frame.add {type = "flow", name = "max-outputs-flow", direction = "horizontal"}
    local max_output_items_slider = max_output_items_flow.add {type = "slider", name = "slider", value = 3, minimum_value = 1, maximum_value = 3}
    max_output_items_slider.style.width = 80
    local max_output_items_label = max_output_items_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max-outputs", 3}}
    max_output_items_label.style.top_margin = -4
    gui.auto_width(max_output_items_label)

    right_frame.add {type = "line", direction = "horizontal"}

    local max_trades_flow = right_frame.add {type = "flow", name = "max-trades-flow", direction = "horizontal"}
    local max_trades_label = max_trades_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max-trades"}}
    max_trades_label.style.top_margin = 3
    local max_trades_dropdown = max_trades_flow.add {type = "drop-down", name = "dropdown", selected_index = 4, items = {{"", 10}, {"", 25}, {"", 100}, {"hextorio-gui.all"}}}

    local sort_method_flow = right_frame.add {type = "flow", name = "sort-method", direction = "horizontal"}
    local sort_method_label = sort_method_flow.add {type = "label", name = "label", caption = {"hextorio-gui.sort-method"}}
    local sort_method_dropdown = sort_method_flow.add {type = "drop-down", name = "dropdown", selected_index = 1, items = {{"trade-sort-method.distance-from-spawn"}, {"trade-sort-method.distance-from-character"}, {"trade-sort-method.total-item-value"}, {"trade-sort-method.num-inputs"}, {"trade-sort-method.num-outputs"}, {"trade-sort-method.productivity"}}}

    local sort_direction = right_frame.add {
        type = "switch",
        name = "sort-direction",
        left_label_caption = {"hextorio-gui.ascending"},
        right_label_caption = {"hextorio-gui.descending"},
    }

    trade_contents_label.style.font = "heading-2"
    processing_progress_bar.visible = false
    gui.auto_width(processing_progress_bar)

    for i = 1, 3 do
        local input_item = trade_contents_frame.add {
            type = "choose-elem-button",
            elem_type = "item",
            name = "input-item-" .. i,
        }
    end

    local trade_arrow = trade_contents_frame.add {
        type = "sprite",
        name = "trade-arrow",
        sprite = "trade-arrow",
    }
    trade_arrow.style.top_margin = 4
    trade_arrow.tooltip = {"hextorio-gui.click-to-swap-sides"}
    trade_arrow.style.width = 30 / 1.2
    trade_arrow.style.height = 30 / 1.2

    for i = 1, 3 do
        local output_item = trade_contents_frame.add {
            type = "choose-elem-button",
            elem_type = "item",
            name = "output-item-" .. (4 - i), -- 4 - i to be more consistent with how trades are shown in general
        }
        if i == 1 then
            output_item.style.left_margin = 12
        end
    end

    -- local surface_list_frame = frame.add {type = "frame", name = "surface-list-frame", direction = "vertical"}
    -- local surface_list = surface_list_frame.add {type = "list-box", name = "list-box", items = storage.trades.trade_overview_surface_list, selected_index = 1}
    -- surface_list_frame.style.natural_width = 100
    -- surface_list_frame.style.vertically_stretchable = true

    local trade_table_frame = frame.add {type = "frame", name = "trade-table-frame", direction = "vertical"}
    gui.auto_width_height(trade_table_frame)

    local scroll_pane = trade_table_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.style.vertically_stretchable = true
    trade_table_frame.style.vertically_stretchable = true
    trade_table_frame.style.vertically_squashable = true
    trade_table_frame.style.natural_width = 700

    local trade_table = scroll_pane.add {type = "table", name = "table", column_count = 2}
    trade_table.style.horizontal_spacing = 109 / 1.2

    for surface_name, _ in pairs(storage.trade_overview.allowed_planet_filters) do
        if not planet_flow[surface_name] then
            local enabled = game.get_surface(surface_name) ~= nil
            local surface_sprite = filter_frame["left"]["planet-flow"].add {
                type = "sprite-button",
                name = surface_name,
                sprite = "planet-" .. surface_name,
                toggled = enabled,
                enabled = enabled,
            }
        end
    end
end

function gui.init_catalog(player)
    local frame = player.gui.screen.add {
        type = "frame",
        name = "catalog",
        direction = "vertical",
    }
    frame.style.width = 1200
    frame.style.height = 800
    frame.visible = false

    gui.add_titlebar(frame, {"hextorio-gui.catalog"})

    local flow = frame.add {type = "flow", name = "flow", direction = "horizontal"}

    local catalog_frame = flow.add {type = "flow", name = "catalog-frame", direction = "vertical"}
    gui.auto_width_height(catalog_frame)

    local scroll_pane = catalog_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.style.vertically_stretchable = true
    scroll_pane.style.vertically_squashable = true

    local inspect_frame = flow.add {type = "frame", name = "inspect-frame", direction = "vertical"}
    gui.auto_width_height(inspect_frame)
    inspect_frame.style.natural_width = 340 / 1.2

    for i, surface_name in ipairs {
        "nauvis",
        "vulcanus",
        "fulgora",
        "gleba",
        "aquilo",
    } do
        local items_sorted_by_value = item_values.get_items_sorted_by_value(surface_name, true)

        if i > 1 then
            scroll_pane.add {type = "line", direction = "horizontal"}
        end

        local surface_header = scroll_pane.add {type = "label", name = "surface-header-" .. surface_name, caption = {"", "[img=space-location." .. surface_name .. "] ", {"space-location-name." .. surface_name}}}
        surface_header.style.font = "heading-1"

        local pb_discovery = scroll_pane.add {type = "progressbar", name = "pb-discovery-" .. surface_name, value = 0}
        pb_discovery.style.horizontally_stretchable = true
        pb_discovery.tooltip = {"hextorio-gui.items-discovered", 0, #items_sorted_by_value}
        pb_discovery.style.color = {39, 137, 228}

        local progress_bar_flow = scroll_pane.add {type = "flow", name = "progress-bar-flow-" .. surface_name, direction = "horizontal"}
        progress_bar_flow.style.horizontally_stretchable = true
        progress_bar_flow.style.horizontally_squashable = true
        for j = 2, 5 do
            local pb_ranks = progress_bar_flow.add {type = "progressbar", name = "pb-ranks-" .. j, value = 0}
            pb_ranks.tooltip = lib.get_rank_img_str(j) .. " x0"
            pb_ranks.style.color = storage.item_ranks.rank_colors[j]
            pb_ranks.style.horizontally_stretchable = true
            pb_ranks.style.horizontally_squashable = true
        end

        local catalog_table = scroll_pane.add {type = "table", name = "table-" .. surface_name, column_count = 13}
        gui.auto_width(catalog_table)

        local n = 1
        for j = 1, #items_sorted_by_value do
            local item_name = items_sorted_by_value[j]
            if lib.is_catalog_item(item_name) then
                n = n + 1
                local rank = item_ranks.get_item_rank(item_name)

                local rank_flow = catalog_table.add {
                    type = "flow",
                    name = "rank-flow-" .. item_name,
                    direction = "vertical",
                }

                rank_flow.style.top_margin = 20
                rank_flow.style.width = 60 -- this makes undiscovered items have the same width as discovered items

                if n % catalog_table.column_count > 0 then
                    rank_flow.style.left_margin = 0
                end

                local sprite_button = rank_flow.add {
                    type = "sprite-button",
                    name = "catalog-item",
                    sprite = "item/" .. item_name,
                }

                sprite_button.style.left_margin = 5

                local rank_stars = rank_flow.add {
                    type = "sprite",
                    name = "rank-stars",
                    sprite = "rank-" .. rank,
                }

                gui.give_item_tooltip(player, surface_name, sprite_button)
            end
        end
    end
end

function gui.is_hex_core_open(player)
    local frame = player.gui.relative["hex-core"]
    return frame ~= nil and frame.visible
end

function gui.is_trade_overview_open(player)
    local frame = player.gui.screen["trade-overview"]
    return frame ~= nil and frame.visible
end

function gui.is_catalog_open(player)
    local frame = player.gui.screen["catalog"]
    return frame ~= nil and frame.visible
end

function gui.is_questbook_open(player)
    local frame = player.gui.screen["questbook"]
    return frame ~= nil and frame.visible
end

function gui.show_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then
        gui.init_hex_core(player)
        frame = player.gui.relative["hex-core"]
    end
    frame.visible = true
    gui.update_hex_core(player)
end

function gui.hide_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then return end
    frame.visible = false
end

function gui.show_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then
        gui.init_trade_overview(player)
        frame = player.gui.screen["trade-overview"]
    end
    frame.visible = true
    player.opened = frame
    gui.update_trade_overview(player)
    frame.force_auto_center()
end

function gui.hide_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end
    frame.visible = false
    player.opened = nil

    if storage.gui and storage.gui.trades_scroll_pane_update and storage.gui.trades_scroll_pane_update[player.name] then
        storage.gui.trades_scroll_pane_update[player.name].finished = true
    end
end

function gui.show_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then
        gui.init_questbook(player)
        frame = player.gui.screen["questbook"]
    end
    frame.visible = true
    player.opened = frame
    gui.update_questbook(player)
    frame.force_auto_center()
end

function gui.hide_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then return end
    frame.visible = false
    player.opened = nil
end

function gui.show_catalog(player)
    local frame = player.gui.screen["catalog"]
    if not frame then
        gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end
    frame.visible = true
    player.opened = frame
    gui.update_catalog(player)
    frame.force_auto_center()
end

function gui.hide_catalog(player)
    local frame = player.gui.screen["catalog"]
    if not frame then return end
    frame.visible = false
    player.opened = nil
end

function gui.hide_all_frames(player)
    gui.hide_questbook(player)
    gui.hide_trade_overview(player)
    gui.hide_catalog(player)
end

function gui.give_item_tooltip(player, surface_name, element)
    local item_name
    local rich_type
    if element.sprite:sub(1, 5) == "item/" then
        item_name = element.sprite:sub(6)
        rich_type = "item"
        if item_name:sub(-5) == "-coin" then
            gui.try_give_coin_tooltip(element)
            return
        end
    elseif element.sprite:sub(1, 7) == "entity/" then
        item_name = element.sprite:sub(8)
        rich_type = "fluid"
        if item_name == "sulfuric-acid-geyser" then
            item_name = "sulfuric-acid"
        elseif item_name == "fluorine-vent" then
            item_name = "fluorine"
        end
    else
        lib.log_error("gui.give_item_tooltip: Could not determine item name from sprite: " .. element.sprite)
        return
    end

    local quality = element.quality
    if quality then
        quality = quality.name
    else
        quality = "normal"
    end

    local hex_coin_value = item_values.get_item_value(surface_name, "hex-coin")
    local item_count = element.number or 1
    local value = item_values.get_item_value(surface_name, item_name)
    local scaled_value = value / hex_coin_value * lib.get_quality_value_scale(quality)

    local rank_str = {""}
    if lib.is_catalog_item(item_name) then
        local rank = item_ranks.get_item_rank(item_name)
        local left_half
        if rank == 1 then
            left_half = gui.get_bronze_sprite_half(item_name)
        end
        rank_str = {"", lib.color_localized_string({"hextorio-gui.rank"}, "white", "heading-1"), " " , lib.get_rank_img_str(rank, left_half), "\n\n"}
    end

    local item_img_rich_text = "[" .. rich_type .. "=" .. item_name .. ",quality=" .. quality .. "]"

    element.tooltip = {"",
        item_img_rich_text,
        prototypes[rich_type][item_name].localised_name,
        "\n-=-=-=-=-=-=-=-=-\n",
        rank_str,
        "[img=planet-" .. surface_name .. "] [font=heading-2][color=green]",
        {"hextorio-gui.item-value"},
        "[.color][.font]\n" .. item_img_rich_text .. "x1 = ",
        coin_tiers.base_coin_value_to_text(scaled_value, false, 4),
        "\n\n[img=planet-" .. surface_name .. "] [font=heading-2][color=yellow]",
        {"hextorio-gui.stack-value-total"},
        "[.color][.font]\n" .. item_img_rich_text .. "x" .. item_count .. " = ",
        coin_tiers.base_coin_value_to_text(item_count * scaled_value, false, nil)
    }
end

function gui.give_productivity_tooltip(element, trade, quality, quality_cost_mult)
    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    local s = {"",
        trades.get_total_values_str(trade, quality, quality_cost_mult),
    }

    if trades.is_interplanetary_trade(trade) then
        table.insert(s, 2, lib.color_localized_string({"hextorio-gui.interplanetary-trade-tooltip-header"}, "cyan", "heading-2"))
        table.insert(s, 3, "\n\n")
    end

    if trades.has_any_productivity_modifiers(trade, quality) then
        table.insert(s, "\n\n")
        table.insert(s, trades.get_productivity_bonus_str(trade, quality))
    end

    element.tooltip = s
end

function gui.try_give_coin_tooltip(element)
    if element.number >= 1000 then
        element.tooltip = element.number
    else
        element.tooltip = nil
    end
end

function gui._process_trades_scroll_panes()
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.trades_scroll_pane_update then
        storage.gui.trades_scroll_pane_update = {}
    end
    for player_name, process in pairs(storage.gui.trades_scroll_pane_update) do
        if process.finished then
            storage.gui.trades_scroll_pane_update[player_name] = nil
        else
            if game.tick % process.tick_interval == 0 then
                gui._update_trades_scroll_pane_tick(process)
            end
        end
    end
end

function gui._update_trades_scroll_pane_tick(process)
    if process.clear_mode then
        process.trades_scroll_pane.clear()
        process.clear_mode = false
        if not process.immediate then
            return
        end
    end

    local batch_size = 150
    if game.is_multiplayer() then
        batch_size = 100 -- slow down for slow connections like my own
    end
    if process.immediate then
        batch_size = #process.trades_list
    end

    for trade_number = process.batch_idx, math.min(#process.trades_list, process.batch_idx + batch_size - 1) do
        local trade = process.trades_list[trade_number]
        if not trade then
            lib.log_error("trade_number = " .. trade_number .. " is out of bounds for list of " .. #process.trades_list .. " trades")
            break
        end

        if process.params.expanded and trade_number ~= 1 then
            local line = process.trades_scroll_pane.add {
                type = "line",
                direction = "horizontal",
            }
            line.style.top_margin = 8 / 1.2
            line.style.bottom_margin = 8 / 1.2
        end

        gui.add_trade_elements(process.player, process.trades_scroll_pane, trade, trade_number, process.params)
    end

    if process.for_trade_overview then
        local processing_label = process.processing_flow["label"]
        local progress_bar = process.processing_flow["progressbar"]
        progress_bar.value = math.min(1, (process.batch_idx + batch_size - 1) / #process.trades_list)
        progress_bar.visible = progress_bar.value < 1
        processing_label.visible = not progress_bar.visible
        if processing_label.visible then
            processing_label.caption = {"hextorio-gui.processing-finished", #process.trades_list}
        end
    end

    process.batch_idx = process.batch_idx + batch_size
    if process.batch_idx > #process.trades_list then
        process.finished = true
    end
end

function gui.add_trade_elements(player, element, trade, trade_number, params)
    local size = 40

    local trade_flow = element.add {
        type = "flow",
        name = "trade-" .. trade_number,
        direction = "horizontal",
    }

    if params.show_core_finder then
        local core_finder_button = trade_flow.add {
            type = "sprite-button",
            name = "core-finder-button-" .. trade_number,
            sprite = "utility/gps_map_icon",
        }
        -- core_finder_button.style.left_margin = 5
        -- core_finder_button.style.top_margin = 10
        core_finder_button.tooltip = {"hextorio-gui.core-finder-button"}
    end

    local quality_to_show = params.quality_to_show or "normal"
    local quality_cost_multipliers = lib.get_quality_cost_multipliers()
    local quality_cost_mult = quality_cost_multipliers[quality_to_show]

    local trade_frame = trade_flow.add {
        type = "flow",
        name = "frame",
        direction = "vertical",
    }
    trade_frame.style.left_margin = 10
    trade_frame.style.natural_height = (size + 20) / 1.2 - 5
    trade_frame.style.width = 381 / 1.2

    local trade_table = trade_frame.add {
        type = "table",
        name = "trade-table",
        column_count = 8,
    }

    if params.expanded then
        local trade_control_flow = trade_frame.add {
            type = "flow",
            name = "trade-control-flow",
            direction = "horizontal",
        }

        if params.show_toggle_trade then
            local sprite
            if trade.active then
                sprite = "virtual-signal/signal-check"
            else
                sprite = "virtual-signal/signal-deny"
            end
            local toggle_trade_button = trade_control_flow.add {
                type = "sprite-button",
                name = "toggle-trade-" .. trade_number,
                sprite = sprite,
            }
            toggle_trade_button.tooltip = {"hex-core-gui.trade-checkbox-tooltip"}
        end

        if params.show_tag_creator then
            local tag_button = trade_control_flow.add {
                type = "sprite-button",
                name = "tag-button-" .. trade_number,
                sprite = "utility/show_tags_in_map_view",
            }
            tag_button.tooltip = {"hex-core-gui.tag-button"}
        end

        if params.show_ping_button then
            local ping_button = trade_control_flow.add {
                type = "sprite-button",
                name = "ping-button",
                sprite = "utility/shoot_cursor_red",
            }
            ping_button.tooltip = {"hextorio-gui.ping-in-chat"}
        end

        if params.show_productivity_info then
            local prod_info = trade_control_flow.add {
                type = "sprite-button",
                name = "productivity-info",
                sprite = "item/productivity-module-3",
            }

            gui.give_productivity_tooltip(prod_info, trade, quality_to_show, quality_cost_mult)
        end

        if params.show_add_to_filters then
            local add_to_filters_button = trade_control_flow.add {
                type = "sprite-button",
                name = "add-to-filters-" .. trade_number,
                sprite = "item/loader",
            }
            add_to_filters_button.tooltip = {"hex-core-gui.add-to-filters-tooltip"}
        end

        if params.show_quality_bounds then
            local allowed_qualities = trade.allowed_qualities or {"normal"}
            local min_quality = trade_control_flow.add {
                type = "choose-elem-button",
                name = "min-quality-" .. trade_number,
                elem_type = "signal",
                signal = {type = "quality", name = allowed_qualities[#allowed_qualities]},
            }
            min_quality.tooltip = {"hex-core-gui.minimum-trade-quality"}

            local max_quality = trade_control_flow.add {
                type = "choose-elem-button",
                name = "max-quality-" .. trade_number,
                elem_type = "signal",
                signal = {type = "quality", name = allowed_qualities[1]},
            }
            max_quality.tooltip = {"hex-core-gui.maximum-trade-quality"}
        end
    end

    local total_empty = 0
    for i = 1, 3 do
        if i <= #trade.input_items then
            local input_item = trade.input_items[i]
            local input = trade_table.add {
                type = "sprite-button",
                name = "input-" .. tostring(i) .. "-" .. input_item.name,
                sprite = "item/" .. input_item.name,
                number = input_item.count,
            }
            if lib.is_coin(input_item.name) then
                local coin = trades.get_input_coins_of_trade(trade, quality_to_show, quality_cost_mult)
                local tier = coin_tiers.get_tier_for_display(coin)
                local coin_name = coin_tiers.get_name_of_tier(tier)
                local base_value, other_value = coin_tiers.to_base_values(coin, tier)
                input.number = math.ceil(other_value)
                input.sprite = "item/" .. coin_name
            else
                input.quality = quality_to_show
            end
            gui.give_item_tooltip(player, trade.surface_name, input)
        else
            total_empty = total_empty + 1
            local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
            empty.style.natural_width = size / 1.2
            empty.style.natural_height = size / 1.2
            empty.ignored_by_interaction = true
        end
    end

    local sprite_name = "trade-arrow"
    if trades.is_interplanetary_trade(trade) then
        sprite_name = "interplanetary-trade-arrow"
    end

    local trade_arrow_sprite = trade_table.add {
        type = "sprite",
        name = "trade-arrow",
        sprite = sprite_name,
    }
    trade_arrow_sprite.style.width = size / 1.2
    trade_arrow_sprite.style.height = size / 1.2
    trade_arrow_sprite.style.top_margin = 2

    local prod = trades.get_productivity(trade, quality_to_show)
    if params.show_productivity_bar and prod ~= 0 then
        local prod_bar = trade_frame.add {
            type = "progressbar",
            name = "prod-bar",
            value = trades.get_current_prod_value(trade, quality_to_show),
            style = "bonus_progressbar",
        }
        if prod < 0 then
            prod_bar.style.color = {1, 0, 0}
        end
        prod_bar.style.horizontally_squashable = true
        prod_bar.style.horizontally_stretchable = true
    end

    local prod_str = "[font=count-font]" .. lib.format_percentage(prod, 1, true, true) .. "[.font]"
    if prod < 0 then
        prod_str = "[color=red]" .. prod_str .. "[.color]"
    elseif prod > 0 then
        prod_str = "[color=green]" .. prod_str .. "[.color]"
    else
        prod_str = ""
    end

    local prod_label = trade_table.add {
        type = "label",
        name = "productivity",
        caption = prod_str,
    }
    prod_label.style.left_margin = -32 / 1.2
    prod_label.style.top_margin = 24 / 1.2

    for i = 1, 3 do
        local j = 4 - i
        if j <= #trade.output_items then
            local output_item = trade.output_items[j]
            local output = trade_table.add {
                type = "sprite-button",
                name = "output-" .. tostring(i) .. "-" .. tostring(output_item.name),
                sprite = "item/" .. output_item.name,
                number = output_item.count,
            }
            if lib.is_coin(output_item.name) then
                local coin = trades.get_output_coins_of_trade(trade, quality_to_show)
                local tier = coin_tiers.get_tier_for_display(coin)
                local coin_name = coin_tiers.get_name_of_tier(tier)
                local base_value, other_value = coin_tiers.to_base_values(coin, tier)
                output.number = math.ceil(other_value)
                output.sprite = "item/" .. coin_name
            else
                output.quality = quality_to_show
            end
            gui.give_item_tooltip(player, trade.surface_name, output)
        else
            total_empty = total_empty + 1
            local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
            empty.style.natural_width = size / 1.2
            empty.style.natural_height = size / 1.2
            empty.ignored_by_interaction = true
        end
    end
end

function gui.update_trades_scroll_pane(player, trades_scroll_pane, trades_list, params)
    if not params then params = {} end
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.trades_scroll_pane_update then
        storage.gui.trades_scroll_pane_update = {}
    end
    local tick_interval = 5
    if game.is_multiplayer() then
        tick_interval = 10
    end
    local process = {
        player = player,
        tick_interval = tick_interval,
        trades_scroll_pane = trades_scroll_pane,
        trades_list = trades_list,
        params = params,
        clear_mode = true,
        batch_idx = 1,
        for_trade_overview = gui.is_descendant_of(trades_scroll_pane, "trade-overview"),
    }
    if process.for_trade_overview then
        process.processing_flow = process.trades_scroll_pane.parent.parent.parent["filter-frame"]["left"]["processing-flow"]
    else
        process.immediate = true
    end
    storage.gui.trades_scroll_pane_update[player.name] = process
end

function gui.generate_sprite_buttons(player, surface_name, flow, items, give_tooltip)
    for item_name, count in pairs(items) do
        local sprite_button = flow.add {
            type = "sprite-button",
            name = item_name,
            sprite = "item/" .. item_name,
            number = count,
        }
        if give_tooltip or give_tooltip == nil then
            gui.give_item_tooltip(player, surface_name, sprite_button)
        end
    end
end

function gui.update_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then
        gui.init_hex_core(player)
        frame = player.gui.relative["hex-core"]
    end

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    frame["hex-control-flow"]["delete-core"].visible = quests.is_feature_unlocked "hex-core-deletion"
    frame["sink-mode-confirmation"].visible = false
    frame["generator-mode-confirmation"].visible = false

    local quality_unlocked = game.forces.player.is_quality_unlocked(prototypes.quality.uncommon)
    frame["trades-header"]["quality-dropdown"].visible = quality_unlocked
    frame["trades-header"]["info"].visible = quality_unlocked

    if state.claimed then
        frame["claim-flow"].visible = false
        local claimed_by_name = state.claimed_by or {"hextorio.server"}
        local claimed_timestamp = state.claimed_timestamp or 0
        frame["claimed-by"].visible = true
        frame["claimed-by"].caption = {"hex-core-gui.claimed-by", claimed_by_name, lib.ticks_to_string(claimed_timestamp)}

        frame["hex-control-flow"].visible = true
        frame["hex-control-flow"]["stats"].tooltip = lib.get_str_from_hex_core_stats(hex_grid.get_hex_core_stats(state))
        frame["hex-control-flow"]["teleport"].visible = quests.is_feature_unlocked "teleportation" and not lib.is_player_editor_like(player) and state.hex_core ~= nil and player.character ~= nil and player.character.surface.name == state.hex_core.surface.name
        frame["hex-control-flow"]["toggle-hexport"].visible = quests.is_feature_unlocked "hexports"

        if state.hexport then
            frame["hex-control-flow"]["toggle-hexport"].sprite = "item/roboport"
        else
            frame["hex-control-flow"]["toggle-hexport"].sprite = "no-roboport"
        end

        frame["hex-control-flow"]["supercharge"].visible = not state.is_infinite and quests.is_feature_unlocked "supercharging"
        if frame["hex-control-flow"]["supercharge"].visible then
            local cost = hex_grid.get_supercharge_cost(hex_core)
            frame["hex-control-flow"]["supercharge"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.supercharge-tooltip-header"}, "orange", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(cost)},
                "\n",
                {"hex-core-gui.supercharge-tooltip-body"},
            }
        end

        frame["hex-control-flow"]["convert-resources"].visible = quests.is_feature_unlocked "resource-conversion" and hex_grid.has_multiple_ore_types(state)
        if frame["hex-control-flow"]["convert-resources"].visible then
            local cost = hex_grid.get_convert_resources_cost(hex_core)
            frame["hex-control-flow"]["convert-resources"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.convert-resources-tooltip-header"}, "blue", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(cost)},
                "\n",
                {"hex-core-gui.convert-resources-tooltip-body", "[item=" .. hex_grid.get_most_abundant_ore(state) .. "]"},
            }
        end

        frame["hex-control-flow"]["delete-core"].enabled = true
        frame["hex-control-flow"]["delete-core"].visible = quests.is_feature_unlocked "hex-core-deletion" and hex_grid.can_delete_hex_core(hex_core)
        if frame["hex-control-flow"]["delete-core"].visible then
            local cost = hex_grid.get_delete_core_cost(hex_core)
            frame["hex-control-flow"]["delete-core"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.delete-core-tooltip-header"}, "red", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(cost)},
                "\n",
                {"hex-core-gui.delete-core-tooltip-body"},
            }
        end

        frame["hex-control-flow"]["sink-mode"].visible = state.mode == nil and quests.is_feature_unlocked "sink-mode"
        frame["hex-control-flow"]["generator-mode"].visible = state.mode == nil and quests.is_feature_unlocked "generator-mode"

        local next_quality = hex_core.quality.next
        if next_quality then
            local next_quality_tier = lib.get_quality_tier(next_quality.name)
            frame["hex-control-flow"]["upgrade-quality"].visible = lib.is_quality_tier_unlocked(next_quality_tier)
            if frame["hex-control-flow"]["upgrade-quality"].visible then
                frame["hex-control-flow"]["upgrade-quality"].sprite = "quality/" .. next_quality.name
                frame["hex-control-flow"]["upgrade-quality"].tooltip = {"",
                    lib.color_localized_string({"hex-core-gui.upgrade-quality-tooltip-header"}, "green", "heading-2"),
                    "\n",
                    {"hextorio-gui.cost", coin_tiers.coin_to_text(hex_grid.get_quality_upgrade_cost(hex_core))},
                    "\n",
                    {"hex-core-gui.upgrade-quality-tooltip-body"},
                }
            end
        else
            frame["hex-control-flow"]["upgrade-quality"].visible = false
        end
    else
        frame["claim-flow"].visible = true
        frame["claimed-by"].visible = false

        frame["hex-control-flow"].visible = false

        if hex_grid.get_free_hex_claims(hex_core.surface.name) > 0 then
            frame["claim-flow"]["free-hexes-remaining"].visible = true
            frame["claim-flow"]["free-hexes-remaining"].caption = {"", lib.color_localized_string({"hextorio-gui.quest-reward"}, "white", "heading-2"), " ", {"hextorio-gui.quest-reward-free-hexes-remaining", hex_grid.get_free_hex_claims(hex_core.surface.name), "green", "heading-2"}}
            gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin_tiers.new())
        else
            frame["claim-flow"]["free-hexes-remaining"].visible = false
            local coin = state.claim_price
            gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin)
        end
    end

    frame["delete-core-confirmation"].visible = false
    -- frame["unloader-filters-flow"].visible = false

    local quality_dropdown = frame["trades-header"]["quality-dropdown"]
    local quality_name = gui.get_quality_name_from_dropdown(quality_dropdown)

    local show_quality_bounds = false
    if state.claimed then
        show_quality_bounds = lib.get_highest_unlocked_quality().name ~= "normal"
    end

    gui.update_trades_scroll_pane(player, frame.trades, trades.convert_trade_id_array_to_trade_array(state.trades), {
        show_toggle_trade = state.claimed,
        show_tag_creator = true,
        show_ping_button = true,
        show_add_to_filters = state.claimed,
        show_core_finder = false,
        show_productivity_bar = true,
        show_quality_bounds = show_quality_bounds,
        quality_to_show = quality_name,
        show_productivity_info = true,
        expanded = true,
    })

    gui.update_hex_core_resources(player)
end

function gui.update_hex_core_resources(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then
        lib.log_error("gui.update_hex_core_resources: hex-core frame could not be found")
        return
    end

    local resources_flow = frame["resources-flow"]
    if not resources_flow then
        lib.log_error("gui.update_hex_core_resources: resources-flow could not be found")
        return
    end

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then
        lib.log_error("gui.update_hex_core_resources: hex_core entity could not be found")
        return
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then
        lib.log_error("gui.update_hex_core_resources: hex_core state could not be found")
        return
    end

    local resources = state.resources or {}

    resources_flow.clear()
    for resource_name, amount in pairs(resources) do
        if state.is_infinite then
            amount = 1000000000000
        end
        local sprite = "item/" .. resource_name
        if state.is_well or state.is_oil then -- is_oil for <=0.2.3, should make this a function
            sprite = "entity/" .. resource_name
        end
        local resource = resources_flow.add {
            type = "sprite-button",
            sprite = sprite,
            number = amount,
        }
        gui.give_item_tooltip(player, hex_core.surface.name, resource)
    end

    if not next(resources) then
        resources_flow.add {
            type = "label",
            name = "no-resources",
            caption = {"hextorio.none"},
        }
    end
end

function gui.update_questbook(player, quest_name)
    local frame = player.gui.screen["questbook"]
    if not frame then
        gui.init_questbook(player)
        frame = player.gui.screen["questbook"]
    end

    gui.repopulate_quest_lists(player) -- THIS IS NOT SUPPOSED TO BE NEEDED.  BUT AT LEAST ONE MOD (RPG) IS KNOWN DESTROY THE QUEST LIST ITEMS.  THIS ADDS "SUPPORT" FOR SUCH MODS THAT SOMEHOW DO THIS.

    local quest_frame = frame["lower-flow"]["quest-frame"]

    local quests_scroll_pane = frame["lower-flow"]["list-frame"]["scroll-pane"]
    local complete_header = quests_scroll_pane["complete-header"]
    local incomplete_header = quests_scroll_pane["incomplete-header"]
    local incomplete_list = quests_scroll_pane["incomplete-list"]
    local complete_list = quests_scroll_pane["complete-list"]

    local quest_info_frame = quest_frame["info-frame"]
    local quest_info_main = quest_info_frame["main"]
    local quest_info_img_frame = quest_info_frame["img-frame"]
    local quest_info_img = quest_info_img_frame["img"]
    local quest_title = quest_info_main["title"]
    local quest_description = quest_info_main["description"]
    local debug_complete_quest = quest_info_main["debug-complete-quest"]
    local quest_notes_flow = quest_info_main["notes-flow"]

    local quest_conditions_frame = quest_frame["conditions-rewards"]["conditions"]
    local quest_conditions_scroll_pane = quest_conditions_frame["scroll-pane"]
    local quest_rewards_frame = quest_frame["conditions-rewards"]["rewards"]
    local quest_rewards_scroll_pane = quest_rewards_frame["scroll-pane"]

    if not quest_name then
        quest_name = gui.get_player_current_quest_selected(player)
    end

    local quest
    if quest_name then
        quest = quests.get_quest_from_name(quest_name)
    end

    if not quest then return end
    if quest.has_img == nil or quest.has_img then
        quest_info_img_frame.visible = true
        quest_info_img.sprite = "quest-" .. quest.name
    else
        quest_info_img_frame.visible = false
    end

    local localized_quest_title = quests.get_quest_localized_title(quest)
    quest_title.caption = localized_quest_title
    quest_description.caption = quests.get_quest_localized_description(quest)
    debug_complete_quest.visible = storage.debug_mode == true and not quests.is_complete(quest)

    complete_header.caption = {"hextorio-questbook.complete", #complete_list.items}
    incomplete_header.caption = {"hextorio-questbook.incomplete", #incomplete_list.items}

    quest_notes_flow.clear()
    if quest.notes then
        for i, note_name in ipairs(quest.notes) do
            gui.add_info(quest_notes_flow, quests.get_localized_note(note_name), "info-" .. i)
        end
    end

    quest_conditions_scroll_pane.clear()
    for i, condition in ipairs(quest.conditions) do
        local condition_frame = quest_conditions_scroll_pane.add {
            type = "frame",
            name = "condition-" .. i,
            direction = "vertical",
            caption = quests.get_condition_localized_name(condition),
        }
        condition_frame.style.horizontally_squashable = false

        local condition_str = condition.progress_requirement
        if condition.type == "coins-in-inventory" then
            condition_str = coin_tiers.base_coin_value_to_text(condition.progress_requirement)
        elseif condition.type == "visit-planet" then
            condition_str = condition.value
        end

        local caption
        if condition.value and condition.type ~= "visit-planet" then
            local condition_value = condition.value
            if type(condition.value) ~= "table" then
                condition_value = {condition_value}
            end
            local t = {table.unpack(condition_value)}
            if condition.type == "kill-entity" or condition.type == "place-entity" or condition.type == "mine-entity" or condition.type == "place-entity-on-planet" then
                table.insert(t, lib.get_true_localized_name(t[1], "entity"))
            elseif condition.type == "use-capsule" then
                table.insert(t, lib.get_true_localized_name(t[1], "item"))
            elseif condition.type == "place-tile" then
                table.insert(t, {"item-name." .. t[1]}) -- could possibly have to change this, but it might be fine
            elseif condition.type == "sell-item-of-quality" then
                table.insert(t, {"quality-name." .. t[1]})
            end
            table.insert(t, "green")
            table.insert(t, "heading-2") -- Lua table.unpack() and ... is weird, so this is necessary
            caption = quests.get_condition_localized_description(condition, condition_str, table.unpack(t))
        else
            caption = quests.get_condition_localized_description(condition, condition_str, "green", "heading-2")
        end

        local condition_desc = condition_frame.add {
            type = "label",
            name = "desc",
            caption = caption,
        }
        condition_desc.style.single_line = false
        gui.auto_width(condition_desc)

        if condition.notes then
            for j, note_name in ipairs(condition.notes) do
                gui.add_info(condition_frame, quests.get_localized_note(note_name), "info-" .. j)
            end
        end

        if condition.show_progress_bar then
            local progress_bar = condition_frame.add {
                type = "progressbar",
                name = "progressbar",
                value = quests.get_condition_progress(quest, condition),
            }
            gui.auto_width(progress_bar)
            local r, g, b = lib.hsv_to_rgb(progress_bar.value * 0.3333, 1, 1)
            progress_bar.style.color = {r, g, b}
            progress_bar.tooltip = condition.progress .. " / " .. condition.progress_requirement
        end
    end

    quest_rewards_scroll_pane.clear()
    for i, reward in ipairs(quest.rewards) do
        local reward_frame = quest_rewards_scroll_pane.add {
            type = "frame",
            name = "reward-" .. i,
            direction = "vertical",
            caption = quests.get_reward_localized_name(reward),
        }
        reward_frame.style.horizontally_squashable = false
        local caption
        if reward.type == "unlock-feature" then
            caption = quests.get_reward_localized_description(reward, "orange", "heading-2", quests.get_feature_localized_name(reward.value))
        elseif reward.type == "receive-items" then
            caption = quests.get_reward_localized_description(reward)
        elseif type(reward.value) == "table" then
            caption = quests.get_reward_localized_description(reward, "green", "heading-2", table.unpack(reward.value))
        else
            caption = quests.get_reward_localized_description(reward, "green", "heading-2", reward.value)
        end
        local reward_desc = reward_frame.add {
            type = "label",
            name = "desc",
            caption = caption,
        }
        reward_desc.style.single_line = false
        gui.auto_width(reward_desc)
        if reward.type == "unlock-feature" then
            local feature_desc = reward_frame.add {
                type = "label",
                name = "feature-desc",
                caption = lib.color_localized_string(quests.get_feature_localized_description(reward.value), "orange"),
            }
            feature_desc.style.single_line = false
            gui.auto_width(feature_desc)
        elseif reward.type == "receive-items" then
            local receive_items_flow = reward_frame.add {
                type = "flow",
                name = "receive-items-flow",
                direction = "horizontal",
            }
            gui.add_sprite_buttons(receive_items_flow, reward.value, "receive-items-", true)
        end
        if reward.notes then
            for j, note_name in ipairs(reward.notes) do
                gui.add_info(reward_frame, quests.get_localized_note(note_name), "info-" .. j)
            end
        end
    end

    -- Ensure that the selected index of the corresponding list is accurate to the displayed quest.
    for idx, item in ipairs(incomplete_list.items) do
        if item[1] == localized_quest_title[1] and incomplete_list.selected_index ~= idx then
            incomplete_list.selected_index = idx
            return
        end
    end
    for idx, item in ipairs(complete_list.items) do
        if item[1] == localized_quest_title[1] and complete_list.selected_index ~= idx then
            complete_list.selected_index = idx
            return
        end
    end
end

function gui.update_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then
        gui.init_trade_overview(player)
        frame = player.gui.screen["trade-overview"]
    end

    -- Ensure that all available planets are enabled
    local filter_frame = frame["filter-frame"]
    for surface_name, _ in pairs(storage.trade_overview.allowed_planet_filters) do
        filter_frame["left"]["planet-flow"][surface_name].enabled = game.get_surface(surface_name) ~= nil
    end

    filter_frame["right"]["max-inputs-flow"]["label"].caption = {"hextorio-gui.max-inputs", filter_frame["right"]["max-inputs-flow"]["slider"].slider_value}
    filter_frame["right"]["max-outputs-flow"]["label"].caption = {"hextorio-gui.max-outputs", filter_frame["right"]["max-outputs-flow"]["slider"].slider_value}

    gui.update_player_trade_overview_filters(player)
    local filter = gui.get_player_trade_overview_filter(player)

    local function intersection(trades_lookup1, trades_lookup2)
        local result = {}
        for trade_id, _ in pairs(trades_lookup1) do
            if trades_lookup2[trade_id] then
                result[trade_id] = true
            end
        end
        return result
    end

    local trades_set
    if filter.input_items then
        for _, item in pairs(filter.input_items) do
            if trades_set then
                trades_set = intersection(trades_set, trades.get_trades_by_input(item))
            else
                trades_set = trades.get_trades_by_input(item)
            end
        end
    end
    if filter.output_items then
        for _, item in pairs(filter.output_items) do
            if trades_set then
                trades_set = intersection(trades_set, trades.get_trades_by_output(item))
            else
                trades_set = trades.get_trades_by_output(item)
            end
        end
    end

    -- log("initial filter by inputs and outputs (" .. lib.tostring_trade_filter(filter) .. "):")
    -- At this point, trades_set is either nil or a lookup table that maps trade ids to boolean (true) values.
    if trades_set then
        -- log(lib.tostring_trades_array(trades.convert_boolean_lookup_to_array(trades_set)))

        -- Convert to lookup table mapping trade ids to trade objects.
        trades_set = trades.convert_boolean_lookup_to_trades_lookup(trades_set)

        -- log("converted trades list after initial filter:")
        -- log(lib.tostring_trades_array(trades.convert_trades_lookup_to_array(trades_set)))
    else
        -- log("no filter: using entire trade tree")
        trades_set = lib.shallow_copy(trades.get_trades_lookup())
    end

    local function filter_trade(trade)
        if trade.hex_core_state then
            if not trade.hex_core_state.hex_core or not trade.hex_core_state.hex_core.valid then
                return true
            end
        end
        if filter.planets and trade.surface_name then
            if not filter.planets[trade.surface_name] then
                return true
            end
        end
        if filter.show_claimed_only and trade.hex_core_state and not trade.hex_core_state.claimed then
            return true
        end
        if filter.exact_inputs_match then
            for _, input in pairs(trade.input_items) do
                if not filter.input_items_lookup[input.name] then
                    return true
                end
            end
        end
        if filter.exact_outputs_match then
            for _, output in pairs(trade.output_items) do
                if not filter.output_items_lookup[output.name] then
                    return true
                end
            end
        end
        if filter.num_item_bounds then
            local input_bounds = filter.num_item_bounds.inputs
            if input_bounds then
                local num_inputs = #trade.input_items
                if num_inputs < (input_bounds.min or 1) or num_inputs > (input_bounds.max or math.huge) then
                    return true
                end
            end
            local output_bounds = filter.num_item_bounds.outputs
            if output_bounds then
                local num_outputs = #trade.output_items
                if num_outputs < (output_bounds.min or 1) or num_outputs > (output_bounds.max or math.huge) then
                    return true
                end
            end
        end
        return false
    end

    -- At this point, trades_set cannot be nil and must be a lookup table that maps trade ids to trade objects.
    for _, trade in pairs(trades_set) do
        if filter_trade(trade) then
            trades_set[trade.id] = nil
        end
    end

    -- log("filtered trades:")
    -- log(lib.tostring_trades_array(trades.convert_trades_lookup_to_array(trades_set)))

    local trades_list = trades.convert_trades_lookup_to_array(trades_set)

    -- Sort trades
    local sort_func
    if filter.sorting and filter.sorting.method then
        if filter.sorting.method == "distance-from-spawn" then
            local distances = {}
            for _, trade in pairs(trades_list) do
                if trade.hex_core_state then
                    distances[trade.id] = axial.distance(trade.hex_core_state.position, {q=0, r=0})
                else
                    distances[trade.id] = 0
                end
            end
            sort_func = function(trade1, trade2)
                local a = distances[trade1.id]
                local b = distances[trade2.id]
                if a == b then
                    return #trade1.output_items < #trade2.output_items
                end
                return a < b
            end
        elseif filter.sorting.method == "distance-from-character" then
            if player.character then
                local transformation = terrain.get_surface_transformation(player.surface)
                local char_pos = axial.get_hex_containing(player.character.position, transformation.scale, transformation.rotation)
                local distances = {}
                for _, trade in pairs(trades_list) do
                    if trade.hex_core_state then
                        distances[trade.id] = axial.distance(trade.hex_core_state.position, char_pos)
                    else
                        distances[trade.id] = 0
                    end
                end
                sort_func = function(trade1, trade2)
                    local a = distances[trade1.id]
                    local b = distances[trade2.id]
                    if a == b then
                        return #trade1.output_items < #trade2.output_items
                    end
                    return a < b
                end
            end
        elseif filter.sorting.method == "num-inputs" then
            sort_func = function(trade1, trade2)
                local a = #trade1.input_items
                local b = #trade2.input_items
                if a == b then
                    return #trade1.output_items < #trade2.output_items
                end
                return a < b
            end
        elseif filter.sorting.method == "num-outputs" then
            sort_func = function(trade1, trade2)
                local a = #trade1.output_items
                local b = #trade2.output_items
                if a == b then
                    return #trade1.input_items < #trade2.input_items
                end
                return a < b
            end
        elseif filter.sorting.method == "productivity" then
            sort_func = function(trade1, trade2)
                local a = trades.get_productivity(trade1)
                local b = trades.get_productivity(trade2)
                if a == b then
                    return #trade1.output_items < #trade2.output_items
                end
                return a < b
            end
        elseif filter.sorting.method == "total-item-value" then
            sort_func = function(trade1, trade2)
                return trades.get_volume_of_trade(trade1.surface_name, trade1) < trades.get_volume_of_trade(trade2.surface_name, trade2)
            end
        end
    end

    if sort_func then
        local directed_sort_func = sort_func
        if not filter.sorting.ascending then
            directed_sort_func = function(a, b) return sort_func(b, a) end
        end
        table.sort(trades_list, directed_sort_func)
    end

    if filter.max_trades and filter.max_trades < math.huge then
        local to_show = {}
        for i = 1, filter.max_trades do
            to_show[i] = trades_list[i]
        end
        trades_list = to_show
    end

    storage.trade_overview.trades[player.name] = trades_list

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    gui.update_trades_scroll_pane(player, trade_table, trades_list, {
        show_toggle_trade = false,
        show_tag_creator = false,
        show_ping_button = false,
        show_add_to_filters = false,
        show_core_finder = true,
        show_productivity_bar = false,
        show_quality_bounds = false,
        quality_to_show = "normal",
        show_productivity_info = false,
        expanded = false,
    })
end

function gui.update_catalog(player)
    local frame = player.gui.screen["catalog"]
    if not frame then
        gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end

    local scroll_pane = frame["flow"]["catalog-frame"]["scroll-pane"]

    for _, tab in pairs(scroll_pane.children) do
        -- lib.log(tab.name)
        if tab.type == "table" then
            -- Count discovered items and achieved ranks for each surface
            local discovered_items = 0
            local achieved_ranks = {0, 0, 0, 0}

            local surface_name = tab.name:sub(7)
            for _, rank_flow in pairs(tab.children) do
                local item_name = rank_flow.name:sub(11)
                if trades.is_item_discovered(item_name) then
                    local rank = item_ranks.get_item_rank(item_name)
                    discovered_items = discovered_items + 1
                    for i = 1, rank - 1 do
                        achieved_ranks[i] = achieved_ranks[i] + 1
                    end
                    rank_flow["catalog-item"].sprite = "item/" .. item_name
                    rank_flow["catalog-item"].ignored_by_interaction = false
                    rank_flow["rank-stars"].sprite = gui.get_rank_sprite(item_name, rank)
                    rank_flow["rank-stars"].visible = true
                    gui.give_item_tooltip(player, surface_name, rank_flow["catalog-item"])
                else
                    rank_flow["catalog-item"].sprite = "utility/questionmark"
                    rank_flow["catalog-item"].ignored_by_interaction = true
                    rank_flow["rank-stars"].visible = false
                end
            end

            -- Update progress bars
            if #tab.children > 0 then
                local pb_discovery = scroll_pane["pb-discovery-" .. surface_name]
                pb_discovery.value = discovered_items / #tab.children
                pb_discovery.tooltip = {"hextorio-gui.items-discovered", discovered_items, #tab.children}

                for i = 2, 5 do
                    local pb_ranks = scroll_pane["progress-bar-flow-" .. surface_name]["pb-ranks-" .. i]
                    pb_ranks.value = achieved_ranks[i - 1] / #tab.children
                    pb_ranks.tooltip = lib.get_rank_img_str(i) .. " x" .. achieved_ranks[i - 1]
                end
            end
        end
    end

    local selection = gui.get_catalog_selection(player)
    gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

function gui.add_info(element, info_id, name)
    local info = element.add {
        type = "label",
        name = name,
        caption = gui.get_info_caption(info_id),
    }
    info.style.single_line = false
    gui.auto_width(info)
end

function gui.add_warning(element, info_id, name)
    local info = element.add {
        type = "label",
        name = name,
        caption = gui.get_warning_caption(info_id),
    }
    info.style.single_line = false
    gui.auto_width(info)
end

function gui.get_info_caption(info_id)
    return {"", "[color=117,218,251][img=virtual-signal.signal-info] ", info_id, "[.color]"}
end

function gui.get_warning_caption(info_id)
    return {"", "[color=255,255,64][img=utility.warning_icon] ", info_id, "[.color]"}
end

function gui.add_sprite_buttons(element, item_stacks, name_prefix, give_item_tooltips)
    if not name_prefix then name_prefix = "" end

    local player
    if give_item_tooltips then
        player = gui.get_player_from_element(element)
    end

    for i, item_stack in ipairs(item_stacks) do
        local sprite_button = element.add {
            type = "sprite-button",
            name = name_prefix .. item_stack.name,
            sprite = "item/" .. item_stack.name,
            number = item_stack.count,
            quality = item_stack.quality,
        }
        if give_item_tooltips then
            if player then
                gui.give_item_tooltip(player, player.surface.name, sprite_button)
            end
        end
    end
end

---@param player LuaPlayer
---@return string
function gui.get_player_current_quest_selected(player)
    if not storage.quests.players_quest_selected[player.name] then
        storage.quests.players_quest_selected[player.name] = "ground-zero"
    end
    return storage.quests.players_quest_selected[player.name]
end

---@param player LuaPlayer
---@param quest_name string
function gui.set_player_current_quest_selected(player, quest_name)
    storage.quests.players_quest_selected[player.name] = quest_name
end

function gui.update_catalog_inspect_frame(player)
    local frame = player.gui.screen["catalog"]
    if not frame then
        gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end

    local inspect_frame = frame["flow"]["inspect-frame"]

    gui.verify_catalog_storage(player)
    local selection = gui.get_catalog_selection(player)
    local rank_obj = item_ranks.get_rank_obj(selection.item_name)
    if not rank_obj then return end

    inspect_frame.clear()

    local rank_flow = inspect_frame.add {
        type = "flow",
        name = "rank-flow",
        direction = "horizontal",
    }

    rank_flow.style.natural_height = 32 / 1.2

    local rank_label1 = rank_flow.add {
        type = "label",
        name = "label1",
        caption = "[font=heading-1][img=item." .. selection.item_name .. "][.font]",
    }

    local left_half
    if rank_obj.rank == 1 then
        left_half = gui.get_bronze_sprite_half(selection.item_name)
    end
    local rank_label2 = rank_flow.add {
        type = "label",
        name = "label2",
        caption = "[font=heading-1]" .. lib.get_rank_img_str(rank_obj.rank, left_half) .. "[.font]",
    }
    rank_label2.style.left_margin = 73 / 1.2

    local rank_label3 = rank_flow.add {
        type = "label",
        name = "label3",
        caption = "[font=heading-1][img=item." .. selection.item_name .. "][.font]",
    }
    rank_label3.style.left_margin = 73 / 1.2

    inspect_frame.add {type = "line", direction = "horizontal"}

    local control_flow = inspect_frame.add {
        type = "flow",
        name = "control-flow",
        direction = "horizontal",
    }

    local show_buffs = quests.is_feature_unlocked("item-buffs")

    local tooltip = {"hextorio-gui.obfuscated-text"}
    if show_buffs then
        tooltip = {"hextorio-gui.item-buff-enhance-all-tooltip"}
    end
    local item_buff_enhance_all = control_flow.add {
        type = "sprite-button",
        name = "item-buff-enhance-all",
        sprite = "item-buff-enhance-all",
        tooltip = tooltip,
    }
    item_buff_enhance_all.enabled = show_buffs

    local open_in_factoriopedia = control_flow.add {
        type = "sprite-button",
        name = "open-in-factoriopedia",
        sprite = "utility/side_menu_factoriopedia_icon",
        tooltip = {"hextorio-gui.open-in-factoriopedia"},
    }

    -- Display only discovered items so that the player can view them in the catalog.
    local elem_filter_names = {}
    for _, name in pairs(item_ranks.get_items_at_rank(1)) do
        if trades.is_item_discovered(name) then
            table.insert(elem_filter_names, name)
        end
    end
    local elem_filters = {{filter = "name", name = elem_filter_names}}

    local selected_item_view = control_flow.add {
        type = "choose-elem-button",
        name = "selected-item-view",
        elem_type = "item",
        elem_filters = elem_filters,
        item = selection.item_name,
    }

    inspect_frame.add {type = "line", direction = "horizontal"}

    local bonuses_label = inspect_frame.add {
        type = "label",
        name = "bonuses-label",
        caption = {"hextorio-gui.bonuses"},
    }
    bonuses_label.style.font = "heading-2"

    local buffs = item_buffs.get_buffs(selection.item_name)
    if show_buffs and rank_obj.rank >= 2 and next(buffs) then
        item_buffs.fetch_settings()

        local item_buff_flow = inspect_frame.add {
            type = "flow",
            name = "item-buff-flow",
            direction = "horizontal",
        }

        local is_buff_unlocked = item_buffs.is_unlocked(selection.item_name)
        local item_buff_level = item_buffs.get_item_buff_level(selection.item_name)
        local cost = item_buffs.get_item_buff_cost(selection.item_name)

        local buff_button_type = "item-buff-unlock"
        local buff_button_sprite = buff_button_type
        if is_buff_unlocked then
            buff_button_type = "item-buff-enhance"
            buff_button_sprite = "utility/side_menu_bonus_icon"
        end

        local buff_button = item_buff_flow.add {
            type = "sprite-button",
            name = buff_button_type,
            sprite = buff_button_sprite,
        }
        -- buff_button.tooltip = {"hextorio-gui." .. buff_button_type .. "-tooltip", coin_tiers.coin_to_text(cost)}
        buff_button.tooltip = {"hextorio-gui." .. buff_button_type .. "-tooltip"}

        local coin_tier_flow = gui.create_coin_tier(item_buff_flow, "cost")
        gui.update_coin_tier(coin_tier_flow, cost)

        local buff_table = inspect_frame.add {
            type = "table",
            name = "buff-table",
            column_count = 2,
        }

        local function format_buff_values(buff)
            local values = item_buffs.get_scaled_buff_values(buff, item_buff_level)
            local incremental_buff = item_buffs.get_incremental_buff(buff, item_buff_level)

            if not values then
                lib.log_error("gui.update_catalog_inspect_frame.format_buff_values: Failed to format buff values for " .. selection.item_name)
                return {"", ""}
            end

            if #values == 1 then
                if storage.item_buffs.show_as_linear[buff.type] then
                    return {"", "[color=green]+" .. (math.floor(values[1] * 10 + 0.5) * 0.1) .. "[.color] [color=gray](+" .. (math.floor((incremental_buff.value or incremental_buff.values[1]) * 100 + 0.5) * 0.01) .. ")[.color]"}
                end
                return {"", "[color=green]" .. lib.format_percentage(values[1], 1, true, true) .. "[.color] [color=gray](" .. lib.format_percentage(incremental_buff.value or incremental_buff.values[1], 2, true, true) .. ")[.color]"}
            end

            if buff.type == "recipe-productivity" then
                return {"", "[color=green]" .. lib.format_percentage(values[2] * 0.01, 1, true, true) .. "[.color] [color=gray](" .. lib.format_percentage(incremental_buff.values[2] * 0.01, 2, true, true) .. ")[.color]"}
            end

            for i, v in pairs(values) do
                if type(v) == "number" then
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    values[i] = "[color=green]" .. v .. "[.color] [color=gray](" .. lib.format_percentage(incremental_buff.values[i], 2, true, true) .. ")[.color]"
                end
            end

            return {"item-buff-name." .. buff.type, table.unpack(values)}
        end

        for i, buff in ipairs(buffs) do
            if buff.value or buff.type == "recipe-productivity" then
                local label_caption = lib.color_localized_string({"hextorio-gui.obfuscated-text"}, "gray", "heading-2")
                local value_caption = lib.color_localized_string({"hextorio-gui.obfuscated-text"}, "gray")

                if is_buff_unlocked then
                    if buff.type == "recipe-productivity" then
                        label_caption = lib.color_localized_string({"item-buff-name." .. buff.type, "[recipe=" .. buff.values[1] .. "]"}, "white", "heading-2")
                    else
                        label_caption = lib.color_localized_string({"item-buff-name." .. buff.type}, "white", "heading-2")
                    end
                    if storage.item_buffs.has_description[buff.type] then
                        table.insert(label_caption, 2, "[img=virtual-signal.signal-info] ")
                    end
                    value_caption = format_buff_values(buff)
                end

                local buff_label = buff_table.add {
                    type = "label",
                    name = "buff-label-" .. i,
                    caption = label_caption,
                }
                local buff_value = buff_table.add {
                    type = "label",
                    name = "buff-value-" .. i,
                    caption = value_caption,
                }

                if is_buff_unlocked and storage.item_buffs.has_description[buff.type] then
                    buff_label.tooltip = {"item-buff-description." .. buff.type}
                end
            elseif buff.values then
                local caption = lib.color_localized_string({"hextorio-gui.obfuscated-text"}, "gray")

                if is_buff_unlocked then
                    caption = format_buff_values(buff)
                end

                local buff_label = inspect_frame.add {
                    type = "label",
                    name = "buff-label-" .. i,
                    caption = caption,
                }
            end
        end
    end

    if rank_obj.rank > 1 then
        local bonus_productivity = inspect_frame.add {
            type = "label",
            name = "bonus-productivity",
            caption = {"", lib.color_localized_string({"hextorio-gui.main-bonus"}, "blue", "heading-2"), "\n", {"hextorio-gui.rank-bonus-trade-productivity", math.floor(100 * item_ranks.get_rank_bonus_effect(rank_obj.rank)), "green", "heading-2"}},
        }
        bonus_productivity.style.single_line = false
        gui.auto_width_height(bonus_productivity)
    else
        local none_label = inspect_frame.add {
            type = "label",
            name = "none",
            caption = {"hextorio-gui.rank-bonus-none"},
        }
        none_label.style.single_line = false
        gui.auto_width_height(none_label)
    end

    for i = 2, rank_obj.rank do
        local color_text = table.concat(storage.item_ranks.rank_colors[i], ",")
        local color_rich_text = "[color=" .. color_text .. "]"
        local rank_bonus_unique_heading = inspect_frame.add {
            type = "label",
            name = "rank-bonus-unique-heading-" .. i,
            caption = lib.color_localized_string({"", "[img=" .. storage.item_ranks.rank_star_sprites[i] .. "] ", {"hextorio-gui.unique-bonus"}}, color_rich_text, "heading-2"),
        }

        local caption
        if i == 2 then
            caption = {"", {"hextorio-gui.rank-bonus-unique-" .. i, lib.format_percentage(lib.runtime_setting_value("rank-" .. i .. "-effect"), 1, false), color_text, "heading-2", selection.item_name}}
        elseif i == 3 then
            local planets_text = {""}
            for surface_name, _ in pairs(storage.item_values.values) do
                if item_values.is_item_interplanetary(surface_name, selection.item_name) then
                    table.insert(planets_text, "[planet=" .. surface_name .. "]")
                end
            end
            if #planets_text == 1 then
                planets_text = lib.color_localized_string({"hextorio-gui.none-yet-visited"}, "gray")
            end
            caption = {"", {"hextorio-gui.rank-bonus-unique-" .. i, lib.runtime_setting_value("rank-" .. i .. "-effect"), planets_text, color_text, "heading-2"}}
        else
            caption = {"", {"hextorio-gui.rank-bonus-unique-" .. i}}
        end

        local rank_bonus_unique = inspect_frame.add {
            type = "label",
            name = "rank-bonus-unique-" .. i,
            caption = caption,
        }

        rank_bonus_unique.style.single_line = false
        gui.auto_width(rank_bonus_unique)
    end

    if rank_obj.rank < 5 then
        inspect_frame.add {type = "line", direction = "horizontal"}

        local rank_up_localized_str = {"hextorio-gui.rank-up-instructions-" .. rank_obj.rank}

        if rank_obj.rank == 1 then
            if trades.get_total_bought(selection.item_name) > 0 then
                table.insert(rank_up_localized_str, "[img=virtual-signal.signal-check]")
            else
                table.insert(rank_up_localized_str, "[img=virtual-signal.signal-deny]")
            end
            if trades.get_total_sold(selection.item_name) > 0 then
                table.insert(rank_up_localized_str, "[img=virtual-signal.signal-check]")
            else
                table.insert(rank_up_localized_str, "[img=virtual-signal.signal-deny]")
            end
        elseif rank_obj.rank == 2 then
            table.insert(rank_up_localized_str, "+10") -- TODO: make these numbers a setting or auto-calculated based on intention of challenge
            table.insert(rank_up_localized_str, "green")
            table.insert(rank_up_localized_str, "heading-2")
        elseif rank_obj.rank == 3 then
            table.insert(rank_up_localized_str, "+70")
            table.insert(rank_up_localized_str, "green")
            table.insert(rank_up_localized_str, "heading-2")
        elseif rank_obj.rank == 4 then
            table.insert(rank_up_localized_str, "+110")
            table.insert(rank_up_localized_str, "green")
            table.insert(rank_up_localized_str, "heading-2")
        end

        local rank_up_instructions = inspect_frame.add {
            type = "label",
            name = "rank-up-instructions",
            caption = {"", lib.get_rank_img_str(rank_obj.rank + 1) .. "\n", rank_up_localized_str},
        }
        rank_up_instructions.style.single_line = false
        gui.auto_width_height(rank_up_instructions)
    end

    if rank_obj.rank == 1 then
        gui.add_info(inspect_frame, {"hextorio-gui.buying-info"}, "info-buying")
        gui.add_info(inspect_frame, {"hextorio-gui.selling-info"}, "info-selling")
    -- elseif rank_obj.rank == 2 or rank_obj.rank == 3 then
    --     gui.add_info(inspect_frame, {"hextorio-gui.higher-qualities-count"}, "info-qualities")
    end

    if rank_obj.rank == 5 then
        inspect_frame.add {type = "line", direction = "horizontal"}
        local quantum_bazaar_header = inspect_frame.add {
            type = "label",
            name = "quantum-bazaar-header",
            caption = lib.color_localized_string({"hextorio-gui.quantum-bazaar"}, "[color=180,255,0]", "heading-1"),
        }
        local quantum_bazaar = inspect_frame.add {
            type = "flow",
            name = "quantum-bazaar",
            direction = "horizontal",
        }
        local left_flow = quantum_bazaar.add {
            type = "flow",
            name = "left",
            direction = "vertical",
        }

        quantum_bazaar.add {type = "line", direction = "vertical"}

        local right_flow = quantum_bazaar.add {
            type = "table",
            name = "right",
            column_count = 2,
        }

        local quality_dropdown = gui.create_quality_dropdown(left_flow, "quality-dropdown", lib.get_quality_tier(selection.bazaar_quality))
        gui.auto_width(quality_dropdown)

        local coin_tier = gui.create_coin_tier(left_flow, "coin-tier")
        local buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality) / item_values.get_item_value("nauvis", "hex-coin"))

        local stack_size = lib.get_stack_size(selection.item_name)
        local buy_stack_coin = coin_tiers.ceil(coin_tiers.multiply(buy_one_coin, stack_size))
        local sell_inv_coin = inventories.get_total_coin_value(player.character.surface.name, lib.get_player_inventory(player), 5)

        buy_one_coin = coin_tiers.ceil(buy_one_coin)
        gui.update_coin_tier(coin_tier, buy_one_coin)

        local sell_in_hand = right_flow.add {
            type = "sprite-button",
            name = "sell-in-hand",
            sprite = "hand",
        }
        sell_in_hand.tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.sell-in-hand-header"}, "green", "heading-2"),
            "\n",
            {"quantum-bazaar.sell-in-hand-info"},
        }

        local sell_inventory = right_flow.add {
            type = "sprite-button",
            name = "sell-inventory",
            sprite = "backpack",
        }
        sell_inventory.tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.sell-inventory-header"}, "yellow", "heading-2"),
            "\n",
            {"quantum-bazaar.sell-inventory-info", coin_tiers.coin_to_text(sell_inv_coin)},
        }

        local buy_one = right_flow.add {
            type = "sprite-button",
            name = "buy-one",
            sprite = "stack-one",
        }
        buy_one.tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.buy-one", "[item=" .. selection.item_name .. ",quality=" .. selection.bazaar_quality .. "]", coin_tiers.coin_to_text(buy_one_coin)}, "cyan"),
        }

        local buy_stack = right_flow.add {
            type = "sprite-button",
            name = "buy-stack",
            sprite = "stack-full",
        }
        buy_stack.tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.buy-stack", "[item=" .. selection.item_name .. ",quality=" .. selection.bazaar_quality .. "]", stack_size, coin_tiers.coin_to_text(buy_stack_coin)}, "purple"),
        }

        local elem_filter_items = sets.new()
        for _, surface in pairs(game.surfaces) do
            if not lib.is_space_platform(surface.name) then
                local values = item_values.get_expanded_item_values_for_surface(surface.name)
                for name, _ in pairs(values) do
                    if lib.is_catalog_item(name) and item_ranks.get_item_rank(name) >= 5 then
                        sets.add(elem_filter_items, name)
                    end
                end
            end
        end
        local elem_filters = {}
        for name, _ in pairs(elem_filter_items) do
            table.insert(elem_filters, {filter = "name", name = name})
        end

        local selected_item_qb = right_flow.add {
            type = "choose-elem-button",
            name = "selected-item-qb",
            elem_type = "item",
            elem_filters = elem_filters,
            item = selection.item_name,
        }
    end
end

function gui.update_quest_lists(player, quest)
    local scroll_pane = player.gui.screen["questbook"]["lower-flow"]["list-frame"]["scroll-pane"]
    local incomplete_list = scroll_pane["incomplete-list"]
    local complete_list = scroll_pane["complete-list"]

    if quest and quest.complete then
        gui.add_quest_to_list(complete_list, quest)
    end

    incomplete_list.clear_items()
    for _, q in pairs(storage.quests.quests) do
        if q.revealed and not q.complete then
            gui.add_quest_to_list(incomplete_list, q)
        end
    end
end

---Repopulate a player's quest lists.  O(nlogn) time complexity.
---@param player LuaPlayer
function gui.repopulate_quest_lists(player)
    local scroll_pane = player.gui.screen["questbook"]["lower-flow"]["list-frame"]["scroll-pane"]
    local incomplete_list = scroll_pane["incomplete-list"]
    local complete_list = scroll_pane["complete-list"]

    complete_list.clear_items()
    incomplete_list.clear_items()

    for _, q in pairs(storage.quests.quests) do
        if quests.is_revealed(q) then
            if quests.is_complete(q) then
                gui.add_quest_to_list(complete_list, q)
            else
                gui.add_quest_to_list(incomplete_list, q)
            end
        end
    end
end

function gui.add_quest_to_list(list, quest)
    local name = quests.get_quest_localized_title(quest)
    for _, item in pairs(list.items) do
        if item[1] == name[1] then
            return
        end
    end

    -- Binary search to insert in order
    local left = 1
    local right = #list.items
    local quest_order = quest.order
    while left <= right do
        local mid = math.floor((left + right) / 2)
        if mid > 0 then
            local mid_quest = gui.get_quest_from_list_item(list.get_item(mid))
            if mid_quest and mid_quest.order < quest_order then
                left = mid + 1
            else
                right = mid - 1
            end
        else
            break
        end
    end
    idx = left

    list.add_item(name, idx)
end

function gui.get_quest_from_list_item(item)
    local quest_name = item[1]:sub(13)
    return quests.get_quest_from_name(quest_name)
end

function gui.get_current_selected_quest(player)
    local scroll_pane = player.gui.screen["questbook"]["lower-flow"]["list-frame"]["scroll-pane"]
    local incomplete_list = scroll_pane["incomplete-list"]
    local complete_list = scroll_pane["complete-list"]

    local list

    if incomplete_list.selected_index > 0 then
        list = incomplete_list
    elseif complete_list.selected_index > 0 then
        list = complete_list
    end

    if not list then return end

    return gui.get_quest_from_list_item(list.get_item(list.selected_index))
end

function gui.update_coin_tier(flow, coin)
    -- Don't show leading zeroes, but show intermediate zeroes, and always show hex coin even if total cost is zero.
    -- local hex_coin_sprite = flow['hex-coin']
    -- hex_coin_sprite.number = coin.values[1]

    -- local visible = false
    -- if coin.values[4] > 0 then visible = true end
    -- local hexaprism_coin_sprite = flow['hexaprism-coin']
    -- hexaprism_coin_sprite.number = coin.values[4]
    -- hexaprism_coin_sprite.visible = visible

    -- if coin.values[3] > 0 then visible = true end
    -- local meteor_coin_sprite = flow['meteor-coin']
    -- meteor_coin_sprite.number = coin.values[3]
    -- meteor_coin_sprite.visible = visible

    -- if coin.values[2] > 0 then visible = true end
    -- local gravity_coin_sprite = flow['gravity-coin']
    -- gravity_coin_sprite.number = coin.values[2]
    -- gravity_coin_sprite.visible = visible

    -- Don't show any zeros unless it's a total of zero coins.
    local coin_names = {"hex-coin", "gravity-coin", "meteor-coin", "hexaprism-coin"}
    for i = 1, 4 do
        local coin_sprite = flow[coin_names[i]]
        if coin.values[i] > 0 then
            coin_sprite.number = coin.values[i]
            coin_sprite.visible = true
            gui.try_give_coin_tooltip(coin_sprite)
        else
            coin_sprite.visible = false
        end
    end

    if coin_tiers.is_zero(coin) then
        flow['hex-coin'].visible = true
        flow['hex-coin'].number = 0
    end
end

function gui.create_coin_tier(parent, name)
    local flow = parent.add {type = "flow", direction = "horizontal"}
    flow.style.horizontal_spacing = 8
    flow.name = name or "coins"

    local hex_coin_sprite = flow.add {type = "sprite-button", sprite = "hex-coin"}
    hex_coin_sprite.name = "hex-coin"
    hex_coin_sprite.style.width = 40
    hex_coin_sprite.style.height = 40
    hex_coin_sprite.number = 1

    local gravity_coin_sprite = flow.add {type = "sprite-button", sprite = "gravity-coin"}
    gravity_coin_sprite.name = "gravity-coin"
    gravity_coin_sprite.style.width = 40
    gravity_coin_sprite.style.height = 40
    gravity_coin_sprite.number = 0

    local meteor_coin_sprite = flow.add {type = "sprite-button", sprite = "meteor-coin"}
    meteor_coin_sprite.name = "meteor-coin"
    meteor_coin_sprite.style.width = 40
    meteor_coin_sprite.style.height = 40
    meteor_coin_sprite.number = 0

    local hexaprism_coin_sprite = flow.add {type = "sprite-button", sprite = "hexaprism-coin"}
    hexaprism_coin_sprite.name = "hexaprism-coin"
    hexaprism_coin_sprite.style.width = 40
    hexaprism_coin_sprite.style.height = 40
    hexaprism_coin_sprite.number = 0

    return flow
end

function gui.create_quality_dropdown(parent, name, selected_index)
    local quality_locales = {}
    for quality_name, _ in pairs(prototypes.quality) do
        if quality_name ~= "quality-unknown" then
            table.insert(quality_locales, {"", "[img=quality." .. quality_name .. "] ", {"quality-name." .. quality_name}})
        end
    end

    return parent.add {type = "drop-down", name = name or "quality-dropdown", items = quality_locales, selected_index = selected_index or 1}
end

function gui.on_gui_switch_state_changed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.element.name == "sort-direction" then
        gui.on_trade_sort_direction_changed(player, event.element)
    end
end

function gui.on_gui_click(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.element.name == "claim-hex" then
        gui.on_claim_hex_button_click(player)
    elseif event.element.name == "questbook-button" then
        gui.on_questbook_button_click(player)
    elseif event.element.name == "trade-overview-button" then
        gui.on_trade_overview_button_click(player)
    elseif event.element.name == "catalog-button" then
        gui.on_catalog_button_click(player)
    elseif event.element.type == "sprite-button" then
        gui.on_sprite_button_click(player, event.element)
    elseif event.element.type == "button" then
        gui.on_button_click(player, event.element)
    elseif event.element.type == "checkbox" then
        gui.on_checkbox_click(player, event.element)
    end
end

function gui.on_ping_button_clicked(player, element)
    -- if gui.is_descendant_of(element, "trade-contents-flow") then
    --     gui.swap_trade_overview_content_filters(player)
    --     return
    -- end

    local trade, gps_str
    if gui.is_descendant_of(element, "trade-overview") then
        if not storage.trade_overview.trades[player.name] then return end

        local trade_number = tonumber(element.parent.parent.parent.name:sub(7))
        trade = storage.trade_overview.trades[player.name][trade_number]
        if not trade then return end
        if not trade.hex_core_state then return end
        gps_str = lib.get_gps_str_from_hex_core(trade.hex_core_state.hex_core)
    else
        -- it's in the hex core GUI
        local hex_core = lib.get_player_opened_entity(player)
        if not hex_core then return end

        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end

        local trade_number = tonumber(element.parent.parent.parent.name:sub(7))
        trade = trades.get_trade_from_id(state.trades[trade_number])
        if not trade then return end

        gps_str = hex_core.gps_tag
    end

    local trade_str = lib.get_trade_img_str(trade, trades.is_interplanetary_trade(trade))
    game.print({"hextorio.player-trade-ping", player.name, trade_str, gps_str})

    quests.set_progress_for_type("ping-trade", 1)
end

function gui.on_button_click(player, element)
    if element.name == "clear-filters-button" then
        gui.on_clear_filters_button_click(player, element)
    elseif element.name == "debug-complete-quest" then
        gui.on_debug_complete_quest_button_click(player, element)
    elseif element.name == "export-json" then
        gui.on_export_json_button_click(player, element)
    end
end

function gui.on_debug_complete_quest_button_click(player, element)
    local quest_name = gui.get_player_current_quest_selected(player)
    if not quest_name then return end
    local quest = quests.get_quest_from_name(quest_name)
    if not quest then return end
    quests.complete_quest(quest)
end

function gui.on_checkbox_click(player, element)
    if element.parent.name == "show-only-claimed" or element.parent.name == "exact-inputs-match" or element.parent.name == "exact-outputs-match" then
        gui.on_trade_overview_filter_changed(player)
    end
end

function gui.on_gui_item_selected(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.element.type == "list-box" then
        gui.on_listbox_item_selected(player, event.element)
    else
        gui.on_dropdown_item_selected(player, event.element)
    end
end

function gui.on_trade_sort_direction_changed(player, element)
    gui.on_trade_overview_filter_changed(player)
end

function gui.on_listbox_item_selected(player, element)
    if element.name == "complete-list" or element.name == "incomplete-list" then
        gui.on_quest_name_selected(player, element)
    end
end

function gui.on_dropdown_item_selected(player, element)
    if element.parent.name == "sort-method" then
        gui.on_trade_overview_filter_changed(player)
    elseif element.parent.name == "max-trades-flow" then
        gui.on_trade_overview_filter_changed(player)
    elseif element.name == "quality-dropdown" then
        gui.on_quality_dropdown_selected(player, element)
    end
end

function gui.on_quality_dropdown_selected(player, element)
    if gui.is_descendant_of(element, "hex-core") then
        gui.update_hex_core(player)
    elseif gui.is_descendant_of(element, "catalog") then
        gui.on_quantum_bazaar_changed(player, element)
    end
end

function gui.on_quantum_bazaar_changed(player, element)
    local selection = gui.get_catalog_selection(player)
    if element.name == "quality-dropdown" then
        selection.bazaar_quality = gui.get_quality_name_from_dropdown(element)
    elseif element.name == "selected-item-qb" then
        selection.item_name = element.elem_value or selection.last_qb_item_selected or "stone"
    end
    gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

function gui.on_catalog_search_item_selected(player, element)
    local selection = gui.get_catalog_selection(player)
    selection.item_name = element.elem_value or selection.last_item_selected or "stone"
    gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

function gui.on_quest_name_selected(player, element)
    if element.selected_index == 0 then return end

    -- First, ensure that only one quest is selected between the two list boxes.
    if element.name == "complete-list" then
        element.parent['incomplete-list'].selected_index = 0
    elseif element.name == "incomplete-list" then
        element.parent['complete-list'].selected_index = 0
    end

    local quest = gui.get_current_selected_quest(player)
    if not quest then return end

    gui.set_player_current_quest_selected(player, quest.name)
    gui.update_questbook(player)
end

function gui.on_toggle_trade_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_serial = tonumber(element.name:sub(14)) -- The location in the hex's trades listing
    local trade_id = state.trades[trade_serial] -- The global identifier of the trade
    if not trade_id then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    trades.set_trade_active(trade, not trades.is_active(trade))
    gui.update_hex_core(player)
end

function gui.on_sprite_button_click(player, element)
    -- ALL of this is EXTREMELY ugly and hard to manage, I will have to clean it up later and utilize a "handler" type of structure, probably using my event_system or implementing a new system for registering callbacks during GUI initialization.
    if element.name == "catalog-item" then
        gui.on_catalog_item_click(player, element)
    elseif element.name == "frame-close-button" then
        gui.on_frame_close_button_click(player, element)
    elseif element.name:sub(1, 10) == "tag-button" then
        gui.on_tag_button_click(player, element)
    elseif element.name:sub(1, 18) == "core-finder-button" then
        gui.on_core_finder_button_click(player, element)
    elseif element.name == "ping-button" then
        gui.on_ping_button_clicked(player, element)
    elseif element.name == "teleport" then
        gui.on_teleport_button_click(player, element)
    elseif element.name == "toggle-hexport" then
        gui.on_toggle_hexport_button_click(player, element)
    elseif element.name == "supercharge" then
        gui.on_supercharge_button_click(player, element)
    elseif element.name == "delete-core" then
        gui.on_delete_core_button_click(player, element)
    elseif element.name == "convert-resources" then
        gui.on_convert_resources_button_click(player, element)
    elseif element.name == "confirmation-button" then
        gui.on_confirmation_button_click(player, element)
    elseif element.name:sub(-18) == "-mode-confirmation" then
        gui.on_hex_mode_confirmation_button_click(player, element)
    elseif element.name == "item-buff-unlock" or element.name == "item-buff-enhance" then
        gui.on_item_buff_button_click(player, element)
    elseif element.name == "item-buff-enhance-all" then
        gui.on_item_buff_all_button_click(player, element)
    elseif element.name == "upgrade-quality" then
        gui.on_upgrade_quality_button_click(player, element)
    else
        if element.parent then
            -- if element.parent.name == "unloader-filters-flow" then
                -- gui.on_unloader_filters_direction_click(player, element)
            if element.name:sub(-5) == "-mode" and element.parent.name == "hex-control-flow" then
                gui.on_hex_mode_button_click(player, element)
            elseif gui.is_descendant_of(element, "trade-overview") and element.parent.name == "trade-table" then
                gui.on_trade_overview_item_clicked(player, element)
            elseif gui.is_descendant_of(element, "hex-core") and element.parent.name ~= "hex-control-flow" then
                if element.parent.name == "trade-control-flow" then
                    gui.on_hex_core_trade_control_flow_button_clicked(player, element)
                else
                    gui.on_hex_core_trade_item_clicked(player, element)
                end
            elseif gui.is_descendant_of(element, "catalog") and element.parent.name == "control-flow" then
                gui.on_catalog_control_button_clicked(player, element)
            elseif gui.is_descendant_of(element, "quantum-bazaar") then
                gui.on_quantum_bazaar_button_clicked(player, element)
            else
                if element.parent.name == "planet-flow" then
                    element.toggled = not element.toggled
                    gui.on_trade_overview_filter_changed(player)
                end
            end
        end
    end
end

function gui.on_convert_resources_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_convert_resources_cost(hex_core)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    coin_tiers.remove_coin_from_inventory(inv, coin)

    hex_grid.convert_resources(hex_core)
    gui.update_hex_core(player)
end

function gui.on_catalog_control_button_clicked(player, element)
    local selection = gui.get_catalog_selection(player)
    if element.name == "open-in-factoriopedia" then
        gui.close_all(player)
        lib.open_factoriopedia_gui(player, selection.item_name)
    end
end

function gui.on_quantum_bazaar_button_clicked(player, element)
    if element.name == "sell-in-hand" then
        local item_stack = player.cursor_stack
        if not item_stack then
            player.print(lib.color_localized_string({"hextorio.no-item-in-hand"}, "red"))
            return
        end

        if item_ranks.get_item_rank(item_stack.name) < 5 then
            player.print(lib.color_localized_string({"hextorio.item-rank-too-low"}, "red"))
            return
        end

        local inv = player.get_main_inventory()
        if not inv then return end

        local item_value = item_values.get_item_value(player.character.surface.name, item_stack.name, true, item_stack.quality.name) * item_stack.count
        local received_coin = coin_tiers.ceil(coin_tiers.from_base_value(item_value / item_values.get_item_value("nauvis", "hex-coin")))

        coin_tiers.add_coin_to_inventory(inv, received_coin)
        item_stack.clear()
    elseif element.name == "sell-inventory" then
        local inv = player.get_main_inventory()
        if not inv then return end

        local received_coin = coin_tiers.ceil(inventories.get_total_coin_value(player.character.surface.name, inv, 5))
        inventories.remove_items_of_rank(inv, 5)
        coin_tiers.add_coin_to_inventory(inv, received_coin)
    elseif element.name == "buy-one" or element.name == "buy-stack" then
        local inv = player.get_main_inventory()
        if not inv then return end

        local selection = gui.get_catalog_selection(player)
        local count = 1
        if element.name == "buy-stack" then
            count = lib.get_stack_size(selection.item_name)
        end

        local item_value = item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality)
        local coin = coin_tiers.ceil(coin_tiers.from_base_value(item_value * count / item_values.get_item_value("nauvis", "hex-coin")))
        local inv_coin = coin_tiers.get_coin_from_inventory(inv)
        if coin_tiers.gt(coin, inv_coin) then
            player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
            return
        end

        coin_tiers.remove_coin_from_inventory(inv, coin)
        lib.safe_insert(player, {name = selection.item_name, count = count, quality = selection.bazaar_quality})
    end

    gui.update_catalog_inspect_frame(player)
end

function gui.on_upgrade_quality_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_quality_upgrade_cost(hex_core)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    coin_tiers.remove_coin_from_inventory(inv, coin)

    hex_grid.upgrade_quality(hex_core)
    gui.update_hex_core(player)
end

function gui.on_supercharge_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    if state.is_infinite then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_supercharge_cost(hex_core)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    coin_tiers.remove_coin_from_inventory(inv, coin)

    hex_grid.supercharge_resources(hex_core)
    gui.update_hex_core(player)
end

function gui.on_trade_overview_item_clicked(player, element)
    local item_name = element.sprite:sub(6)
    if element.name:sub(1, 5) == "input" then
        gui.set_trade_overview_item_filters(player, {}, {item_name})
    else
        gui.set_trade_overview_item_filters(player, {item_name}, {})
    end
end

function gui.set_trade_overview_item_filters(player, input_items, output_items)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local trade_contents_frame = frame["filter-frame"]["left"]["trade-contents-flow"]["frame"]

    for i = 1, 3 do
        local button = trade_contents_frame["input-item-" .. i]
        button.elem_value = input_items[i]
    end

    for i = 1, 3 do
        local button = trade_contents_frame["output-item-" .. i]
        button.elem_value = output_items[i]
    end

    gui.update_trade_overview(player)
end

function gui.on_hex_core_trade_control_flow_button_clicked(player, element)
    if element.name:sub(1, 13) == "toggle-trade-" then
        gui.on_toggle_trade_button_click(player, element)
    elseif element.name:sub(1, 15) == "add-to-filters-" then
        gui.on_add_to_filters_button_click(player, element)
    end
end

function gui.on_add_to_filters_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_number = tonumber(element.name:sub(16))
    local trade_id = state.trades[trade_number]
    if not trade_id then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    local _, output_item_names = trades.get_input_output_item_names_of_trade(trade)
    hex_grid.add_items_to_unloader_filters(state, output_item_names)
end

function gui.on_hex_core_trade_item_clicked(player, element)
    if not quests.is_feature_unlocked "catalog" then return end

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local item_name = element.sprite:sub(6)

    gui.close_all(player)
    gui.show_catalog(player)
    gui.set_catalog_selection(player, hex_core.surface.name, item_name, "normal")
end

function gui.on_hex_mode_button_click(player, element)
    local mode = element.name:sub(1, -6)
    element.parent.parent[mode .. "-mode-confirmation"].visible = true
end

function gui.on_hex_mode_confirmation_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local mode = element.name:sub(1, -19)
    local succeeded = hex_grid.switch_hex_core_mode(state, mode)

    if succeeded then
        for _, elem in pairs(element.parent.children) do
            if elem.name:sub(-5) == "-mode" then
                elem.visible = false
            end
        end

        gui.update_hex_core(player)
    end
end

function gui.on_clear_filters_button_click(player, element)
    local filter_frame = element.parent.parent.parent
    for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
        planet_button.toggled = true
    end

    for i = 1, 3 do
        filter_frame["left"]["trade-contents-flow"]["frame"]["input-item-" .. i].elem_value = nil
    end

    for i = 1, 3 do
        filter_frame["left"]["trade-contents-flow"]["frame"]["output-item-" .. i].elem_value = nil
    end

    filter_frame["right"]["show-only-claimed"]["checkbox"].state = false
    filter_frame["right"]["exact-inputs-match"]["checkbox"].state = false
    filter_frame["right"]["exact-outputs-match"]["checkbox"].state = false
    filter_frame["right"]["max-inputs-flow"]["slider"].slider_value = filter_frame["right"]["max-inputs-flow"]["slider"].get_slider_maximum()
    filter_frame["right"]["max-outputs-flow"]["slider"].slider_value = filter_frame["right"]["max-outputs-flow"]["slider"].get_slider_maximum()
    -- filter_frame["right"]["max-trades-flow"]["dropdown"].selected_index = #filter_frame["right"]["max-trades-flow"]["dropdown"].items

    gui.on_trade_overview_filter_changed(player)
end

function gui.on_export_json_button_click(player, element)
    local seen_items = {nauvis = {}, vulcanus = {}, fulgora = {}, gleba = {}, aquilo = {}}
    local item_value_lookup = {nauvis = {}, vulcanus = {}, fulgora = {}, gleba = {}, aquilo = {}}
    local formatted_trades = {nauvis = {}, vulcanus = {}, fulgora = {}, gleba = {}, aquilo = {}}

    for _, trade in pairs(trades.get_all_trades(true)) do
        local transformation = terrain.get_surface_transformation(trade.surface_name)
        local hex_core = trade.hex_core_state.hex_core
        local quality = "normal"
        if hex_core and hex_core.valid then
            quality = hex_core.quality.name
        end
        table.insert(formatted_trades[trade.surface_name], {
            axial_pos = trade.hex_core_state.position,
            rect_pos = axial.get_hex_center(trade.hex_core_state.position, transformation.scale, transformation.rotation),
            inputs = trade.input_items,
            outputs = trade.output_items,
            claimed = trade.hex_core_state.claimed == true,
            is_dungeon = trade.hex_core_state.is_dungeon == true or trade.hex_core_state.was_dungeon == true,
            productivity = trades.get_productivity(trade),
            is_interplanetary = trades.is_interplanetary_trade(trade),
            mode = hex_grid.get_hex_core_mode(trade.hex_core_state),
            core_quality = quality,
        })

        local seen = seen_items[trade.surface_name]
        for _, input in pairs(trade.input_items) do
            table.insert(seen, input.name)
        end
        for _, output in pairs(trade.output_items) do
            table.insert(seen, output.name)
        end
    end

    local hex_coin_value_inv = 1 / item_values.get_item_value("nauvis", "hex-coin")
    for surface_name, item_names in pairs(seen_items) do
        for _, item_name in pairs(item_names) do
            item_value_lookup[surface_name][item_name] = item_values.get_item_value(surface_name, item_name, true, "normal") * hex_coin_value_inv
        end
    end

    local to_export = {
        trades = formatted_trades,
        item_values = item_value_lookup,
    }

    local filename = "all-trades-encoded-json.txt"
    helpers.write_file(
        filename,
        helpers.encode_string(helpers.table_to_json(to_export)),
        false,
        player.index
    )

    player.print({"hextorio.trades-exported", "Factorio/script-output/" .. filename})
end

function gui.on_confirmation_button_click(player, element)
    if element.parent.name == "delete-core-confirmation" then
        local hex_core = lib.get_player_opened_entity(player)
        if not hex_core then return end

        local inv = lib.get_player_inventory(player)
        if not inv then return end

        local coin = hex_grid.get_delete_core_cost(hex_core)
        local inv_coin = coin_tiers.get_coin_from_inventory(inv)
        if coin_tiers.gt(coin, inv_coin) then
            player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
            return
        end

        coin_tiers.remove_coin_from_inventory(inv, coin)

        hex_grid.delete_hex_core(hex_core)
        gui.hide_all_frames(player)
    end
end

function gui.on_delete_core_button_click(player, element)
    element.parent.parent["delete-core-confirmation"].visible = true
    element.enabled = false
end

function gui.on_teleport_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end
    if hex_core.surface.name ~= player.surface.name then return end

    lib.teleport_player(player, hex_core.position, hex_core.surface)
end

function gui.on_toggle_hexport_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    if state.hexport then
        hex_grid.remove_hexport(state)
        element.sprite = "no-roboport"
    else
        hex_grid.spawn_hexport(state)
        element.sprite = "item/roboport"
    end
end

function gui.on_core_finder_button_click(player, element)
    if not storage.trade_overview.trades[player.name] then
        lib.log_error("gui.on_core_finder_button_click: Player trades list not found")
        return
    end

    local trade_number = tonumber(element.name:sub(20))
    if not trade_number then
        lib.log_error("gui.on_core_finder_button_click: Trade number could not be determined from element name: " .. element.name)
        return
    end

    local trade = storage.trade_overview.trades[player.name][trade_number]
    if not trade then
        lib.log_error("gui.on_core_finder_button_click: No trade found from trade overview")
        return
    end

    if not trade.hex_core_state then
        lib.log_error("gui.on_core_finder_button_click: No core found from trade overview")
        return
    end

    player.set_controller {
        type = defines.controllers.remote,
        position = trade.hex_core_state.hex_core.position,
        surface = trade.hex_core_state.hex_core.surface
    }

    player.opened = trade.hex_core_state.hex_core
end

function gui.on_tag_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_serial = tonumber(element.name:sub(12))
    local trade_id = state.trades[trade_serial]
    if not trade_id then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    local trade_str = lib.get_trade_img_str(trade, trades.is_interplanetary_trade(trade))

    state.tags_created = (state.tags_created or -1) + 1

    player.force.add_chart_tag(state.hex_core.surface, {
        position = {x = state.hex_core.position.x, y = state.hex_core.position.y + state.tags_created * 4, surface = state.hex_core.surface},
        -- icon = {type = "entity", name = "hex-core"},
        text = trade_str,
        quality = state.hex_core.quality,
    })

    quests.set_progress_for_type("create-trade-map-tag", 1)
end

function gui.on_claim_hex_button_click(player)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then
        lib.log_error("on_claim_hex_button_click: Couldn't find hex core")
        return
    end

    local transformation = terrain.get_surface_transformation(hex_core.surface)

    if not transformation then
        lib.log_error("on_claim_hex_button_click: No transformation found")
        return
    end

    local hex_pos = axial.get_hex_containing(hex_core.position, transformation.scale, transformation.rotation)

    if not hex_grid.can_claim_hex(player, player.surface, hex_pos) then
        local state = hex_grid.get_hex_state(hex_core.surface.index, hex_pos)
        if state.is_dungeon then
            player.print(lib.color_localized_string({"hextorio.loot-dungeon-first"}, "red"))
        else
            player.print(lib.color_localized_string({"hextorio.cannot-afford"}, "red"))
        end
        return
    end

    hex_grid.add_hex_to_claim_queue(hex_core.surface, hex_pos, player)
end

function gui.on_questbook_button_click(player)
    if gui.is_frame_open(player, "questbook") then
        gui.hide_questbook(player)
    else
        gui.close_all(player)
        gui.show_questbook(player)
    end
end

function gui.on_trade_overview_button_click(player)
    if gui.is_frame_open(player, "trade-overview") then
        gui.hide_trade_overview(player)
    else
        gui.close_all(player)
        gui.show_trade_overview(player)
    end
end

function gui.on_catalog_button_click(player)
    if gui.is_frame_open(player, "catalog") then
        gui.hide_catalog(player)
    else
        gui.close_all(player)
        gui.show_catalog(player)
    end
end

function gui.on_frame_close_button_click(player, button)
    local frame = gui.get_frame_from_close_button(button)
    if frame then
        frame.visible = false
    end
    player.opened = nil
end

function gui.on_catalog_item_click(player, button)
    local selection = gui.get_catalog_selection(player)
    local item_name = button.parent.name:sub(11)
    local surface_name = button.parent.parent.name:sub(7)
    gui.set_catalog_selection(player, surface_name, item_name, selection.bazaar_quality)
end

function gui.on_item_buff_button_click(player, element)
    local inv = lib.get_player_inventory(player)
    if not inv then return end

    item_buffs.fetch_settings()
    local selection = gui.get_catalog_selection(player)
    local cost = item_buffs.get_item_buff_cost(selection.item_name)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)

    if coin_tiers.gt(cost, inv_coin) then
        game.print({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(cost), coin_tiers.coin_to_text(inv_coin)})
        return
    end

    item_buffs.set_item_buff_level(
        selection.item_name,
        item_buffs.get_item_buff_level(selection.item_name) + 1
    )

    coin_tiers.remove_coin_from_inventory(inv, cost)

    gui.update_catalog_inspect_frame(player)
end

function gui.on_item_buff_all_button_click(player, element)
    item_buffs.enhance_all_item_buffs {
        player = player,
    }
end

function gui.on_trade_overview_filter_changed(player)
    gui.update_trade_overview(player)
end

function gui.close_all(player)
    gui.hide_hex_core(player)
    gui.hide_questbook(player)
    gui.hide_trade_overview(player)
    gui.hide_catalog(player)
end

function gui.on_gui_closed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    gui.close_all(player)
end

function gui.on_gui_confirmed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    gui.close_all(player)
end

function gui.on_gui_elem_changed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.element.name:sub(1, 11) == "input-item-" or event.element.name:sub(1, 12) == "output-item-" then
        gui.on_trade_overview_filter_changed(player)
    elseif gui.is_descendant_of(event.element, "catalog") then
        gui.on_catalog_choose_elem_button_changed(player, event.element)
    elseif gui.is_descendant_of(event.element, "trade-control-flow") then
        gui.on_quality_bound_selected(player, event.element)
    end
end

function gui.on_catalog_choose_elem_button_changed(player, element)
    if element.name == "selected-item-view" then
        gui.on_catalog_search_item_selected(player, element)
    elseif element.name == "selected-item-qb" then
        gui.on_quantum_bazaar_changed(player, element)
    end
end

function gui.on_gui_value_changed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if gui.is_descendant_of(event.element, "trade-overview") then
        gui.on_trade_overview_filter_changed(player)
    end
end

---Reset a choose-elem-button's element value to a valid quality.
---@param player LuaPlayer
---@param element LuaGuiElement
---@param hex_core_quality string|nil
function gui.reset_quality_bound(player, element, hex_core_quality)
    if element.name:sub(1, 12) == "min-quality-" then
        element.elem_value = {type = "quality", name = "normal"}
    elseif element.name:sub(1, 12) == "max-quality-" then
        local quality_tier = lib.get_quality_tier(lib.get_highest_unlocked_quality().name)
        if hex_core_quality then
            quality_tier = math.min(quality_tier, lib.get_quality_tier(hex_core_quality))
        end
        element.elem_value = {type = "quality", name = lib.get_quality_at_tier(quality_tier)}
    end
end

function gui.on_quality_bound_selected(player, element)
    local signal = element.elem_value

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    if not signal then
        gui.reset_quality_bound(player, element, hex_core.quality.name)
        signal = element.elem_value
    elseif signal.type ~= "quality" then
        player.print({"hextorio.invalid-quality-selected"})
        gui.reset_quality_bound(player, element, hex_core.quality.name)
        signal = element.elem_value
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_number = tonumber(element.name:sub(13))
    trade = trades.get_trade_from_id(state.trades[trade_number])
    if not trade then return end

    local adjusted = false
    if element.name:sub(1, 12) == "min-quality-" then
        adjusted = not hex_grid.set_trade_allowed_qualities(hex_core, trade, signal.name, trade.allowed_qualities[1])
    elseif element.name:sub(1, 12) == "max-quality-" then
        adjusted = not hex_grid.set_trade_allowed_qualities(hex_core, trade, trade.allowed_qualities[#trade.allowed_qualities], signal.name)
    end

    if adjusted then
        player.print({"hextorio.quality-bounds-adjusted"})
        element.elem_value = nil
    end

    gui.update_hex_core(player)
end

function gui.get_frame_from_close_button(close_button)
    return close_button.parent.parent
end

function gui.add_titlebar(frame, caption)
    local titlebar = frame.add{type = "flow"}
    titlebar.drag_target = frame
    titlebar.add{
        type = "label",
        style = "frame_title",
        caption = caption,
        ignored_by_interaction = true,
    }
    local filler = titlebar.add{
        type = "empty-widget",
        style = "draggable_space",
        ignored_by_interaction = true,
    }
    filler.style.height = 24
    filler.style.horizontally_stretchable = true
    titlebar.add{
        type = "sprite-button",
        name = "frame-close-button",
        style = "frame_action_button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close-instruction"},
    }
end

function gui.get_player_trade_overview_filter(player)
    local filters = storage.trade_overview.filters
    if not filters[player.name] then
        filters[player.name] = {}
    end
    return filters[player.name]
end

function gui.update_player_trade_overview_filters(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local filter_frame = frame["filter-frame"]
    if not filter_frame then return end

    local filter = gui.get_player_trade_overview_filter(player)
    local trade_contents_frame = filter_frame["left"]["trade-contents-flow"]["frame"]

    if not filter.planets then
        filter.planets = {}
    end

    for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
        filter.planets[planet_button.name] = planet_button.toggled
    end

    filter.input_items = {}
    for i = 1, 3 do
        local input_item = trade_contents_frame["input-item-" .. i]
        if input_item.elem_value then
            local item_name = input_item.elem_value
            table.insert(filter.input_items, item_name)
        end
    end
    if not next(filter.input_items) then
        filter.input_items = nil
    end

    filter.output_items = {}
    for i = 1, 3 do
        local output_item = trade_contents_frame["output-item-" .. i]
        if output_item.elem_value then
            local item_name = output_item.elem_value
            table.insert(filter.output_items, item_name)
        end
    end
    if not next(filter.output_items) then
        filter.output_items = nil
    end

    filter.show_claimed_only = filter_frame["right"]["show-only-claimed"]["checkbox"].state
    filter.exact_inputs_match = filter_frame["right"]["exact-inputs-match"]["checkbox"].state
    filter.exact_outputs_match = filter_frame["right"]["exact-outputs-match"]["checkbox"].state

    if filter.exact_inputs_match then
        filter.input_items_lookup = sets.new(filter.input_items)
    end
    if filter.exact_outputs_match then
        filter.output_items_lookup = sets.new(filter.output_items)
    end

    filter.num_item_bounds = {
        inputs = {
            min = 1,
            max = filter_frame["right"]["max-inputs-flow"]["slider"].slider_value,
        },
        outputs = {
            min = 1,
            max = filter_frame["right"]["max-outputs-flow"]["slider"].slider_value,
        },
    }

    -- Sorting stuff
    filter.sorting = {}

    local sorting_dropdown = filter_frame["right"]["sort-method"]["dropdown"]
    filter.sorting.method = sorting_dropdown.get_item(sorting_dropdown.selected_index)[1]:sub(19)
    filter.sorting.ascending = filter_frame["right"]["sort-direction"].switch_state == "left"

    local max_trades
    local max_trades_dropdown = filter_frame["right"]["max-trades-flow"]["dropdown"]
    if max_trades_dropdown.selected_index == 0 then
        max_trades = math.huge
    else
        local selected = max_trades_dropdown.items[max_trades_dropdown.selected_index]
        if selected[1] == "hextorio-gui.all" then
            max_trades = math.huge
        else
            max_trades = tonumber(selected[2])
        end
    end
    filter.max_trades = max_trades

    -- TODO: min/max num inputs/outputs
end

function gui.swap_trade_overview_content_filters(player)
    local filters = gui.get_player_trade_overview_filter(player)
    local new_inputs = filters.output_items or {}
    local new_outputs = filters.input_items or {}

    -- Only trigger a refresh if necessary.
    if not lib.tables_equal(sets.new(new_inputs), sets.new(new_outputs)) then
        gui.set_trade_overview_item_filters(player, new_inputs, new_outputs)
    end
end

---Check if a LuaGuiElement is a descendant of a given parent name.
---@param element LuaGuiElement
---@param parent_name string
---@return boolean
function gui.is_descendant_of(element, parent_name)
    local parent = element.parent
    if not parent then return false end
    if parent.name == parent_name then return true end
    return gui.is_descendant_of(parent, parent_name)
end

---Automatically stretch a LuaGuiElement horizontally.
---@param element LuaGuiElement
function gui.auto_width(element)
    element.style.horizontally_stretchable = true
    element.style.horizontally_squashable = true
end

---Automatically stretch a LuaGuiElement vertically.
---@param element LuaGuiElement
function gui.auto_height(element)
    element.style.vertically_stretchable = true
    element.style.vertically_squashable = true
end

---Automatically stretch a LuaGuiElement horizontally and vertically.
---@param element LuaGuiElement
function gui.auto_width_height(element)
    gui.auto_width(element)
    gui.auto_height(element)
end

---Verify the catalog storage is set up correctly.
---@param player LuaPlayer
function gui.verify_catalog_storage(player)
    if not storage.catalog then
        storage.catalog = {}
    end
    if not storage.catalog.current_selection then
        storage.catalog.current_selection = {}
    end
    if player then
        if not storage.catalog.current_selection[player.name] then
            storage.catalog.current_selection[player.name] = {surface_name = "nauvis", item_name = "stone", bazaar_quality = "normal"}
        end
    end
end

---Set the catalog selection for a player.
---@param player LuaPlayer
---@param surface_name string
---@param item_name string
---@param bazaar_quality string
function gui.set_catalog_selection(player, surface_name, item_name, bazaar_quality)
    gui.verify_catalog_storage(player)
    local selection = storage.catalog.current_selection[player.name]
    selection.surface_name = surface_name
    selection.item_name = item_name
    selection.last_item_selected = selection.item_name
    selection.bazaar_quality = bazaar_quality

    local rank = item_ranks.get_item_rank(selection.item_name)
    if rank >= 5 then
        selection.last_qb_item_selected = selection.item_name
    end

    gui.update_catalog_inspect_frame(player)
end

---Get the catalog selection for a player.
---@param player LuaPlayer
---@return PlayerCatalogSelection
function gui.get_catalog_selection(player)
    gui.verify_catalog_storage(player)
    return storage.catalog.current_selection[player.name]
end

---Get the quality name from a dropdown element.
---@param element LuaGuiElement
---@return string
function gui.get_quality_name_from_dropdown(element)
    local item = element.get_item(math.max(1, element.selected_index))[3][1] --[[@as string]]
    if not item then
        lib.log_error("gui.get_quality_name_from_dropdown: Could not find item in dropdown, assuming normal quality.")
        return "normal"
    end
    return item:sub(14)
end

---Get the sprite name for an item's rank.
---@param item_name string
---@param rank_value int|nil If not provided, the rank is automatically determined.
---@return string
function gui.get_rank_sprite(item_name, rank_value)
    if not rank_value then
        rank_value = item_ranks.get_item_rank(item_name)
    end

    local sprite = "rank-" .. rank_value
    if rank_value == 1 then
        local left_half = gui.get_bronze_sprite_half(item_name)
        if left_half ~= nil then
            if left_half then
                sprite = "rank-1-bought"
            else
                sprite = "rank-1-sold"
            end
        end
    end

    return sprite
end

---Get which half, if any, of the bronze star that should be used.
---@param item_name string
---@return boolean|nil
function gui.get_bronze_sprite_half(item_name)
    local left_half

    if trades.get_total_bought(item_name) > 0 then
        left_half = true
    elseif trades.get_total_sold(item_name) > 0 then
        left_half = false
    end

    return left_half
end

---Return the player who owns this element. Not expected to return nil under any circumstances.
---@param element LuaGuiElement
---@return LuaPlayer|nil
function gui.get_player_from_element(element)
    return game.get_player(element.player_index)
end

---Clear the opened stack of GUIs for a player.
---@param player LuaPlayer
function gui.clear_stack(player)
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.stack then
        storage.gui.stack = {}
    end
    if not storage.gui.stack[player.index] then
        storage.gui.stack[player.index] = {}
    end
    while next(storage.gui.stack[player.index]) do
        gui.pop_stack(player)
    end
end

---Add a GUI element to a player's opened stack.  If the element already exists in the stack, bring it to the front.
---@param player LuaPlayer
---@param element LuaGuiElement
function gui.add_to_stack(player, element)
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.stack then
        storage.gui.stack = {}
    end
    if not storage.gui.stack[player.index] then
        storage.gui.stack[player.index] = {}
    end

    local stack = storage.gui.stack[player.index]
    local index = gui.get_element_index_in_stack(player, element)

    if index >= 1 then
        table.remove(stack, index)
    end
    table.insert(stack, element)

    element.visible = true
    player.opened = element
end

---Get the opened stack of GUIs that a player has.
---@param player LuaPlayer
---@return LuaGuiElement[]
function gui.get_stack(player)
    if not storage.gui then
        storage.gui = {}
    end
    if not storage.gui.stack then
        storage.gui.stack = {}
    end
    if not storage.gui.stack[player.index] then
        storage.gui.stack[player.index] = {}
    end
    return storage.gui.stack[player.index]
end

---Pop and return the last element off of the opened stack for a player, or the element at the given index.
---@param player LuaPlayer
---@param index int|nil
---@return LuaGuiElement|nil
function gui.pop_stack(player, index)
    local stack = gui.get_stack(player)
    if not next(stack) then return end

    if not index then index = #stack end
    if index > #stack then
        lib.log_error("gui.pop_stack: index=" .. index .. " is out of bounds for stack of size=" .. #stack)
        return
    end

    local elem = stack[index]
    table.remove(stack, index)

    if next(stack) then
        if player.opened == elem then
            player.opened = stack[index]
        else
            player.opened = stack[#stack]
        end
    else
        player.opened = nil
    end

    elem.visible = false

    return elem
end

---Return whether the given element is in a player's opened stack.
---@param player LuaPlayer
---@param element LuaGuiElement
---@return boolean
function gui.is_element_in_stack(player, element)
    return gui.get_element_index_in_stack(player, element) >= 1
end

---Get the index of an element in a player's opened stack.  Return -1 if not found (conventional).
---@param player LuaPlayer
---@param element LuaGuiElement
---@return int
function gui.get_element_index_in_stack(player, element)
    for i, elem in ipairs(gui.get_stack(player)) do
        if elem == element then
            return i
        end
    end
    return -1
end



return gui
