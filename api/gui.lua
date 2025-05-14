local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"
local coin_tiers  = require "api.coin_tiers"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local sets = require "api.sets"
local event_system = require "api.event_system"
local quests = require "api.quests"

local gui = {}



function gui.register_events()
    event_system.register_callback("post-rank-up-command", function(player, params)
        gui.close_all(player)
        gui.show_catalog(player)
        gui.update_catalog(player, "nauvis", params[1])
    end)
    event_system.register_callback("post-rank-up-all-command", function(player, params)
        gui.close_all(player)
        gui.show_catalog(player)
        gui.update_catalog(player, "nauvis", "stone")
    end)
    event_system.register_callback("post-discover-all-command", function(player, params)
        gui.close_all(player)
        gui.show_catalog(player)
        gui.update_catalog(player, "nauvis", "stone")
    end)
    event_system.register_callback("trade-processed", function(trade)
        if not trade.hex_core_state or not trade.hex_core_state.hex_core or not trade.hex_core_state.hex_core.valid then return end
        for _, player in pairs(game.players) do
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
        for _, player in pairs(game.players) do
            gui.update_quest_lists(player, quest)
            gui.update_questbook(player)
        end
    end)

    event_system.register_callback("quest-completed", function(quest)
        for _, player in pairs(game.players) do
            gui.update_quest_lists(player, quest)
            gui.update_questbook(player)
        end
    end)

    event_system.register_callback("hex-core-deleted", function(state)
        if not state then return end
        for _, player in pairs(game.players) do
            if player.gui.screen["trade-overview"].visible then
                gui.update_trade_overview(player)
            end
        end
    end)
end

function gui.reinitialize_everything(player)
    -- called during migration or for player joins

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
    hex_core_gui.style.width = 444
    hex_core_gui.style.natural_height = 625
    hex_core_gui.style.vertically_stretchable = true

    local resources_header = hex_core_gui.add {type = "label", name = "resources-header", caption = {"hex-core-gui.initial-resources"}}
    resources_header.style.font = "heading-2"

    local resources_flow = hex_core_gui.add {type = "flow", name = "resources-flow", direction = "horizontal"}

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local claim_flow = hex_core_gui.add {type = "flow", name = "claim-flow", direction = "vertical"}
    local free_hexes_remaining = claim_flow.add {type = "label", name = "free-hexes-remaining"}
    local claim_price = gui.create_coin_tier(claim_flow, "claim-price")
    local claim_hex = claim_flow.add {type = "button", name = "claim-hex", caption = {"hex-core-gui.claim-hex"}, style = "confirm_button"}
    claim_hex.tooltip = nil

    local claimed_by = hex_core_gui.add {type = "label", name = "claimed-by", caption = {"hex-core-gui.claimed-by"}}
    claimed_by.style.font = "heading-2"

    local hex_control_flow = hex_core_gui.add {type = "flow", name = "hex-control-flow", direction = "horizontal"}
    hex_control_flow.visible = false

    local teleport = hex_control_flow.add {type = "sprite-button", name = "teleport", sprite = "teleport"}
    teleport.tooltip = {"hex-core-gui.teleport-tooltip"}

    local unloader_filters = hex_control_flow.add {type = "sprite-button", name = "unloader-filters", sprite = "item/loader"}
    unloader_filters.tooltip = {"hex-core-gui.unloader-filters-tooltip"}

    local supercharge = hex_control_flow.add {type = "sprite-button", name = "supercharge", sprite = "item/electric-mining-drill"}

    local sink_mode = hex_control_flow.add {type = "sprite-button", name = "sink-mode", sprite = "hex-coin"}
    sink_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.sink-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.sink-mode-tooltip-body"}}

    local generator_mode = hex_control_flow.add {type = "sprite-button", name = "generator-mode", sprite = "gravity-coin"}
    generator_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.generator-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.generator-mode-tooltip-body"}}

    local delete_core = hex_control_flow.add {type = "sprite-button", name = "delete-core", sprite = "utility/deconstruction_mark"}

    local unloader_filters_flow = hex_core_gui.add {type = "flow", name = "unloader-filters-flow", direction = "horizontal"}
    for i, dir in ipairs {"west", "north", "south", "east"} do
        local unloader_filters_dir = unloader_filters_flow.add {type = "sprite-button", name = dir, sprite = "arrow-" .. dir}
    end
    unloader_filters_flow.visible = false

    local delete_core_confirmation = hex_core_gui.add {type = "flow", name = "delete-core-confirmation", direction = "horizontal"}
    delete_core_confirmation.visible = false

    local delete_core_confirmation_button = delete_core_confirmation.add {type = "sprite-button", name = "confirmation-button", sprite = "utility/deconstruction_mark"}
    local delete_core_confirmation_label = delete_core_confirmation.add {type = "label", name = "confirmation-label", caption = lib.color_localized_string({"hex-core-gui.delete-core-confirmation"}, "red")}
    delete_core_confirmation_label.style.font = "heading-1"

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local trades_total_sold = hex_core_gui.add {type = "label", name = "trades-total-sold", caption = {"hex-core-gui.trades-total-sold"}}
    trades_total_sold.style.font = "heading-2"

    local trades_total_sold_none = hex_core_gui.add {type = "label", name = "trades-total-sold-none", caption = {"hex-core-gui.trades-total-sold-none"}}
    local trades_total_sold_table = hex_core_gui.add {type = "table", name = "trades-total-sold-table", column_count = 8}

    local trades_total_bought = hex_core_gui.add {type = "label", name = "trades-total-bought", caption = {"hex-core-gui.trades-total-bought"}}
    trades_total_bought.style.font = "heading-2"

    local trades_total_bought_none = hex_core_gui.add {type = "label", name = "trades-total-bought-none", caption = {"hex-core-gui.trades-total-bought-none"}}
    local trades_total_bought_table = hex_core_gui.add {type = "table", name = "trades-total-bought-table", column_count = 8}

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local trades_header = hex_core_gui.add {type = "label", name = "trades-header", caption = {"hex-core-gui.trades-header"}}
    trades_header.style.font = "heading-1"

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

    gui.add_titlebar(questbook, {"hextorio-questbook.questbook-title"})

    -- TODO
    -- local info_frame = questbook.add {type = "frame", name = "info-frame", direction = "horizontal"}
    -- info_frame.style.horizontally_stretchable = true
    -- info_frame.style.vertically_squashable = true
    -- info_frame.style.natural_height = 75

    local lower_flow = questbook.add {type = "flow", name = "lower-flow", direction = "horizontal"}
    gui.auto_width_height(lower_flow)

    local list_frame = lower_flow.add {type = "frame", name = "list-frame", direction = "vertical"}
    list_frame.style.natural_width = 300 / 1.2
    list_frame.style.horizontally_stretchable = false
    list_frame.style.horizontally_squashable = true

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

    local quest_info_main = quest_info_frame.add {type = "flow", name = "main", direction = "vertical"}
    local quest_info_img_frame = quest_info_frame.add {type = "frame", name = "img-frame"}
    local quest_info_img = quest_info_img_frame.add {type = "sprite", name = "img", sprite = "missing-quest-img"}

    local quest_title = quest_info_main.add {type = "label", name = "title", caption = "[Quest Title]"}
    quest_title.style.font = "heading-1"
    quest_info_main.add {type = "line", direction = "horizontal"}

    local quest_description = quest_info_main.add {type = "label", name = "description", caption = "[Quest Description]"}
    quest_description.style.single_line = false

    local quest_notes_flow = quest_info_main.add {type = "flow", name = "notes-flow", direction = "vertical"}

    local quest_conditions_rewards = quest_frame.add {type = "flow", name = "conditions-rewards", direction = "horizontal"}
    gui.auto_width_height(quest_conditions_rewards)

    local quest_conditions_frame = quest_conditions_rewards.add {type = "frame", name = "conditions", direction = "vertical"}

    local quest_conditions_header = quest_conditions_frame.add {type = "label", name = "header", caption = {"hextorio-questbook.conditions"}}
    quest_conditions_header.style.font = "heading-1"
    quest_conditions_frame.add {type = "line", direction = "horizontal"}

    local quest_conditions_scroll_pane = quest_conditions_frame.add {type = "scroll-pane", name = "scroll-pane"}
    gui.auto_width_height(quest_conditions_scroll_pane)

    local quest_rewards_frame = quest_conditions_rewards.add {type = "frame", name = "rewards", direction = "vertical"}

    local quest_rewards_header = quest_rewards_frame.add {type = "label", name = "header", caption = {"hextorio-questbook.rewards"}}
    quest_rewards_header.style.font = "heading-1"
    quest_rewards_frame.add {type = "line", direction = "horizontal"}

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

    gui.add_titlebar(frame, {"hex-core-gui.trade-overview"})

    local filter_frame = frame.add {type = "flow", name = "filter-frame", direction = "horizontal"}
    -- filter_frame.style.natural_height = 200
    filter_frame.style.vertically_stretchable = false
    local left_frame = filter_frame.add {type = "frame", name = "left", direction = "vertical"}
    gui.auto_width_height(left_frame)
    local right_frame = filter_frame.add {type = "frame", name = "right", direction = "vertical"}
    gui.auto_width_height(right_frame)

    local clear_filters_button = left_frame.add {type = "button", name = "clear-filters-button", caption = {"hextorio-gui.clear-filters"}}
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

    right_frame.add {type = "line", direction = "horizontal"}

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
end

function gui.init_catalog(player)
    local frame = player.gui.screen.add {
        type = "frame",
        name = "catalog",
        direction = "vertical",
    }
    frame.style.width = 1200
    frame.style.height = 800

    gui.add_titlebar(frame, {"hextorio-gui.catalog"})

    local flow = frame.add {type = "flow", name = "flow", direction = "horizontal"}

    local catalog_frame = flow.add {type = "frame", name = "catalog-frame", direction = "vertical"}
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
        -- lib.log(serpent.block(items_sorted_by_value))

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
    gui.update_catalog(player, "nauvis", "stone")
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
        if item_name:sub(-5) == "-coin" then return end
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

    local hex_coin_value = item_values.get_item_value(surface_name, "hex-coin")
    local item_count = element.number or 1
    local value = item_values.get_item_value(surface_name, item_name)
    local scaled_value = value / hex_coin_value

    local rank_str = {""}
    if lib.is_catalog_item(item_name) then
        local rank = item_ranks.get_item_rank(item_name)
        rank_str = {"", lib.color_localized_string({"hextorio-gui.rank"}, "white", "heading-1"), " " , lib.get_rank_img_str(rank), "\n\n"}
    end

    element.tooltip = {"",
        rank_str,
        "[font=heading-2][color=green]",
        {"hextorio-gui.item-value"},
        "[.color][.font]\n[" .. rich_type .. "=" .. item_name .. "]x1 = ",
        coin_tiers.coin_to_text(scaled_value, false, 4),
        "\n\n[font=heading-2][color=yellow]",
        {"hextorio-gui.stack-value-total"},
        "[.color][.font]\n[" .. rich_type .. "=" .. item_name .. "]x" .. item_count .. " = ",
        coin_tiers.coin_to_text(item_count * scaled_value, false, nil)
    }
end

function gui.give_trade_arrow_tooltip(element, trade)
    local s = {"",
        trades.get_total_values_str(trade),
    }
    local prod = trades.get_productivity(trade)
    if prod > 0 then
        table.insert(s, "\n\n")
        table.insert(s, trades.get_productivity_bonus_str(trade))
    end
    if not gui.is_descendant_of(element, "trade-contents-flow") then
        table.insert(s, "\n\n")
        table.insert(s, lib.color_localized_string({"hextorio-gui.click-to-ping"}, "gray"))
    end
    element.tooltip = s
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
        -- local batch_size = 50
        -- for i = math.min(#process.trades_scroll_pane.children, batch_size), 1, -1 do
        --     process.trades_scroll_pane.children[i].destroy()
        -- end
        -- if #process.trades_scroll_pane.children == 0 then
        --     process.clear_mode = false
        -- end
        process.trades_scroll_pane.clear()
        process.clear_mode = false
        return
    end

    local batch_size = 150
    if game.is_multiplayer() then
        batch_size = 100 -- slow down for slow connections like my own
    end

    local size = 40
    for trade_number = process.batch_idx, math.min(#process.trades_list, process.batch_idx + batch_size - 1) do
        local trade = process.trades_list[trade_number]
        if not trade then
            lib.log_error("trade_number = " .. trade_number .. " is out of bounds for list of " .. #process.trades_list .. " trades")
            break
        end
        local trade_flow = process.trades_scroll_pane.add {
            type = "flow",
            name = "trade-" .. trade_number,
            direction = "horizontal",
        }
        if process.params.show_toggle_trade then
            local checkbox = trade_flow.add {
                type = "checkbox",
                name = "toggle-trade-" .. trade_number,
                state = trade.active,
            }
            checkbox.tooltip = {"hex-core-gui.trade-checkbox-tooltip"}
            -- checkbox.style.left_margin = 10
            checkbox.style.left_margin = 5
            checkbox.style.top_margin = size / 2 + 1
            -- checkbox.style.top_margin = size / 2 - 5
        end
        if process.params.show_tag_creator then
            local tag_button = trade_flow.add {
                type = "sprite-button",
                name = "tag-button-" .. trade_number,
                sprite = "utility/show_tags_in_map_view",
            }
            -- tag_button.style.left_margin = 5
            tag_button.style.top_margin = 10
            tag_button.tooltip = {"hex-core-gui.tag-button"}
        end
        if process.params.show_core_finder then
            local core_finder_button = trade_flow.add {
                type = "sprite-button",
                name = "core-finder-button-" .. trade_number,
                sprite = "utility/gps_map_icon",
            }
            -- core_finder_button.style.left_margin = 5
            core_finder_button.style.top_margin = 10
            core_finder_button.tooltip = {"hextorio-gui.core-finder-button"}
        end
        local trade_frame = trade_flow.add {
            type = "frame",
            name = "frame",
            direction = "vertical",
        }
        trade_frame.style.left_margin = 10
        trade_frame.style.natural_height = (size + 20) / 1.2 - 5
        -- trade_frame.style.horizontally_stretchable = true
        -- gui.auto_width(trade_frame)
        trade_frame.style.width = 381 / 1.2
        local trade_table = trade_frame.add {
            type = "table",
            name = "trade-table",
            column_count = 7,
        }
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
                gui.give_item_tooltip(process.player, trade.surface_name, input)
            else
                total_empty = total_empty + 1
                local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
                empty.style.natural_width = size / 1.2
                empty.style.natural_height = size / 1.2
                empty.ignored_by_interaction = true
            end
        end
        local trade_arrow_sprite = trade_table.add {
            type = "sprite",
            name = "trade-arrow",
            sprite = "trade-arrow",
        }
        if process.params.show_productivity and trades.get_productivity(trade) > 0 then
            local prod_bar = trade_frame.add {
                type = "progressbar",
                name = "prod-bar",
                value = trades.get_current_prod_value(trade),
                style = "bonus_progressbar",
            }
            prod_bar.style.horizontally_squashable = true
            prod_bar.style.horizontally_stretchable = true
        end

        trade_arrow_sprite.style.width = size / 1.2
        trade_arrow_sprite.style.height = size / 1.2
        trade_arrow_sprite.style.top_margin = 2
        gui.give_trade_arrow_tooltip(trade_arrow_sprite, trade)

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
                gui.give_item_tooltip(process.player, trade.surface_name, output)
            else
                total_empty = total_empty + 1
                local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
                empty.style.natural_width = size / 1.2
                empty.style.natural_height = size / 1.2
                empty.ignored_by_interaction = true
            end
        end
    end

    process.batch_idx = process.batch_idx + batch_size
    if process.batch_idx > #process.trades_list then
        process.finished = true
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
    storage.gui.trades_scroll_pane_update[player.name] = {
        player = player,
        tick_interval = tick_interval,
        trades_scroll_pane = trades_scroll_pane,
        trades_list = trades_list,
        params = params,
        clear_mode = true,
        batch_idx = 1,
    }
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

    local hex_core = player.opened
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    frame["hex-control-flow"]["teleport"].visible = quests.is_feature_unlocked "teleportation"
    frame["hex-control-flow"]["delete-core"].visible = quests.is_feature_unlocked "hex-core-deletion"

    if state.claimed then
        frame["claim-flow"].visible = false
        local claimed_by_name = state.claimed_by or {"hextorio.server"}
        local claimed_timestamp = state.claimed_timestamp or 0
        frame["claimed-by"].visible = true
        frame["claimed-by"].caption = {"hex-core-gui.claimed-by", claimed_by_name, lib.ticks_to_string(claimed_timestamp)}

        frame["trades-total-sold"].visible = true
        frame["trades-total-bought"].visible = true

        local total_items_sold = state.total_items_sold or {}
        if next(total_items_sold) then
            frame["trades-total-sold-none"].visible = false
            frame["trades-total-sold-table"].visible = true
            frame["trades-total-sold-table"].clear()
            gui.generate_sprite_buttons(player, hex_core.surface.name, frame["trades-total-sold-table"], total_items_sold, true)
        else
            frame["trades-total-sold-none"].visible = true
            frame["trades-total-sold-table"].visible = false
        end

        local total_items_bought = state.total_items_bought or {}
        if next(total_items_bought) then
            frame["trades-total-bought-none"].visible = false
            frame["trades-total-bought-table"].visible = true
            frame["trades-total-bought-table"].clear()
            gui.generate_sprite_buttons(player, hex_core.surface.name, frame["trades-total-bought-table"], total_items_bought, true)
        else
            frame["trades-total-bought-none"].visible = true
            frame["trades-total-bought-table"].visible = false
        end

        frame["hex-control-flow"].visible = true
        frame["hex-control-flow"]["teleport"].visible = player.character and state.hex_core and player.character.surface.name == state.hex_core.surface.name
        frame["hex-control-flow"]["unloader-filters"].enabled = true
        frame["hex-control-flow"]["supercharge"].visible = not state.is_infinite and quests.is_feature_unlocked "supercharging"
        if not state.is_infinite then
            frame["hex-control-flow"]["supercharge"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.supercharge-tooltip-header"}, "orange", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(hex_grid.get_supercharge_cost(hex_core))},
                "\n",
                {"hex-core-gui.supercharge-tooltip-body"},
            }
        end
        frame["hex-control-flow"]["delete-core"].enabled = true
        frame["hex-control-flow"]["delete-core"].tooltip = {"",
            lib.color_localized_string({"hex-core-gui.delete-core-tooltip-header"}, "red", "heading-2"),
            "\n",
            {"hextorio-gui.cost", coin_tiers.coin_to_text(hex_grid.get_delete_core_cost(hex_core))},
            "\n",
            {"hex-core-gui.delete-core-tooltip-body"},
        }

        frame["hex-control-flow"]["sink-mode"].visible = state.mode == nil and quests.is_feature_unlocked "sink-mode"
        frame["hex-control-flow"]["generator-mode"].visible = state.mode == nil and quests.is_feature_unlocked "generator-mode"
    else
        frame["claim-flow"].visible = true
        frame["claimed-by"].visible = false

        frame["trades-total-sold"].visible = false
        frame["trades-total-sold-table"].visible = false
        frame["trades-total-bought"].visible = false
        frame["trades-total-bought-table"].visible = false

        frame["trades-total-sold-none"].visible = false
        frame["trades-total-bought-none"].visible = false

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
    frame["unloader-filters-flow"].visible = false

    gui.update_trades_scroll_pane(player, frame.trades, trades.convert_trade_id_array_to_trade_array(state.trades), {show_toggle_trade=state.claimed, show_tag_creator=true, show_core_finder=false, show_productivity=true})
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

    local hex_core = player.opened
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
            caption = {"hex-core-gui.no-resources"},
        }
    end
end

function gui.update_questbook(player, quest_name)
    local frame = player.gui.screen["questbook"]
    if not frame then
        gui.init_questbook(player)
        frame = player.gui.screen["questbook"]
    end

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
        quest = quests.get_quest(quest_name)
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
            condition_str = coin_tiers.coin_to_text(coin_tiers.from_base_value(condition.progress_requirement))
        end

        local condition_desc = condition_frame.add {
            type = "label",
            name = "desc",
            caption = quests.get_condition_localized_description(condition, condition_str, "green", "heading-2"),
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
                value = condition.progress / condition.progress_requirement,
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
            gui.add_sprite_buttons(receive_items_flow, reward.value, "receive-items-")
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

    -- Ensure that all available planets are listed
    local filter_frame = frame["filter-frame"]
    for surface_name, _ in pairs(game.surfaces) do
        if storage.trade_overview.allowed_planet_filters[surface_name] then
            if not filter_frame["left"]["planet-flow"][surface_name] then
                local surface_flow = filter_frame["left"]["planet-flow"].add {
                    type = "flow",
                    name = surface_name,
                    direction = "vertical",
                }
                local surface_sprite = surface_flow.add {
                    type = "sprite-button",
                    name = "sprite-button",
                    sprite = "planet-" .. surface_name,
                }
                -- local surface_checkbox = surface_flow.add {
                --     type = "checkbox",
                --     name = "checkbox",
                --     state = true,
                -- }
                local surface_status = surface_flow.add {
                    type = "sprite",
                    name = "status",
                    sprite = "check-mark-green",
                }
                surface_status.style.left_margin = 8
                -- surface_status.style.width = 24
                -- surface_status.style.height = 24
                surface_status.style.size = {24, 24}
            end
        end
    end

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
                    distances[trade.id] = hex_grid.distance(trade.hex_core_state.position, {q=0, r=0})
                else
                    distances[trade.id] = 0
                end
            end
            sort_func = function(trade1, trade2)
                return distances[trade1.id] < distances[trade2.id]
            end
        elseif filter.sorting.method == "distance-from-character" then
            if player.character then
                local transformation = hex_grid.get_surface_transformation(player.surface)
                local char_pos = hex_grid.get_hex_containing(player.character.position, transformation.scale, transformation.rotation)
                local distances = {}
                for _, trade in pairs(trades_list) do
                    if trade.hex_core_state then
                        distances[trade.id] = hex_grid.distance(trade.hex_core_state.position, char_pos)
                    else
                        distances[trade.id] = 0
                    end
                end
                sort_func = function(trade1, trade2)
                    return distances[trade1.id] < distances[trade2.id]
                end
            end
        elseif filter.sorting.method == "num-inputs" then
            sort_func = function(trade1, trade2)
                return #trade1.input_items < #trade2.input_items
            end
        elseif filter.sorting.method == "num-outputs" then
            sort_func = function(trade1, trade2)
                return #trade1.output_items < #trade2.output_items
            end
        elseif filter.sorting.method == "productivity" then
            sort_func = function(trade1, trade2)
                return trades.get_productivity(trade1) < trades.get_productivity(trade2)
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

    storage.trade_overview.trades[player.name] = trades_list

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    gui.update_trades_scroll_pane(player, trade_table, trades_list, {show_toggle_trade=false, show_tag_creator=false, show_core_finder=true, show_productivity=false})
end

function gui.update_catalog(player, selected_item_surface, selected_item_name)
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
                    rank_flow["rank-stars"].sprite = "rank-" .. rank
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

    gui.update_catalog_inspect_frame(player, selected_item_surface, selected_item_name)
end

function gui.add_info(element, info_id, name)
    local info = element.add {
        type = "label",
        name = name,
        caption = {"", "[color=117,218,251][img=virtual-signal.signal-info] ", info_id, "[.color]"},
    }
    info.style.single_line = false
    gui.auto_width(info)
end

function gui.add_sprite_buttons(element, item_stacks, name_prefix)
    if not name_prefix then name_prefix = "" end
    for i, item_stack in ipairs(item_stacks) do
        local sprite_button = element.add {
            type = "sprite-button",
            name = name_prefix .. item_stack.name,
            sprite = "item/" .. item_stack.name,
            number = item_stack.count,
        }
    end
end

function gui.get_player_current_quest_selected(player)
    if not storage.quests.players_quest_selected[player.name] then
        storage.quests.players_quest_selected[player.name] = "ground-zero"
    end
    return storage.quests.players_quest_selected[player.name]
end

function gui.set_player_current_quest_selected(player, quest_name)
    storage.quests.players_quest_selected[player.name] = quest_name
end

function gui.update_catalog_inspect_frame(player, surface_name, item_name)
    local frame = player.gui.screen["catalog"]
    if not frame then
        gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end

    local inspect_frame = frame["flow"]["inspect-frame"]

    if not trades.is_item_discovered(item_name) then
        item_name = nil
    end
    if not item_name then return end

    local rank_obj = item_ranks.get_rank_obj(item_name)
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
        caption = "[font=heading-1][img=item." .. item_name .. "][.font]",
    }

    local rank_label2 = rank_flow.add {
        type = "label",
        name = "label2",
        caption = "[font=heading-1]" .. lib.get_rank_img_str(rank_obj.rank) .. "[.font]",
    }
    rank_label2.style.left_margin = 73 / 1.2

    local rank_label3 = rank_flow.add {
        type = "label",
        name = "label3",
        caption = "[font=heading-1][img=item." .. item_name .. "][.font]",
    }
    rank_label3.style.left_margin = 73 / 1.2

    inspect_frame.add {type = "line", direction = "horizontal"}

    local bonuses_label = inspect_frame.add {
        type = "label",
        name = "bonuses-label",
        caption = {"hextorio-gui.bonuses"},
    }
    bonuses_label.style.font = "heading-2"

    if rank_obj.rank > 1 then
        local bonus_productivity = inspect_frame.add {
            type = "label",
            name = "bonus-productivity",
            caption = {"", lib.color_localized_string({"hextorio-gui.main-bonus"}, "blue", "heading-2"), "\n", {"hextorio-gui.rank-bonus-trade-productivity", "[color=green]" .. math.floor(100 * item_ranks.get_rank_bonus_effect(rank_obj.rank)) .. "[.color]"}},
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
        local color_rich_text = lib.color_to_rich_text(storage.item_ranks.rank_colors[i])
        local rank_bonus_unique_heading = inspect_frame.add {
            type = "label",
            name = "rank-bonus-unique-heading-" .. i,
            caption = lib.color_localized_string({"", "[img=" .. storage.item_ranks.rank_star_sprites[i] .. "] ", {"hextorio-gui.unique-bonus"}}, color_rich_text, "heading-2"),
        }
        local rank_bonus_unique = inspect_frame.add {
            type = "label",
            name = "rank-bonus-unique-" .. i,
            caption = {"", {"hextorio-gui.rank-bonus-unique-" .. i, color_rich_text .. lib.format_percentage(lib.runtime_setting_value("rank-" .. i .. "-effect"), 1, false) .. "[.color]"}},
        }
        rank_bonus_unique.style.single_line = false
        gui.auto_width_height(rank_bonus_unique)
    end

    inspect_frame.add {type = "line", direction = "horizontal"}

    local rank_up_localized_str = {"hextorio-gui.rank-up-instructions-" .. rank_obj.rank}

    if rank_obj.rank == 1 then
        if trades.get_total_bought(item_name) > 0 then
            table.insert(rank_up_localized_str, "[img=virtual-signal.signal-check]")
        else
            table.insert(rank_up_localized_str, "[img=virtual-signal.signal-deny]")
        end
        if trades.get_total_sold(item_name) > 0 then
            table.insert(rank_up_localized_str, "[img=virtual-signal.signal-check]")
        else
            table.insert(rank_up_localized_str, "[img=virtual-signal.signal-deny]")
        end
    elseif rank_obj.rank == 2 then
        table.insert(rank_up_localized_str, lib.color_localized_string({"hex-core-gui.generator-mode-tooltip-header"}, "red", "heading-2"))
    elseif rank_obj.rank == 3 then
        table.insert(rank_up_localized_str, lib.color_localized_string({"hex-core-gui.sink-mode-tooltip-header"}, "red", "heading-2"))
    end

    local rank_up_instructions = inspect_frame.add {
        type = "label",
        name = "rank-up-instructions",
        caption = {"", "\n" .. lib.get_rank_img_str(math.min(5, (rank_obj.rank + 1))) .. "\n", rank_up_localized_str, "\n"},
    }
    rank_up_instructions.style.single_line = false
    gui.auto_width_height(rank_up_instructions)

    if rank_obj.rank == 1 then
        gui.add_info(inspect_frame, {"hextorio-gui.buying-info"}, "info-buying")
        gui.add_info(inspect_frame, {"hextorio-gui.selling-info"}, "info-selling")
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

function gui.repopulate_quest_lists(player)
    local scroll_pane = player.gui.screen["questbook"]["lower-flow"]["list-frame"]["scroll-pane"]
    local incomplete_list = scroll_pane["incomplete-list"]
    local complete_list = scroll_pane["complete-list"]

    complete_list.clear_items()
    incomplete_list.clear_items()

    for _, q in pairs(storage.quests.quests) do
        if q.revealed then
            if q.complete then
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
            if mid_quest.order < quest_order then
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
    return quests.get_quest(quest_name)
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

    -- Don't show any zeros unless it's a totla of zero coins.
    local coin_names = {"hex-coin", "gravity-coin", "meteor-coin", "hexaprism-coin"}
    for i = 1, 4 do
        local coin_sprite = flow[coin_names[i]]
        if coin.values[i] > 0 then
            coin_sprite.number = coin.values[i]
            coin_sprite.visible = true
        else
            coin_sprite.visible = false
        end
    end

    if coin_tiers.is_zero(coin) then
        flow['hex-coin'].visible = true
    end
end

function gui.create_coin_tier(parent, name)
    local flow = parent.add {type = "flow", direction = "horizontal"}
    flow.style.horizontal_spacing = 8
    flow.name = name or "coins"

    local hex_coin_sprite = flow.add {type = "sprite-button", sprite = "hex-coin"}
    hex_coin_sprite.ignored_by_interaction = true
    hex_coin_sprite.name = "hex-coin"
    hex_coin_sprite.style.width = 40
    hex_coin_sprite.style.height = 40
    hex_coin_sprite.number = 1

    local gravity_coin_sprite = flow.add {type = "sprite-button", sprite = "gravity-coin"}
    gravity_coin_sprite.ignored_by_interaction = true
    gravity_coin_sprite.name = "gravity-coin"
    gravity_coin_sprite.style.width = 40
    gravity_coin_sprite.style.height = 40
    gravity_coin_sprite.number = 0

    local meteor_coin_sprite = flow.add {type = "sprite-button", sprite = "meteor-coin"}
    meteor_coin_sprite.ignored_by_interaction = true
    meteor_coin_sprite.name = "meteor-coin"
    meteor_coin_sprite.style.width = 40
    meteor_coin_sprite.style.height = 40
    meteor_coin_sprite.number = 0

    local hexaprism_coin_sprite = flow.add {type = "sprite-button", sprite = "hexaprism-coin"}
    hexaprism_coin_sprite.ignored_by_interaction = true
    hexaprism_coin_sprite.name = "hexaprism-coin"
    hexaprism_coin_sprite.style.width = 40
    hexaprism_coin_sprite.style.height = 40
    hexaprism_coin_sprite.number = 0

    return flow
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
    elseif event.element.type == "sprite" then
        gui.on_sprite_click(player, event.element)
    elseif event.element.type == "sprite-button" then
        gui.on_sprite_button_click(player, event.element)
    elseif event.element.type == "button" then
        gui.on_button_click(player, event.element)
    elseif event.element.type == "checkbox" then
        gui.on_checkbox_click(player, event.element)
    end
end

function gui.on_sprite_click(player, element)
    if element.name == "trade-arrow" then
        gui.on_trade_arrow_click(player, element)
    end
end

function gui.on_trade_arrow_click(player, element)
    if gui.is_descendant_of(element, "trade-contents-flow") then return end

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
        local hex_core = player.opened
        if not hex_core then return end

        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end

        local trade_number = tonumber(element.parent.parent.parent.name:sub(7))
        trade = trades.get_trade_from_id(state.trades[trade_number])
        if not trade then return end

        gps_str = hex_core.gps_tag
    end

    local trade_str = lib.get_trade_img_str(trade)
    game.print({"hextorio.player-trade-ping", player.name, trade_str, gps_str})
end

function gui.on_button_click(player, element)
    if element.name == "clear-filters-button" then
        gui.on_clear_filters_button_click(player, element)
    end
end

function gui.on_checkbox_click(player, element)
    if element.name:sub(1, 12) == "toggle-trade" then
        gui.on_toggle_trade_checkbox_click(player, element)
    elseif element.parent.name == "show-only-claimed" or element.parent.name == "exact-inputs-match" or element.parent.name == "exact-outputs-match" then
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
    end
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

function gui.on_toggle_trade_checkbox_click(player, element)
    local hex_core = player.opened
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_number = tonumber(element.name:sub(14))
    hex_grid.set_trade_active(state, trade_number, element.state)
end

function gui.on_sprite_button_click(player, element)
    if element.name == "catalog-item" then
        gui.on_catalog_item_click(player, element)
    elseif element.name == "frame-close-button" then
        gui.on_frame_close_button_click(player, element)
    elseif element.name:sub(1, 10) == "tag-button" then
        gui.on_tag_button_click(player, element)
    elseif element.name:sub(1, 18) == "core-finder-button" then
        gui.on_core_finder_button_click(player, element)
    elseif element.name == "teleport" then
        gui.on_teleport_button_click(player, element)
    elseif element.name == "supercharge" then
        gui.on_supercharge_button_click(player, element)
    elseif element.name == "delete-core" then
        gui.on_delete_core_button_click(player, element)
    elseif element.name == "confirmation-button" then
        gui.on_confirmation_button_click(player, element)
    elseif element.name == "unloader-filters" then
        gui.on_unloader_filters_button_click(player, element)
    else
        if element.parent then
            if element.parent.name == "unloader-filters-flow" then
                gui.on_unloader_filters_direction_click(player, element)
            elseif element.name:sub(-5) == "-mode" and element.parent.name == "hex-control-flow" then
                gui.on_hex_mode_button_click(player, element)
            elseif gui.is_descendant_of(element, "trade-overview") and element.parent.name == "trade-table" then
                gui.on_trade_overview_item_clicked(player, element)
            elseif gui.is_descendant_of(element, "hex-core") then
                gui.on_hex_core_trade_item_clicked(player, element)
            else -- this is just horribly ugly, maybe I'll clean it up later
                if element.parent.parent then
                    if element.parent.parent.name == "planet-flow" then
                        if element.parent["status"].sprite == "check-mark-green" then
                            element.parent["status"].sprite = "red-ex"
                        else
                            element.parent["status"].sprite = "check-mark-green"
                        end
                        gui.update_trade_overview(player)
                    end
                end
            end
        end
    end
end

function gui.on_supercharge_button_click(player, element)
    local hex_core = player.opened
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

function gui.on_hex_core_trade_item_clicked(player, element)
    local item_name = element.sprite:sub(6)
    local prot = prototypes.item[item_name]
    if not prot then return end
    gui.close_all(player)
    player.open_factoriopedia_gui(prot)
end

function gui.on_hex_mode_button_click(player, element)
    local hex_core = player.opened
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local mode = element.name:sub(1, -6)
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

function gui.on_unloader_filters_button_click(player, element)
    element.parent.parent["unloader-filters-flow"].visible = true
    element.enabled = false
end

function gui.on_unloader_filters_direction_click(player, element)
    local hex_core = player.opened
    if not hex_core then return end

    local dir = element.name
    local entities = player.surface.find_entities_filtered{
        name = "hex-core-loader",
        area = {{hex_core.position.x - 2, hex_core.position.y - 2}, {hex_core.position.x + 2, hex_core.position.y + 2}},
    }
    for _, e in pairs(entities) do
        if e.direction == defines.direction[dir] and e.loader_type == "output" then
            gui.close_all(player)
            player.opened = e
            break
        end
    end
end

function gui.on_clear_filters_button_click(player, element)
    local filter_frame = element.parent.parent
    for _, planet_filter in pairs(filter_frame["left"]["planet-flow"].children) do
        planet_filter["status"].sprite = "check-mark-green"
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

    gui.on_trade_overview_filter_changed(player)
end

function gui.on_confirmation_button_click(player, element)
    if element.parent.name == "delete-core-confirmation" then
        local hex_core = player.opened
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
    local hex_core = player.opened
    if not hex_core then return end
    if hex_core.surface.name ~= player.surface.name then return end

    lib.teleport_player(player, hex_core.position, hex_core.surface)
end

function gui.on_core_finder_button_click(player, element)
    if not storage.trade_overview.trades[player.name] then
        player.print("player trades not found")
        player.print(element.name)
        return
    end
    local trade_number = tonumber(element.name:sub(20))
    local trade = storage.trade_overview.trades[player.name][trade_number]
    if not trade then
        player.print("No trade found.")
        return
    end
    if not trade.hex_core_state then
        player.print("No core found.")
        return
    end
    local gps_str = lib.get_gps_str_from_hex_core(trade.hex_core_state.hex_core)
    player.print(gps_str)
end

function gui.on_tag_button_click(player, element)
    local hex_core = player.opened
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_number = tonumber(element.name:sub(12))
    local trade = trades.get_trade_from_id(state.trades[trade_number])
    local trade_str = lib.get_trade_img_str(trade)

    state.tags_created = (state.tags_created or -1) + 1

    player.force.add_chart_tag(state.hex_core.surface, {
        position = {x = state.hex_core.position.x, y = state.hex_core.position.y + state.tags_created * 4, surface = state.hex_core.surface},
        -- icon = {type = "entity", name = "hex-core"},
        text = trade_str,
        quality = state.hex_core.quality,
    })
end

function gui.on_claim_hex_button_click(player)
    local hex_core = player.opened
    if not hex_core then
        lib.log_error("on_claim_hex_button_click: Couldn't find hex core")
        return
    end

    local transformation = hex_grid.get_surface_transformation(hex_core.surface)

    if not transformation then
        lib.log_error("on_claim_hex_button_click: No transformation found")
        return
    end

    local hex_pos = hex_grid.get_hex_containing(hex_core.position, transformation.scale, transformation.rotation)

    if not hex_grid.can_claim_hex(player, player.surface, hex_pos) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford"}, "red"))
        return
    end

    hex_grid.claim_hex(hex_core.surface, hex_pos, player)
    gui.update_hex_core(player)
end

function gui.on_questbook_button_click(player)
    if player.opened and player.opened.name == "questbook" then
        gui.hide_questbook(player)
    else
        gui.close_all(player)
        gui.show_questbook(player)
    end
end

function gui.on_trade_overview_button_click(player)
    if player.opened and player.opened.name == "trade-overview" then
        gui.hide_trade_overview(player)
    else
        gui.close_all(player)
        gui.show_trade_overview(player)
    end
end

function gui.on_catalog_button_click(player)
    if player.opened and player.opened.name == "catalog" then
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
    local item_name = button.parent.name:sub(11)
    local surface_name = button.parent.parent.name:sub(7)
    gui.update_catalog_inspect_frame(player, surface_name, item_name)
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

    -- THIS SHOULD NOT BE NECESSARY
    -- THE BUG IN 2.0.43 WHICH MADE THIS NECESSARY
    -- HAS BEEN FIXED FOR 2.0.44 (https://forums.factorio.com/viewtopic.php?t=127900)
    -- (not yet released)
    -- THANKS DEVBRO
    gui.close_all(player)
end

function gui.on_gui_confirmed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- THIS SHOULD NOT BE NECESSARY
    -- THE BUG IN 2.0.43 WHICH MADE THIS NECESSARY
    -- HAS BEEN FIXED FOR 2.0.44 (https://forums.factorio.com/viewtopic.php?t=127900)
    -- (not yet released)
    -- THANKS DEVBRO
    gui.close_all(player)
end

function gui.on_gui_elem_changed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.element.name:sub(1, 11) == "input-item-" or event.element.name:sub(1, 12) == "output-item-" then
        gui.on_trade_overview_filter_changed(player)
    end
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

    for _, planet_filter_flow in pairs(filter_frame["left"]["planet-flow"].children) do
        local planet_name = planet_filter_flow.name
        -- local planet_checkbox = planet_filter_flow["checkbox"]
        -- filter.planets[planet_name] = planet_checkbox.state
        local planet_status = planet_filter_flow["status"]
        filter.planets[planet_name] = planet_status.sprite == "check-mark-green"
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

    -- Sorting stuff
    filter.sorting = {}

    local sorting_dropdown = filter_frame["right"]["sort-method"]["dropdown"]
    filter.sorting.method = sorting_dropdown.get_item(sorting_dropdown.selected_index)[1]:sub(19)
    filter.sorting.ascending = filter_frame["right"]["sort-direction"].switch_state == "left"
end

function gui.is_descendant_of(element, parent_name)
    local parent = element.parent
    if not parent then return false end
    if parent.name == parent_name then return true end
    return gui.is_descendant_of(parent, parent_name)
end

function gui.auto_width(element)
    element.style.horizontally_stretchable = true
    element.style.horizontally_squashable = true
end

function gui.auto_height(element)
    element.style.vertically_stretchable = true
    element.style.vertically_squashable = true
end

function gui.auto_width_height(element)
    gui.auto_width(element)
    gui.auto_height(element)
end



return gui
