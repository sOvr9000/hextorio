
local lib = require "api.lib"
local event_system = require "api.event_system"
local sets         = require "api.sets"
local axial        = require "api.axial"
local terrain      = require "api.terrain"



local quests = {}



function quests.register_events()
    event_system.register_callback("command-complete-quest", function(player, params)
        local quest = quests.get_quest_from_name(params[1])
        if quest then
            quests.complete_quest(quest)
        else
            player.print("Unrecognized quest name: " .. params[1])
        end
    end)

    event_system.register_callback("command-hextorio-debug", function(player, params)
        local quest = quests.get_quest_from_name "find-some-trades"
        if quest then
            quests.complete_quest(quest)
        else
            lib.log_error("Couldn't find quest to unlock trade overview")
        end
    end)

    event_system.register_callback("spawner-rammed", function(spawner, vehicle)
        quests.increment_progress_for_type "biter-ramming"
    end)

    event_system.register_callback("enemy-died-to-damage-type", function(entity, damage_type_name, cause)
        quests.increment_progress_for_type("kill-with-damage-type", 1, damage_type_name)
    end)

    event_system.register_callback("player-built-entity", function(player, entity)
        quests.increment_progress_for_type("place-entity", 1, entity.name)
        quests.increment_progress_for_type("place-entity-on-planet", 1, {entity.name, entity.surface.name})
    end)

    event_system.register_callback("player-mined-entity", function(player, entity)
        quests.increment_progress_for_type("mine-entity", 1, entity.name)
    end)

    event_system.register_callback("entity-picked-up", function(entity)
        quests.increment_progress_for_type("place-entity", -1, entity.name)
        quests.increment_progress_for_type("place-entity-on-planet", -1, {entity.name, entity.surface.name})
    end)

    event_system.register_callback("dungeon-looted", function(dungeon)
        quests.increment_progress_for_type("loot-dungeons-on", 1, dungeon.surface.name)

        local passed = true
        for _, player in pairs(game.connected_players) do
            if player.character and player.character.surface == dungeon.surface then
                passed = false
            end
        end

        if passed then
            quests.increment_progress_for_type "loot-dungeons-off-planet"
        end
    end)
end

function quests.reinitialize_everything()
    -- event_system.trigger("quests-reinitializing")
    quests.init()
    quests.recalculate_all_revelations()
    event_system.trigger("quests-reinitialized")
end

function quests.init()
    if not storage.quests.quests then
        storage.quests.quests = {}
    end
    if not storage.quests.quest_ids_by_name then
        storage.quests.quest_ids_by_name = {}
    end

    -- Remove any duplicates just in case duplication ever happens (a bug pre-1.1.3).
    quests.remove_duplicates()

    local old_quests = table.deepcopy(storage.quests.quests)
    local old_quest_ids_by_name = table.deepcopy(storage.quests.quest_ids_by_name)
    storage.quests.quests = {}
    storage.quests.quest_ids_by_name = {}
    storage.quests.quest_id_counter = 0

    local reveal = {}
    local check_rev = {}
    for _, def in pairs(storage.quests.quest_defs) do
        local old_quest
        if old_quest_ids_by_name[def.name] then
            old_quest = old_quests[old_quest_ids_by_name[def.name]]
        end

        local new_quest = quests.new_quest(def)
        storage.quests.quests[new_quest.id] = new_quest
        storage.quests.quest_ids_by_name[def.name] = new_quest.id

        if old_quest and quests.is_complete(old_quest) then
            -- check if extra rewards have been added due to migration
            local extra_rewards = quests.get_reward_list_additions(new_quest, old_quest)
            for _, reward in pairs(extra_rewards) do
                quests.give_reward(reward)
            end

            -- don't overwrite old quest progress
            quests._mark_complete(new_quest)
            table.insert(check_rev, new_quest)
        end

        quests.index_by_condition_types(new_quest)

        if not new_quest.prerequisites or not next(new_quest.prerequisites) then
            table.insert(reveal, new_quest)
        end
    end

    quests.calculate_quest_order()

    for _, quest in pairs(reveal) do
        quests.reveal_quest(quest)
    end
    for _, quest in pairs(check_rev) do
        quests.check_revelations(quest)
    end
end

function quests.index_by_condition_types(quest)
    if not storage.quests.quests_by_condition_type then
        storage.quests.quests_by_condition_type = {}
    end
    for _, condition in pairs(quest.conditions) do
        local t = storage.quests.quests_by_condition_type[condition.type]
        if not t then
            t = {}
            storage.quests.quests_by_condition_type[condition.type] = t
        end
        local condition_value_key = quests.get_condition_value_key(condition.value, condition.value_is_table)
        local s = t[condition_value_key]
        if not s then
            s = {}
            t[condition_value_key] = s
        end
        s[quest.id] = true
    end
end

function quests.remove_duplicates()
    local complete = {}
    local revealed = {}
    for i, q in pairs(storage.quests.quests) do
        if quests.is_complete(q) then
            complete[q.name] = true
        end
        if quests.is_revealed(q) then
            revealed[q.name] = true
        end
    end
    local seen = {}
    for i, q in pairs(storage.quests.quests) do
        if seen[q.name] then
            local lowest_i = seen[q.name]
            storage.quests.quest_ids_by_name[q.name] = lowest_i
            for j, q2 in pairs(storage.quests.quests) do
                if q2.name == q.name then
                    storage.quests.quests[lowest_i] = q2
                    storage.quests.quests[j] = nil
                    if complete[q.name] then
                        quests._mark_complete(q2)
                    end
                    if revealed[q.name] then
                        quests._mark_revealed(q2)
                    end
                end
            end
        else
            seen[q.name] = i
        end
    end
end

function quests.get_condition_value_key(condition_value, is_table)
    if condition_value == nil then
        return "none"
    end
    if is_table then
        return table.concat(condition_value, "-")
    end
    return condition_value
end

function quests.get_reward_list_additions(new_quest, old_quest)
    local additions = {}

    for _, new_reward in pairs(new_quest.rewards) do
        local found = false
        for _, old_reward in pairs(old_quest.rewards) do
            if quests.rewards_equal(new_reward, old_reward) then
                found = true
                break
            end
        end
        if not found then
            table.insert(additions, new_reward)
        end
    end

    return additions
end

---@param params table
---@param id int|nil
---@return Quest
function quests.new_quest(params, id)
    if not params.name then
        lib.log_error("quests.new_quest: Quest has no name")
    end
    if not params.conditions then
        lib.log("quests.new_quest: Quest has no conditions")
    end
    if not params.rewards then
        lib.log("quests.new_quest: Quest has no rewards")
    end

    if id and storage.quests.quests[id] and storage.quests.quests[id].name ~= params.name then
        lib.log_error("quests.new_quest: Provided id " .. id .. " is already used by another quest: " .. storage.quests.quests[id].name)
        id = nil
    end
    if not id then
        while storage.quests.quests[storage.quests.quest_id_counter] do
            storage.quests.quest_id_counter = storage.quests.quest_id_counter + 1
        end
        id = storage.quests.quest_id_counter
    end

    local quest = {
        id = id,
        name = params.name,
        conditions = {},
        rewards = {},
        notes = params.notes, -- can be nil
        unlocks = params.unlocks, -- can be nil
        prerequisites = params.prerequisites, -- can be nil
        has_img = params.has_img, -- can be nil, defaults to true
        order = 0,
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
        value = params.value,
        value_is_table = type(params.value) == "table",
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

function quests.conditions_equal(condition1, condition2)
    if condition1.type ~= condition2.type then return false end
    if condition1.progress_requirement ~= condition2.progress_requirement then return false end
    if condition1.value ~= condition2.value then return false end
    return true
end

function quests.rewards_equal(reward1, reward2)
    if reward1.type ~= reward2.type then return false end
    if type(reward1.value) ~= type(reward2.value) then return false end

    if type(reward1.value) == "table" then
        if not lib.tables_equal(reward1.value, reward2.value) then
            return false
        end
    else
        if reward1.value ~= reward2.value then
            return false
        end
    end

    return true
end

function quests.calculate_quest_order()
    local visited = {}
    local function dfs(quest)
        if visited[quest.name] then return end
        visited[quest.name] = true
        local q
        if quest.unlocks then
            for _, unlock in pairs(quest.unlocks) do
                q = quests.get_quest_from_name(unlock)
                if q then
                    q.order = math.min(q.order, quest.order + 1)
                    dfs(q)
                end
            end
        end
        if quest.prerequisites then
            for _, prereq in pairs(quest.prerequisites) do
                q = quests.get_quest_from_name(prereq)
                if q then
                    quest.order = math.min(quest.order, q.order + 1)
                    dfs(q)
                end
            end
        end
    end
    dfs(quests.get_quest_from_name "ground-zero")
end

---@param quest_name string
---@return Quest|nil
function quests.get_quest_from_name(quest_name)
    local quest_id = storage.quests.quest_ids_by_name[quest_name]
    if not quest_id then
        lib.log_error("quests.get_quest_from_name: Could not find quest id with name " .. quest_name)
        return
    end
    return quests.get_quest_from_id(quest_id)
end

---Return whether a quest by the given name exists.
---@param quest_name string
---@return boolean
function quests.quest_exists(quest_name)
    local quest_id = storage.quests.quest_ids_by_name[quest_name]
    if not quest_id then
        return false
    end
    return storage.quests.quests[quest_id] ~= nil
end

---@param quest_id int
---@return Quest|nil
function quests.get_quest_from_id(quest_id)
    local quest = storage.quests.quests[quest_id]
    if not quest then
        lib.log_error("quests.get_quest_from_id: Could not find quest with id " .. quest_id)
    end
    return quest
end

---@param quest QuestIdentification|nil
---@return Quest|nil
function quests.get_quest(quest)
    if not quest then return end
    if type(quest) == "number" then
        return quests.get_quest_from_id(quest)
    elseif type(quest) == "string" then
        return quests.get_quest_from_name(quest)
    elseif type(quest) == "table" then
        return quest
    end
end

function quests.get_quest_localized_title(quest)
    return {"quest-title." .. quest.name}
end

function quests.get_quest_localized_description(quest)
    return {"quest-description." .. quest.name}
end

function quests.get_condition_localized_name(condition)
    return {"quest-condition-name." .. condition.type}
end

function quests.get_condition_localized_description(condition, ...)
    return {"quest-condition-description." .. condition.type, ...}
end

function quests.get_reward_localized_name(reward)
    return {"quest-reward-name." .. reward.type}
end

function quests.get_reward_localized_description(reward, ...)
    return {"quest-reward-description." .. reward.type, ...}
end

function quests.get_localized_note(note_name)
    return {"questbook-note." .. note_name}
end

function quests.get_feature_localized_name(feature_name)
    return {"feature-name." .. feature_name}
end

function quests.get_feature_localized_description(feature_name)
    return {"feature-description." .. feature_name}
end

---@param quest QuestIdentification
---@return boolean
function quests.is_complete(quest)
    if not quest then
        lib.log_error("quests.is_complete: quest is nil")
        return false
    end
    local q = quests.get_quest(quest)
    if not q then
        lib.log_error("quests.is_complete: Quest not found: " .. tostring(quest))
        return false
    end
    return q.complete == true
end

function quests._mark_complete(quest)
    quest.complete = true
    quest.revealed = true
end

---@param quest QuestIdentification
---@return boolean
function quests.is_revealed(quest)
    if not quest then
        lib.log_error("quests.is_revealed: quest is nil")
        return false
    end
    local q = quests.get_quest(quest)
    if not q then
        lib.log_error("quests.is_revealed: Quest not found: " .. tostring(quest))
        return false
    end
    return q.revealed == true or quests.is_complete(q)
end

function quests._mark_revealed(quest)
    quest.revealed = true
end

---Get the current progress of completion for a condition in a quest.
---If the quest is complete, assume 100% progress completion.
---@param quest Quest
---@param condition table
---@return float
function quests.get_condition_progress(quest, condition)
    if quests.is_complete(quest) then
        return 1
    end
    return condition.progress / condition.progress_requirement
end

---Process the obtainment of a quest reward.
---@param reward QuestReward
---@param from_quest Quest|nil
function quests.give_reward(reward, from_quest)
    if reward.type == "unlock-feature" then
        storage.quests.unlocked_features[reward.value] = true
    elseif reward.type == "receive-items" then
        if from_quest then
            for _, player in pairs(game.players) do
                quests.try_receive_items_reward(player, from_quest, reward)
            end
        else
            lib.log_error("quests.give_reward: Tried to give a quest reward of type 'receive-items' from a nil quest.")
        end
    end

    event_system.trigger("quest-reward-received", reward.type, reward.value)
end

---Dish out the rewards of a quest.
---@param quest QuestIdentification
function quests.give_rewards_of_quest(quest)
    local q = quests.get_quest(quest)
    if not q then
        lib.log_error("quests.give_rewards: Quest not found: " .. tostring(quest))
        return
    end
    if quests.is_complete(q) then return end

    for _, reward in pairs(q.rewards) do
        quests.give_reward(reward, q)
    end
end

function quests.try_receive_items_reward(player, quest, reward)
    if not storage.quests.players_rewarded[player.name] then
        storage.quests.players_rewarded[player.name] = {}
    end
    if storage.quests.players_rewarded[player.name][quest.name] then return false end

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
        if quests.is_complete(quest) then
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
            if type(reward.value) == "table" then
                table.insert(s, lib.color_localized_string(quests.get_reward_localized_description(reward, "green", "heading-1", table.unpack(reward.value)), "gray"))
            else
                table.insert(s, lib.color_localized_string(quests.get_reward_localized_description(reward, "green", "heading-1", reward.value), "gray"))
            end
        end
        table.insert(rewards_str, s)
    end
    table.insert(rewards_str, "\n")

    lib.print_notification("quest-completed", {"",
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
---@param quest Quest|int
function quests.check_quest_completion(quest)
    if quests.is_complete(quest) then return end
    for _, condition in pairs(quest.conditions) do
        if condition.progress < condition.progress_requirement then
            return
        end
    end

    quests.complete_quest(quest)
end

---@param condition_type string
---@param condition_value any
---@return table[]
function quests.get_quests_by_condition_type(condition_type, condition_value)
    if condition_value == nil then condition_value = "none" end
    if not storage.quests.quests_by_condition_type[condition_type] then
        lib.log_error("quests.get_quests_by_condition_type: No quests found with condition type " .. condition_type)
        return {}
    end
    local condition_value_key = quests.get_condition_value_key(condition_value, type(condition_value) == "table")
    local quest_ids = storage.quests.quests_by_condition_type[condition_type][condition_value_key] or {}
    local q = {}
    for quest_id, _ in pairs(quest_ids) do
        table.insert(q, storage.quests.quests[quest_id])
    end
    return q
end

-- Set a quest condition's progress and check if the quest is complete.
function quests.set_progress(quest, condition, amount)
    if quests.is_complete(quest) then return end
    condition.progress = math.max(0, math.min(condition.progress_requirement, amount))
    if condition.progress >= condition.progress_requirement then
        quests.check_quest_completion(quest)
    end
end

-- Set the progress of all quest conditions of a certain type.
function quests.set_progress_for_type(condition_type, amount, condition_value)
    for _, quest in pairs(quests.get_quests_by_condition_type(condition_type, condition_value)) do
        if not quests.is_complete(quest) then
            for _, condition in pairs(quest.conditions) do
                local pass = condition.type == condition_type and (condition.value == nil or condition.value == condition_value)
                if not pass and condition.value_is_table then
                    pass = lib.tables_equal(condition_value, condition.value)
                end
                if pass then
                    quests.set_progress(quest, condition, amount)
                end
            end
        end
    end
end

-- Increment the progress of all quest conditions of a certain type.
function quests.increment_progress_for_type(condition_type, amount, condition_value)
    if not amount then amount = 1 end
    if not storage.quests.quests_by_condition_type[condition_type] then return end
    for _, quest in pairs(quests.get_quests_by_condition_type(condition_type, condition_value)) do
        if not quests.is_complete(quest) then
            for _, condition in pairs(quest.conditions) do
                local pass = condition.type == condition_type and (condition.value == nil or condition.value == condition_value)
                if not pass and condition.value_is_table then
                    pass = lib.tables_equal(condition_value, condition.value)
                end
                if pass then
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
            local unlock_quest = quests.get_quest_from_name(unlock)
            quests.reveal_quest(unlock_quest)
        end
    end

    -- All prerequisites must be completed for the quest to be revealed (like AND).
    for _, q in pairs(storage.quests.quests) do
        if not q.complete and not q.revealed then
            local reveal = true
            if q.prerequisites then
                for _, prereq in pairs(q.prerequisites) do
                    local prereq_quest = quests.get_quest_from_name(prereq)
                    if prereq_quest and not quests.is_complete(prereq_quest) then
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

---Particularly meant for migrations, force check all quests for whether they should be revealed or hidden.
function quests.recalculate_all_revelations()
    for _, quest in pairs(storage.quests.quests) do
        quest.revealed = false
    end
    for _, quest in pairs(storage.quests.quests) do
        if quests.is_complete(quest) then
            quests.check_revelations(quest)
        end
    end
end

---Remove a quest from the game.
---Particularly meant for migrations and replacing old quests with new ones using the same name.
---@param quest QuestIdentification
function quests.remove_quest(quest)
    local q = quests.get_quest(quest)
    if not q then return end

    local found_i = -1
    for i, def in ipairs(storage.quests.quest_defs) do
        if def.name == q.name then
            found_i = i
            break
        end
    end
    if found_i >= 1 then
        storage.quests.quest_defs[i] = nil
    end

    storage.quests.quest_ids_by_name[q.name] = nil
    storage.quests.quests[q.id] = nil
end

---Complete a quest, bypassing any progress requirements.
---@param quest QuestIdentification
function quests.complete_quest(quest)
    if not quest then
        lib.log_error("quests.complete_quest: No quest provided")
        return
    end

    local q = quests.get_quest(quest)
    if not q then
        lib.log_error("quests.complete_quest: Quest not found: " .. tostring(quest))
        return
    end

    if quests.is_complete(q) then return end

    quests.reveal_quest(quest)
    quests.print_quest_completion(q)
    quests.give_rewards_of_quest(q)
    quests._mark_complete(q)

    for _, condition in pairs(q.conditions) do
        condition.progress = condition.progress_requirement
    end

    quests.check_revelations(q)
    event_system.trigger("quest-completed", q)
end



return quests
