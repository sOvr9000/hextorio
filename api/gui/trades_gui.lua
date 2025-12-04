
local lib = require "api.lib"
local gui = require "api.gui.core_gui"
local trades = require "api.trades"
local coin_tiers = require "api.coin_tiers"
local gui_events = require "api.gui.gui_events"
local event_system = require "api.event_system"
local quests = require "api.quests"
local hex_grid = require "api.hex_grid"

local trades_gui = {}



function trades_gui._process_trades_scroll_panes()
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
                trades_gui._update_trades_scroll_pane_tick(process)
            end
        end
    end
end

function trades_gui._update_trades_scroll_pane_tick(process)
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

        trades_gui.add_trade_elements(process.player, process.trades_scroll_pane, trade, trade_number, process.params)
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

function trades_gui.add_trade_elements(player, element, trade, trade_number, params)
    local size = 40

    local trade_flow = element.add {
        type = "flow",
        name = "trade-" .. trade_number,
        direction = "horizontal",
    }

    local function create_ping_button(element)
        local ping_button = element.add {
            type = "sprite-button",
            name = "ping-button",
            sprite = "utility/shoot_cursor_red",
        }
        ping_button.tooltip = {"hextorio-gui.ping-in-chat"}

        gui_events.register(ping_button, "on-clicked", function()
            if not trade.hex_core_state or not trade.hex_core_state.hex_core then return end

            local trade_str = lib.get_trade_img_str(trade, trades.is_interplanetary_trade(trade))
            local gps_str = lib.get_gps_str_from_hex_core(trade.hex_core_state.hex_core)

            game.print({"hextorio.player-trade-ping", player.name, trade_str, gps_str})
            quests.set_progress_for_type("ping-trade", 1)
        end)
    end

    if params.show_core_finder then
        local core_finder_button = trade_flow.add {
            type = "sprite-button",
            name = "core-finder-button-" .. trade_number,
            sprite = "utility/gps_map_icon",
        }
        core_finder_button.tooltip = {"hextorio-gui.core-finder-button"}
        gui_events.register(core_finder_button, "on-clicked", function() trades_gui.on_core_finder_button_click(player, core_finder_button, trade_number) end)
    end

    if not params.expanded and params.show_ping_button then
        create_ping_button(trade_flow)
    end

    local quality_to_show = params.quality_to_show or "normal"
    local quality_cost_multipliers = lib.get_quality_cost_multipliers()
    local quality_cost_mult = quality_cost_multipliers[quality_to_show]

    local trade_frame = trade_flow.add {
        type = "flow",
        name = "frame",
        direction = "vertical",
    }
    -- trade_frame.style.left_margin = 10
    trade_frame.style.natural_height = (size + 20) / 1.2 - 5
    trade_frame.style.width = 381 / 1.2

    local trade_table = trade_frame.add {
        type = "table",
        name = "trade-table",
        column_count = 8,
    }

    if params.expanded and params.is_configuration_unlocked then
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
            gui_events.register(toggle_trade_button, "on-clicked", function() event_system.trigger("trade-toggle-button-clicked", player, toggle_trade_button) end)
        end

        if params.show_tag_creator then
            local tag_button = trade_control_flow.add {
                type = "sprite-button",
                name = "tag-button-" .. trade_number,
                sprite = "utility/show_tags_in_map_view",
            }
            tag_button.tooltip = {"hex-core-gui.tag-button"}
            gui_events.register(tag_button, "on-clicked", function() event_system.trigger("trade-tag-button-clicked", player, tag_button) end)
        end

        if params.show_ping_button then
            create_ping_button(trade_control_flow)
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
            gui_events.register(add_to_filters_button, "on-clicked", function() event_system.trigger("trade-add-to-filters-button-clicked", player, add_to_filters_button) end)
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
            gui_events.register(min_quality, "on-elem-selected", function() event_system.trigger("trade-quality-bounds-selected", player, min_quality, trade_number) end)

            local max_quality = trade_control_flow.add {
                type = "choose-elem-button",
                name = "max-quality-" .. trade_number,
                elem_type = "signal",
                signal = {type = "quality", name = allowed_qualities[1]},
            }
            max_quality.tooltip = {"hex-core-gui.maximum-trade-quality"}
            gui_events.register(max_quality, "on-elem-selected", function() event_system.trigger("trade-quality-bounds-selected", player, max_quality, trade_number) end)
        end
    end

    local total_empty = 0
    for i = 1, 3 do
        if i <= #trade.input_items then
            local input_item = trade.input_items[i]
            local input_sprite_button = trade_table.add {
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
                input_sprite_button.number = math.ceil(other_value)
                input_sprite_button.sprite = "item/" .. coin_name
            else
                input_sprite_button.quality = quality_to_show
            end
            gui.give_item_tooltip(player, trade.surface_name, input_sprite_button)
            gui_events.register(input_sprite_button, "on-clicked", function() event_system.trigger("trade-item-clicked", player, input_sprite_button, input_item.name, true) end)
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
    trade_arrow_sprite.style.left_margin = 4
    trade_arrow_sprite.style.stretch_image_to_widget_size = true

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
            local output_sprite_button = trade_table.add {
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
                output_sprite_button.number = math.ceil(other_value)
                output_sprite_button.sprite = "item/" .. coin_name
            else
                output_sprite_button.quality = quality_to_show
            end
            gui.give_item_tooltip(player, trade.surface_name, output_sprite_button)
            gui_events.register(output_sprite_button, "on-clicked", function() event_system.trigger("trade-item-clicked", player, output_sprite_button, output_item.name, false) end)
        else
            total_empty = total_empty + 1
            local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
            empty.style.natural_width = size / 1.2
            empty.style.natural_height = size / 1.2
            empty.ignored_by_interaction = true
        end
    end
end

function trades_gui.update_trades_scroll_pane(player, trades_scroll_pane, trades_list, params)
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
        process.processing_flow = process.trades_scroll_pane.parent.parent.parent["filter-frame"]["left"]["buttons-flow"]["processing-flow"]
    else
        process.immediate = true
    end
    storage.gui.trades_scroll_pane_update[player.name] = process
end

function trades_gui.on_core_finder_button_click(player, element, trade_number)
    if not storage.trade_overview.trades[player.name] then
        lib.log_error("gui.on_core_finder_button_click: Player trades list not found")
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

    event_system.trigger("core-finder-button-clicked", player, element)

    player.opened = trade.hex_core_state.hex_core
end



return trades_gui
