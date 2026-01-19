
local sets = require "api.sets"
local gui_stack = require "api.gui.gui_stack"
local event_system = require "api.event_system"
local core_gui     = require "api.gui.core_gui"
local item_buffs = require "api.item_buffs"
local item_ranks = require "api.item_ranks"
local trades = require "api.trades"
local lib = require "api.lib"
local quests = require "api.quests"

local item_buffs_gui = {}



function item_buffs_gui.register_events()
    event_system.register("catalog-item-buffs-button-clicked", item_buffs_gui.on_catalog_item_buffs_button_click)
    event_system.register_gui("gui-clicked", "item-buff-toggle", item_buffs_gui.on_item_buff_toggle)
    event_system.register_gui("gui-clicked", "item-buff-enhance-all", item_buffs_gui.on_item_buff_enhance_all)
    event_system.register_gui("gui-closed", "item-buffs", item_buffs_gui.hide_item_buffs_frame)

    event_system.register("item-buff-level-changed", function(item_name)
        for _, player in pairs(game.connected_players) do
            local frame = player.gui.screen["item-buffs"]
            if frame and frame.visible then
                item_buffs_gui.update_item_in_item_buffs_frame(player, item_name)
            end
        end
    end)

    event_system.register("item-buffs-enhance-all-finished", function(player, total_cost, enhanced_items)
        item_buffs_gui.update_item_buffs_frame(player)
    end)
end

---Reinitialize the item buffs GUI for the given player, or all online players if no player is provided.
---@param player LuaPlayer|nil
function item_buffs_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.connected_players) do
            item_buffs_gui.reinitialize(p)
        end
        return
    end

    local frame = player.gui.screen["item-buffs"]
    if frame then frame.destroy() end

    item_buffs_gui.init_item_buffs_frame(player)
end

---@param player LuaPlayer
function item_buffs_gui.init_item_buffs_frame(player)
    local frame = player.gui.screen.add {
        type = "frame",
        name = "item-buffs",
        tags = {handlers = {["gui-closed"] = "item-buffs"}},
        direction = "vertical",
    }
    frame.style.width = 1200
    frame.style.height = 800
    frame.visible = false

    core_gui.add_titlebar(frame, {"hextorio-gui.item-buffs"})

    local main_flow = frame.add {type = "flow", name = "main-flow", direction = "horizontal"}
    main_flow.style.horizontally_stretchable = true

    -- Left section: filters and enhance all button
    local left_frame = main_flow.add {type = "frame", name = "left-frame", direction = "vertical"}
    left_frame.style.width = 200
    core_gui.auto_height(left_frame)

    local button_flow = left_frame.add {type = "flow", name = "button-flow", direction = "horizontal"}
    button_flow.style.horizontally_stretchable = true

    local enhance_all_button = button_flow.add {
        type = "sprite-button",
        name = "item-buff-enhance-all",
        sprite = "item-buff-enhance-all",
        tooltip = {"hextorio-gui.item-buff-enhance-all-tooltip"},
        tags = {handlers = {["gui-clicked"] = "item-buff-enhance-all"}},
    }

    left_frame.add {type = "line", direction = "horizontal"}

    -- Placeholder for filters
    local filter_placeholder = left_frame.add {type = "label", name = "filter-placeholder", caption = "Filters coming soon!"}
    filter_placeholder.style.font_color = {128, 128, 128}

    -- Right section: buff cards in scroll pane
    local right_frame = main_flow.add {type = "frame", name = "right-frame", direction = "vertical"}
    right_frame.style.width = 974
    -- right_frame.style.horizontally_stretchable = true
    core_gui.auto_height(right_frame)

    local scroll_pane = right_frame.add {type = "scroll-pane", name = "scroll-pane"}
    scroll_pane.horizontal_scroll_policy = "never"
    core_gui.auto_width_height(scroll_pane)

    local buff_table = scroll_pane.add {type = "table", name = "buff-table", column_count = 3}
    -- core_gui.auto_width_height(buff_table)
end

---Regenerate all item buff cards.
---@param player LuaPlayer
function item_buffs_gui.update_item_buffs_frame(player)
    local frame = player.gui.screen["item-buffs"]
    if not frame then return end

    local buff_table = frame["main-flow"]["right-frame"]["scroll-pane"]["buff-table"]
    buff_table.clear()

    if not quests.is_feature_unlocked "item-buffs" then return end

    -- Group items by buff type (only include unlocked items)
    local buff_groups = {}
    for item_name, _ in pairs(storage.trades.discovered_items) do
        local rank = item_ranks.get_item_rank(item_name)
        if rank >= 2 and lib.is_catalog_item(item_name) and item_buffs.is_unlocked(item_name) then
            local buffs = item_buffs.get_buffs(item_name)
            for _, buff in ipairs(buffs) do
                local buff_key = buff.type
                if buff.type == "recipe-productivity" then
                    buff_key = "recipe-productivity:" .. buff.values[1]
                end

                if not buff_groups[buff_key] then
                    buff_groups[buff_key] = {
                        buff_type = buff.type,
                        recipe_name = (buff.type == "recipe-productivity" and buff.values[1]) or nil,
                        items = {},
                    }
                end

                table.insert(buff_groups[buff_key].items, item_name)
            end
        end
    end

    -- Sort buff groups by type for consistent display
    local sorted_keys = {}
    for key, _ in pairs(buff_groups) do
        table.insert(sorted_keys, key)
    end
    table.sort(sorted_keys)

    -- Create buff cards
    for _, buff_key in ipairs(sorted_keys) do
        local group = buff_groups[buff_key]
        item_buffs_gui.create_buff_card(player, buff_table, group)
    end
end

---Update select buff cards based on an item's recent change in buff level.
---@param player LuaPlayer
---@param item_name string The item about which all buff cards should update their details.
function item_buffs_gui.update_item_in_item_buffs_frame(player, item_name)
    local frame = player.gui.screen["item-buffs"]
    if not frame then return end

    local buff_table = frame["main-flow"]["right-frame"]["scroll-pane"]["buff-table"]

    -- Build list of buff keys that this item affects
    local buff_keys = {}
    local buffs = item_buffs.get_buffs(item_name)
    for _, buff in pairs(buffs) do
        local buff_key = buff.type
        if buff.type == "recipe-productivity" then
            buff_key = "recipe-productivity:" .. buff.values[1]
        end
        table.insert(buff_keys, buff_key)
    end

    -- Build the full groups for each affected buff type
    local buff_groups = {}
    for _, buff_key in ipairs(buff_keys) do
        buff_groups[buff_key] = {
            buff_type = buff_key:match("^([^:]+)"),
            recipe_name = buff_key:match("^recipe%-productivity:(.+)"),
            items = {},
        }
    end

    -- Populate items for each buff group
    for discovered_item_name, _ in pairs(storage.trades.discovered_items) do
        local rank = item_ranks.get_item_rank(discovered_item_name)
        if rank >= 2 and lib.is_catalog_item(discovered_item_name) and item_buffs.is_unlocked(discovered_item_name) then
            local discovered_buffs = item_buffs.get_buffs(discovered_item_name)
            for _, buff in ipairs(discovered_buffs) do
                local buff_key = buff.type
                if buff.type == "recipe-productivity" then
                    buff_key = "recipe-productivity:" .. buff.values[1]
                end

                if buff_groups[buff_key] then
                    table.insert(buff_groups[buff_key].items, discovered_item_name)
                end
            end
        end
    end

    -- Update existing cards or create new ones (only if there are items in the group)
    for buff_key, group in pairs(buff_groups) do
        if #group.items > 0 then
            local card_name = "buff-card-" .. group.buff_type
            if group.recipe_name then
                card_name = card_name .. "-" .. group.recipe_name
            end

            local card = buff_table[card_name]
            if card then
                -- Update existing card
                card.tags = {
                    buff_type = group.buff_type,
                    item_names = group.items,
                    recipe_name = group.recipe_name,
                }
                card.clear()
                item_buffs_gui.add_buff_card_elements(card)
            else
                -- Create new card (shouldn't happen often, but handle it)
                item_buffs_gui.create_buff_card(player, buff_table, group)
            end
        end
    end
end

---@param player LuaPlayer
function item_buffs_gui.show_item_buffs_frame(player)
    local frame = player.gui.screen["item-buffs"]
    if not frame then
        item_buffs_gui.init_item_buffs_frame(player)
        frame = player.gui.screen["item-buffs"]
    end
    gui_stack.add(player, frame)
    item_buffs_gui.update_item_buffs_frame(player)
    frame.force_auto_center()
end

---@param player LuaPlayer
function item_buffs_gui.hide_item_buffs_frame(player)
    local frame = player.gui.screen["item-buffs"]
    if not frame or not frame.valid then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))

    event_system.trigger("item-buffs-gui-closed", player)
end

---Create a buff card for a specific buff type
---@param player LuaPlayer
---@param parent LuaGuiElement
---@param group table
function item_buffs_gui.create_buff_card(player, parent, group)
    local card_name = "buff-card-" .. group.buff_type
    if group.recipe_name then
        card_name = card_name .. "-" .. group.recipe_name
    end

    local card_frame = parent.add {
        type = "frame",
        name = card_name,
        direction = "vertical",
        style = "inside_shallow_frame",
    }
    card_frame.style.width = 307
    card_frame.style.height = 270
    card_frame.style.padding = 10
    -- core_gui.auto_width(card_frame)

    local tags = {
        buff_type = group.buff_type,
        item_names = group.items,
    }

    if group.recipe_name then
        tags.recipe_name = group.recipe_name
    end

    card_frame.tags = tags

    item_buffs_gui.add_buff_card_elements(card_frame)
end

---@param card_frame LuaGuiElement
function item_buffs_gui.add_buff_card_elements(card_frame)
    local buff_type = card_frame.tags.buff_type
    if not buff_type then return end
    ---@cast buff_type ItemBuffType

    local items = card_frame.tags.item_names
    if not items then return end
    ---@cast items string[]

    local recipe_name
    if buff_type == "recipe-productivity" then
        recipe_name = card_frame.tags.recipe_name ---@as string
    end

    -- Header with buff name
    local header_flow = card_frame.add {type = "flow", name = "header", direction = "horizontal"}
    header_flow.style.horizontally_stretchable = true

    local buff_name_caption
    if buff_type == "recipe-productivity" then
        buff_name_caption = {"item-buff-name." .. buff_type, "[recipe=" .. recipe_name .. "]"}
    else
        buff_name_caption = {"item-buff-name." .. buff_type}
    end

    local buff_name_label = header_flow.add {
        type = "label",
        name = "buff-name",
        caption = buff_name_caption,
    }
    buff_name_label.style.font = "heading-2"

    if storage.item_buffs.has_description[buff_type] then
        buff_name_label.caption = {"", "[img=virtual-signal.signal-info] ", buff_name_caption}
        buff_name_label.tooltip = core_gui.get_buff_description_tooltip(buff_type)
    end

    card_frame.add {type = "line", direction = "horizontal"}

    -- Show items giving this buff
    local items_table = card_frame.add {type = "table", name = "items-table", column_count = 6}
    items_table.style.horizontally_stretchable = true

    for i, item_name in ipairs(items) do
        local is_enabled = item_buffs.is_enabled(item_name)

        local item_button = items_table.add {
            type = "sprite-button",
            name = "item-buff-toggle-" .. i,
            sprite = "item/" .. item_name,
            style = "slot_button",
            toggled = is_enabled,
            tags = {handlers = {["gui-clicked"] = "item-buff-toggle"}, item_name = item_name},
        }
    end

    -- Total buff level
    local total_level = 0
    for _, item_name in ipairs(items) do
        if item_buffs.is_enabled(item_name) then
            total_level = total_level + item_buffs.get_item_buff_level(item_name)
        end
    end

    local level_label = card_frame.add {
        type = "label",
        name = "total-level",
        caption = {"hextorio-gui.level-x", total_level},
        -- caption = {"", {"hextorio-gui.level-x", total_level}, " | ", total_effect},
    }
    level_label.style.font = "default-semibold"

    card_frame.add {type = "line", direction = "horizontal"}

    -- Effects in a scrollable 3-column table
    local effects_scroll = card_frame.add {type = "scroll-pane", name = "effects-scroll"}
    effects_scroll.style.maximal_height = 140
    effects_scroll.style.vertically_stretchable = true
    effects_scroll.style.horizontally_stretchable = true

    local effects_table = effects_scroll.add {type = "table", name = "effects-table", column_count = 3}

    -- Display effects for each item (combined icon + value in each cell)
    for _, item_name in ipairs(items) do
        if item_buffs.is_enabled(item_name) then
            local buffs = item_buffs.get_buffs(item_name)
            local level = item_buffs.get_item_buff_level(item_name)

            for _, buff in ipairs(buffs) do
                local buff_key = buff.type
                if buff.type == "recipe-productivity" then
                    buff_key = "recipe-productivity:" .. buff.values[1]
                end

                local expected_key = buff_type
                if recipe_name then
                    expected_key = "recipe-productivity:" .. recipe_name
                end

                if buff_key == expected_key then
                    local values = item_buffs.get_scaled_buff_values(buff, level)
                    if values then
                        local value_caption
                        -- TODO: This is repeated code from catalog_gui.lua and SHOULD be put into a single place to be reused here.
                        if #values == 1 then
                            if storage.item_buffs.show_as_linear[buff.type] then
                                value_caption = {"", "[color=green]+" .. (math.floor(values[1] * 10 + 0.5) * 0.1) .. "[.color]"}
                            else
                                value_caption = {"", "[color=green]" .. lib.format_percentage(values[1], 1, true, true) .. "[.color]"}
                            end
                        elseif buff.type == "recipe-productivity" then
                            value_caption = {"", "[color=green]" .. lib.format_percentage(values[2] * 0.01, 1, true, true) .. "[.color]"}
                        else
                            value_caption = {"", "[color=green]" .. table.concat(values, ", ") .. "[.color]"}
                        end

                        -- Combine icon and value in one cell
                        local effect_label = effects_table.add {
                            type = "label",
                            name = "effect-" .. item_name,
                            caption = {"", "[img=item." .. item_name .. "] ", value_caption},
                        }
                    end
                end
            end
        end
    end
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function item_buffs_gui.on_catalog_item_buffs_button_click(player, elem)
    item_buffs_gui.show_item_buffs_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function item_buffs_gui.on_item_buff_toggle(player, elem)
    local item_name = elem.tags.item_name
    if not item_name then return end

    ---@cast item_name string
    local new_state = not item_buffs.is_enabled(item_name)
    item_buffs.set_enabled(item_name, new_state)
    item_buffs_gui.update_item_buffs_frame(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function item_buffs_gui.on_item_buff_enhance_all(player, elem)
    item_buffs.enhance_all_item_buffs {
        player = player,
    }
end



return item_buffs_gui
