
local lib = require "api.lib"
local gui = require "api.gui.core_gui"
local coin_tiers  = require "api.coin_tiers"
local event_system = require "api.event_system"
local quests = require "api.quests"
local gui_stack = require "api.gui.gui_stack"

local questbook_gui = {}



function questbook_gui.register_events()
    event_system.register_gui("gui-clicked", "questbook-button", questbook_gui.on_questbook_button_click)
    event_system.register_gui("gui-clicked", "debug-complete-quest", questbook_gui.on_debug_complete_quest_button_clicked)
    event_system.register_gui("gui-selection-changed", "complete-list", questbook_gui.on_quest_name_selected)
    event_system.register_gui("gui-selection-changed", "incomplete-list", questbook_gui.on_quest_name_selected)
    event_system.register_gui("gui-closed", "questbook", questbook_gui.hide_questbook)

    local function update_quest_guis(quest)
        for _, player in pairs(game.connected_players) do
            questbook_gui.update_quest_lists(player, quest)
            questbook_gui.update_questbook(player)
        end
    end

    event_system.register("quest-revealed", update_quest_guis)
    event_system.register("quest-completed", update_quest_guis)
end

---Reinitialize the hex core GUI for the given player, or all online players if no player is provided.
---@param player LuaPlayer|nil
function questbook_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.connected_players) do
            questbook_gui.reinitialize(p)
        end
        return
    end

    local frame = player.gui.screen["questbook"]
    if frame then frame.destroy() end

    local button = player.gui.top["questbook-button"]
    if button then button.destroy() end

    questbook_gui.init_questbook_button(player)
    questbook_gui.init_questbook(player)
    questbook_gui.repopulate_quest_lists(player)
end

function questbook_gui.init_questbook_button(player)
    if player.gui.top["questbook-button"] then return end
    local questbook_button = player.gui.top.add {
        type = "sprite-button",
        name = "questbook-button",
        sprite = "questbook",
        style = "side_menu_button",
        tooltip = {"hextorio-gui.questbook-button-tooltip"},
    }
    questbook_button.tags = {handlers = {["gui-clicked"] = "questbook-button"}}
end

function questbook_gui.init_questbook(player)
    if player.gui.screen["questbook"] then return end

    local questbook = player.gui.screen.add {type = "frame", name = "questbook", direction = "vertical"}
    questbook.style.size = {width = 1200, height = 800}
    questbook.visible = false
    questbook.tags = {handlers = {["gui-closed"] = "questbook"}}

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
    incomplete_list.tags = {handlers = {["gui-selection-changed"] = "incomplete-list"}}
    gui.auto_width_height(incomplete_list)

    local complete_header = list_scroll_pane.add {type = "label", name = "complete-header", caption = {"hextorio-questbook.complete", 0}}
    complete_header.style.font = "heading-2"
    local complete_list = list_scroll_pane.add {type = "list-box", name = "complete-list"}
    complete_list.tags = {handlers = {["gui-selection-changed"] = "complete-list"}}
    gui.auto_width_height(complete_list)

    local quest_info_frame = quest_frame.add {type = "frame", name = "info-frame", direction = "horizontal"}
    quest_info_frame.style.natural_height = 300 / 1.2
    quest_info_frame.style.maximal_width = 1153 / 1.2
    quest_info_frame.style.natural_width = 1153 / 1.2

    local quest_info_main = quest_info_frame.add {type = "flow", name = "main", direction = "vertical"}
    local quest_info_img_frame = quest_info_frame.add {type = "frame", name = "img-frame"}
    local quest_info_img = quest_info_img_frame.add {type = "sprite", name = "img", sprite = "missing-quest-img", resize_to_sprite = true}
    quest_info_img.style.width = 256 / 1.2
    quest_info_img.style.height = 256 / 1.2
    quest_info_img.style.stretch_image_to_widget_size = true

    local quest_title = quest_info_main.add {type = "label", name = "title", caption = "[Quest Title]"}
    quest_title.style.font = "heading-1"
    quest_info_main.add {type = "line", direction = "horizontal"}

    local quest_description = quest_info_main.add {type = "label", name = "description", caption = "[Quest Description]"}
    quest_description.style.single_line = false

    local quest_notes_flow = quest_info_main.add {type = "flow", name = "notes-flow", direction = "vertical"}

    local debug_complete_quest = quest_info_main.add {type = "button", name = "debug-complete-quest", caption = {"hextorio-debug.complete-quest"}}
    debug_complete_quest.tags = {handlers = {["gui-clicked"] = "debug-complete-quest"}}

    local quest_conditions_rewards = quest_frame.add {type = "flow", name = "conditions-rewards", direction = "horizontal"}
    gui.auto_width_height(quest_conditions_rewards)

    local quest_conditions_frame = quest_conditions_rewards.add {type = "frame", name = "conditions", direction = "vertical"}

    local quest_conditions_header = quest_conditions_frame.add {type = "label", name = "header", caption = {"hextorio-questbook.conditions"}}
    quest_conditions_header.style.font = "heading-1"

    local quest_conditions_scroll_pane = quest_conditions_frame.add {type = "scroll-pane", name = "scroll-pane"}
    gui.auto_width_height(quest_conditions_scroll_pane)

    local quest_rewards_frame = quest_conditions_rewards.add {type = "frame", name = "rewards", direction = "vertical"}

    local quest_rewards_header = quest_rewards_frame.add {type = "label", name = "header", caption = {"hextorio-questbook.rewards"}}
    quest_rewards_header.style.font = "heading-1"

    local quest_rewards_scroll_pane = quest_rewards_frame.add {type = "scroll-pane", name = "scroll-pane"}
    gui.auto_width_height(quest_rewards_scroll_pane)
end

function questbook_gui.update_questbook(player, quest_name)
    local frame = player.gui.screen["questbook"]
    if not frame then
        questbook_gui.init_questbook(player)
        frame = player.gui.screen["questbook"]
    end

    questbook_gui.repopulate_quest_lists(player) -- THIS IS NOT SUPPOSED TO BE NEEDED.  BUT AT LEAST ONE MOD (RPG) IS KNOWN DESTROY THE QUEST LIST ITEMS.  THIS ADDS "SUPPORT" FOR SUCH MODS THAT SOMEHOW DO THIS.

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
        quest_name = questbook_gui.get_player_current_quest_selected(player)
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

function questbook_gui.update_quest_lists(player, quest)
    local scroll_pane = player.gui.screen["questbook"]["lower-flow"]["list-frame"]["scroll-pane"]
    local incomplete_list = scroll_pane["incomplete-list"]
    local complete_list = scroll_pane["complete-list"]

    if quest and quest.complete then
        questbook_gui.add_quest_to_list(complete_list, quest)
    end

    incomplete_list.clear_items()
    for _, q in pairs(storage.quests.quests) do
        if q.revealed and not q.complete then
            questbook_gui.add_quest_to_list(incomplete_list, q)
        end
    end
end

---Repopulate a player's quest lists.  O(nlogn) time complexity.
---@param player LuaPlayer
function questbook_gui.repopulate_quest_lists(player)
    local scroll_pane = player.gui.screen["questbook"]["lower-flow"]["list-frame"]["scroll-pane"]
    local incomplete_list = scroll_pane["incomplete-list"]
    local complete_list = scroll_pane["complete-list"]

    complete_list.clear_items()
    incomplete_list.clear_items()

    for _, q in pairs(storage.quests.quests) do
        if quests.is_revealed(q) then
            if quests.is_complete(q) then
                questbook_gui.add_quest_to_list(complete_list, q)
            else
                questbook_gui.add_quest_to_list(incomplete_list, q)
            end
        end
    end
end

function questbook_gui.add_quest_to_list(list, quest)
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
            local mid_quest = questbook_gui.get_quest_from_list_item(list.get_item(mid))
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

function questbook_gui.show_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then
        questbook_gui.init_questbook(player)
        frame = player.gui.screen["questbook"]
    end
    gui_stack.add(player, frame)
    questbook_gui.update_questbook(player)
    frame.force_auto_center()
end

function questbook_gui.hide_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))
end

function questbook_gui.get_quest_from_list_item(item)
    local quest_name = item[1]:sub(13)
    return quests.get_quest_from_name(quest_name)
end

function questbook_gui.get_current_selected_quest(player)
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

    return questbook_gui.get_quest_from_list_item(list.get_item(list.selected_index))
end

function questbook_gui.get_player_current_quest_selected(player)
    if not storage.quests.players_quest_selected[player.name] then
        storage.quests.players_quest_selected[player.name] = "ground-zero"
    end
    return storage.quests.players_quest_selected[player.name]
end

function questbook_gui.set_player_current_quest_selected(player, quest_name)
    storage.quests.players_quest_selected[player.name] = quest_name
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function questbook_gui.on_quest_name_selected(player, elem)
    if elem.selected_index == 0 then return end

    -- First, ensure that only one quest is selected between the two list boxes.
    if elem.name == "complete-list" then
        elem.parent['incomplete-list'].selected_index = 0
    elseif elem.name == "incomplete-list" then
        elem.parent['complete-list'].selected_index = 0
    end

    local quest = questbook_gui.get_current_selected_quest(player)
    if not quest then return end

    questbook_gui.set_player_current_quest_selected(player, quest.name)
    questbook_gui.update_questbook(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function questbook_gui.on_questbook_button_click(player, elem)
    if gui.is_frame_open(player, "questbook") then
        questbook_gui.hide_questbook(player)
    else
        questbook_gui.show_questbook(player)
    end
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function questbook_gui.on_debug_complete_quest_button_clicked(player, elem)
    local quest = questbook_gui.get_current_selected_quest(player)
    if not quest then return end
    quests.complete_quest(quest)
end



return questbook_gui
