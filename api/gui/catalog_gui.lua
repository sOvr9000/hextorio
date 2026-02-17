
local lib = require "api.lib"
local gui = require "api.gui.core_gui"
local item_values = require "api.item_values"
local coin_tiers  = require "api.coin_tiers"
local inventories = require "api.inventories"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local sets = require "api.sets"
local event_system = require "api.event_system"
local quests = require "api.quests"
local item_buffs = require "api.item_buffs"
local gui_stack = require "api.gui.gui_stack"
local coin_tier_gui = require "api.gui.coin_tier_gui"

local catalog_gui = {}



---@class PlayerCatalogSelection
---@field surface_name string The surface under which the item was selected; can be used to set scroll position when re-opening the catalog GUI
---@field item_name string The currently selected item in the catalog
---@field bazaar_quality string Quality name for quantum bazaar transactions
---@field last_item_selected string|nil The last item selected in the catalog search
---@field last_qb_item_selected string|nil The last item selected in the quantum bazaar search
---@field bazaar_buy_amount int|nil The quantity of items selected for purchase from the quantum bazaar



function catalog_gui.register_events()
    event_system.register_gui("gui-clicked", "catalog-button", catalog_gui.on_catalog_button_click)
    event_system.register_gui("gui-closed", "catalog", catalog_gui.hide_catalog)
    event_system.register_gui("gui-clicked", "catalog-item", catalog_gui.on_catalog_item_click)
    event_system.register_gui("gui-clicked", "open-in-factoriopedia", catalog_gui.on_open_factoriopedia_button_click)
    event_system.register_gui("gui-clicked", "open-in-trade-overview", catalog_gui.on_open_trade_overview_button_click)
    event_system.register_gui("gui-elem-changed", "selected-item-view", catalog_gui.on_catalog_search_item_selected)
    event_system.register_gui("gui-clicked", "item-buff-button", catalog_gui.on_item_buff_button_click)
    event_system.register_gui("gui-clicked", "open-item-buffs-button", catalog_gui.on_open_item_buffs_button_click)

    event_system.register_gui("gui-selection-changed", "quantum-bazaar-changed", catalog_gui.on_quantum_bazaar_changed)
    event_system.register_gui("gui-clicked", "quantum-bazaar-sell-in-hand", catalog_gui.on_quantum_bazaar_sell_in_hand_clicked)
    event_system.register_gui("gui-clicked", "quantum-bazaar-sell-inventory", catalog_gui.on_quantum_bazaar_sell_inventory_clicked)
    event_system.register_gui("gui-clicked", "quantum-bazaar-buy-items", catalog_gui.on_quantum_bazaar_buy_items_clicked)
    event_system.register_gui("gui-clicked", "quantum-bazaar-buy-max", catalog_gui.on_quantum_bazaar_buy_max_clicked)
    event_system.register_gui("gui-elem-changed", "quantum-bazaar-changed", catalog_gui.on_quantum_bazaar_changed)
    event_system.register_gui("gui-slider-changed", "quantum-bazaar-slider-changed", catalog_gui.on_quantum_bazaar_slider_changed)

    event_system.register("post-rank-up-command", function(player, params)
        local selection = catalog_gui.get_catalog_selection(player)
        catalog_gui.set_catalog_selection(player, "nauvis", params[1], selection.bazaar_quality)
        catalog_gui.show_catalog(player)
    end)

    event_system.register("post-rank-up-all-command", function(player, params)
        catalog_gui.show_catalog(player)
    end)

    event_system.register("post-discover-all-command", function(player, params)
        catalog_gui.show_catalog(player)
    end)

    event_system.register("quest-reward-received", function(reward_type, value)
        if reward_type == "unlock-feature" then
            if value == "catalog" then
                for _, player in pairs(game.players) do
                    catalog_gui.init_catalog_button(player)
                end
            end
        end
    end)

    event_system.register("item-buff-level-changed", function(item_name)
        for _, player in pairs(game.connected_players) do
            if gui.is_frame_open(player, "catalog") then
                local selection = catalog_gui.get_catalog_selection(player)
                if selection.item_name == item_name then
                    catalog_gui.update_catalog_inspect_frame(player)
                end
            end
        end
    end)

    event_system.register("item-buff-data-reset", function()
        for _, player in pairs(game.connected_players) do
            if gui.is_frame_open(player, "catalog") then
                -- catalog_gui.hide_catalog(player)
                catalog_gui.update_catalog(player)
            end
        end
    end)

    event_system.register("post-set-item-value-command", function(player, params)
        catalog_gui.reinitialize()
    end)

    event_system.register("post-import-item-values-command", function(player, params)
        catalog_gui.reinitialize()
    end)

    event_system.register("player-coins-base-value-changed", function(player, coin_value)
        if not catalog_gui.is_catalog_open(player) then return end
        catalog_gui.update_quantum_bazaar(player)
    end)

    event_system.register("item-buffs-gui-closed", function(player)
        if gui_stack.is_switching(player) then
            return
        end
        catalog_gui.show_catalog(player)
    end)

    event_system.register("item-values-recalculated", catalog_gui.reinitialize)
end

---Reinitialize the catalog GUI for the given player, or all players if no player is provided.
---@param player LuaPlayer|nil
function catalog_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.connected_players) do
            catalog_gui.reinitialize(p)
        end
        return
    end

    local frame = player.gui.screen["catalog"]
    if frame then frame.destroy() end

    local button = player.gui.top["catalog-button"]
    if button then button.destroy() end

    catalog_gui.init_catalog_button(player)
    catalog_gui.init_catalog(player)
end

function catalog_gui.init_catalog_button(player)
    if not player.gui.top["catalog-button"] then
        local catalog_button = player.gui.top.add {
            type = "sprite-button",
            name = "catalog-button",
            sprite = "catalog",
            tags = {handlers = {["gui-clicked"] = "catalog-button"}},
            tooltip = {"hextorio-gui.catalog-button-tooltip"},
        }
    end
    player.gui.top["catalog-button"].visible = quests.is_feature_unlocked "catalog"
end

function catalog_gui.init_catalog(player)
    local frame = player.gui.screen.add {
        type = "frame",
        name = "catalog",
        direction = "vertical",
        tags = {handlers = {["gui-closed"] = "catalog"}},
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
        local items_sorted_by_value = item_values.get_items_sorted_by_value(surface_name, true, true, false, true)

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

        local catalog_table = scroll_pane.add {type = "table", name = "table-" .. surface_name, column_count = 13, tags = {surface_name = surface_name}}
        gui.auto_width(catalog_table)

        local n = 1
        for j = 1, #items_sorted_by_value do
            local item_name = items_sorted_by_value[j]
            if lib.is_catalog_item(surface_name, item_name) then
                -- log("create catalog entry for " .. item_name .. " on " .. surface_name)

                n = n + 1
                local rank = item_ranks.get_item_rank(item_name)

                local rank_flow = catalog_table.add {
                    type = "flow",
                    name = "rank-flow-" .. item_name,
                    direction = "vertical",
                    tags = {item_name = item_name},
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
                    tags = {handlers = {["gui-clicked"] = "catalog-item"}, surface_name = surface_name, item_name = item_name},
                }
                sprite_button.style.left_margin = 5

                local rank_stars = rank_flow.add {
                    type = "sprite",
                    name = "rank-stars",
                    sprite = "rank-" .. rank,
                }
                rank_stars.style.height = 20
                rank_stars.style.width = 50
                rank_stars.style.stretch_image_to_widget_size = true

                gui.give_item_tooltip(player, surface_name, sprite_button)
            end
        end
    end
end

function catalog_gui.update_catalog(player)
    local frame = player.gui.screen["catalog"]
    if not frame then
        catalog_gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end

    local scroll_pane = frame["flow"]["catalog-frame"]["scroll-pane"]

    log("update catalog entry sprites")
    for _, tab in pairs(scroll_pane.children) do
        -- lib.log(tab.name)
        if tab.type == "table" then
            -- Count discovered items and achieved ranks for each surface
            local discovered_items = 0
            local achieved_ranks = {0, 0, 0, 0}

            local surface_name = tab.tags.surface_name or "nauvis"
            -- log("surface " .. surface_name)
            for _, rank_flow in pairs(tab.children) do
                local item_name = rank_flow.tags.item_name or "stone"
                -- log("item " .. item_name)
                if trades.is_item_discovered(item_name) then
                    -- log("DISCOVERED")
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
                    -- log("NOT DISCOVERED")
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

    local selection = catalog_gui.get_catalog_selection(player)
    catalog_gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

function catalog_gui.update_catalog_inspect_frame(player)
    local frame = player.gui.screen["catalog"]
    if not frame or not frame.valid then
        catalog_gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end

    local inspect_frame = frame["flow"]["inspect-frame"]
    if not inspect_frame or not inspect_frame.valid then
        return
    end

    catalog_gui.verify_catalog_storage(player)
    local selection = catalog_gui.get_catalog_selection(player)
    local rank_obj = item_ranks.get_rank_obj(selection.item_name)
    if not rank_obj then return end

    inspect_frame.clear()

    catalog_gui.build_header(player, rank_obj, inspect_frame)
    catalog_gui.build_item_buffs(player, rank_obj, inspect_frame)
    catalog_gui.build_rank_bonuses(player, rank_obj, inspect_frame)
    catalog_gui.build_quantum_bazaar(player, rank_obj, inspect_frame)
end

function catalog_gui.build_header(player, rank_obj, frame)
    local selection = catalog_gui.get_catalog_selection(player)

    local rank_flow = frame.add {
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

    frame.add {type = "line", direction = "horizontal"}

    local control_flow = frame.add {
        type = "flow",
        name = "control-flow",
        direction = "horizontal",
    }

    local show_buffs = quests.is_feature_unlocked "item-buffs"

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
        tags = {handlers = {["gui-elem-changed"] = "selected-item-view"}},
    }

    local is_input = catalog_gui.get_expected_trade_overview_filter_side(selection.item_name)
    local open_in_trade_overview = control_flow.add {
        type = "sprite-button",
        name = "open-in-trade-overview",
        sprite = "trade-overview",
        tags = {handlers = {["gui-clicked"] = "open-in-trade-overview"}},
    }

    if is_input then
        open_in_trade_overview.tooltip = {"hextorio-gui.open-in-trade-overview-input"}
    else
        open_in_trade_overview.tooltip = {"hextorio-gui.open-in-trade-overview-output"}
    end

    if not quests.is_feature_unlocked "trade-overview" then
        open_in_trade_overview.enabled = false
    end

    local open_in_factoriopedia = control_flow.add {
        type = "sprite-button",
        name = "open-in-factoriopedia",
        sprite = "utility/side_menu_factoriopedia_icon",
        tooltip = {"hextorio-gui.open-in-factoriopedia"},
        tags = {handlers = {["gui-clicked"] = "open-in-factoriopedia"}},
    }

    local open_item_buffs = control_flow.add {
        type = "sprite-button",
        name = "open-item-buffs-button",
        sprite = "utility/side_menu_bonus_icon",
        tags = {handlers = {["gui-clicked"] = "open-item-buffs-button"}},
    }
    open_item_buffs.enabled = show_buffs
    if show_buffs then
        open_item_buffs.tooltip = {"hextorio-gui.open-item-buffs-button-tooltip"}
    end

    frame.add {type = "line", direction = "horizontal"}
end

function catalog_gui.build_item_buffs(player, rank_obj, frame)
    local selection = catalog_gui.get_catalog_selection(player)
    local buffs = item_buffs.get_buffs(selection.item_name)

    local bonuses_label = gui.auto_center_horizontally(frame, {
        type = "label",
        name = "bonuses-label",
        caption = {"hextorio-gui.bonuses"},
    })
    bonuses_label.style.font = "heading-1"

    if not quests.is_feature_unlocked "item-buffs" or rank_obj.rank < 2 or not next(buffs) then return end
    item_buffs.fetch_settings()

    local item_buff_flow = frame.add {
        type = "flow",
        name = "item-buff-flow",
        direction = "horizontal",
    }

    local is_buff_unlocked = item_buffs.is_unlocked(selection.item_name)
    local is_enhancement_unlocked = quests.is_feature_unlocked "item-buff-enhancement"
    local item_buff_level = item_buffs.get_item_buff_level(selection.item_name)
    local cost = item_buffs.get_item_buff_cost(selection.item_name)

    local buff_button_type = "item-buff-unlock"
    local buff_button_sprite = buff_button_type
    local enabled = true
    local tooltip = {"hextorio-gui." .. buff_button_type .. "-tooltip"}
    if is_buff_unlocked then
        buff_button_type = "item-buff-enhance"
        buff_button_sprite = "utility/side_menu_bonus_icon"
        tooltip = {"hextorio-gui." .. buff_button_type .. "-tooltip"}
        if not is_enhancement_unlocked then
            enabled = false
            tooltip = nil
        end
    end

    -- SOMEHOW this is occurring. I have NO idea how it's even possible. Fixes some random crashes. This element is not immediately invalid after creation. It's only invalid after the block above executes. (what the actual fuck?)
    -- TODO: resolve that item buff level is being reset somehow with /reload-item-buff-effects
    if not item_buff_flow.valid then
        lib.log_error("item buffs level reset?")
        return
    end

    local buff_button = item_buff_flow.add {
        type = "sprite-button",
        name = buff_button_type,
        sprite = buff_button_sprite,
        tags = {handlers = {["gui-clicked"] = "item-buff-button"}},
        enabled = enabled,
        tooltip = tooltip,
    }

    local coin_tier_flow = coin_tier_gui.create_coin_tier(item_buff_flow, "cost")
    coin_tier_gui.update_coin_tier(coin_tier_flow, cost)

    local buff_table = frame.add {
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
                local str = {"", "[color=green]+" .. (math.floor(values[1] * 10 + 0.5) * 0.1) .. "[.color]"}
                if is_enhancement_unlocked then
                    table.insert(str, " [color=gray](+" .. (math.floor((incremental_buff.value or incremental_buff.values[1]) * 100 + 0.5) * 0.01) .. ")[.color]")
                end
                return str
            end
            local str = {"", "[color=green]" .. lib.format_percentage(values[1], 1, true, true) .. "[.color]"}
            if is_enhancement_unlocked then
                table.insert(str, " [color=gray](" .. lib.format_percentage(incremental_buff.value or incremental_buff.values[1], 2, true, true) .. ")[.color]")
            end
            return str
        end

        if buff.type == "recipe-productivity" then
            local str = {"", "[color=green]" .. lib.format_percentage(values[2] * 0.01, 1, true, true) .. "[.color]"}
            if is_enhancement_unlocked then
                table.insert(str, " [color=gray](" .. lib.format_percentage(incremental_buff.values[2] * 0.01, 2, true, true) .. ")[.color]")
            end
            return str
        end

        for i, v in pairs(values) do
            if type(v) == "number" then
                ---@diagnostic disable-next-line: assign-type-mismatch
                values[i] = "[color=green]" .. v .. "[.color]"
                if is_enhancement_unlocked then
                    ---@diagnostic disable-next-line: assign-type-mismatch
                    values[i] = values[i] .. " [color=gray](" .. lib.format_percentage(incremental_buff.values[i], 2, true, true) .. ")[.color]"
                end
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

            if is_buff_unlocked then
                buff_label.tooltip = gui.get_buff_description_tooltip(buff.type)
            end
        elseif buff.values then
            local caption = lib.color_localized_string({"hextorio-gui.obfuscated-text"}, "gray")

            if is_buff_unlocked then
                caption = format_buff_values(buff)
            end

            local buff_label = frame.add {
                type = "label",
                name = "buff-label-" .. i,
                caption = caption,
            }
        end
    end
end

function catalog_gui.build_rank_bonuses(player, rank_obj, frame)
    local selection = catalog_gui.get_catalog_selection(player)

    if rank_obj.rank > 1 then
        local bonus_productivity = frame.add {
            type = "label",
            name = "bonus-productivity",
            caption = {"", lib.color_localized_string({"hextorio-gui.main-bonus"}, "blue", "heading-2"), "\n", {"hextorio-gui.rank-bonus-trade-productivity", math.floor(100 * item_ranks.get_rank_bonus_effect(rank_obj.rank)), "green", "heading-2"}},
        }
        bonus_productivity.style.single_line = false
        gui.auto_width_height(bonus_productivity)
    else
        local none_label = frame.add {
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
        local rank_bonus_unique_heading = frame.add {
            type = "label",
            name = "rank-bonus-unique-heading-" .. i,
            caption = lib.color_localized_string({"", "[img=" .. storage.item_ranks.rank_star_sprites[i] .. "] ", {"hextorio-gui.unique-bonus"}}, color_rich_text, "heading-2"),
        }

        local caption
        if i == 2 then
            caption = {"", {"hextorio-gui.rank-bonus-unique-" .. i, lib.format_percentage(lib.runtime_setting_value("rank-" .. i .. "-effect"), 1, false), color_text, "heading-2", selection.item_name}}
        elseif i == 3 then
            local planets_text = {""}
            for surface_name, _ in pairs(storage.SUPPORTED_PLANETS) do
                if not item_values.is_item_tradable(surface_name, selection.item_name) then
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

        local rank_bonus_unique = frame.add {
            type = "label",
            name = "rank-bonus-unique-" .. i,
            caption = caption,
        }

        rank_bonus_unique.style.single_line = false
        gui.auto_width(rank_bonus_unique)
    end

    if rank_obj.rank < 5 then
        frame.add {type = "line", direction = "horizontal"}

        local rank_up_header = frame.add {
            type = "label",
            name = "rank-up-header",
            caption = lib.get_rank_img_str(rank_obj.rank + 1),
        }

        local needs_prod = true
        if rank_obj.rank == 1 then
            -- Buy requirement
            local buy_completed = trades.get_total_bought(selection.item_name) > 0
            local buy_flow = frame.add {
                type = "flow",
                name = "buy-requirement-flow",
                direction = "horizontal",
            }
            local buy_checkbox = buy_flow.add {
                type = "checkbox",
                name = "buy-checkbox",
                state = buy_completed,
                enabled = not buy_completed,
            }
            buy_checkbox.ignored_by_interaction = true
            local buy_text_color = buy_completed and "96,96,96" or "white"
            local buy_label = buy_flow.add {
                type = "label",
                name = "buy-label",
                caption = lib.color_localized_string({"hextorio-gui.buy-requirement"}, buy_text_color),
            }
            buy_label.style.top_margin = -3

            -- Sell requirement
            local sell_completed = trades.get_total_sold(selection.item_name) > 0
            local sell_flow = frame.add {
                type = "flow",
                name = "sell-requirement-flow",
                direction = "horizontal",
            }
            local sell_checkbox = sell_flow.add {
                type = "checkbox",
                name = "sell-checkbox",
                state = sell_completed,
                enabled = not sell_completed,
            }
            sell_checkbox.ignored_by_interaction = true
            local sell_text_color = sell_completed and "96,96,96" or "white"
            local sell_label = sell_flow.add {
                type = "label",
                name = "sell-label",
                caption = lib.color_localized_string({"hextorio-gui.sell-requirement"}, sell_text_color),
            }
            sell_label.style.top_margin = -3

            needs_prod = false
        end

        if needs_prod then
            local rank_up_localized_str = {"hextorio-gui.rank-up-instructions-" .. rank_obj.rank}
            table.insert(rank_up_localized_str, lib.format_percentage(storage.item_ranks.productivity_requirements[rank_obj.rank], 0, false, true))
            table.insert(rank_up_localized_str, "green")
            table.insert(rank_up_localized_str, "heading-2")

            local rank_up_instructions = frame.add {
                type = "label",
                name = "rank-up-instructions",
                caption = rank_up_localized_str,
            }
            rank_up_instructions.style.single_line = false
            gui.auto_width_height(rank_up_instructions)
        end
    end

    if rank_obj.rank == 1 then
        gui.add_info(frame, {"hextorio-gui.buying-info"}, "info-buying")
        gui.add_info(frame, {"hextorio-gui.selling-info"}, "info-selling")
    end
end

function catalog_gui.build_quantum_bazaar(player, rank_obj, frame)
    if rank_obj.rank < 5 then return end

    local selection = catalog_gui.get_catalog_selection(player)

    frame.add {type = "line", direction = "horizontal"}
    local quantum_bazaar_header = gui.auto_center_horizontally(frame, {
        type = "label",
        name = "quantum-bazaar-header",
        caption = lib.color_localized_string({"hextorio-gui.quantum-bazaar"}, "[color=180,255,0]", "heading-1"),
    })
    local quantum_bazaar = frame.add {
        type = "flow",
        name = "quantum-bazaar",
        direction = "vertical",
    }

    local sell_inv_coin, buy_one_coin
    if player.character then
        buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality) / (storage.item_values.base_coin_value or 10))
        sell_inv_coin = inventories.get_total_coin_value(player.character.surface.name, lib.get_player_inventory(player), 5)
    else
        buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value("nauvis", selection.item_name, true, selection.bazaar_quality) / (storage.item_values.base_coin_value or 10))
        sell_inv_coin = inventories.get_total_coin_value("nauvis", lib.get_player_inventory(player), 5)
    end
    buy_one_coin = coin_tiers.ceil(buy_one_coin)

    local elem_filter_items = sets.new()
    for _, surface in pairs(game.surfaces) do
        local surface_name = surface.name
        if not lib.is_space_platform(surface) then
            local values = item_values.get_item_values_for_surface(surface.name, true)
            if values then
                for name, _ in pairs(values) do
                    if lib.is_catalog_item(surface_name, name) and item_ranks.get_item_rank(name) >= 5 then
                        sets.add(elem_filter_items, name)
                    end
                end
            end
        end
    end

    if not next(elem_filter_items) then
        lib.log_error("catalog_gui.build_quantum_bazaar: Failed to find valid items")
        return
    end

    local elem_filters = {}
    for name, _ in pairs(elem_filter_items) do
        table.insert(elem_filters, {filter = "name", name = name})
    end

    local button_flow = quantum_bazaar.add {
        type = "flow",
        name = "button-flow",
        direction = "horizontal",
    }

    local selected_item_qb = button_flow.add {
        type = "choose-elem-button",
        name = "selected-item-qb",
        elem_type = "item", -- TODO: Convert this to use "item-with-quality" so that the quality dropdown doesn't have to exist
        elem_filters = elem_filters,
        item = selection.item_name,
        tags = {handlers = {["gui-elem-changed"] = "quantum-bazaar-changed"}},
    }

    local sell_in_hand = button_flow.add {
        type = "sprite-button",
        name = "sell-in-hand",
        sprite = "hand",
        tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.sell-in-hand-header"}, "green", "heading-2"),
            "\n",
            {"quantum-bazaar.sell-in-hand-info"},
        },
        tags = {handlers = {["gui-clicked"] = "quantum-bazaar-sell-in-hand"}},
    }

    local sell_inventory = button_flow.add {
        type = "sprite-button",
        name = "sell-inventory",
        sprite = "backpack",
        tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.sell-inventory-header"}, "yellow", "heading-2"),
            "\n",
            {"quantum-bazaar.sell-inventory-info", coin_tiers.coin_to_text(sell_inv_coin)},
        },
        tags = {handlers = {["gui-clicked"] = "quantum-bazaar-sell-inventory"}},
    }

    -- TODO: Potential bug with other mods. If qualities are unlocked in an order such that successive quality "levels" are skipped, then this will not work as expected. Reason: lib.get_quality_tier() will not match what could be listed as unlocked qualities.
    local quality_dropdown = gui.create_quality_dropdown(quantum_bazaar, "quality-dropdown", lib.get_quality_tier(selection.bazaar_quality), true)
    gui.auto_width(quality_dropdown)
    quality_dropdown.tags = {handlers = {["gui-selection-changed"] = "quantum-bazaar-changed"}}

    local buy_flow = quantum_bazaar.add {
        type = "flow",
        name = "buy-flow",
        direction = "horizontal",
    }
    gui.auto_width(buy_flow)

    local buy_button = buy_flow.add {
        type = "button",
        name = "buy-button",
        tags = {handlers = {["gui-clicked"] = "quantum-bazaar-buy-items"}},
    }
    gui.auto_width(buy_button)

    local buy_max_button = buy_flow.add {
        type = "button",
        name = "buy-max-button",
        tags = {handlers = {["gui-clicked"] = "quantum-bazaar-buy-max"}},
    }
    gui.auto_width(buy_max_button)

    local stack_size = lib.get_stack_size(selection.item_name)
    local amount_slider = quantum_bazaar.add {
        type = "slider",
        name = "amount-slider",
        minimum_value = 1,
        maximum_value = math.max(2, stack_size),
        value = selection.bazaar_buy_amount,
        value_step = 1,
        discrete_values = true,
        enabled = stack_size > 1,
        tags = {handlers = {["gui-slider-changed"] = "quantum-bazaar-slider-changed"}},
    }
    gui.auto_width(amount_slider)

    local coin_tier = coin_tier_gui.create_coin_tier(quantum_bazaar, "coin-tier")

    catalog_gui.verify_catalog_storage(player)
    if not selection.bazaar_buy_amount then
        selection.bazaar_buy_amount = 1
    end

    gui.add_warning(quantum_bazaar, {"quantum-bazaar.capped-amount"}, "capped-amount")
    gui.add_warning(quantum_bazaar, {"quantum-bazaar.no-coins"}, "no-coins")

    catalog_gui.update_quantum_bazaar(player)
end

function catalog_gui.show_catalog(player)
    local frame = player.gui.screen["catalog"]
    if not frame then
        catalog_gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end
    gui_stack.add(player, frame)
    catalog_gui.update_catalog(player)
    frame.force_auto_center()
end

function catalog_gui.hide_catalog(player)
    local frame = player.gui.screen["catalog"]
    if not frame or not frame.valid then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))
end

---@param player LuaPlayer
---@return boolean
function catalog_gui.is_catalog_open(player)
    local frame = player.gui.screen["catalog"]
    return frame ~= nil and frame.visible
end

---Verify the catalog storage is set up correctly.
---@param player LuaPlayer
function catalog_gui.verify_catalog_storage(player)
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
function catalog_gui.set_catalog_selection(player, surface_name, item_name, bazaar_quality)
    catalog_gui.verify_catalog_storage(player)
    local selection = storage.catalog.current_selection[player.name]
    selection.surface_name = surface_name
    selection.item_name = item_name
    selection.last_item_selected = selection.item_name
    selection.bazaar_quality = bazaar_quality

    local rank = item_ranks.get_item_rank(selection.item_name)
    if rank >= 5 then
        selection.last_qb_item_selected = selection.item_name
    end

    catalog_gui.update_catalog_inspect_frame(player)
end

---Get the catalog selection for a player.
---@param player LuaPlayer
---@return PlayerCatalogSelection
function catalog_gui.get_catalog_selection(player)
    catalog_gui.verify_catalog_storage(player)
    return storage.catalog.current_selection[player.name]
end

---Return whether the given item is more likely to be set as an input or output filter in the trade overview, based on the current rank-up requirements.
---@param item_name string
---@return boolean is_input Whether the item would be an input filter
function catalog_gui.get_expected_trade_overview_filter_side(item_name)
    local rank = item_ranks.get_item_rank(item_name)
    if rank == 1 then
        if trades.get_total_bought(item_name) > 0 then
            return true
        end
        return false
    elseif rank == 2 then
        return false
    elseif rank == 3 then
        return true
    elseif rank == 4 then
        return true
    end
    return true
end

---Get the maximum insertable items given the current Quantum Bazaar item selected and the available inventory space of the player.
---@param player LuaPlayer
---@return int
function catalog_gui.get_max_insertable_quantum_bazaar_stack(player)
    local inv = lib.get_player_inventory(player)
    if not inv then return -1 end

    catalog_gui.verify_catalog_storage(player)
    local selection = catalog_gui.get_catalog_selection(player)

    local insertable = inv.get_insertable_count {
        name = selection.item_name,
        quality = selection.bazaar_quality,
    }

    return insertable
end

---Get the maximum purchaseable items given the current Quantum Bazaar item selected and the available inventory coins of the player.
---@param player LuaPlayer
---@return int
function catalog_gui.get_max_purchaseable_quantum_bazaar_stack(player)
    local inv = lib.get_player_inventory(player)
    if not inv then return -1 end

    catalog_gui.verify_catalog_storage(player)
    local selection = catalog_gui.get_catalog_selection(player)

    local item_value = item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality)

    local inv_coin = inventories.get_coin_from_inventory(inv, nil, quests.is_feature_unlocked "piggy-bank")
    local purchaseable = math.floor(coin_tiers.divide_coins(inv_coin, coin_tiers.from_base_value(item_value / (storage.item_values.base_coin_value or 10))))

    return purchaseable
end

---Return a count less than or equal to the given count based on the player's available inventory space and available coins.
---@param player LuaPlayer
---@param count int
---@return int
function catalog_gui.adjust_quantum_bazaar_stack_count(player, count)
    local insertable = catalog_gui.get_max_insertable_quantum_bazaar_stack(player)
    local purchaseable = catalog_gui.get_max_purchaseable_quantum_bazaar_stack(player)
    return math.min(insertable, purchaseable, count)
end

---Handle the action of the player requesting to purchase a stack of an item from the Quantum Bazaar.
---@param player LuaPlayer
---@param count int
function catalog_gui.handle_quantum_bazaar_stack_purchase(player, count)
    local inv = lib.get_player_inventory(player)
    if not inv then return end

    count = catalog_gui.adjust_quantum_bazaar_stack_count(player, count)
    if count < 1 then return end

    local selection = catalog_gui.get_catalog_selection(player)

    local item_value = item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality)
    local total_coin = coin_tiers.ceil(coin_tiers.from_base_value(item_value * count / (storage.item_values.base_coin_value or 10)))

    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    local inv_coin = inventories.get_coin_from_inventory(inv, nil, is_piggy_bank_unlocked)
    if coin_tiers.gt(total_coin, inv_coin) then
        -- This should no longer happen, but it's here just in case.
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(total_coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    inventories.remove_coin_from_inventory(inv, total_coin, nil, is_piggy_bank_unlocked)
    lib.safe_insert(player, {name = selection.item_name, count = count, quality = selection.bazaar_quality})

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
function catalog_gui.on_catalog_button_click(player)
    if gui.is_frame_open(player, "catalog") then
        catalog_gui.hide_catalog(player)
    else
        catalog_gui.show_catalog(player)
    end
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_catalog_item_click(player, elem)
    local surface_name = elem.tags.surface_name
    local item_name = elem.tags.item_name

    ---@cast surface_name string
    ---@cast item_name string

    local selection = catalog_gui.get_catalog_selection(player)
    catalog_gui.set_catalog_selection(player, surface_name, item_name, selection.bazaar_quality)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_item_buff_button_click(player, elem)
    local inv = lib.get_player_inventory(player)
    if not inv then return end

    item_buffs.fetch_settings()
    local selection = catalog_gui.get_catalog_selection(player)
    local cost = item_buffs.get_item_buff_cost(selection.item_name)
    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    local inv_coin = inventories.get_coin_from_inventory(inv, nil, is_piggy_bank_unlocked)

    if coin_tiers.gt(cost, inv_coin) then
        player.print({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(cost), coin_tiers.coin_to_text(inv_coin)})
        return
    end

    item_buffs.set_item_buff_level(
        selection.item_name,
        item_buffs.get_item_buff_level(selection.item_name) + 1
    )

    inventories.remove_coin_from_inventory(inv, cost, nil, is_piggy_bank_unlocked)

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_open_item_buffs_button_click(player, elem)
    catalog_gui.hide_catalog(player)
    event_system.trigger("catalog-item-buffs-button-clicked", player, elem)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_changed(player, elem)
    local selection = catalog_gui.get_catalog_selection(player)
    if elem.name == "quality-dropdown" then
        selection.bazaar_quality = gui.get_quality_name_from_dropdown(elem)
    elseif elem.name == "selected-item-qb" then
        local id = elem.elem_value or selection.last_qb_item_selected or "stone"
        ---@cast id string
        selection.item_name = id
    end
    catalog_gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_slider_changed(player, elem)
    catalog_gui.verify_catalog_storage(player)
    catalog_gui.update_quantum_bazaar(player)
end

---Update captions, tooltips, and other attributes in the Quantum Bazaar.
---@param player LuaPlayer
function catalog_gui.update_quantum_bazaar(player)
    local frame = player.gui.screen["catalog"]
    if not frame then return end

    local inspect_frame = frame["flow"]["inspect-frame"]
    if not inspect_frame then return end

    local quantum_bazaar = inspect_frame["quantum-bazaar"]
    if not quantum_bazaar then return end

    local buy_button = quantum_bazaar["buy-flow"]["buy-button"]
    local buy_max_button = quantum_bazaar["buy-flow"]["buy-max-button"]
    local slider = quantum_bazaar["amount-slider"]
    local coin_tier = quantum_bazaar["coin-tier"]
    local capped_amount_label = quantum_bazaar["capped-amount"]
    local no_coins_label = quantum_bazaar["no-coins"]

    -- local new_amount = math.floor(slider.slider_value)
    -- new_amount = catalog_gui.adjust_quantum_bazaar_stack_count(player, new_amount)
    -- if new_amount == -1 then
    --     new_amount = 1 -- Just so GUI doesn't show -1
    -- end

    local selection = catalog_gui.get_catalog_selection(player)
    local stack_size = lib.get_stack_size(selection.item_name)

    local buy_one_coin
    if player.character then
        buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality) / (storage.item_values.base_coin_value or 10))
    else
        buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value("nauvis", selection.item_name, true, selection.bazaar_quality) / (storage.item_values.base_coin_value or 10))
    end
    buy_one_coin = coin_tiers.ceil(buy_one_coin)

    local current_amount = slider.slider_value
    local insertable_count = catalog_gui.get_max_insertable_quantum_bazaar_stack(player)
    local purchaseable_count = catalog_gui.get_max_purchaseable_quantum_bazaar_stack(player)
    local valid_buy_amount = math.max(0, math.min(insertable_count, purchaseable_count, stack_size, current_amount))
    selection.bazaar_buy_amount = valid_buy_amount

    local buy_amount_coin = coin_tiers.ceil(coin_tiers.multiply(buy_one_coin, valid_buy_amount))

    local valid_max_amount = math.max(0, math.min(insertable_count, purchaseable_count))
    local buy_max_coin = coin_tiers.ceil(coin_tiers.multiply(buy_one_coin, valid_max_amount))

    buy_button.caption = {"quantum-bazaar.buy-button-caption", valid_buy_amount}
    buy_button.tooltip = {"",
        lib.color_localized_string(
            {"quantum-bazaar.buy-stack",
                "[item=" .. selection.item_name .. ",quality=" .. selection.bazaar_quality .. "]",
                valid_buy_amount,
                coin_tiers.coin_to_text(buy_amount_coin)
            },
            "cyan"
        ),
    }

    buy_max_button.caption = {"quantum-bazaar.buy-max"}
    buy_max_button.tooltip = {"",
        lib.color_localized_string(
            {"quantum-bazaar.buy-stack",
                "[item=" .. selection.item_name .. ",quality=" .. selection.bazaar_quality .. "]",
                valid_max_amount,
                coin_tiers.coin_to_text(buy_max_coin)
            },
            "cyan"
        ),
    }

    capped_amount_label.visible = current_amount > valid_buy_amount

    local inv = lib.get_player_inventory(player)
    if inv then
        local inv_coin = inventories.get_coin_from_inventory(inv, nil, quests.is_feature_unlocked "piggy-bank")
        no_coins_label.visible = coin_tiers.is_zero(inv_coin)
    end

    coin_tier_gui.update_coin_tier(coin_tier, buy_amount_coin)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_buy_items_clicked(player, elem)
    catalog_gui.verify_catalog_storage(player)
    local count = storage.catalog.current_selection[player.name].bazaar_buy_amount or 1
    catalog_gui.handle_quantum_bazaar_stack_purchase(player, count)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_buy_max_clicked(player, elem)
    local insertable = catalog_gui.get_max_insertable_quantum_bazaar_stack(player)
    local purchaseable = catalog_gui.get_max_purchaseable_quantum_bazaar_stack(player)
    local count = math.max(0, math.min(insertable, purchaseable))
    catalog_gui.handle_quantum_bazaar_stack_purchase(player, count)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_sell_inventory_clicked(player, elem)
    local inv = lib.get_player_inventory(player)
    if not inv then return end

    -- Ensure that if the character is in space due to some glitch, this doesn't bug the shit out.
    if not player.character or storage.item_values.values[player.character.surface.name] == nil then return end

    local received_coin = coin_tiers.ceil(inventories.get_total_coin_value(player.character.surface.name, inv, 5))
    inventories.remove_items_of_rank(inv, 5)
    inventories.add_coin_to_inventory(inv, received_coin, nil, quests.is_feature_unlocked "piggy-bank")

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_sell_in_hand_clicked(player, elem)
    -- Ensure that if the character is in space due to some glitch, this doesn't bug the shit out.
    if not player.character or storage.item_values.values[player.character.surface.name] == nil then return end

    local item_stack = player.cursor_stack
    if not item_stack or not item_stack.valid_for_read then
        player.print(lib.color_localized_string({"hextorio.no-item-in-hand"}, "red"))
        return
    end

    if item_ranks.get_item_rank(item_stack.name) < 5 then
        player.print(lib.color_localized_string({"hextorio.item-rank-too-low"}, "red"))
        return
    end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local item_value = item_values.get_item_value(player.character.surface.name, item_stack.name, true, item_stack.quality.name) * item_stack.count
    local received_coin = coin_tiers.ceil(coin_tiers.from_base_value(item_value / (storage.item_values.base_coin_value or 10)))

    inventories.add_coin_to_inventory(inv, received_coin, nil, quests.is_feature_unlocked "piggy-bank")
    item_stack.clear()

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_catalog_search_item_selected(player, elem)
    local selection = catalog_gui.get_catalog_selection(player)
    local id = elem.elem_value or selection.last_item_selected or "stone"
    ---@cast id string
    selection.item_name = id
    catalog_gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_catalog_choose_elem_button_changed(player, elem)
    if elem.name == "selected-item-view" then
        catalog_gui.on_catalog_search_item_selected(player, elem)
    elseif elem.name == "selected-item-qb" then
        catalog_gui.on_quantum_bazaar_changed(player, elem)
    end
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_open_factoriopedia_button_click(player, elem)
    local selection = catalog_gui.get_catalog_selection(player)
    lib.open_factoriopedia_gui(player, selection.item_name)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_open_trade_overview_button_click(player, elem)
    local selection = catalog_gui.get_catalog_selection(player)
    local is_input = catalog_gui.get_expected_trade_overview_filter_side(selection.item_name)
    event_system.trigger("catalog-trade-overview-clicked", player, selection.item_name, is_input)
end



return catalog_gui
