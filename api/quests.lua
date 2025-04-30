local lib = require "api.lib"
local event_system = require "api.event_system"
local sets         = require "api.sets"

local quests = {}



function quests.init()
    lib.log("Indexing quests...")
    for _, def in pairs(storage.quests.quest_defs) do
        lib.log(def.name)
        local quest = quests.new_quest(def)
        storage.quests.quests[def.name] = quest
        quests.index_by_condition_types(quest)
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
    }
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
    }
    if reward.type == "unlock-feature" and not reward.value then
        error("Reward of type \"unlock-feature\" must have a value")
    end
    return reward
end

function quests.get_quest_localized_title(quest)
    return {"quest." .. quest.name .. "-title"}
end

function quests.get_quest_localized_description(quest)
    return {"quest." .. quest.name .. "-desc"}
end

-- Dish out the rewards of a quest.
function quests.give_rewards(quest)
    if quest.completed then return end
    for _, reward in pairs(quest.rewards) do
        if reward.type == "unlock-feature" then
            storage.quests.unlocked_features[reward.value] = true
        end
        event_system.trigger("quest-reward-received", reward.type, reward.value)
    end
end

function quests.print_quest_completion(quest)
    game.print({"",
        "\n[font=heading-1][color=blue]-=-=-=-=-= ",
        {"hextorio.quest-complete"},
        " =-=-=-=-=-[.color][.font]\n",
        lib.color_localized_string(quests.get_quest_localized_title(quest), "cyan", "heading-1"),
        "\n",
        lib.color_localized_string(quests.get_quest_localized_description(quest), "gray"),
        "\n",
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
    quests.give_rewards(quest)
    quest.completed = true
    quests.print_quest_completion(quest)
    event_system.trigger("quest-completed", quest)
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

function quests.is_feature_unlocked(feature_name)
    return storage.quests.unlocked_features[feature_name] == true
end



return quests
