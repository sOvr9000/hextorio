
local lib = require "api.lib"
local gui = require "api.gui.core_gui"
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_grid = require "api.hex_grid"
local trades = require "api.trades"
local sets = require "api.sets"
local item_values = require "api.item_values"
local event_system = require "api.event_system"
local quests = require "api.quests"
local gui_stack = require "api.gui.gui_stack"
local core_gui = require "api.gui.core_gui"
local gui_events = require "api.gui.gui_events"
local trades_gui = require "api.gui.trades_gui"

local trade_overview_gui = {}



function trade_overview_gui.register_events()
    event_system.register_callback("quest-reward-received", function(reward_type, value)
        if reward_type == "unlock-feature" then
            if value == "trade-overview" then
                for _, player in pairs(game.players) do
                    trade_overview_gui.init_trade_overview_button(player)
                end
            end
        end
    end)

    event_system.register_callback("hex-core-deleted", function(state)
        if not state then return end
        for _, player in pairs(game.connected_players) do
            if core_gui.is_frame_open(player, "trade-overview") then
                trade_overview_gui.update_trade_overview(player)
            end
        end
    end)

    event_system.register_callback("core-finder-button-clicked", function(player, element)
        trade_overview_gui.hide_trade_overview(player)
    end)

    event_system.register_callback("trade-item-clicked", function(player, element, item_name, is_input)
        trade_overview_gui.on_trade_item_clicked(player, element, item_name, is_input)
    end)
end

---Reinitialize the hex core GUI for the given player, or all online players if no player is provided.
---@param player LuaPlayer|nil
function trade_overview_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.connected_players) do
            trade_overview_gui.reinitialize(p)
        end
        return
    end

    local frame = player.gui.screen["trade-overview"]
    if frame then frame.destroy() end

    local button = player.gui.top["trade-overview-button"]
    if button then button.destroy() end

    trade_overview_gui.init_trade_overview_button(player)
    trade_overview_gui.init_trade_overview(player)
end

function trade_overview_gui.init_trade_overview_button(player)
    if not player.gui.top["trade-overview-button"] then
        local trade_overview_button = player.gui.top.add {
            type = "sprite-button",
            name = "trade-overview-button",
            sprite = "trade-overview",
        }
        gui_events.register(trade_overview_button, "on-clicked", function() trade_overview_gui.on_trade_overview_button_click(player) end)
    end
    player.gui.top["trade-overview-button"].visible = quests.is_feature_unlocked "trade-overview"
end

function trade_overview_gui.init_trade_overview(player)
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
    filter_frame.style.vertically_stretchable = false

    trade_overview_gui.build_left_filter_frame(filter_frame)
    trade_overview_gui.build_right_filter_frame(filter_frame)
    trade_overview_gui.build_trade_table_frame(frame)
end

function trade_overview_gui.build_left_filter_frame(frame)
    local player = core_gui.get_player_from_element(frame)

    local left_frame = frame.add {type = "frame", name = "left", direction = "vertical"}
    gui.auto_width_height(left_frame)

    local left_frame_buttons_flow = left_frame.add {type = "flow", name = "buttons-flow", direction = "horizontal"}

    local clear_filters_button = left_frame_buttons_flow.add {type = "button", name = "clear-filters-button", caption = {"hextorio-gui.clear-filters"}}
    gui_events.register(clear_filters_button, "on-clicked", function() trade_overview_gui.on_clear_filters_button_click(player, clear_filters_button) end)

    local export_json_button = left_frame_buttons_flow.add {type = "button", name = "export-json", caption = {"hextorio-gui.export-json"}}
    export_json_button.tooltip = {"hextorio-gui.export-json-tooltip"}
    gui_events.register(export_json_button, "on-clicked", function() trade_overview_gui.on_export_json_button_click(player, export_json_button) end)

    local processing_flow = left_frame_buttons_flow.add {type = "flow", name = "processing-flow", direction = "horizontal"}
    local processing_label = processing_flow.add {type = "label", name = "label", caption = {"hextorio-gui.processing-finished"}}
    processing_label.style.top_margin = 2
    local processing_progress_bar = processing_flow.add {type = "progressbar", name = "progressbar", value = 0}
    processing_progress_bar.style.top_margin = 6
    processing_progress_bar.visible = false
    gui.auto_width(processing_progress_bar)

    local planet_flow = left_frame.add {type = "flow", name = "planet-flow", direction = "horizontal"}
    for surface_name, _ in pairs(storage.trade_overview.allowed_planet_filters) do
        if not planet_flow[surface_name] then
            local enabled = game.get_surface(surface_name) ~= nil
            local surface_sprite = planet_flow.add {
                type = "sprite-button",
                name = surface_name,
                sprite = "planet-" .. surface_name,
                toggled = enabled,
                enabled = enabled,
            }
            gui_events.register(surface_sprite, "on-clicked", function()
                surface_sprite.toggled = not surface_sprite.toggled
                gui.update_trade_overview(player)
            end)
        end
    end

    left_frame.add {type = "line", direction = "horizontal"}

    local item_names_with_value = item_values.get_all_items_with_value()
    local elem_filters = {{filter = "name", name = item_names_with_value}}

    local trade_contents_flow = left_frame.add {type = "flow", name = "trade-contents-flow", direction = "vertical"}
    local trade_contents_label = trade_contents_flow.add {type = "label", name = "label", caption = {"hextorio-gui.trade-contents"}}
    local trade_contents_frame = trade_contents_flow.add {type = "flow", name = "frame", direction = "horizontal"}
    trade_contents_label.style.font = "heading-2"

    local trade_inputs_flow = trade_contents_frame.add {
        type = "flow",
        name = "inputs",
        direction = "vertical",
    }
    trade_inputs_flow.style.maximal_width = 170 / 1.2
    local choose_elems_flow = trade_inputs_flow.add {
        type = "flow",
        name = "choose-elems",
        direction = "horizontal",
    }

    local max_input_items_flow = trade_inputs_flow.add {type = "flow", name = "max-inputs-flow", direction = "horizontal"}
    local max_input_items_slider = max_input_items_flow.add {type = "slider", name = "slider", value = 3, minimum_value = 1, maximum_value = 3}
    max_input_items_slider.style.width = 80
    max_input_items_slider.style.top_margin = 4
    local max_input_items_label = max_input_items_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max", 3}}
    gui_events.register(max_input_items_slider, "on-slider-changed", function() trade_overview_gui.update_trade_overview(player) end)

    local exact_inputs_match_flow = trade_inputs_flow.add {type = "flow", name = "exact-inputs-match", direction = "horizontal"}
    gui.auto_width(
        exact_inputs_match_flow.add {type = "empty-widget", name = "empty-1"}
    )
    exact_inputs_match_flow.style.top_margin = -5
    local toggle_exact_inputs_match = exact_inputs_match_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_exact_inputs_match.style.top_margin = 3
    local toggle_exact_inputs_match_label = exact_inputs_match_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exact"}}
    gui.auto_width(
        exact_inputs_match_flow.add {type = "empty-widget", name = "empty-2"}
    )
    gui_events.register(toggle_exact_inputs_match, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)

    for i = 1, 3 do
        local input_item = choose_elems_flow.add {
            type = "choose-elem-button",
            elem_type = "item",
            name = "input-item-" .. i,
        }
        input_item.elem_filters = elem_filters
        gui_events.register(input_item, "on-elem-selected", function() trade_overview_gui.update_trade_overview(player) end)
    end



    local trade_arrow = trade_contents_frame.add {
        type = "sprite",
        name = "trade-arrow",
        sprite = "trade-arrow",
    }
    trade_arrow.style.top_margin = 4
    trade_arrow.style.width = 30 / 1.2
    trade_arrow.style.height = 30 / 1.2
    trade_arrow.style.stretch_image_to_widget_size = true



    local trade_outputs_flow = trade_contents_frame.add {
        type = "flow",
        name = "outputs",
        direction = "vertical",
    }
    trade_outputs_flow.style.maximal_width = 170 / 1.2
    trade_outputs_flow.style.left_margin = 18
    choose_elems_flow = trade_outputs_flow.add {
        type = "flow",
        name = "choose-elems",
        direction = "horizontal",
    }

    local max_output_items_flow = trade_outputs_flow.add {type = "flow", name = "max-outputs-flow", direction = "horizontal"}
    local max_output_items_slider = max_output_items_flow.add {type = "slider", name = "slider", value = 3, minimum_value = 1, maximum_value = 3}
    max_output_items_slider.style.width = 80
    max_output_items_slider.style.top_margin = 4
    local max_output_items_label = max_output_items_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max", 3}}
    gui_events.register(max_output_items_slider, "on-slider-changed", function() trade_overview_gui.update_trade_overview(player) end)

    local exact_outputs_match_flow = trade_outputs_flow.add {type = "flow", name = "exact-outputs-match", direction = "horizontal"}
    gui.auto_width(
        exact_outputs_match_flow.add {type = "empty-widget", name = "empty-1"}
    )
    exact_outputs_match_flow.style.top_margin = -5
    local toggle_exact_outputs_match = exact_outputs_match_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_exact_outputs_match.style.top_margin = 3
    local toggle_exact_outputs_match_label = exact_outputs_match_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exact"}}
    gui.auto_width(
        exact_outputs_match_flow.add {type = "empty-widget", name = "empty-2"}
    )
    gui_events.register(toggle_exact_outputs_match, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)

    for i = 1, 3 do
        local output_item = choose_elems_flow.add {
            type = "choose-elem-button",
            elem_type = "item",
            name = "output-item-" .. (4 - i), -- 4 - i to be more consistent with how trades are shown in general
        }
        output_item.elem_filters = elem_filters
        gui_events.register(output_item, "on-elem-selected", function() trade_overview_gui.update_trade_overview(player) end)
    end
end

function trade_overview_gui.build_right_filter_frame(frame)
    local player = core_gui.get_player_from_element(frame)

    local right_frame = frame.add {type = "frame", name = "right", direction = "vertical"}
    gui.auto_width_height(right_frame)

    local max_trades_flow = right_frame.add {type = "flow", name = "max-trades-flow", direction = "horizontal"}
    local max_trades_label = max_trades_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max-trades"}}
    max_trades_label.style.top_margin = 3
    local max_trades_dropdown = max_trades_flow.add {type = "drop-down", name = "dropdown", selected_index = 4, items = {{"", 10}, {"", 25}, {"", 100}, {"hextorio-gui.all"}}}
    gui_events.register(max_trades_dropdown, "on-selection-changed", function(value) trade_overview_gui.update_trade_overview(player) end)

    local sort_method_flow = right_frame.add {type = "flow", name = "sort-method", direction = "horizontal"}
    local sort_method_label = sort_method_flow.add {type = "label", name = "label", caption = {"hextorio-gui.sort-method"}}
    local sort_method_dropdown = sort_method_flow.add {type = "drop-down", name = "dropdown", selected_index = 1, items = {{"trade-sort-method.distance-from-spawn"}, {"trade-sort-method.distance-from-character"}, {"trade-sort-method.total-item-value"}, {"trade-sort-method.num-inputs"}, {"trade-sort-method.num-outputs"}, {"trade-sort-method.productivity"}}}
    gui_events.register(sort_method_dropdown, "on-selection-changed", function(value) trade_overview_gui.update_trade_overview(player) end)

    local sort_direction = right_frame.add {
        type = "switch",
        name = "sort-direction",
        left_label_caption = {"hextorio-gui.ascending"},
        right_label_caption = {"hextorio-gui.descending"},
    }
    gui_events.register(sort_direction, "on-switch-changed", function() trade_overview_gui.update_trade_overview(player) end)

    right_frame.add {type = "line", direction = "horizontal"}

    local show_only_claimed_flow = right_frame.add {type = "flow", name = "show-only-claimed", direction = "horizontal"}
    local toggle_show_only_claimed = show_only_claimed_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_show_only_claimed.style.top_margin = 3
    local toggle_show_only_claimed_label = show_only_claimed_flow.add {type = "label", name = "label", caption = {"hextorio-gui.show-only-claimed"}}
    gui_events.register(toggle_show_only_claimed, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)

    local show_only_interplanetary_flow = right_frame.add {type = "flow", name = "show-only-interplanetary", direction = "horizontal"}
    local toggle_show_only_interplanetary = show_only_interplanetary_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_show_only_interplanetary.style.top_margin = 3
    local toggle_show_only_interplanetary_label = show_only_interplanetary_flow.add {type = "label", name = "label", caption = {"hextorio-gui.show-only-interplanetary"}}
    gui_events.register(toggle_show_only_interplanetary, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)

    local exclude_dungeons_flow = right_frame.add {type = "flow", name = "exclude-dungeons", direction = "horizontal"}
    local toggle_exclude_dungeons = exclude_dungeons_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_exclude_dungeons.style.top_margin = 3
    local toggle_exclude_dungeons_label = exclude_dungeons_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exclude-dungeons"}}
    gui_events.register(toggle_exclude_dungeons, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)

    local exclude_sinks_generators_flow = right_frame.add {type = "flow", name = "exclude-sinks-generators", direction = "horizontal"}
    local toggle_exclude_sinks_generators = exclude_sinks_generators_flow.add {type = "checkbox", name = "checkbox", state = false}
    toggle_exclude_sinks_generators.style.top_margin = 3
    local toggle_exclude_sinks_generators_label = exclude_sinks_generators_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exclude-sinks-generators"}}
    gui_events.register(toggle_exclude_sinks_generators, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)
end

function trade_overview_gui.build_trade_table_frame(frame)
    local trade_table_frame = frame.add {type = "frame", name = "trade-table-frame", direction = "vertical"}
    gui.auto_width_height(trade_table_frame)

    local scroll_pane = trade_table_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.style.vertically_stretchable = true
    trade_table_frame.style.vertically_stretchable = true
    trade_table_frame.style.vertically_squashable = true
    trade_table_frame.style.natural_width = 700

    local trade_table = scroll_pane.add {type = "table", name = "table", column_count = 2}
    trade_table.style.horizontal_spacing = 28 / 1.2
end

function trade_overview_gui.update_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then
        trade_overview_gui.init_trade_overview(player)
        frame = player.gui.screen["trade-overview"]
    end

    -- Ensure that all available planets are enabled
    local filter_frame = frame["filter-frame"]
    for surface_name, _ in pairs(storage.trade_overview.allowed_planet_filters) do
        filter_frame["left"]["planet-flow"][surface_name].enabled = game.get_surface(surface_name) ~= nil
    end

    trade_overview_gui.update_player_trade_overview_filters(player)
    local filter = trade_overview_gui.get_player_trade_overview_filter(player)

    if filter.exact_inputs_match and filter.input_items and #filter.input_items > 0 then
        filter_frame["left"]["trade-contents-flow"]["frame"]["inputs"]["max-inputs-flow"]["slider"].slider_value = #filter.input_items
    end

    if filter.exact_outputs_match and filter.output_items and #filter.output_items > 0 then
        filter_frame["left"]["trade-contents-flow"]["frame"]["outputs"]["max-outputs-flow"]["slider"].slider_value = #filter.output_items
    end

    local trade_contents_frame = filter_frame["left"]["trade-contents-flow"]["frame"]
    trade_contents_frame["inputs"]["max-inputs-flow"]["label"].caption = {"hextorio-gui.max", trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].slider_value}
    trade_contents_frame["outputs"]["max-outputs-flow"]["label"].caption = {"hextorio-gui.max", trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].slider_value}

    trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].enabled = not filter.exact_inputs_match
    trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].enabled = not filter.exact_outputs_match
    filter_frame["right"]["exclude-dungeons"]["checkbox"].enabled = not filter.show_claimed_only

    if filter.show_claimed_only then
        filter_frame["right"]["exclude-dungeons"]["checkbox"].state = true
    end

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

    -- At this point, trades_set is either nil or a lookup table that maps trade ids to boolean (true) values.
    if trades_set then
        -- Convert to lookup table mapping trade ids to trade objects.
        trades_set = trades.convert_boolean_lookup_to_trades_lookup(trades_set)
    else
        trades_set = lib.shallow_copy(trades.get_trades_lookup())
    end

    local function filter_trade(trade)
        if trade.hex_core_state then
            local state = trade.hex_core_state
            if not state.hex_core or not state.hex_core.valid then
                return true
            end
            if filter.show_claimed_only and not state.claimed then
                return true
            end
            if filter.exclude_dungeons and state.is_dungeon then
                return true
            end
            if filter.exclude_sinks_generators and (state.mode == "sink" or state.mode == "generator") then
                return true
            end
        end
        if filter.show_interplanetary_only and not trades.is_interplanetary_trade(trade) then
            return true
        end
        if filter.planets and trade.surface_name then
            if not filter.planets[trade.surface_name] then
                return true
            end
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
    trades_gui.update_trades_scroll_pane(player, trade_table, trades_list, {
        show_toggle_trade = false,
        show_tag_creator = false,
        show_ping_button = true,
        show_add_to_filters = false,
        show_core_finder = true,
        show_productivity_bar = false,
        show_quality_bounds = false,
        quality_to_show = "normal",
        show_productivity_info = false,
        expanded = false,
        is_configuration_unlocked = quests.is_feature_unlocked "trade-configuration",
    })
end

function trade_overview_gui.show_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then
        trade_overview_gui.init_trade_overview(player)
        frame = player.gui.screen["trade-overview"]
    end
    gui_stack.add(player, frame)
    trade_overview_gui.update_trade_overview(player)
    frame.force_auto_center()
end

function trade_overview_gui.hide_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))

    if storage.gui and storage.gui.trades_scroll_pane_update and storage.gui.trades_scroll_pane_update[player.name] then
        storage.gui.trades_scroll_pane_update[player.name].finished = true
    end
end

function trade_overview_gui.on_trade_item_clicked(player, element, item_name, is_input)
    if not quests.is_feature_unlocked "trade-overview" then return end

    trade_overview_gui.show_trade_overview(player)

    if is_input then
        trade_overview_gui.set_trade_overview_item_filters(player, {}, {item_name})
    else
        trade_overview_gui.set_trade_overview_item_filters(player, {item_name}, {})
    end
end

function trade_overview_gui.set_trade_overview_item_filters(player, input_items, output_items)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local trade_contents_frame = frame["filter-frame"]["left"]["trade-contents-flow"]["frame"]

    for i = 1, 3 do
        local button = trade_contents_frame["inputs"]["choose-elems"]["input-item-" .. i]
        button.elem_value = input_items[i]
    end

    for i = 1, 3 do
        local button = trade_contents_frame["outputs"]["choose-elems"]["output-item-" .. i]
        button.elem_value = output_items[i]
    end

    trade_overview_gui.update_trade_overview(player)
end

function trade_overview_gui.on_trade_overview_button_click(player)
    if gui.is_frame_open(player, "trade-overview") then
        trade_overview_gui.hide_trade_overview(player)
    else
        trade_overview_gui.show_trade_overview(player)
    end
end

function trade_overview_gui.get_player_trade_overview_filter(player)
    local filters = storage.trade_overview.filters
    if not filters[player.name] then
        filters[player.name] = {}
    end
    return filters[player.name]
end

function trade_overview_gui.update_player_trade_overview_filters(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local filter_frame = frame["filter-frame"]
    if not filter_frame then return end

    local filter = trade_overview_gui.get_player_trade_overview_filter(player)
    local trade_contents_frame = filter_frame["left"]["trade-contents-flow"]["frame"]

    if not filter.planets then
        filter.planets = {}
    end

    for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
        filter.planets[planet_button.name] = planet_button.toggled
    end

    filter.input_items = {}
    for i = 1, 3 do
        local input_item = trade_contents_frame["inputs"]["choose-elems"]["input-item-" .. i]
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
        local output_item = trade_contents_frame["outputs"]["choose-elems"]["output-item-" .. i]
        if output_item.elem_value then
            local item_name = output_item.elem_value
            table.insert(filter.output_items, item_name)
        end
    end
    if not next(filter.output_items) then
        filter.output_items = nil
    end

    filter.exact_inputs_match = filter_frame["left"]["trade-contents-flow"]["frame"]["inputs"]["exact-inputs-match"]["checkbox"].state
    filter.exact_outputs_match = filter_frame["left"]["trade-contents-flow"]["frame"]["outputs"]["exact-outputs-match"]["checkbox"].state
    filter.show_claimed_only = filter_frame["right"]["show-only-claimed"]["checkbox"].state
    filter.show_interplanetary_only = filter_frame["right"]["show-only-interplanetary"]["checkbox"].state
    filter.exclude_dungeons = filter_frame["right"]["exclude-dungeons"]["checkbox"].state
    filter.exclude_sinks_generators = filter_frame["right"]["exclude-sinks-generators"]["checkbox"].state

    filter.num_item_bounds = {
        inputs = {
            min = 1,
            max = filter_frame["left"]["trade-contents-flow"]["frame"]["inputs"]["max-inputs-flow"]["slider"].slider_value,
        },
        outputs = {
            min = 1,
            max = filter_frame["left"]["trade-contents-flow"]["frame"]["outputs"]["max-outputs-flow"]["slider"].slider_value,
        },
    }

    if filter.exact_inputs_match then
        filter.input_items_lookup = sets.new(filter.input_items)
        if filter.input_items then
            filter.num_item_bounds.inputs.max = #filter.input_items
        end
    end
    if filter.exact_outputs_match then
        filter.output_items_lookup = sets.new(filter.output_items)
        if filter.output_items then
            filter.num_item_bounds.outputs.max = #filter.output_items
        end
    end

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
end

function trade_overview_gui.swap_trade_overview_content_filters(player)
    local filters = trade_overview_gui.get_player_trade_overview_filter(player)
    local new_inputs = filters.output_items or {}
    local new_outputs = filters.input_items or {}

    -- Only trigger a refresh if necessary.
    if not lib.tables_equal(sets.new(new_inputs), sets.new(new_outputs)) then
        trade_overview_gui.set_trade_overview_item_filters(player, new_inputs, new_outputs)
    end
end

function trade_overview_gui.on_export_json_button_click(player, element)
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

function trade_overview_gui.on_clear_filters_button_click(player, element)
    local filter_frame = element.parent.parent.parent
    for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
        planet_button.toggled = true
    end

    for i = 1, 3 do
        filter_frame["left"]["trade-contents-flow"]["frame"]["inputs"]["choose-elems"]["input-item-" .. i].elem_value = nil
    end

    for i = 1, 3 do
        filter_frame["left"]["trade-contents-flow"]["frame"]["outputs"]["choose-elems"]["output-item-" .. i].elem_value = nil
    end

    local right_frame = filter_frame["right"]
    right_frame["show-only-claimed"]["checkbox"].state = false
    right_frame["show-only-interplanetary"]["checkbox"].state = false
    right_frame["exclude-dungeons"]["checkbox"].state = false
    right_frame["exclude-sinks-generators"]["checkbox"].state = false

    local trade_contents_frame = filter_frame["left"]["trade-contents-flow"]["frame"]
    trade_contents_frame["inputs"]["exact-inputs-match"]["checkbox"].state = false
    trade_contents_frame["outputs"]["exact-outputs-match"]["checkbox"].state = false
    trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].slider_value = trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].get_slider_maximum()
    trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].slider_value = trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].get_slider_maximum()

    trade_overview_gui.update_trade_overview(player)
end



return trade_overview_gui
