local lib = require "api.lib"
local event_system = require "api.event_system"
local sets         = require "api.sets"

local quests = {}



function quests.register_events()
    event_system.register_callback("command-complete-quest", function(player, params)
        local quest = quests.get_quest(params[1])
        if quest then
            quests.complete_quest(quest)
        else
            player.print("Unrecognized quest name: " .. params[1])
        end
    end)
end

function quests.init()
    lib.log("Indexing quests...")

    local reveal = {}
    for _, def in pairs(storage.quests.quest_defs) do
        lib.log(def.name)
        local quest = quests.new_quest(def)
        if quest then
            storage.quests.quests[def.name] = quest
            quest.order = 0
            quests.index_by_condition_types(quest)

            if not quest.prerequisites or not next(quest.prerequisites) then
                table.insert(reveal, quest)
            end
        end
    end

    local visited = {}
    local function dfs(quest)
        if visited[quest.name] then return end
        visited[quest.name] = true
        local q
        if quest.unlocks then
            for _, unlock in pairs(quest.unlocks) do
                q = quests.get_quest(unlock)
                q.order = math.min(q.order, quest.order + 1)
                dfs(q)
            end
        end
        if quest.prerequisites then
            for _, prereq in pairs(quest.prerequisites) do
                q = quests.get_quest(prereq)
                quest.order = math.min(quest.order, q.order + 1)
                dfs(q)
            end
        end
    end
    dfs(quests.get_quest "ground-zero")

    for _, quest in pairs(reveal) do
        quests.reveal_quest(quest)
    end
end

function quests.index_by_condition_types(quest)
    local types = sets.new()
    for _, condition in pairs(quest.conditions) do
        sets.add(types, condition.type)
    end
    for ct, _ in pairs(types) do
        local t = storage.quests.quests_by_condition_type[ct]
        if not t then
            t = {}
            storage.quests.quests_by_condition_type[ct] = t
        end
        table.insert(t, quest)
    end
end

function quests.new_quest(params)
    if not params.name then
        lib.log_error("quests.new_quest: Quest must have a name")
        return
    end
    if not params.conditions then
        lib.log("quests.new_quest: Quest has no conditions")
    end
    if not params.rewards then
        lib.log("quests.new_quest: Quest has no rewards")
    end
    local quest = {
        -- type = params.type,
        name = params.name,
        conditions = {},
        rewards = {},
        notes = params.notes, -- can be nil
        unlocks = params.unlocks, -- can be nil
        prerequisites = params.prerequisites, -- can be nil
        has_img = params.has_img, -- can be nil, defaults to true
    }

    for _, condition in pairs(params.conditions or {}) do
        table.insert(quest.conditions, quests.new_condition(condition))
    end

    for _, reward in pairs(params.rewards or {}) do
        table.insert(quest.rewards, quests.new_reward(reward))
    end

    return quest
end

function quests.new_condition(params)
    if not params.type then
        lib.log_error("Condition must have a type")
        return
    end
    if params.show_progress_bar == nil then
        params.show_progress_bar = true
    end
    local condition = {
        type = params.type,
        progress_requirement = params.progress_requirement or 1,
        progress = 0,
        show_progress_bar = params.show_progress_bar,
        notes = params.notes, -- can be nil
    }
    local constant_notes = storage.quests.notes_per_condition_type[condition.type]
    if constant_notes then
        if not condition.notes then
            condition.notes = constant_notes
        else
            for _, note in pairs(constant_notes) do
                table.insert(condition.notes, note)
            end
        end
    end
    return condition
end

function quests.new_reward(params)
    if not params.type then
        lib.log_error("Reward must have a type")
        return
    end
    local reward = {
        type = params.type,
        value = params.value, -- can be nil
        notes = params.notes, -- can be nil
    }
    local constant_notes = storage.quests.notes_per_reward_type[reward.type]
    if constant_notes then
        if not reward.notes then
            reward.notes = constant_notes
        else
            for _, note in pairs(constant_notes) do
                table.insert(reward.notes, note)
            end
        end
    end
    if reward.type == "unlock-feature" and not reward.value then
        error("Reward of type \"unlock-feature\" must have a value")
    end
    return reward
end

function quests.get_quest(quest_name)
    local quest = storage.quests.quests[quest_name]
    if not quest then
        lib.log_error("quests.get_quest: Could not find quest with name " .. quest_name)
    end
    return quest
end

function quests.get_quest_localized_title(quest)
    return {"quest." .. quest.name .. "-title"}
end

function quests.get_quest_localized_description(quest)
    return {"quest." .. quest.name .. "-desc"}
end

function quests.get_condition_localized_name(condition)
    return {"quest-condition." .. condition.type .. "-name"}
end

function quests.get_condition_localized_description(condition, ...)
    return {"quest-condition." .. condition.type .. "-desc", ...}
end

function quests.get_reward_localized_name(reward)
    return {"quest-reward." .. reward.type .. "-name"}
end

function quests.get_reward_localized_description(reward, ...)
    return {"quest-reward." .. reward.type .. "-desc", ...}
end

function quests.get_localized_note(note_name)
    return {"hextorio-questbook.note-" .. note_name}
end

function quests.get_feature_localized_name(feature_name)
    return {"hextorio-feature." .. feature_name .. "-name"}
end

function quests.get_feature_localized_description(feature_name)
    return {"hextorio-feature." .. feature_name .. "-desc"}
end

-- Dish out the rewards of a quest.
function quests.give_rewards(quest)
    if quest.completed then return end

    for _, reward in pairs(quest.rewards) do
        if reward.type == "unlock-feature" then
            storage.quests.unlocked_features[reward.value] = true
        elseif reward.type == "receive-items" then
            for _, player in pairs(game.players) do
                quests.try_receive_items_reward(player, quest, reward)
            end
        end

        event_system.trigger("quest-reward-received", reward.type, reward.value)
    end
end

function quests.try_receive_items_reward(player, quest, reward)
    if not storage.quests.players_rewarded[player.name] then
        storage.quests.players_rewarded[player.name] = {}
        if storage.quests.players_rewarded[player.name][quest.name] then
            return false
        end
    end
    storage.quests.players_rewarded[player.name][quest.name] = true

    local spilled = false
    for _, item_stack in pairs(reward.value) do
        if not lib.safe_insert(player, item_stack) then
            spilled = true
        end
    end

    if spilled then
        player.print("[gps=" .. player.position.x .. "," .. player.position.y .. "," .. player.surface.name .. "]")
    end

    return true
end

function quests.check_player_receive_items(player)
    local any = false
    for _, quest in pairs(storage.quests.quests) do
        if quest.complete then
            for _, reward in pairs(quest.rewards) do
                if reward.type == "receive-items" then
                    if quests.try_receive_items_reward(player, quest, reward) then
                        any = true
                    end
                end
            end
        end
    end
    if any then
        player.print({"hextorio.rewards-while-away"})
    end
end

function quests.print_quest_completion(quest)
    local rewards_str = {""}
    for _, reward in pairs(quest.rewards) do
        local s = {"", "\n"}
        if reward.type == "unlock-feature" then
            table.insert(s, lib.color_localized_string(quests.get_feature_localized_name(reward.value), "orange", "heading-1"))
            table.insert(s, " ")
            table.insert(s, lib.color_localized_string(quests.get_feature_localized_description(reward.value), "gray"))
        elseif reward.type == "receive-items" then
            local item_imgs = {}
            for _, item_stack in pairs(reward.value) do
                table.insert(item_imgs, "[img=item." .. item_stack.name .. "]x" .. item_stack.count)
            end
            table.insert(s, lib.color_localized_string(quests.get_reward_localized_name(reward), "yellow", "heading-1"))
            table.insert(s, " [color=gray]" .. table.concat(item_imgs, " ") .. "[.color]")
        else
            table.insert(s, lib.color_localized_string(quests.get_reward_localized_name(reward), "white", "heading-1"))
            table.insert(s, " ")
            table.insert(s, lib.color_localized_string(quests.get_reward_localized_description(reward, "[color=green]" .. reward.value .. "[.color]"), "gray"))
        end
        table.insert(rewards_str, s)
    end
    table.insert(rewards_str, "\n")

    game.print({"",
        "\n[font=heading-1][color=blue]-=-=-=-=-= ",
        {"hextorio.quest-complete"},
        " =-=-=-=-=-[.color][.font]\n",
        lib.color_localized_string(quests.get_quest_localized_title(quest), "cyan", "heading-1"),
        " ",
        lib.color_localized_string(quests.get_quest_localized_description(quest), "gray"),
        "\n\n",
        lib.color_localized_string({"hextorio-questbook.rewards"}, "green", "heading-1"),
        rewards_str,
    })
end

-- Check if all conditions are satisfied.
function quests.check_quest_completion(quest)
    if quest.completed then return end
    for _, condition in pairs(quest.conditions) do
        if condition.progress < condition.progress_requirement then
            return
        end
    end

    quests.complete_quest(quest)
end

-- Set a quest condition's progress and check if the quest is complete.
function quests.set_progress(quest, condition, amount)
    if quest.completed then return end
    condition.progress = math.max(0, math.min(condition.progress_requirement, amount))
    if condition.progress >= condition.progress_requirement then
        quests.check_quest_completion(quest)
    end
end

-- Set the progress of all quest conditions of a certain type.
function quests.set_progress_for_type(condition_type, amount)
    for _, quest in pairs(storage.quests.quests_by_condition_type) do
        if not quest.completed then
            for _, condition in pairs(quest.conditions) do
                if condition.type == condition_type then
                    quests.set_progress(quest, condition, amount)
                end
            end
        end
    end
end

-- Increment the progress of all quest conditions of a certain type.
function quests.increment_progress_for_type(condition_type, amount)
    if not amount then amount = 1 end
    local quest_list = storage.quests.quests_by_condition_type[condition_type]
    if not quest_list then return end
    for _, quest in pairs(quest_list) do
        if not quest.completed then
            for _, condition in pairs(quest.conditions) do
                if condition.type == condition_type then
                    quests.set_progress(quest, condition, condition.progress + amount)
                end
            end
        end
    end
end

-- Return whether a given feature has been unlocked by any quest.
function quests.is_feature_unlocked(feature_name)
    return storage.quests.unlocked_features[feature_name] == true
end

-- Reveal a quest, making it visible in the questbook.
function quests.reveal_quest(quest)
    if quest.revealed then return end
    quest.revealed = true
    event_system.trigger("quest-revealed", quest)
end

-- Reveal any quests that are unlocked by this quest and have all prerequisite quests completed.
function quests.check_revelations(quest)
    -- Direct unlocks are always revealed (like OR).
    if quest.unlocks then
        for _, unlock in pairs(quest.unlocks) do
            local unlock_quest = quests.get_quest(unlock)
            quests.reveal_quest(unlock_quest)
        end
    end

    -- All prerequisites must be completed for the quest to be revealed (like AND).
    for _, q in pairs(storage.quests.quests) do
        if not q.complete and not q.revealed then
            local reveal = true
            if q.prerequisites then
                for _, prereq in pairs(q.prerequisites) do
                    local prereq_quest = quests.get_quest(prereq)
                    if not prereq_quest.complete then
                        reveal = false
                        break
                    end
                end
            end
            if reveal then
                quests.reveal_quest(q)
            end
        end
    end
end

-- Complete a quest, bypassing any progress requirements.
function quests.complete_quest(quest)
    if quest.complete then return end

    quests.print_quest_completion(quest)
    quests.give_rewards(quest)
    quest.complete = true

    for _, condition in pairs(quest.conditions) do
        condition.progress = condition.progress_requirement
    end
    
    quests.check_revelations(quest)
    event_system.trigger("quest-completed", quest)
end



return quests
