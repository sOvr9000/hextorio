
local lib = require "api.lib"
local gui = require "api.gui.core_gui"
local trades = require "api.trades"
local coin_tiers = require "api.coin_tiers"
local event_system = require "api.event_system"
local gameplay_statistics = require "api.gameplay_statistics"
local quests = require "api.quests"
local core_gui = require "api.gui.core_gui"

local trades_gui = {}



function trades_gui.register_events()
    event_system.register_gui("gui-clicked", "ping-button", trades_gui.on_ping_button_clicked)
    event_system.register_gui("gui-clicked", "core-finder", trades_gui.on_core_finder_button_click)
    event_system.register_gui("gui-clicked", "toggle-trade", trades_gui.on_toggle_trade_button_clicked)
    event_system.register_gui("gui-clicked", "tag-button", trades_gui.on_trade_tag_button_clicked)
    event_system.register_gui("gui-clicked", "add-to-filters", trades_gui.on_trade_add_to_filters_button_clicked)
    event_system.register_gui("gui-clicked", "trade-item", trades_gui.on_trade_item_clicked)
    event_system.register_gui("gui-clicked", "trade-arrow", trades_gui.on_trade_arrow_clicked)
    event_system.register_gui("gui-elem-changed", "trade-quality", trades_gui.on_trade_quality_selected)

    -- event_system.register("favorite-trade-key-pressed", trades_gui.on_favorite_trade_key_pressed)
end

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

    local params = process.params

    local batch_size = 24
    if process.immediate then
        batch_size = #process.trades_list
    end

    local group_flow
    if params.batched then
        if params.table_batch_def then
            group_flow = process.trades_scroll_pane.add {
                type = "table",
                name = process.batch_idx,
                column_count = params.table_batch_def.column_count or 2,
            }
            group_flow.style.horizontal_spacing = params.table_batch_def.horizontal_spacing or (28 / 1.2)
        else
            group_flow = process.trades_scroll_pane.add {
                type = "flow",
                name = process.batch_idx,
                direction = "vertical",
            }
        end
    else
        group_flow = process.trades_scroll_pane
    end

    for trade_number = process.batch_idx, math.min(#process.trades_list, process.batch_idx + batch_size - 1) do
        local trade = process.trades_list[trade_number]
        if not trade then
            lib.log_error("trade_number = " .. trade_number .. " is out of bounds for list of " .. #process.trades_list .. " trades")
            break
        end

        if process.params.expanded and process.params.is_configuration_unlocked and trade_number ~= 1 then
            local line = process.trades_scroll_pane.add {
                type = "line",
                direction = "horizontal",
            }
            line.style.top_margin = 3
            line.style.bottom_margin = 6
        end

        trades_gui.add_trade_elements(process.player, group_flow, trade, trade_number, process.params)
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

    local function create_ping_button(e)
        local ping_button = e.add {
            type = "sprite-button",
            name = "ping-button",
            sprite = "utility/shoot_cursor_red",
            tags = {handlers = {["gui-clicked"] = "ping-button"}, trade_number = trade_number},
            raise_hover_events = true,
        }
        ping_button.tooltip = {"hextorio-gui.ping-in-chat"}
    end

    if params.show_core_finder then
        local core_finder_button = trade_flow.add {
            type = "sprite-button",
            name = "core-finder-button-" .. trade_number,
            sprite = "utility/gps_map_icon",
            tags = {handlers = {["gui-clicked"] = "core-finder"}, trade_number = trade_number},
            raise_hover_events = true,
        }
        core_finder_button.tooltip = {"hextorio-gui.core-finder-button"}
    end

    if not params.expanded and params.show_ping_button then
        create_ping_button(trade_flow)
    end

    -- Quality to show is first set by params, but if not set, it defaults to the trade's current set quality, and if that for some reason doesn't exist, it defaults to normal quality.
    local quality_to_show = params.quality_to_show or (trade.allowed_qualities or {})[1] or "normal"
    local quality_cost_multipliers = lib.get_quality_cost_multipliers()
    local quality_cost_mult = quality_cost_multipliers[quality_to_show]

    local trade_frame = trade_flow.add {
        type = "flow",
        name = "frame",
        direction = "vertical",
    }
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
            raise_hover_events = true,
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
                tags = {handlers = {["gui-clicked"] = "toggle-trade"}},
                raise_hover_events = true,
            }
            toggle_trade_button.tooltip = {"hex-core-gui.trade-checkbox-tooltip"}
        end

        if params.show_tag_creator then
            local tag_button = trade_control_flow.add {
                type = "sprite-button",
                name = "tag-button-" .. trade_number,
                sprite = "utility/show_tags_in_map_view",
                tooltip = {"hex-core-gui.tag-button"},
                tags = {handlers = {["gui-clicked"] = "tag-button"}},
                raise_hover_events = true,
            }
        end

        if params.show_ping_button then
            create_ping_button(trade_control_flow)
        end

        if params.show_productivity_info then
            local prod_info = trade_control_flow.add {
                type = "sprite-button",
                name = "productivity-info",
                sprite = "item/productivity-module-3",
                raise_hover_events = true,
            }
            gui.give_productivity_tooltip(prod_info, trade, quality_to_show, quality_cost_mult)
        end

        if params.show_add_to_filters then
            local add_to_filters_button = trade_control_flow.add {
                type = "sprite-button",
                name = "add-to-filters-" .. trade_number,
                sprite = "item/loader",
                tags = {handlers = {["gui-clicked"] = "add-to-filters"}},
                raise_hover_events = true,
            }
            add_to_filters_button.tooltip = {"hex-core-gui.add-to-filters-tooltip"}
        end

        if params.show_quality_bounds then
            -- TODO: optimize by caching elem_filter results, but it's not super critical as long as no one is putting 100+ trades in a single hex core (other performance issues probably would arise from that than just this)
            local elem_filters = {}
            local core_quality_level = 0
            if trade.hex_core_state and trade.hex_core_state.hex_core and trade.hex_core_state.hex_core.valid then
                core_quality_level = trade.hex_core_state.hex_core.quality.level
            end
            for _, q in pairs(lib.get_all_unlocked_qualities()) do
                if q.level <= core_quality_level then
                    elem_filters[#elem_filters+1] = {filter = "name", name = "pseudo-signal-quality-" .. q.name}
                end
            end

            local allowed_qualities = trade.allowed_qualities or {"normal"}
            local quality_button = trade_control_flow.add {
                type = "choose-elem-button",
                name = "trade-quality-" .. trade_number,
                elem_type = "item",
                item = "pseudo-signal-quality-" .. allowed_qualities[1],
                tags = {handlers = {["gui-elem-changed"] = "trade-quality"}, trade_number = trade_number},
                raise_hover_events = true,
                elem_filters = elem_filters,
            }
            quality_button.tooltip = {"hex-core-gui.trade-quality"}
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
                tags = {handlers = {["gui-clicked"] = "trade-item"}, item_name = input_item.name, is_input = true},
                raise_hover_events = true,
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
        raise_hover_events = true,
        tags = {handlers = {["gui-clicked"] = "trade-arrow"}},
    }
    trade_arrow_sprite.style.width = size / 1.2
    trade_arrow_sprite.style.height = size / 1.2
    trade_arrow_sprite.style.top_margin = 2
    trade_arrow_sprite.style.left_margin = 4
    trade_arrow_sprite.style.stretch_image_to_widget_size = true

    local prod = trades.get_productivity(trade, quality_to_show)
    if params.show_productivity_bar and prod ~= 0 then
        local current_prod_value = trades.get_current_prod_value(trade, quality_to_show)

        local prod_bar = trade_frame.add {
            type = "progressbar",
            name = "prod-bar",
            value = current_prod_value,
            style = "bonus_progressbar",
            raise_hover_events = true,
        }
        core_gui.auto_width(prod_bar)

        local desc
        if prod > 0 then
            desc = {"hextorio-gui.positive-prod-description"}
        else
            desc = {"hextorio-gui.negative-prod-description"}
        end

        prod_bar.tooltip = {"",
            {"hextorio-gui.productivity-meter", lib.format_percentage(current_prod_value, 1, true, false), "purple", "heading-2"},
            "\n\n",
            desc,
        }

        if prod < 0 then
            prod_bar.style.color = {1, 0, 0}
        end
    end

    local prod_label = trade_table.add {
        type = "label",
        name = "productivity",
        caption = "", -- Gets set by trades_gui.update_trade_elements()
        tags = {handlers = {["gui-clicked"] = "trade-arrow"}},
        raise_hover_events = true,
    }
    prod_label.style.width = size / 1.2 + 10
    prod_label.style.left_margin = -size / 1.2 - 10
    prod_label.style.top_margin = 24 / 1.2
    prod_label.style.horizontal_align = "right"

    for i = 1, 3 do
        local j = 4 - i
        if j <= #trade.output_items then
            local output_item = trade.output_items[j]
            local output_sprite_button = trade_table.add {
                type = "sprite-button",
                name = "output-" .. tostring(i) .. "-" .. tostring(output_item.name),
                sprite = "item/" .. output_item.name,
                number = output_item.count,
                tags = {handlers = {["gui-clicked"] = "trade-item"}, item_name = output_item.name, is_input = false},
                raise_hover_events = true,
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
        else
            total_empty = total_empty + 1
            local empty = trade_table.add {type = "sprite-button", name = "empty" .. tostring(total_empty)}
            empty.style.natural_width = size / 1.2
            empty.style.natural_height = size / 1.2
            empty.ignored_by_interaction = true
        end
    end

    trades_gui.update_trade_elements(player, trade_flow, trade, quality_to_show)
end

---@param player LuaPlayer
---@param trade_flow LuaGuiElement
---@param trade Trade
---@param quality string|nil
function trades_gui.update_trade_elements(player, trade_flow, trade, quality)
    local sprite_name = "trade-arrow"

    if trades.is_trade_favorited(player, trade) then
        sprite_name = sprite_name .. "-favorited"
    end

    if trades.trade_has_untradable_items(trade) then
        sprite_name = "interplanetary-" .. sprite_name
    end

    trade_flow["frame"]["trade-table"]["trade-arrow"].sprite = sprite_name

    if quality then
        local prod = trades.get_productivity(trade, quality)
        local prod_str = trades_gui.get_productivity_number_label(prod, true)
        trade_flow["frame"]["trade-table"]["productivity"].caption = prod_str

        local control_flow = trade_flow["frame"]["trade-control-flow"]
        if control_flow then
            core_gui.give_productivity_tooltip(control_flow["productivity-info"], trade, quality, lib.get_quality_cost_multiplier(quality))
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

---Get the rich text formatted string for a label that shows the productivity percentage.
---@param productivity number
---@param empty_for_zero boolean Whether to return an empty string when `productivity == 0`.
---@return string
function trades_gui.get_productivity_number_label(productivity, empty_for_zero)
    local prod_str = "[font=count-font]" .. lib.format_percentage(productivity, 0, true, true) .. "[.font]"

    if productivity < 0 then
        prod_str = "[color=red]" .. prod_str .. "[.color]"
    elseif productivity > 0 or (not empty_for_zero and productivity == 0) then
        prod_str = "[color=green]" .. prod_str .. "[.color]"
    else
        prod_str = ""
    end

    return prod_str
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_core_finder_button_click(player, elem)
    if not storage.trade_overview.trades[player.name] then
        lib.log_error("gui.on_core_finder_button_click: Player trades list not found")
        return
    end

    local trade = storage.trade_overview.trades[player.name][elem.tags.trade_number]
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
        surface = trade.hex_core_state.hex_core.surface,
    }

    event_system.trigger("core-finder-button-clicked", player, elem)

    player.opened = trade.hex_core_state.hex_core
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_ping_button_clicked(player, elem)
    local flow = trades_gui.get_trade_flow_from_trade_element(elem)
    if not flow then return end

    local trade = core_gui.get_trade_from_trade_flow(player, flow)
    if not trade or not trade.hex_core_state or not trade.hex_core_state.hex_core then return end

    local trade_str = lib.get_trade_img_str(trade, trades.trade_has_untradable_items(trade))
    local gps_str = lib.get_gps_str_from_hex_core(trade.hex_core_state.hex_core)

    game.print({"hextorio.player-trade-ping", player.name, trade_str, gps_str})
    gameplay_statistics.set("ping-trade", 1)
end

---Get a trade GUI flow from one of its nested child elements.
---@param elem LuaGuiElement
---@return LuaGuiElement|nil
function trades_gui.get_trade_flow_from_trade_element(elem)
    return core_gui.get_parent_of_name_match(elem, "^trade%-%d+$")
end


---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_toggle_trade_button_clicked(player, elem)
    event_system.trigger("trade-toggle-button-clicked", player, elem)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_trade_tag_button_clicked(player, elem)
    event_system.trigger("trade-tag-button-clicked", player, elem)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_trade_add_to_filters_button_clicked(player, elem)
    event_system.trigger("trade-add-to-filters-button-clicked", player, elem)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_trade_item_clicked(player, elem)
    event_system.trigger("trade-item-clicked", player, elem, elem.tags.item_name, elem.tags.is_input)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_trade_quality_selected(player, elem)
    event_system.trigger("trade-quality-selected", player, elem, elem.tags.trade_number)
end

-- ---@param player LuaPlayer
-- function trades_gui.on_favorite_trade_key_pressed(player)
--     local elem = core_gui.get_currently_hovered_element(player.index)
--     if not elem then return end

--     trades_gui.on_trade_arrow_clicked(player, elem)
-- end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trades_gui.on_trade_arrow_clicked(player, elem)
    local flow = trades_gui.get_trade_flow_from_trade_element(elem)
    if not flow then return end

    local trade = core_gui.get_trade_from_trade_flow(player, flow)
    if not trade then return end

    trades.favorite_trade(player, trade, not trades.is_trade_favorited(player, trade))

    -- TODO: Bad practice below.  Instead of separately calling the GUI update here, the trades.favorite_trade() should trigger an event which causes this GUI manager to update sprites.
    -- But I'm cutting corners here for now because it saves a lot more time than it would initially seem.
    trades_gui.update_trade_elements(player, flow, trade, nil)
end



return trades_gui
