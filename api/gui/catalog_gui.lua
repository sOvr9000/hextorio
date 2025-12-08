
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



function catalog_gui.register_events()
    event_system.register_gui("gui-clicked", "catalog-button", catalog_gui.on_catalog_button_click)
    event_system.register_gui("gui-closed", "catalog", catalog_gui.hide_catalog)
    event_system.register_gui("gui-clicked", "catalog-item", catalog_gui.on_catalog_item_click)
    event_system.register_gui("gui-clicked", "item-buff-enhance-all", catalog_gui.on_item_buff_all_button_click)
    event_system.register_gui("gui-clicked", "open-in-factoriopedia", catalog_gui.on_open_factoriopedia_button_click)
    event_system.register_gui("gui-elem-changed", "selected-item-view", catalog_gui.on_catalog_search_item_selected)
    event_system.register_gui("gui-clicked", "item-buff-button", catalog_gui.on_item_buff_button_click)

    event_system.register_gui("gui-selection-changed", "quantum-bazaar-changed", catalog_gui.on_quantum_bazaar_changed)
    event_system.register_gui("gui-clicked", "quantum-bazaar-sell-in-hand", catalog_gui.on_quantum_bazaar_sell_in_hand_clicked)
    event_system.register_gui("gui-clicked", "quantum-bazaar-sell-inventory", catalog_gui.on_quantum_bazaar_sell_inventory_clicked)
    event_system.register_gui("gui-clicked", "quantum-bazaar-buy-one", catalog_gui.on_quantum_bazaar_buy_item_clicked)
    event_system.register_gui("gui-clicked", "quantum-bazaar-buy-stack", catalog_gui.on_quantum_bazaar_buy_item_clicked)
    event_system.register_gui("gui-elem-changed", "quantum-bazaar-changed", catalog_gui.on_quantum_bazaar_changed)

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

    event_system.register("item-buffs-enhance-all-finished", function(player, total_cost, enhanced_items)
        catalog_gui.update_catalog_inspect_frame(player)
    end)

    event_system.register("post-set-item-value-command", function(player, params)
        catalog_gui.reinitialize()
    end)

    event_system.register("post-import-item-values-command", function(player, params)
        catalog_gui.reinitialize()
    end)
end

---Reinitialize the catalog GUI for the given player, or all online players if no player is provided.
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

    local selection = catalog_gui.get_catalog_selection(player)
    catalog_gui.set_catalog_selection(player, selection.surface_name, selection.item_name, selection.bazaar_quality)
end

function catalog_gui.update_catalog_inspect_frame(player)
    local frame = player.gui.screen["catalog"]
    if not frame then
        catalog_gui.init_catalog(player)
        frame = player.gui.screen["catalog"]
    end

    local inspect_frame = frame["flow"]["inspect-frame"]

    catalog_gui.verify_catalog_storage(player)
    local selection = catalog_gui.get_catalog_selection(player)
    local rank_obj = item_ranks.get_rank_obj(selection.item_name)
    if not rank_obj then return end

    -- TODO (IMPORTANT): UNREGISTER CALLBACKS FROM BEFORE
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

    local tooltip = {"hextorio-gui.obfuscated-text"}
    if show_buffs then
        tooltip = {"hextorio-gui.item-buff-enhance-all-tooltip"}
    end
    local item_buff_enhance_all = control_flow.add {
        type = "sprite-button",
        name = "item-buff-enhance-all",
        sprite = "item-buff-enhance-all",
        tooltip = tooltip,
        tags = {handlers = {["gui-clicked"] = "item-buff-enhance-all"}},
    }
    item_buff_enhance_all.enabled = show_buffs

    local open_in_factoriopedia = control_flow.add {
        type = "sprite-button",
        name = "open-in-factoriopedia",
        sprite = "utility/side_menu_factoriopedia_icon",
        tooltip = {"hextorio-gui.open-in-factoriopedia"},
        tags = {handlers = {["gui-clicked"] = "open-in-factoriopedia"}},
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
        tags = {handlers = {["gui-elem-changed"] = "selected-item-view"}},
    }

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
        tags = {handlers = {["gui-clicked"] = "item-buff-button"}},
    }
    buff_button.tooltip = {"hextorio-gui." .. buff_button_type .. "-tooltip"}

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

    -- TODO: Potential bug with other mods. If qualities are unlocked in an order such that successive quality "levels" are skipped, then this will not work as expected. Reason: lib.get_quality_tier() will not match what could be listed as unlocked qualities.
    local quality_dropdown = gui.create_quality_dropdown(left_flow, "quality-dropdown", lib.get_quality_tier(selection.bazaar_quality), true)
    gui.auto_width(quality_dropdown)
    quality_dropdown.tags = {handlers = {["gui-selection-changed"] = "quantum-bazaar-changed"}}

    local coin_tier = coin_tier_gui.create_coin_tier(left_flow, "coin-tier")
    local buy_one_coin
    local sell_inv_coin
    if player.character then
        buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value(player.character.surface.name, selection.item_name, true, selection.bazaar_quality) / item_values.get_item_value("nauvis", "hex-coin"))
        sell_inv_coin = inventories.get_total_coin_value(player.character.surface.name, lib.get_player_inventory(player), 5)
    else
        buy_one_coin = coin_tiers.from_base_value(item_values.get_item_value("nauvis", selection.item_name, true, selection.bazaar_quality) / item_values.get_item_value("nauvis", "hex-coin"))
        sell_inv_coin = inventories.get_total_coin_value("nauvis", lib.get_player_inventory(player), 5)
    end

    local stack_size = lib.get_stack_size(selection.item_name)
    local buy_stack_coin = coin_tiers.ceil(coin_tiers.multiply(buy_one_coin, stack_size))

    buy_one_coin = coin_tiers.ceil(buy_one_coin)
    coin_tier_gui.update_coin_tier(coin_tier, buy_one_coin)

    local sell_in_hand = right_flow.add {
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

    local sell_inventory = right_flow.add {
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

    local buy_one = right_flow.add {
        type = "sprite-button",
        name = "buy-one",
        sprite = "stack-one",
        tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.buy-one", "[item=" .. selection.item_name .. ",quality=" .. selection.bazaar_quality .. "]", coin_tiers.coin_to_text(buy_one_coin)}, "cyan"),
        },
        tags = {handlers = {["gui-clicked"] = "quantum-bazaar-buy-one"}},
    }

    local buy_stack = right_flow.add {
        type = "sprite-button",
        name = "buy-stack",
        sprite = "stack-full",
        tooltip = {"",
            lib.color_localized_string({"quantum-bazaar.buy-stack", "[item=" .. selection.item_name .. ",quality=" .. selection.bazaar_quality .. "]", stack_size, coin_tiers.coin_to_text(buy_stack_coin)}, "purple"),
        },
        tags = {handlers = {["gui-clicked"] = "quantum-bazaar-buy-stack"}},
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
        tags = {handlers = {["gui-elem-changed"] = "quantum-bazaar-changed"}},
    }
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
    if not frame then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))
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
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)

    if coin_tiers.gt(cost, inv_coin) then
        player.print({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(cost), coin_tiers.coin_to_text(inv_coin)})
        return
    end

    item_buffs.set_item_buff_level(
        selection.item_name,
        item_buffs.get_item_buff_level(selection.item_name) + 1
    )

    coin_tiers.remove_coin_from_inventory(inv, cost)

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_item_buff_all_button_click(player, elem)
    item_buffs.enhance_all_item_buffs {
        player = player,
    }
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
function catalog_gui.on_quantum_bazaar_buy_item_clicked(player, elem)
    local inv = player.get_main_inventory()
    if not inv then return end

    local selection = catalog_gui.get_catalog_selection(player)
    local count = 1
    if elem.name == "buy-stack" then
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

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_sell_inventory_clicked(player, elem)
    local inv = player.get_main_inventory()
    if not inv then return end

    local received_coin = coin_tiers.ceil(inventories.get_total_coin_value(player.character.surface.name, inv, 5))
    inventories.remove_items_of_rank(inv, 5)
    coin_tiers.add_coin_to_inventory(inv, received_coin)

    catalog_gui.update_catalog_inspect_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function catalog_gui.on_quantum_bazaar_sell_in_hand_clicked(player, elem)
    local item_stack = player.cursor_stack
    if not item_stack or not item_stack.valid_for_read then
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



return catalog_gui
