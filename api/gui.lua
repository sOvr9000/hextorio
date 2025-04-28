local lib = require "api.lib"
local hex_grid = require "api.hex_grid"
local item_values = require "api.item_values"
local coin_tiers  = require "api.coin_tiers"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local sets = require "api.sets"

local gui = {}



function gui.reinitialize_everything(player)
    -- called during migration

    local frame

    -- frame = player.gui.screen["hex-core"]
    -- if frame then frame.destroy() end
    -- gui.init_hex_core(player)

    frame = player.gui.screen["questbook"]
    if frame then frame.destroy() end
    gui.init_questbook(player)

    frame = player.gui.screen["trade-overview"]
    if frame then frame.destroy() end
    gui.init_trade_overview(player)

    frame = player.gui.screen["catalog"]
    if frame then frame.destroy() end
    gui.init_catalog(player)

    local button

    button = player.gui.top["questbook-button"]
    if button then button.destroy() end

    button = player.gui.top["trade-overview-button"]
    if button then button.destroy() end

    button = player.gui.top["catalog-button"]
    if button then button.destroy() end

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
    if player.gui.top["trade-overview-button"] then return end
    local trade_overview_button = player.gui.top.add {
        type = "sprite-button",
        name = "trade-overview-button",
        sprite = "trade-overview",
    }
end

function gui.init_catalog_button(player)
    if player.gui.top["catalog-button"] then return end
    local catalog_button = player.gui.top.add {
        type = "sprite-button",
        name = "catalog-button",
        sprite = "catalog",
    }
end

function gui.init_hex_core(player)
    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right,
    }
    local hex_core_gui = player.gui.relative.add {type = "frame", name = "hex-core", direction = "vertical", anchor = anchor}
    hex_core_gui.caption = {"hex-core-gui.title"}
    -- hex_core_gui.style.size = {width = 385, height = 625}
    hex_core_gui.style.size = {width = 444, height = 625}

    local resources_header = hex_core_gui.add {type = "label", name = "resources-header", caption = {"hex-core-gui.initial-resources"}}
    resources_header.style.font = "heading-2"

    local resources_flow = hex_core_gui.add {type = "flow", name = "resources-flow", direction = "horizontal"}

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local claim_flow = hex_core_gui.add {type = "flow", name = "claim-flow", direction = "vertical"}
    local claim_price = gui.create_coin_tier(claim_flow, "claim-price")
    local claim_hex = claim_flow.add {type = "button", name = "claim-hex", caption = {"hex-core-gui.claim-hex"}, style = "confirm_button"}
    claim_hex.tooltip = nil

    local claimed_by = hex_core_gui.add {type = "label", name = "claimed-by", caption = {"hex-core-gui.claimed-by"}}
    claimed_by.style.font = "heading-2"

    local hex_control_flow = hex_core_gui.add {type = "flow", name = "hex-control-flow", direction = "horizontal"}
    hex_control_flow.visible = false

    local teleport = hex_control_flow.add {type = "sprite-button", name = "teleport", sprite = "teleport"}
    teleport.tooltip = {"hex-core-gui.teleport-tooltip"}

    local delete_core = hex_control_flow.add {type = "sprite-button", name = "delete-core", sprite = "utility/deconstruction_mark"}
    delete_core.tooltip = {"hex-core-gui.delete-core-tooltip"}

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
    questbook.style.size = {width = 400, height = 600}

    gui.add_titlebar(questbook, {"hextorio-questbook.questbook-title"})
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

    local filter_frame = frame.add {type = "frame", name = "filter-frame", direction = "vertical"}
    local clear_filters_button = filter_frame.add {type = "button", name = "clear-filters-button", caption = {"hextorio-gui.clear-filters"}}
    local planet_flow = filter_frame.add {type = "flow", name = "planet-flow", direction = "horizontal"}
    filter_frame.add {type = "line", direction = "horizontal"}
    local trade_contents_flow = filter_frame.add {type = "flow", name = "trade-contents-flow", direction = "vertical"}
    local trade_contents_label = trade_contents_flow.add {type = "label", name = "label", caption = {"hextorio-gui.trade-contents"}}
    local trade_contents_frame = trade_contents_flow.add {type = "frame", name = "frame", direction = "horizontal"}
    filter_frame.add {type = "line", direction = "horizontal"}
    local processing_flow = filter_frame.add {type = "flow", name = "processing-flow", direction = "horizontal"}
    local processing_label = processing_flow.add {type = "label", name = "label", caption = {"hextorio-gui.processing-finished"}}
    local processing_progress_bar = processing_flow.add {type = "progressbar", name = "progressbar", value = 0}

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
            name = "output-item-" .. i,
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
    local scroll_pane = trade_table_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.style.vertically_stretchable = true
    trade_table_frame.style.vertically_stretchable = true
    trade_table_frame.style.vertically_squashable = true
    trade_table_frame.style.natural_width = 700
end

function gui.init_catalog(player)
    local frame = player.gui.screen.add {
        type = "frame",
        name = "catalog",
        direction = "vertical",
    }
    frame.style.width = 900
    frame.style.height = 700

    gui.add_titlebar(frame, {"hextorio-gui.catalog"})

    local flow = frame.add {type = "flow", name = "flow", direction = "horizontal"}

    local catalog_frame = flow.add {type = "frame", name = "catalog-frame", direction = "vertical"}
    catalog_frame.style.natural_width = 500
    catalog_frame.style.vertically_stretchable = true
    catalog_frame.style.horizontally_squashable = true

    local scroll_pane = catalog_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.style.vertically_stretchable = true
    scroll_pane.style.vertically_squashable = true

    local inspect_frame = flow.add {type = "frame", name = "inspect-frame", direction = "vertical"}
    -- inspect_frame.style.natural_width = 400
    inspect_frame.style.vertically_stretchable = true
    inspect_frame.style.horizontally_stretchable = true

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
        -- progress_bar_flow.style.natural_width = 
        progress_bar_flow.style.horizontally_stretchable = true
        progress_bar_flow.style.horizontally_squashable = true
        for j = 2, 5 do
            local pb_ranks = progress_bar_flow.add {type = "progressbar", name = "pb-ranks-" .. j, value = 0}
            pb_ranks.tooltip = lib.get_rank_img_str(j) .. " x0"
            pb_ranks.style.color = storage.item_ranks.rank_colors[j]
            pb_ranks.style.horizontally_stretchable = true
            pb_ranks.style.horizontally_squashable = true
        end

        local table = scroll_pane.add {type = "table", name = "table-" .. surface_name, column_count = 9}
        table.style.horizontally_stretchable = true
        table.style.horizontally_squashable = true

        for j = 1, #items_sorted_by_value do
            local item_name = items_sorted_by_value[j]
            if item_name:sub(-5) ~= "-coin" then
                local rank = item_ranks.get_item_rank(item_name)

                local rank_flow = table.add {
                    type = "flow",
                    name = "rank-flow-" .. item_name,
                    direction = "vertical",
                }

                rank_flow.style.top_margin = 20
                rank_flow.style.right_margin = 10

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

function gui.give_item_tooltip(player, surface_name, sprite_button, trade_side)
    local item_name
    local rich_type
    if sprite_button.sprite:sub(1, 5) == "item/" then
        item_name = sprite_button.sprite:sub(6)
        rich_type = "item"
        if item_name:sub(-5) == "-coin" then return end
    elseif sprite_button.sprite:sub(1, 7) == "entity/" then
        item_name = sprite_button.sprite:sub(8)
        rich_type = "fluid"
    else
        lib.log_error("gui.give_item_tooltip: Could not determine item name from sprite: " .. sprite_button.sprite)
        return
    end

    local hex_coin_value = item_values.get_item_value(surface_name, "hex-coin")
    local item_count = sprite_button.number or 1
    local value = item_values.get_item_value(surface_name, item_name)
    local scaled_value = value / hex_coin_value
    local rank = item_ranks.get_item_rank(item_name)

    local true_sell_value = value + item_values.get_item_sell_value_bonus_from_rank(surface_name, item_name, rank)
    local scaled_true_sell_value = true_sell_value / hex_coin_value
    local true_buy_value = value + item_values.get_item_buy_value_bonus_from_rank(surface_name, item_name, rank)
    local scaled_true_buy_value = true_buy_value / hex_coin_value

    local rank_bonus_type, rank_mod_str, scaled_true_value
    if trade_side == "buy" then
        rank_bonus_type = {"hextorio-gui.rank-bonus-buying"}
        rank_mod_str = "- " .. coin_tiers.coin_to_text(scaled_value - scaled_true_buy_value, false, 4)
        scaled_true_value = scaled_true_buy_value
    elseif trade_side == "sell" then
        rank_bonus_type = {"hextorio-gui.rank-bonus-selling"}
        rank_mod_str = "+ " .. coin_tiers.coin_to_text(scaled_true_sell_value - scaled_value, false, 4)
        scaled_true_value = scaled_true_sell_value
    else
        scaled_true_value = scaled_value
    end

    local rank_bonus_str
    if rank_bonus_type and rank > 1 then
        rank_bonus_str = {"",
            "\n[color=green]",
            rank_bonus_type,
            "[.color]\n" .. rank_mod_str,
        }
    else
        rank_bonus_str = ""
    end

    sprite_button.tooltip = {"",
        "[font=heading-1]",
        {"hextorio-gui.rank"},
        "[.font] " .. lib.get_rank_img_str(rank),
        "\n\n[font=heading-2][color=green]",
        {"hextorio-gui.item-value"},
        "[.color][.font]\n[" .. rich_type .. "=" .. item_name .. "]x1 = ",
        coin_tiers.coin_to_text(scaled_value, false, 4),
        rank_bonus_str,
        "\n\n[font=heading-2][color=purple]",
        {"hextorio-gui.stack-value-total"},
        "[.color][.font]\n[" .. rich_type .. "=" .. item_name .. "]x" .. item_count .. " = ",
        coin_tiers.coin_to_text(item_count * scaled_true_value, false, nil)
    }
end

function gui.update_trades_scroll_pane(player, trades_scroll_pane, trades_list, show_toggle_trade, show_tag_creator, show_core_finder)
    trades_scroll_pane.clear()

    local size = 40
    for trade_number, trade in ipairs(trades_list) do
        local trade_flow = trades_scroll_pane.add {
            type = "flow",
            name = "trade-" .. trade_number,
            direction = "horizontal",
        }
        if show_toggle_trade then
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
        if show_tag_creator then
            local tag_button = trade_flow.add {
                type = "sprite-button",
                name = "tag-button-" .. trade_number,
                sprite = "utility/show_tags_in_map_view",
            }
            -- tag_button.style.left_margin = 5
            tag_button.style.top_margin = 10
            tag_button.tooltip = {"hex-core-gui.tag-button"}
        end
        if show_core_finder then
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
            direction = "horizontal",
        }
        trade_frame.style.left_margin = 10
        trade_frame.style.natural_height = (size + 20) / 1.2 - 5
        trade_frame.style.horizontally_stretchable = true
        local trade_table = trade_frame.add {
            type = "table",
            name = "trade_table",
            column_count = 7,
        }
        local total_empty = 0
        for i = 1, 3 do
            if i <= #trade.input_items then
                local input_item = trade.input_items[i]
                local input = trade_table.add {
                    type = "sprite-button",
                    name = "input" .. tostring(i) .. "-" .. input_item.name,
                    sprite = "item/" .. input_item.name,
                    number = input_item.count,
                }
                gui.give_item_tooltip(player, trade.surface_name, input, "sell")
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
            sprite = "trade-arrow",
        }
        trade_arrow_sprite.style.width = size / 1.2
        trade_arrow_sprite.style.height = size / 1.2
        trade_arrow_sprite.style.top_margin = 2
        trade_arrow_sprite.tooltip = trades.get_total_values_str(trade)
        for i = 1, 3 do
            local j = 4 - i
            if j <= #trade.output_items then
                local output_item = trade.output_items[j]
                local output = trade_table.add {
                    type = "sprite-button",
                    name = "output" .. tostring(i) .. "-" .. tostring(output_item.name),
                    sprite = "item/" .. output_item.name,
                    number = output_item.count,
                }
                gui.give_item_tooltip(player, trade.surface_name, output, "buy")
            else
                total_empty = total_empty + 1
                local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
                empty.style.natural_width = size / 1.2
                empty.style.natural_height = size / 1.2
                empty.ignored_by_interaction = true
            end
        end
    end
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
            gui.give_item_tooltip(player, surface_name, sprite_button, nil)
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

    local coin = state.claim_price
    gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin)

    if state.claimed then
        frame["claim-flow"].visible = false
        local claimed_by_name = state.claimed_by or {"hextorio.server"}
        local claimed_timestamp = state.claimed_timestamp or 0
        frame["claimed-by"].visible = true
        frame["claimed-by"].caption = {"hex-core-gui.claimed-by", claimed_by_name, lib.ticks_to_string(claimed_timestamp)}

        frame["trades-total-sold"].visible = true
        frame["trades-total-bought"].visible = true

        local total_items_sold = state.total_items_sold or {}
        lib.log("gui.update_hex_core: total items sold: " .. serpent.line(total_items_sold))
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
        lib.log("gui.update_hex_core: total items bought: " .. serpent.line(total_items_bought))
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
        frame["hex-control-flow"]["delete-core"].enabled = true
        frame["hex-control-flow"]["delete-core"].tooltip = {"hex-core-gui.delete-core-tooltip", coin_tiers.coin_to_text(hex_grid.get_delete_core_cost(hex_core))}
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
    end

    frame["delete-core-confirmation"].visible = false

    gui.update_trades_scroll_pane(player, frame.trades, state.trades, state.claimed, true, false)
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
    local any = false

    resources_flow.clear()
    for resource_name, amount in pairs(resources) do
        local sprite = "item/" .. resource_name
        if state.is_oil then
            sprite = "entity/crude-oil"
        end
        local resource = resources_flow.add {
            type = "sprite-button",
            sprite = sprite,
            number = amount,
        }
        gui.give_item_tooltip(player, hex_core.surface.name, resource, nil)
        any = true
    end

    if not any then
        resources_flow.add {
            type = "label",
            name = "no-resources",
            caption = {"hex-core-gui.no-resources"},
        }
    end
end

function gui.update_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then
        gui.init_questbook(player)
    end
    -- todo
end

function gui.update_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then
        gui.init_trade_overview(player)
        frame = player.gui.screen["trade-overview"]
    end

    -- Ensure that all available planets are listed
    local filter_frame = frame["filter-frame"]
    for surface_name, surface in pairs(game.surfaces) do
        if surface_name ~= "hextorio-temp" and surface_name ~= "space-platform" then
            if not filter_frame["planet-flow"][surface_name] then
                local surface_flow = filter_frame["planet-flow"].add {
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
                -- surface_status.style.width = 24
                -- surface_status.style.height = 24
                surface_status.style.size = {24, 24}
            end
        end
    end

    gui.update_player_trade_overview_filters(player)
    local filter = gui.get_player_trade_overview_filter(player)

    -- lib.log(serpent.line(filter))

    local trades_scroll_pane = frame["trade-table-frame"]["scroll-pane"]

    if not filter.planets then
        filter.planets = sets.new {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"}
    end

    -- local empty_input_filter = true
    -- if filter.input_items then
    --     empty_input_filter = next(filter.input_items) ~= nil
    -- end

    -- local empty_output_filter = true
    -- if filter.output_items then
    --     empty_output_filter = next(filter.output_items) ~= nil
    -- end

    local function filter_condition(trade)
        if filter.input_items then
            for _, input_item_name in pairs(filter.input_items) do
                local found = false
                for _, input in pairs(trade.input_items) do
                    if input.name == input_item_name then
                        found = true
                    end
                end
                if not found then
                    return false
                end
            end
        end

        if filter.output_items then
            for _, output_item_name in pairs(filter.output_items) do
                local found = false
                for _, output in pairs(trade.output_items) do
                    if output.name == output_item_name then
                        found = true
                    end
                end
                if not found then
                    return false
                end
            end
        end

        return true
    end

    local trades_list = {}
    -- lib.log(serpent.line(filter.planets))
    for surface_id, surface_hexes in pairs(storage.hex_grid.surface_hexes) do
        local surface = game.get_surface(surface_id)
        if surface then
            local surface_name = surface.name
            -- lib.log(surface_name)
            if filter.planets[surface_name] then
                for _, Q in pairs(surface_hexes) do
                    for _, state in pairs(Q) do
                        if state.trades then
                            -- lib.log(serpent.block(state.trades))
                            for _, trade in pairs(state.trades) do
                                if filter_condition(trade) then
                                    table.insert(trades_list, trade)
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    -- lib.log(serpent.block(trades_list))

    storage.trade_overview.trades[player.name] = trades_list
    gui.update_trades_scroll_pane(player, trades_scroll_pane, trades_list, false, false, true)
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

function gui.add_info(element, info_type)
    local info = element.add {
        type = "label",
        name = info_type,
        caption = {"", "[color=117,218,251][img=virtual-signal.signal-info] ", {"hextorio-gui." .. info_type}, "[.color]"},
    }
    info.style.single_line = false
    info.style.horizontally_squashable = true
    info.style.horizontally_stretchable = true
    info.style.vertically_squashable = true
    info.style.vertically_stretchable = true
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

    inspect_frame.clear()
    if not item_name then return end

    local rank_obj = item_ranks.get_rank_obj(item_name)

    local inspect_header = inspect_frame.add {
        type = "label",
        name = "inspect-header",
        caption = {"", "[font=heading-1]", {"hextorio-gui.catalog-item", "[item=" .. item_name .. "]"}, "[.font]"},
    }

    inspect_frame.add {type = "line", direction = "horizontal"}

    local rank_label = inspect_frame.add {
        type = "label",
        name = "rank-label",
        caption = {"", "[font=heading-2]", {"hextorio-gui.rank"}, " " .. lib.get_rank_img_str(rank_obj.rank) .. "[.font]"},
    }

    local bonuses_label = inspect_frame.add {
        type = "label",
        name = "bonuses-label",
        caption = {"hextorio-gui.bonuses"},
    }
    bonuses_label.style.font = "heading-2"

    if rank_obj.rank > 1 then
        local bonus_sell = inspect_frame.add {
            type = "label",
            name = "bonus-sell",
            caption = {"hextorio-gui.rank-bonus-sells-for-more", "[color=green]" .. math.floor(100 * item_ranks.get_rank_bonus_effect(rank_obj.rank)) .. "[.color]"},
        }
        bonus_sell.style.single_line = false
        bonus_sell.style.horizontally_squashable = true
        bonus_sell.style.horizontally_stretchable = true
        bonus_sell.style.vertically_squashable = true
        bonus_sell.style.vertically_stretchable = true

        local bonus_buy = inspect_frame.add {
            type = "label",
            name = "bonus-buy",
            caption = {"hextorio-gui.rank-bonus-buys-for-less", "[color=green]" .. math.floor(100 * (1 - 1 / (1 + item_ranks.get_rank_bonus_effect(rank_obj.rank)))) .. "[.color]"},
        }
        bonus_buy.style.single_line = false
        bonus_buy.style.horizontally_squashable = true
        bonus_buy.style.horizontally_stretchable = true
        bonus_buy.style.vertically_squashable = true
        bonus_buy.style.vertically_stretchable = true
    else
        local none_label = inspect_frame.add {
            type = "label",
            name = "none",
            caption = {"hextorio-gui.rank-bonus-none"},
        }
    end

    for i = 2, rank_obj.rank do
        local rank_bonus_unique = inspect_frame.add {
            type = "label",
            name = "rank-bonus-unique-" .. i,
            caption = {"", "[img=" .. storage.item_ranks.rank_star_sprites[i] .. "] ", {"hextorio-gui.rank-bonus-unique-" .. i, "[color=purple]" .. lib.format_percentage(lib.runtime_setting_value("rank-" .. i .. "-effect"), 1, false) .. "[.color]"}},
        }
        rank_bonus_unique.style.single_line = false
        rank_bonus_unique.style.horizontally_squashable = true
        rank_bonus_unique.style.horizontally_stretchable = true
        rank_bonus_unique.style.vertically_squashable = true
        rank_bonus_unique.style.vertically_stretchable = true
    end

    inspect_frame.add {type = "line", direction = "horizontal"}

    local rank_up_instructions = inspect_frame.add {
        type = "label",
        name = "rank-up-instructions",
        caption = {"", "[img=" .. storage.item_ranks.rank_star_sprites[math.min(5, (rank_obj.rank + 1))] .. "] ", {"hextorio-gui.rank-up-instructions-" .. rank_obj.rank}},
    }
    rank_up_instructions.style.single_line = false
    rank_up_instructions.style.horizontally_squashable = true
    rank_up_instructions.style.horizontally_stretchable = true
    rank_up_instructions.style.vertically_squashable = true
    rank_up_instructions.style.vertically_stretchable = true

    if rank_obj.rank == 1 then
        gui.add_info(inspect_frame, "buying-info")
        gui.add_info(inspect_frame, "selling-info")
    elseif rank_obj.rank == 2 or rank_obj.rank == 3 then
        gui.add_info(inspect_frame, "selling-info")
    end

    -- inspect_frame.add {type = "line", direction = "horizontal"}
end

function gui.update_coin_tier(flow, coin)
    -- Don't show leading zeroes, but show intermediate zeroes, and always show hex coin even if total cost is zero.
    local hex_coin_sprite = flow['hex-coin']
    hex_coin_sprite.number = coin.values[1]

    local visible = false
    if coin.values[4] > 0 then visible = true end
    local hexaprism_coin_sprite = flow['hexaprism-coin']
    hexaprism_coin_sprite.number = coin.values[4]
    hexaprism_coin_sprite.visible = visible

    if coin.values[3] > 0 then visible = true end
    local meteor_coin_sprite = flow['meteor-coin']
    meteor_coin_sprite.number = coin.values[3]
    meteor_coin_sprite.visible = visible

    if coin.values[2] > 0 then visible = true end
    local gravity_coin_sprite = flow['gravity-coin']
    gravity_coin_sprite.number = coin.values[2]
    gravity_coin_sprite.visible = visible
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

function gui.on_button_click(player, element)
    if element.name == "clear-filters-button" then
        gui.on_clear_filters_button_click(player, element)
    end
end

function gui.on_checkbox_click(player, element)
    if element.name:sub(1, 12) == "toggle-trade" then
        gui.on_toggle_trade_checkbox_click(player, element)
    elseif element.parent.parent.name == "planet-flow" then
        gui.on_trade_overview_filter_changed(player)
    end
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
    elseif element.name == "delete-core" then
        gui.on_delete_core_button_click(player, element)
    elseif element.name == "confirmation-button" then
        gui.on_confirmation_button_click(player, element)
    elseif element.parent.parent.name == "planet-flow" then
        if element.parent["status"].sprite == "check-mark-green" then
            element.parent["status"].sprite = "red-ex"
        else
            element.parent["status"].sprite = "check-mark-green"
        end
        gui.update_trade_overview(player)
    end
end

function gui.on_clear_filters_button_click(player, element)
    local filter_frame = element.parent
    for _, planet_filter in pairs(filter_frame["planet-flow"].children) do
        planet_filter["status"].sprite = "check-mark-green"
    end

    for i = 1, 3 do
        filter_frame["trade-contents-flow"]["frame"]["input-item-" .. i].elem_value = nil
    end

    for i = 1, 3 do
        filter_frame["trade-contents-flow"]["frame"]["output-item-" .. i].elem_value = nil
    end

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
    local trade = state.trades[trade_number]
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
    local trade_contents_frame = filter_frame["trade-contents-flow"]["frame"]

    if not filter.planets then
        filter.planets = {}
    end

    for _, planet_filter_flow in pairs(filter_frame["planet-flow"].children) do
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
end



return gui
