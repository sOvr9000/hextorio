
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
local trades_gui = require "api.gui.trades_gui"
local history    = require "api.history"

local trade_overview_gui = {}



---@alias TradeOverviewSortingMethod
---| "distance-from-spawn"
---| "distance-from-character"
---| "total-item-value"
---| "num-inputs"
---| "num-outputs"
---| "productivity"

---@class TradeOverviewFilterSettings
---@field input_items string[]|nil
---@field output_items string[]|nil
---@field input_items_lookup {[string]: boolean}|nil
---@field output_items_lookup {[string]: boolean}|nil
---@field exact_inputs_match boolean|nil
---@field exact_outputs_match boolean|nil
---@field planets {[string]: boolean}
---@field show_interplanetary_only boolean
---@field show_claimed_only boolean
---@field show_favorited_only boolean
---@field exclude_favorited boolean
---@field exclude_dungeons boolean
---@field exclude_sinks_generators boolean
---@field num_item_bounds TradeOverviewFilterNumItemBounds|nil
---@field sorting TradeOverviewSortingSettings
---@field max_trades int

---@class TradeOverviewSortingSettings
---@field method TradeOverviewSortingMethod
---@field ascending boolean

---@class TradeOverviewFilterNumItemBounds
---@field inputs {min: int, max: int}
---@field outputs {min: int, max: int}



function trade_overview_gui.register_events()
    event_system.register_gui("gui-clicked", "trade-overview-button", trade_overview_gui.on_trade_overview_button_click)
    event_system.register_gui("gui-closed", "trade-overview", trade_overview_gui.hide_trade_overview)
    event_system.register_gui("gui-clicked", "trade-overview-clear-filters", trade_overview_gui.on_clear_filters_button_click)
    event_system.register_gui("gui-clicked", "export-json", trade_overview_gui.on_export_json_button_click)
    event_system.register_gui("gui-clicked", "planet-filter", trade_overview_gui.on_planet_filter_button_click)
    event_system.register_gui("gui-clicked", "trade-overview-contents-arrow", trade_overview_gui.on_trade_overview_contents_arrow_click)
    event_system.register_gui("gui-slider-changed", "trade-overview-filter-changed", trade_overview_gui.update_trade_overview)
    event_system.register_gui("gui-elem-changed", "trade-overview-filter-changed", trade_overview_gui.update_trade_overview)
    event_system.register_gui("gui-selection-changed", "trade-overview-filter-changed", trade_overview_gui.update_trade_overview)
    event_system.register_gui("gui-switch-changed", "trade-overview-filter-changed", trade_overview_gui.update_trade_overview)
    event_system.register_gui("gui-clicked", "trade-overview-filter-changed", trade_overview_gui.update_trade_overview)
    event_system.register_gui("gui-clicked", "swap-filters", trade_overview_gui.swap_trade_overview_content_filters)
    event_system.register_gui("gui-back", "trade-overview", trade_overview_gui.on_gui_back)
    event_system.register_gui("gui-forward", "trade-overview", trade_overview_gui.on_gui_forward)

    -- Listen to trade job events
    event_system.register("trade-collection-progress", trade_overview_gui.on_trade_collection_progress)
    event_system.register("trade-collection-complete", trade_overview_gui.on_trade_collection_complete)
    event_system.register("trade-filtering-progress", trade_overview_gui.on_trade_filtering_progress)
    event_system.register("trade-sorting-starting", trade_overview_gui.on_trade_sorting_starting)
    event_system.register("trade-sorting-progress", trade_overview_gui.on_trade_sorting_progress)
    event_system.register("trade-sorting-complete", trade_overview_gui.on_trade_sorting_complete)
    event_system.register("trade-overview-jobs-cancelled", trade_overview_gui.on_trade_overview_jobs_cancelled)
    event_system.register("trade-export-progress", trade_overview_gui.on_trade_export_progress)
    event_system.register("trade-export-complete", trade_overview_gui.on_trade_export_complete)

    event_system.register("quest-reward-received", function(reward_type, value)
        if reward_type == "unlock-feature" then
            if value == "trade-overview" then
                for _, player in pairs(game.players) do
                    trade_overview_gui.init_trade_overview_button(player)
                end
            end
        end
    end)

    event_system.register("hex-core-deleted", function(state)
        if not state then return end
        for _, player in pairs(game.connected_players) do
            if core_gui.is_frame_open(player, "trade-overview") then
                trade_overview_gui.update_trade_overview(player)
            end
        end
    end)

    event_system.register("core-finder-button-clicked", function(player, element)
        trade_overview_gui.hide_trade_overview(player)
    end)

    event_system.register("trade-item-clicked", function(player, element, item_name, is_input)
        trade_overview_gui.on_trade_item_clicked(player, element, item_name, is_input)
    end)

    event_system.register("catalog-trade-overview-clicked", trade_overview_gui.on_catalog_trade_overview_clicked)

    event_system.register("player-favorited-trade", function(player, trade)
        -- might be annoying if updated each time?
        -- trade_overview_gui.update_trade_overview(player)
    end)

    event_system.register("post-item-values-recalculated", function()
        for _, player in pairs(game.players) do
            trade_overview_gui.init_trade_overview(player)
        end
    end)
end

---Reinitialize the trade overview GUI for the given player, or all players if no player is provided.
---@param player LuaPlayer|nil
function trade_overview_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.players) do
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
            tags = {handlers = {["gui-clicked"] = "trade-overview-button"}},
            tooltip = {"hextorio-gui.trade-overview-button-tooltip"},
        }
    end
    player.gui.top["trade-overview-button"].visible = quests.is_feature_unlocked "trade-overview"
end

function trade_overview_gui.init_trade_overview(player)
    if storage.item_values.awaiting_solver then return end

    local frame = player.gui.screen.add {
        type = "frame",
        name = "trade-overview",
        direction = "vertical",
    }
    frame.style.width = 900
    frame.style.height = 900
    frame.visible = false

    gui.add_titlebar(frame, {"hex-core-gui.trade-overview"}, true)

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

    local clear_filters_button = left_frame_buttons_flow.add {
        type = "button",
        name = "clear-filters",
        caption = {"hextorio-gui.clear-filters"},
        tags = {handlers = {["gui-clicked"] = "trade-overview-clear-filters"}},
    }

    local export_json_button = left_frame_buttons_flow.add {
        type = "button",
        name = "export-json",
        caption = {"hextorio-gui.export-json"},
        tooltip = {"hextorio-gui.export-json-tooltip"},
        tags = {handlers = {["gui-clicked"] = "export-json"}},
    }

    local processing_flow = left_frame_buttons_flow.add {type = "flow", name = "processing-flow", direction = "horizontal"}
    local processing_label = processing_flow.add {type = "label", name = "label", caption = {"hextorio-gui.processing-finished"}}
    processing_label.style.top_margin = 2
    local processing_progress_bar = processing_flow.add {type = "progressbar", name = "progressbar", value = 0}
    processing_progress_bar.style.top_margin = 6
    processing_progress_bar.visible = false
    gui.auto_width(processing_progress_bar)

    local planet_flow = left_frame.add {type = "flow", name = "planet-flow", direction = "horizontal"}
    for surface_name, _ in pairs(storage.SUPPORTED_PLANETS) do
        if not planet_flow[surface_name] then
            local enabled = game.get_surface(surface_name) ~= nil
            local surface_sprite = planet_flow.add {
                type = "sprite-button",
                name = surface_name,
                sprite = "planet-" .. surface_name,
                toggled = enabled,
                enabled = enabled,
                tags = {handlers = {["gui-clicked"] = "planet-filter"}}
            }
        end
    end

    left_frame.add {type = "line", direction = "horizontal"}

    trade_overview_gui.build_trade_content_filter(left_frame)
end

function trade_overview_gui.build_trade_content_filter(frame)
    -- Could cache this, but having to reset the cache from other events made it simpler to recalculate when needed.
    local all_tradable_items = sets.new()
    for _, tradable in pairs(storage.item_values.is_tradable) do
        all_tradable_items = sets.union(all_tradable_items, tradable)
    end

    for i = #storage.coin_tiers.COIN_NAMES, 1, -1 do
        sets.add(all_tradable_items, storage.coin_tiers.COIN_NAMES[i])
    end

    local elem_filters = {{filter = "name", name = sets.to_array(all_tradable_items)}}

    local trade_contents_flow = frame.add {type = "flow", name = "trade-contents-flow", direction = "vertical"}
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
    local max_input_items_slider = max_input_items_flow.add {
        type = "slider",
        name = "slider",
        value = 3,
        minimum_value = 1,
        maximum_value = 3,
        tags = {handlers = {["gui-slider-changed"] = "trade-overview-filter-changed"}},
    }
    max_input_items_slider.style.width = 80
    max_input_items_slider.style.top_margin = 4
    local max_input_items_label = max_input_items_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max", 3}}

    local exact_inputs_match_flow = trade_inputs_flow.add {type = "flow", name = "exact-inputs-match", direction = "horizontal"}
    gui.auto_width(
        exact_inputs_match_flow.add {type = "empty-widget", name = "empty-1"}
    )
    exact_inputs_match_flow.style.top_margin = -5

    local toggle_exact_inputs_match = exact_inputs_match_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_exact_inputs_match.style.top_margin = 3
    local toggle_exact_inputs_match_label = exact_inputs_match_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exact"}}
    gui.auto_width(
        exact_inputs_match_flow.add {type = "empty-widget", name = "empty-2"}
    )
    -- gui_handlers.register(toggle_exact_inputs_match, "on-clicked", function() trade_overview_gui.update_trade_overview(player) end)

    for i = 1, 3 do
        local input_item = choose_elems_flow.add {
            type = "choose-elem-button",
            elem_type = "item",
            name = "input-item-" .. i,
            tags = {handlers = {["gui-elem-changed"] = "trade-overview-filter-changed"}},
        }
        input_item.elem_filters = elem_filters
    end

    trade_overview_gui.build_trade_content_filter_center(trade_contents_frame)

    local trade_outputs_flow = trade_contents_frame.add {
        type = "flow",
        name = "outputs",
        direction = "vertical",
    }
    trade_outputs_flow.style.maximal_width = 170 / 1.2
    trade_outputs_flow.style.left_margin = 14
    choose_elems_flow = trade_outputs_flow.add {
        type = "flow",
        name = "choose-elems",
        direction = "horizontal",
    }

    local max_output_items_flow = trade_outputs_flow.add {type = "flow", name = "max-outputs-flow", direction = "horizontal"}
    local max_output_items_slider = max_output_items_flow.add {
        type = "slider",
        name = "slider",
        value = 3,
        minimum_value = 1,
        maximum_value = 3,
        tags = {handlers = {["gui-slider-changed"] = "trade-overview-filter-changed"}},
    }
    max_output_items_slider.style.width = 80
    max_output_items_slider.style.top_margin = 4
    local max_output_items_label = max_output_items_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max", 3}}

    local exact_outputs_match_flow = trade_outputs_flow.add {type = "flow", name = "exact-outputs-match", direction = "horizontal"}
    gui.auto_width(
        exact_outputs_match_flow.add {type = "empty-widget", name = "empty-1"}
    )
    exact_outputs_match_flow.style.top_margin = -5

    local toggle_exact_outputs_match = exact_outputs_match_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_exact_outputs_match.style.top_margin = 3
    local toggle_exact_outputs_match_label = exact_outputs_match_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exact"}}
    gui.auto_width(
        exact_outputs_match_flow.add {type = "empty-widget", name = "empty-2"}
    )

    for i = 1, 3 do
        local output_item = choose_elems_flow.add {
            type = "choose-elem-button",
            elem_type = "item",
            name = "output-item-" .. (4 - i), -- 4 - i to be more consistent with how trades are shown in general
            tags = {handlers = {["gui-elem-changed"] = "trade-overview-filter-changed"}},
        }
        output_item.elem_filters = elem_filters
    end
end

function trade_overview_gui.build_trade_content_filter_center(frame)
    local flow = frame.add {
        type = "flow",
        name = "center",
        direction = "vertical",
    }

    local trade_arrow = flow.add {
        type = "sprite",
        name = "trade-arrow",
        sprite = "trade-arrow",
        tags = {handlers = {["gui-clicked"] = "trade-overview-contents-arrow"}},
    }
    trade_arrow.style.top_margin = 4
    trade_arrow.style.left_margin = 4
    trade_arrow.style.width = 40 / 1.2
    trade_arrow.style.height = 40 / 1.2
    trade_arrow.style.stretch_image_to_widget_size = true

    local swap_filters = flow.add {
        type = "sprite-button",
        name = "swap-filters",
        sprite = "virtual-signal/signal-rightwards-leftwards-arrow",
        tags = {handlers = {["gui-clicked"] = "swap-filters"}},
    }
end

function trade_overview_gui.build_right_filter_frame(frame)
    local player = core_gui.get_player_from_element(frame)

    local right_frame = frame.add {type = "frame", name = "right", direction = "vertical"}
    gui.auto_width_height(right_frame)

    local max_trades_flow = right_frame.add {type = "flow", name = "max-trades-flow", direction = "horizontal"}
    local max_trades_label = max_trades_flow.add {type = "label", name = "label", caption = {"hextorio-gui.max-trades"}}
    max_trades_label.style.top_margin = 3
    local max_trades_dropdown = max_trades_flow.add {
        type = "drop-down",
        name = "dropdown",
        selected_index = 4,
        items = {{"", 10}, {"", 25}, {"", 100}, {"", 250}},
        tags = {handlers = {["gui-selection-changed"] = "trade-overview-filter-changed"}},
    }

    local sort_method_flow = right_frame.add {type = "flow", name = "sort-method", direction = "horizontal"}
    local sort_method_label = sort_method_flow.add {type = "label", name = "label", caption = {"hextorio-gui.sort-method"}}
    local sort_method_dropdown = sort_method_flow.add {
        type = "drop-down",
        name = "dropdown",
        selected_index = 1,
        items = {
            {"trade-sort-method.distance-from-spawn"},
            {"trade-sort-method.distance-from-character"},
            {"trade-sort-method.total-item-value"},
            {"trade-sort-method.num-inputs"},
            {"trade-sort-method.num-outputs"},
            {"trade-sort-method.productivity"},
        },
        tags = {handlers = {["gui-selection-changed"] = "trade-overview-filter-changed"}},
    }

    local sort_direction = right_frame.add {
        type = "switch",
        name = "sort-direction",
        left_label_caption = {"hextorio-gui.ascending"},
        right_label_caption = {"hextorio-gui.descending"},
        tags = {handlers = {["gui-switch-changed"] = "trade-overview-filter-changed"}},
    }

    right_frame.add {type = "line", direction = "horizontal"}

    local show_only_claimed_flow = right_frame.add {type = "flow", name = "show-only-claimed", direction = "horizontal"}
    local toggle_show_only_claimed = show_only_claimed_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_show_only_claimed.style.top_margin = 3
    local toggle_show_only_claimed_label = show_only_claimed_flow.add {type = "label", name = "label", caption = {"hextorio-gui.show-only-claimed"}}

    local show_only_interplanetary_flow = right_frame.add {type = "flow", name = "show-only-interplanetary", direction = "horizontal"}
    local toggle_show_only_interplanetary = show_only_interplanetary_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_show_only_interplanetary.style.top_margin = 3
    local toggle_show_only_interplanetary_label = show_only_interplanetary_flow.add {type = "label", name = "label", caption = {"hextorio-gui.show-only-interplanetary"}}

    local exclude_favorited_flow = right_frame.add {type = "flow", name = "exclude-favorited", direction = "horizontal"}
    local toggle_exclude_favorited = exclude_favorited_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_exclude_favorited.style.top_margin = 3
    local toggle_exclude_favorited_label = exclude_favorited_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exclude-favorited"}}

    local exclude_dungeons_flow = right_frame.add {type = "flow", name = "exclude-dungeons", direction = "horizontal"}
    local toggle_exclude_dungeons = exclude_dungeons_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_exclude_dungeons.style.top_margin = 3
    local toggle_exclude_dungeons_label = exclude_dungeons_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exclude-dungeons"}}

    local exclude_sinks_generators_flow = right_frame.add {type = "flow", name = "exclude-sinks-generators", direction = "horizontal"}
    local toggle_exclude_sinks_generators = exclude_sinks_generators_flow.add {
        type = "checkbox",
        name = "checkbox",
        state = false,
        tags = {handlers = {["gui-clicked"] = "trade-overview-filter-changed"}},
    }
    toggle_exclude_sinks_generators.style.top_margin = 3
    local toggle_exclude_sinks_generators_label = exclude_sinks_generators_flow.add {type = "label", name = "label", caption = {"hextorio-gui.exclude-sinks-generators"}}
end

function trade_overview_gui.build_trade_table_frame(frame)
    local trade_table_frame = frame.add {type = "frame", name = "trade-table-frame", direction = "vertical"}
    gui.auto_width_height(trade_table_frame)

    local scroll_pane = trade_table_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.style.vertically_stretchable = true
    trade_table_frame.style.vertically_stretchable = true
    trade_table_frame.style.vertically_squashable = true
    trade_table_frame.style.natural_width = 700

    local trade_table = scroll_pane.add {type = "flow", name = "table", direction = "vertical"}
end

---Compute extra information on the filter to be used during trade filtration.
---Additionally normalize the data to ensure logical coherence such as `exclude_favorited` being forced to false when `show_favorited_only` is true.
---Also set default values for nil fields.
---@param filter TradeOverviewFilterSettings
function trade_overview_gui.post_process_filter_data(filter)
    if filter.show_favorited_only then filter.exclude_favorited = false end
    if filter.show_claimed_only then filter.exclude_dungeons = true end

    if not filter.num_item_bounds then
        filter.num_item_bounds = {inputs = {min = 1, max = 3}, outputs = {min = 1, max = 3}}
    end
    if not filter.planets then
        filter.planets = {}
        for surface_name, _ in pairs(storage.SUPPORTED_PLANETS) do
            filter.planets[surface_name] = game.get_surface(surface_name) ~= nil
        end
    end
    if not filter.sorting then filter.sorting = {method = "distance-from-spawn", ascending = true} end
    if not filter.max_trades then filter.max_trades = 250 end

    if filter.exact_inputs_match then
        filter.input_items_lookup = sets.new(filter.input_items)
        filter.num_item_bounds.inputs.max = filter.input_items and #filter.input_items or 3
    else
        filter.input_items_lookup = nil
    end
    if filter.exact_outputs_match then
        filter.output_items_lookup = sets.new(filter.output_items)
        filter.num_item_bounds.outputs.max = filter.output_items and #filter.output_items or 3
    else
        filter.output_items_lookup = nil
    end
end

---Collect the trade candidates set and queue the filtration and rendering jobs for a player's trade overview GUI.
---@param player LuaPlayer
function trade_overview_gui.collect_and_display_trades(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local filter = trade_overview_gui.get_player_trade_overview_filter(player)

    local trades_set
    if filter.show_favorited_only then
        trades_set = trades.get_favorited_trades(player)
    end

    if filter.input_items then
        for _, item in pairs(filter.input_items) do
            if trades_set then
                trades_set = sets.intersection(trades_set, trades.get_trades_by_input(item))
            else
                trades_set = trades.get_trades_by_input(item)
            end
        end
    end
    if filter.output_items then
        for _, item in pairs(filter.output_items) do
            if trades_set then
                trades_set = sets.intersection(trades_set, trades.get_trades_by_output(item))
            else
                trades_set = trades.get_trades_by_output(item)
            end
        end
    end

    if not trades_set then
        if filter.planets then
            for surface_name, allow in pairs(filter.planets) do
                if allow then
                    if trades_set then
                        trades_set = sets.union(trades_set, trades.get_trades_by_surface(surface_name))
                    else
                        trades_set = trades.get_trades_by_surface(surface_name)
                    end
                end
            end
        end
    end

    if not trades_set then trades_set = sets.new() end

    -- Cancel any existing jobs and clear the trade table immediately
    trades.cancel_trade_overview_jobs(player)
    storage.trade_overview.trades[player.name] = {}

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    trade_table.clear()

    local use_batch_processing = trades.should_use_batch_processing(filter)

    if use_batch_processing then
        local progress_flow = trade_table.add {type = "flow", name = "progress-flow", direction = "vertical"}
        progress_flow.style.horizontally_stretchable = true
        progress_flow.style.vertical_spacing = 8

        local collection_flow = progress_flow.add {type = "flow", name = "collection-flow", direction = "vertical"}
        collection_flow.style.horizontally_stretchable = true
        collection_flow.style.vertical_spacing = 0
        collection_flow.style.bottom_padding = 0
        collection_flow.style.top_padding = 0
        local collection_label = collection_flow.add {type = "label", name = "label", caption = {"hextorio-gui.collecting-trades", 0, 0}}
        collection_label.style.font = "default-bold"
        local collection_progressbar = collection_flow.add {type = "progressbar", name = "progressbar", value = 0}
        collection_progressbar.style.horizontally_stretchable = true

        local filtering_flow = progress_flow.add {type = "flow", name = "filtering-flow", direction = "vertical"}
        filtering_flow.style.horizontally_stretchable = true
        filtering_flow.style.vertical_spacing = 0
        filtering_flow.style.bottom_padding = 0
        filtering_flow.style.top_padding = 0
        local filtering_label = filtering_flow.add {type = "label", name = "label", caption = {"hextorio-gui.filtering-trades", 0, 0}}
        filtering_label.style.font = "default-bold"
        filtering_label.style.font_color = {0.5, 0.5, 0.5}
        local filtering_progressbar = filtering_flow.add {type = "progressbar", name = "progressbar", value = 0}
        filtering_progressbar.style.horizontally_stretchable = true

        local sorting_flow = progress_flow.add {type = "flow", name = "sorting-flow", direction = "vertical"}
        sorting_flow.style.horizontally_stretchable = true
        sorting_flow.style.vertical_spacing = 0
        sorting_flow.style.bottom_padding = 0
        sorting_flow.style.top_padding = 0
        local sorting_label = sorting_flow.add {type = "label", name = "label", caption = {"hextorio-gui.sorting-trades", 0, 0}}
        sorting_label.style.font = "default-bold"
        sorting_label.style.font_color = {0.5, 0.5, 0.5}
        local sorting_progressbar = sorting_flow.add {type = "progressbar", name = "progressbar", value = 0}
        sorting_progressbar.style.horizontally_stretchable = true
    end

    trades.queue_trade_collection_job(player, trades_set, filter, not use_batch_processing)
end

---Fully refresh a player's trade overview GUI.
---Forces the player's filter settings to match their GUI (changing the filter settings, not the GUI).
---Subsequently clears currently displayed trades and queues a filtration and rendering job.
---@param player LuaPlayer
function trade_overview_gui.update_trade_overview(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then
        trade_overview_gui.init_trade_overview(player)
        frame = player.gui.screen["trade-overview"]
    end

    local filter_frame = frame["filter-frame"]
    for surface_name, _ in pairs(storage.SUPPORTED_PLANETS) do
        filter_frame["left"]["planet-flow"][surface_name].enabled = game.get_surface(surface_name) ~= nil
    end

    -- The GUI likely changed as update_trade_overview() typically called from GUI event callbacks.
    -- So, update filter settings to match.
    -- Doing that automatically triggers a trade list refresh as well.
    trade_overview_gui.reconcile_filter_settings_with_gui(player, true)
    trade_overview_gui.collect_and_display_trades(player)
end

---Get a player's history of past filter settings.
---@param player LuaPlayer
---@return {data: TradeOverviewFilterSettings[], index: int, capacity: int}
function trade_overview_gui.get_filter_history(player)
    local filter_history_storage = storage.trade_overview.filter_history
    if not filter_history_storage then
        filter_history_storage = {}
        storage.trade_overview.filter_history = filter_history_storage
    end

    local filter_history = filter_history_storage[player.index]
    if not filter_history then
        filter_history = history.new("TradeOverviewFilterSettings", 32)
        filter_history_storage[player.index] = filter_history
    end

    return filter_history
end

---Add filter settings to a player's filter history.
---@param player LuaPlayer
---@param filters TradeOverviewFilterSettings
function trade_overview_gui.add_filter_history(player, filters)
    local filter_history = trade_overview_gui.get_filter_history(player)

    -- TODO: store only non-default values from filter settings to minimize data which can bloat save times (don't know if it's enough data to care about, though, the hex grid data is far more abundant)
    -- e.g. don't store "show interplanetary = false" but store "show interplanetary = true", and infer default values on fetch
    local new_data = table.deepcopy(filters)

    history.add(filter_history, new_data)
end

---Set GUI states in a player's trade overview to exactly match their current stored trade overview filter settings.
---Does not reload the trades list.
---@param player LuaPlayer
function trade_overview_gui.reconcile_gui_with_filter_settings(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local filter_frame = frame["filter-frame"]
    if not filter_frame then return end

    local filter = trade_overview_gui.get_player_trade_overview_filter(player)

    local left_frame = filter_frame["left"]
    local right_frame = filter_frame["right"]

    local trade_contents_frame = left_frame["trade-contents-flow"]["frame"]
    local trade_inputs = trade_contents_frame["inputs"]
    local trade_outputs = trade_contents_frame["outputs"]

    if filter.planets then
        for _, planet_button in pairs(left_frame["planet-flow"].children) do
            if filter.planets[planet_button.name] ~= nil then
                planet_button.toggled = filter.planets[planet_button.name]
            end
        end
    end

    for i = 1, 3 do
        trade_inputs["choose-elems"]["input-item-" .. i].elem_value = filter.input_items and filter.input_items[i] or nil
        trade_outputs["choose-elems"]["output-item-" .. i].elem_value = filter.output_items and filter.output_items[i] or nil
    end

    trade_inputs["exact-inputs-match"]["checkbox"].state = filter.exact_inputs_match or false
    trade_outputs["exact-outputs-match"]["checkbox"].state = filter.exact_outputs_match or false
    if filter.num_item_bounds then
        trade_inputs["max-inputs-flow"]["slider"].slider_value = filter.num_item_bounds.inputs.max
        trade_outputs["max-outputs-flow"]["slider"].slider_value = filter.num_item_bounds.outputs.max
    end

    trade_contents_frame["center"]["trade-arrow"].sprite = filter.show_favorited_only and "trade-arrow-favorited" or "trade-arrow"

    right_frame["show-only-claimed"]["checkbox"].state = filter.show_claimed_only or false
    right_frame["show-only-interplanetary"]["checkbox"].state = filter.show_interplanetary_only or false
    right_frame["exclude-favorited"]["checkbox"].state = filter.exclude_favorited or false
    right_frame["exclude-dungeons"]["checkbox"].state = filter.exclude_dungeons or false
    right_frame["exclude-sinks-generators"]["checkbox"].state = filter.exclude_sinks_generators or false

    if filter.sorting then
        local sorting_dropdown = right_frame["sort-method"]["dropdown"]
        for i = 1, #sorting_dropdown.items do
            if sorting_dropdown.get_item(i)[1]:sub(19) == filter.sorting.method then
                sorting_dropdown.selected_index = i
                break
            end
        end
        right_frame["sort-direction"].switch_state = filter.sorting.ascending and "left" or "right"
    end

    if filter.max_trades then
        local max_trades_dropdown = right_frame["max-trades-flow"]["dropdown"]
        for i = 1, #max_trades_dropdown.items do
            if tonumber(max_trades_dropdown.items[i][2]) == filter.max_trades then
                max_trades_dropdown.selected_index = i
                break
            end
        end
    end

    right_frame["exclude-dungeons"]["checkbox"].state = filter.exclude_dungeons or false
    right_frame["exclude-favorited"]["checkbox"].state = filter.exclude_favorited or false
    right_frame["exclude-dungeons"]["checkbox"].enabled = not filter.show_claimed_only
    right_frame["exclude-favorited"]["checkbox"].enabled = not filter.show_favorited_only

    if filter.exact_inputs_match then
        trade_inputs["max-inputs-flow"]["slider"].slider_value = filter.num_item_bounds.inputs.max
    end
    if filter.exact_outputs_match then
        trade_outputs["max-outputs-flow"]["slider"].slider_value = filter.num_item_bounds.outputs.max
    end

    trade_inputs["max-inputs-flow"]["label"].caption   = {"hextorio-gui.max", filter.num_item_bounds.inputs.max}
    trade_outputs["max-outputs-flow"]["label"].caption = {"hextorio-gui.max", filter.num_item_bounds.outputs.max}
    trade_inputs["max-inputs-flow"]["slider"].enabled   = not filter.exact_inputs_match
    trade_outputs["max-outputs-flow"]["slider"].enabled = not filter.exact_outputs_match
end

---Set values in a player's filter settings to exactly match the GUI states in their trade overview.
---@param player LuaPlayer
---@param add_to_history boolean Whether to record the newly updated filter settings to the player's history.
function trade_overview_gui.reconcile_filter_settings_with_gui(player, add_to_history)
    local frame = player.gui.screen["trade-overview"]
    if not frame then return end

    local filter_frame = frame["filter-frame"]
    if not filter_frame then return end

    local trade_contents_frame = filter_frame["left"]["trade-contents-flow"]["frame"]

    local filter = trade_overview_gui.get_player_trade_overview_filter(player)

    filter.planets = {}
    for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
        filter.planets[planet_button.name] = planet_button.toggled
    end

    filter.input_items = {}
    for i = 1, 3 do
        local input_item = trade_contents_frame["inputs"]["choose-elems"]["input-item-" .. i]
        if input_item.elem_value then table.insert(filter.input_items, input_item.elem_value) end
    end
    if not next(filter.input_items) then filter.input_items = nil end

    filter.output_items = {}
    for i = 1, 3 do
        local output_item = trade_contents_frame["outputs"]["choose-elems"]["output-item-" .. i]
        if output_item.elem_value then table.insert(filter.output_items, output_item.elem_value) end
    end
    if not next(filter.output_items) then filter.output_items = nil end

    filter.exact_inputs_match = trade_contents_frame["inputs"]["exact-inputs-match"]["checkbox"].state
    filter.exact_outputs_match = trade_contents_frame["outputs"]["exact-outputs-match"]["checkbox"].state
    filter.show_claimed_only = filter_frame["right"]["show-only-claimed"]["checkbox"].state
    filter.show_interplanetary_only = filter_frame["right"]["show-only-interplanetary"]["checkbox"].state
    filter.show_favorited_only = trade_contents_frame["center"]["trade-arrow"].sprite == "trade-arrow-favorited"
    filter.exclude_dungeons = filter_frame["right"]["exclude-dungeons"]["checkbox"].state
    filter.exclude_sinks_generators = filter_frame["right"]["exclude-sinks-generators"]["checkbox"].state
    filter.exclude_favorited = filter_frame["right"]["exclude-favorited"]["checkbox"].state

    filter.num_item_bounds = {
        inputs  = {min = 1, max = trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].slider_value},
        outputs = {min = 1, max = trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].slider_value},
    }

    local sorting_dropdown = filter_frame["right"]["sort-method"]["dropdown"]
    filter.sorting = {
        method = sorting_dropdown.get_item(sorting_dropdown.selected_index)[1]:sub(19),
        ascending = filter_frame["right"]["sort-direction"].switch_state == "left",
    }

    local max_trades
    local max_trades_dropdown = filter_frame["right"]["max-trades-flow"]["dropdown"]
    if max_trades_dropdown.selected_index == 0 then
        max_trades = math.huge
    else
        local selected = max_trades_dropdown.items[max_trades_dropdown.selected_index]
        if selected then max_trades = tonumber(selected[2]) end
    end
    filter.max_trades = max_trades or 100

    trade_overview_gui.post_process_filter_data(filter)

    if add_to_history then
        trade_overview_gui.add_filter_history(player, filter)
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

---Get the current filter settings for a player's trade overview.
---@param player LuaPlayer
---@return TradeOverviewFilterSettings
function trade_overview_gui.get_player_trade_overview_filter(player)
    local filters = storage.trade_overview.filters
    if not filters[player.name] then
        filters[player.name] = {}
    end
    return filters[player.name]
end

---Set a player's trade overview filters, reconcile their GUI, and refresh the trade list.
---@param player LuaPlayer
---@param filters TradeOverviewFilterSettings
---@param add_to_history boolean Whether to record the newly updated filter settings to the player's history.
function trade_overview_gui.set_player_trade_overview_filters(player, filters, add_to_history)
    trade_overview_gui.post_process_filter_data(filters)
    storage.trade_overview.filters[player.name] = table.deepcopy(filters)

    trade_overview_gui.reconcile_gui_with_filter_settings(player)
    trade_overview_gui.collect_and_display_trades(player)

    if add_to_history then
        trade_overview_gui.add_filter_history(player, filters)
    end
end

---@param player LuaPlayer
function trade_overview_gui.swap_trade_overview_content_filters(player)
    local filters = trade_overview_gui.get_player_trade_overview_filter(player)
    local new_inputs = filters.output_items or {}
    local new_outputs = filters.input_items or {}

    -- Only trigger a refresh if necessary.
    if
        lib.tables_equal(sets.new(new_inputs), sets.new(new_outputs)) and
        lib.tables_equal(filters.num_item_bounds.inputs, filters.num_item_bounds.outputs) and
        filters.exact_inputs_match == filters.exact_outputs_match
    then return end

    if #new_inputs > 0 then
        filters.input_items = new_inputs
    else
        filters.input_items = nil
    end

    if #new_outputs > 0 then
        filters.output_items = new_outputs
    else
        filters.output_items = nil
    end

    filters.num_item_bounds.inputs, filters.num_item_bounds.outputs = filters.num_item_bounds.outputs, filters.num_item_bounds.inputs
    filters.exact_inputs_match, filters.exact_outputs_match = filters.exact_outputs_match, filters.exact_inputs_match

    trade_overview_gui.set_player_trade_overview_filters(player, filters, true)
end

function trade_overview_gui.on_trade_collection_progress(player, progress, current, total)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]
    if not progress_flow then return end

    local collection_flow = progress_flow["collection-flow"]
    if collection_flow then
        collection_flow["label"].caption = {"hextorio-gui.collecting-trades", current, total}
        collection_flow["progressbar"].value = progress
    end
end

function trade_overview_gui.on_trade_collection_complete(player, collected_trades, filter, process_immediately)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]
    if progress_flow then
        local collection_flow = progress_flow["collection-flow"]
        if collection_flow then
            collection_flow["progressbar"].value = 1
        end

        local filtering_flow = progress_flow["filtering-flow"]
        if filtering_flow then
            filtering_flow["label"].style.font_color = {1, 1, 1}
        end
    end

    trades.queue_trade_filtering_job(player, collected_trades, filter, process_immediately)
end

function trade_overview_gui.on_trade_filtering_progress(player, progress, current, total)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]
    if not progress_flow then return end

    local filtering_flow = progress_flow["filtering-flow"]
    if filtering_flow then
        filtering_flow["label"].caption = {"hextorio-gui.filtering-trades", current, total}
        filtering_flow["progressbar"].value = progress
    end
end

function trade_overview_gui.on_trade_sorting_starting(player, num_trades)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]
    if progress_flow then
        -- Mark filtering as complete
        local filtering_flow = progress_flow["filtering-flow"]
        if filtering_flow then
            filtering_flow["progressbar"].value = 1
        end

        -- Enable sorting label (remove greyed out appearance)
        local sorting_flow = progress_flow["sorting-flow"]
        if sorting_flow then
            sorting_flow["label"].style.font_color = {1, 1, 1}
        end
    end
end

function trade_overview_gui.on_trade_sorting_progress(player, progress, current, total)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]
    if not progress_flow then return end

    local sorting_flow = progress_flow["sorting-flow"]
    if sorting_flow then
        sorting_flow["label"].caption = {"hextorio-gui.sorting-trades", current, total}
        sorting_flow["progressbar"].value = progress
    end
end

function trade_overview_gui.on_trade_sorting_complete(player, sorted_lookup, sorted_array, is_favorited, filter)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    -- Use the sorted array directly (already in correct order)
    local trades_list = sorted_array or {}

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]

    if #trades_list == 0 then
        trade_table.clear()

        local has_planet_selected = false
        if filter.planets then
            for _, allow in pairs(filter.planets) do
                if allow then
                    has_planet_selected = true
                    break
                end
            end
        end

        if not has_planet_selected then
            trade_table.add {type = "label", caption = lib.color_localized_string({"hextorio-gui.no-planets-selected"}, "white", "heading-2")}
        else
            trade_table.add {type = "label", caption = lib.color_localized_string({"hextorio-gui.no-trades-match-filters"}, "white", "heading-2")}
        end

        storage.trade_overview.trades[player.name] = {}
        return
    end

    storage.trade_overview.trades[player.name] = trades_list

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

        batched = true,
        table_batch_def = {
            column_count = 2,
            horizontal_spacing = 28 / 1.2,
        },
    })
end

function trade_overview_gui.on_trade_overview_jobs_cancelled(player)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not core_gui.is_frame_open(player, "trade-overview") then return end

    local trade_table = frame["trade-table-frame"]["scroll-pane"]["table"]
    local progress_flow = trade_table["progress-flow"]
    if progress_flow then
        local collection_flow = progress_flow["collection-flow"]
        if collection_flow then
            collection_flow["label"].caption = {"hextorio-gui.collecting-trades", 0, 0}
            collection_flow["progressbar"].value = 0
        end

        local filtering_flow = progress_flow["filtering-flow"]
        if filtering_flow then
            filtering_flow["label"].caption = {"hextorio-gui.filtering-trades", 0, 0}
            filtering_flow["progressbar"].value = 0
        end

        local sorting_flow = progress_flow["sorting-flow"]
        if sorting_flow then
            sorting_flow["label"].caption = {"hextorio-gui.sorting-trades", 0, 0}
            sorting_flow["progressbar"].value = 0
        end
    end

    local processing_flow = frame["filter-frame"]["left"]["buttons-flow"]["processing-flow"]
    if processing_flow and processing_flow.valid then
        local processing_label = processing_flow["label"]
        local processing_progressbar = processing_flow["progressbar"]
        if processing_label and processing_label.valid then
            processing_label.caption = ""
        end
        if processing_progressbar and processing_progressbar.valid then
            processing_progressbar.value = 0
            processing_progressbar.visible = false
        end
    end
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
    if not frame or not frame.valid then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))

    if storage.gui and storage.gui.trades_scroll_pane_update and storage.gui.trades_scroll_pane_update[player.name] then
        storage.gui.trades_scroll_pane_update[player.name].finished = true
    end
end

function trade_overview_gui.on_trade_item_clicked(player, element, item_name, is_input)
    -- Probably should use a different function for this but whatever
    trade_overview_gui.on_catalog_trade_overview_clicked(player, item_name, not is_input)
end

function trade_overview_gui.on_catalog_trade_overview_clicked(player, item_name, as_input)
    if not quests.is_feature_unlocked "trade-overview" then return end
    local filter = trade_overview_gui.get_player_trade_overview_filter(player)

    if as_input then
        filter.input_items = {item_name}
        filter.output_items = {}
    else
        filter.input_items = {}
        filter.output_items = {item_name}
    end

    trade_overview_gui.reconcile_gui_with_filter_settings(player)
    trade_overview_gui.show_trade_overview(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_trade_overview_button_click(player, elem)
    if gui.is_frame_open(player, "trade-overview") then
        trade_overview_gui.hide_trade_overview(player)
    else
        trade_overview_gui.show_trade_overview(player)
    end
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_export_json_button_click(player, elem)
    -- Queue the export job
    trades.queue_trade_export_job(player)

    -- Update the button to show it's processing
    local processing_flow = elem.parent["processing-flow"]
    if processing_flow and processing_flow.valid then
        local processing_label = processing_flow["label"]
        local processing_progressbar = processing_flow["progressbar"]
        if processing_label and processing_label.valid then
            processing_label.caption = {"hextorio-gui.exporting-trades", 0, 0}
        end
        if processing_progressbar and processing_progressbar.valid then
            processing_progressbar.value = 0
            processing_progressbar.visible = true
        end
    end
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_clear_filters_button_click(player, elem)
    local filter_frame = elem.parent.parent.parent
    if not filter_frame then return end

    local all_planets_off = true
    for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
        if planet_button.toggled then
            all_planets_off = false
        end
    end

    if all_planets_off then
        for _, planet_button in pairs(filter_frame["left"]["planet-flow"].children) do
            planet_button.toggled = planet_button.name == "nauvis"
        end
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
    right_frame["exclude-favorited"]["checkbox"].state = false
    right_frame["exclude-dungeons"]["checkbox"].state = false
    right_frame["exclude-sinks-generators"]["checkbox"].state = false

    local trade_contents_frame = filter_frame["left"]["trade-contents-flow"]["frame"]
    trade_contents_frame["inputs"]["exact-inputs-match"]["checkbox"].state = false
    trade_contents_frame["outputs"]["exact-outputs-match"]["checkbox"].state = false
    trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].slider_value = trade_contents_frame["inputs"]["max-inputs-flow"]["slider"].get_slider_maximum()
    trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].slider_value = trade_contents_frame["outputs"]["max-outputs-flow"]["slider"].get_slider_maximum()
    trade_contents_frame["center"]["trade-arrow"].sprite = "trade-arrow"

    trade_overview_gui.update_trade_overview(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_planet_filter_button_click(player, elem)
    elem.toggled = not elem.toggled
    trade_overview_gui.update_trade_overview(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_trade_overview_contents_arrow_click(player, elem)
    if elem.sprite == "trade-arrow" then
        elem.sprite = "trade-arrow-favorited"
    else
        elem.sprite = "trade-arrow"
    end

    trade_overview_gui.update_trade_overview(player)
end

---@param player LuaPlayer
---@param progress number
---@param current int
---@param total int
function trade_overview_gui.on_trade_export_progress(player, progress, current, total)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not frame.valid then return end

    local processing_flow = frame["filter-frame"]["left"]["buttons-flow"]["processing-flow"]
    if processing_flow and processing_flow.valid then
        local processing_label = processing_flow["label"]
        local processing_progressbar = processing_flow["progressbar"]
        if processing_label and processing_label.valid then
            processing_label.caption = {"hextorio-gui.exporting-trades", current, total}
        end
        if processing_progressbar and processing_progressbar.valid then
            processing_progressbar.value = progress
            processing_progressbar.visible = true
        end
    end
end

---@param player LuaPlayer
---@param to_export table
function trade_overview_gui.on_trade_export_complete(player, to_export)
    local frame = player.gui.screen["trade-overview"]
    if not frame or not frame.valid then return end

    local processing_flow = frame["filter-frame"]["left"]["buttons-flow"]["processing-flow"]
    if processing_flow and processing_flow.valid then
        local processing_label = processing_flow["label"]
        local processing_progressbar = processing_flow["progressbar"]
        if processing_label and processing_label.valid then
            processing_label.caption = {"hextorio-gui.export-complete"}
        end
        if processing_progressbar and processing_progressbar.valid then
            processing_progressbar.value = 1
            processing_progressbar.visible = false
        end
    end

    -- local prof = game.create_profiler()
    local filename = "all-trades-encoded-json.txt"
    helpers.write_file(
        filename,
        helpers.encode_string(helpers.table_to_json(to_export)),
        false,
        player.index
    )
    -- log("JSON export completed in:")
    -- log(prof)

    player.print({"hextorio.trades-exported", "Factorio/script-output/" .. filename})
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_gui_back(player, elem)
    local filter_history = trade_overview_gui.get_filter_history(player)
    local filters = history.step(filter_history, -1)
    if not filters then filters = {} end
    trade_overview_gui.set_player_trade_overview_filters(player, filters, false)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function trade_overview_gui.on_gui_forward(player, elem)
    local filter_history = trade_overview_gui.get_filter_history(player)
    if history.is_current(filter_history) then return end

    local filters = history.step(filter_history, 1)
    if not filters then filters = {} end
    trade_overview_gui.set_player_trade_overview_filters(player, filters, false)
end



return trade_overview_gui
