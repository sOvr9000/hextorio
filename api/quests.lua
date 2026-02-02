
local lib = require "api.lib"
local coin_tiers = require "api.coin_tiers"
local event_system = require "api.event_system"
local entity_util  = require "api.entity_util"
local sets         = require "api.sets"
local gameplay_statistics = require "api.gameplay_statistics"

local quests = {}



---@alias QuestConditionType "claimed-hexes"|"make-trades"|"ping-trade"|"create-trade-map-tag"|"reach-hex-rank"|"trades-found"|"biter-ramming"|"items-at-rank"|"total-item-rank"|"hex-span"|"coins-in-inventory"|"hex-cores-in-mode"|"loot-dungeons-on"|"loot-dungeons-off-planet"|"visit-planet"|"place-entity-on-planet"|"kill-entity"|"claimed-hexes-on"|"die-to-damage-type"|"use-capsule"|"kill-with-damage-type"|"mine-entity"|"die-to-railgun"|"place-tile"|"sell-item-of-quality"|"place-entity"|"favorite-trade"|"total-strongbox-level"|"hex-core-trades-read"|"cover-ores-on"
---@alias QuestRewardType "unlock-feature"|"receive-items"|"claim-free-hexes"|"reduce-biters"|"all-trades-productivity"|"receive-spaceship"
---@alias FeatureName "trade-overview"|"catalog"|"hex-rank"|"hexports"|"supercharging"|"resource-conversion"|"quantum-bazaar"|"trade-configuration"|"item-buffs"|"teleportation"|"teleportation-cross-planet"|"hex-core-deletion"|"generator-mode"|"sink-mode"|"locomotive-trading"|"quick-trading"|"item-buff-enhancement"|"enhance-all"|"piggy-bank"

---@alias SingleQuestConditionValue string|number
---@alias SingleQuestRewardValue string|number|ItemStackIdentification
---@alias QuestConditionValue SingleQuestConditionValue|SingleQuestConditionValue[]
---@alias QuestRewardValue SingleQuestRewardValue|SingleQuestRewardValue[]

---@alias QuestConditionTypeValuePair {[1]: QuestConditionType, [2]: QuestConditionValue}

---@alias QuestIdentification Quest|int|string

---@class Quest
---@field id int
---@field name string
---@field conditions QuestCondition[]
---@field rewards QuestReward[]
---@field notes string[]|nil
---@field unlocks string[]|nil
---@field prerequisites string[]|nil
---@field has_img boolean|nil
---@field order int
---@field revealed boolean|nil
---@field complete boolean|nil

---@class QuestCondition
---@field type QuestConditionType
---@field value QuestConditionValue
---@field value_is_table boolean
---@field progress_requirement int
---@field progress int
---@field show_progress_bar boolean
---@field notes string[]|nil

---@class QuestReward
---@field type QuestRewardType
---@field value QuestRewardValue|nil
---@field notes string[]|nil



---@class QuestDefinition
---@field name string
---@field conditions QuestConditionDefinition[]
---@field rewards QuestRewardDefinition[]
---@field notes string[]|nil
---@field unlocks string[]|nil
---@field prerequisites string[]|nil
---@field has_img boolean|nil

---@class QuestConditionDefinition
---@field type QuestConditionType
---@field value QuestConditionValue
---@field progress_requirement int
---@field show_progress_bar boolean
---@field notes string[]|nil

---@class QuestRewardDefinition
---@field type QuestRewardType
---@field value QuestRewardValue|nil
---@field notes string[]|nil



-- TODO: (IMPORTANT REFACTORING) Move condition progress management into gameplay_statistics.lua or a similar module.  They are functionally the same thing.
local quest_condition_progress_recalculators = {} ---@as {[QuestConditionType]: fun(condition_value: QuestConditionValue): int}

---@param condition_type QuestConditionType
---@param func fun(condition_value: QuestConditionValue): int
local function define_progress_recalculator(condition_type, func)
    quest_condition_progress_recalculators[condition_type] = func
end

define_progress_recalculator("visit-planet", function(condition_value)
    local surface_name = condition_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    return 1
end)

define_progress_recalculator("items-at-rank", function(condition_value)
    local rank = condition_value
    local total = 0
    for item_name, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if lib.is_catalog_item(item_name) then -- Shouldn't be necessary to check this, but it's here just in case it prevents a bug/exploit.
            if rank_obj.rank >= rank then
                total = total + 1
            end
        end
    end
    return total
end)

define_progress_recalculator("total-item-rank", function(condition_value)
    local total = 0
    for item_name, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if lib.is_catalog_item(item_name) then -- Shouldn't be necessary to check this, but it's here just in case it prevents a bug/exploit.
            total = total + rank_obj.rank - 1
        end
    end
    return total
end)

define_progress_recalculator("claimed-hexes-on", function(condition_value)
    local surface_name = condition_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    local surface_hexes = storage.hex_grid.surface_hexes[surface.index]
    if not surface_hexes then return 0 end

    local total = 0
    for _, Q in pairs(surface_hexes) do
        for _, state in pairs(Q) do
            if state.claimed then
                total = total + 1
            end
        end
    end

    return total
end)

define_progress_recalculator("claimed-hexes", function(condition_value)
    local total = 0
    for surface_id, hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(hexes) do
            for _, state in pairs(Q) do
                if state.claimed then
                    total = total + 1
                end
            end
        end
    end
    return total
end)

define_progress_recalculator("total-strongbox-level", function(condition_value)
    local total_level = 0
    for surface_id, hexes in pairs(storage.hex_grid.surface_hexes) do
        for _, Q in pairs(hexes) do
            for _, state in pairs(Q) do
                if state.strongboxes then
                    for _, sb_entity in pairs(state.strongboxes) do
                        total_level = total_level + (entity_util.get_tier_of_strongbox(sb_entity) or 1) - 1
                    end
                end
            end
        end
    end
    return total_level
end)

define_progress_recalculator("cover-ores-on", function(condition_value)
    local surface_name = condition_value
    ---@cast surface_name string

    local surface = game.get_surface(surface_name)
    if not surface then return 0 end

    local total_ores = 0
    for _, entity in pairs(surface.find_entities_filtered {
        type = "mining-drill",
    }) do
        total_ores = total_ores + entity_util.track_ores_covered_by_drill(entity)
    end

    return total_ores
end)



function quests.register_events()
    event_system.register("command-complete-quest", function(player, params)
        local quest = quests.get_quest_from_name(params[1])
        if quest then
            quests.complete_quest(quest)
        else
            player.print("Unrecognized quest name: " .. params[1])
        end
    end)

    event_system.register("command-hextorio-debug", function(player, params)
        local quest = quests.get_quest_from_name "find-some-trades"
        if quest then
            quests.complete_quest(quest)
        else
            lib.log_error("Couldn't find quest to unlock trade overview")
        end
    end)

    event_system.register("entity-died", function(entity)
        if not entity.valid then return end
        if entity.type == "mining-drill" then
            local now_uncovered = entity_util.untrack_ores_covered_by_drill(entity)
            quests.increment_progress_for_type("cover-ores-on", -now_uncovered, entity.surface.name)
        end
    end)

    event_system.register("player-built-entity", function(player, entity)
        if not entity.valid then return end
        quests.increment_progress_for_type("place-entity", 1, entity.name)
        quests.increment_progress_for_type("place-entity-on-planet", 1, {entity.name, entity.surface.name})

        if entity.type == "mining-drill" then
            local now_covered = entity_util.track_ores_covered_by_drill(entity)
            quests.increment_progress_for_type("cover-ores-on", now_covered, entity.surface.name)
        end
    end)

    event_system.register("player-mined-entity", function(player, entity)
        quests.increment_progress_for_type("mine-entity", 1, entity.name)
    end)

    event_system.register("entity-picked-up", function(entity)
        if not entity.valid then return end
        quests.increment_progress_for_type("place-entity", -1, entity.name)
        quests.increment_progress_for_type("place-entity-on-planet", -1, {entity.name, entity.surface.name})

        if entity.type == "mining-drill" then
            local now_uncovered = entity_util.untrack_ores_covered_by_drill(entity)
            quests.increment_progress_for_type("cover-ores-on", -now_uncovered, entity.surface.name)
        end
    end)

    event_system.register("dungeon-looted", function(dungeon)
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

    event_system.register("surface-created", function(surface)
        quests.set_progress_for_type("visit-planet", 1, surface.name)
    end)

    event_system.register("player-favorited-trade", function(player, trade)
        quests.set_progress_for_type("favorite-trade", 1)
    end)

    event_system.register("player-coins-changed", function(player, coin)
        quests.set_progress_for_type("coins-in-inventory", coin_tiers.to_base_value(coin))
    end)

    event_system.register("entity-killed-entity", quests.on_entity_killed_entity)
    -- event_system.register("pre-player-died-to-entity", quests.on_pre_player_died_to_entity)
    event_system.register("player-respawned", quests.on_player_respawned)
    event_system.register("lightning-struck-character", quests.on_lightning_struck_character)

    event_system.register("command-hextorio-debug", function(player, params)
        quests.complete_quest "ground-zero"
    end)

    event_system.register("command-disable-quest", function(player, params)
        local quest_name = params[1]
        local q = quests.get_quest(quest_name)
        if quests.remove_quest(quest_name) and q then
            player.print {"hextorio.quest-disabled", quests.get_quest_localized_title(q)}
        else
            player.print {"hextorio.command-failed-to-disable-quest", quest_name}
        end
    end)

    event_system.register("item-buff-data-migrated", function()
        quests.redistribute_quest_rewards "all-trades-productivity"
    end)

    event_system.register("hex-rank-changed", function(prev_val, new_val)
        quests.set_progress_for_type("reach-hex-rank", new_val)
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

        if old_quest then
            if quests.is_complete(old_quest) then
                -- check if extra rewards have been added due to migration
                local extra_rewards = quests.get_reward_list_additions(new_quest, old_quest)
                for _, reward in pairs(extra_rewards) do
                    quests.give_reward(reward)
                end

                -- don't overwrite old quest progress
                quests._mark_complete(new_quest)
                table.insert(check_rev, new_quest)
            else
                -- don't overwrite old quest progress
                for _, new_condition in pairs(new_quest.conditions) do
                    for _, old_condition in pairs(old_quest.conditions) do
                        if quests.conditions_equal(new_condition, old_condition) then
                            new_condition.progress = old_condition.progress
                            break
                        end
                    end
                end
            end
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

---@param quest Quest
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

---@param condition_value QuestConditionValue
---@param is_table boolean
---@return string|number
function quests.get_condition_value_key(condition_value, is_table)
    if condition_value == nil then
        return "none"
    end
    if is_table then
        ---@cast condition_value (string|number)[]
        return table.concat(condition_value, "-")
    end
    ---@cast condition_value string|number
    return condition_value
end

---@param new_quest Quest
---@param old_quest Quest
---@return QuestReward[]
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

---@param params QuestDefinition
---@param id int|nil
---@return Quest
function quests.new_quest(params, id)
    if not params.name then
        lib.log_error("quests.new_quest: Quest has no name")
    end
    if not params.conditions or not next(params.conditions) then
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

---@param params QuestConditionDefinition
---@return QuestCondition|nil
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

---@param params QuestRewardDefinition
---@return QuestReward|nil
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

---@param condition1 QuestCondition
---@param condition2 QuestCondition
---@return boolean
function quests.conditions_equal(condition1, condition2)
    if condition1.type ~= condition2.type then return false end
    if condition1.progress_requirement ~= condition2.progress_requirement then return false end
    if condition1.value_is_table ~= condition2.value_is_table then return false end

    if condition1.value_is_table then
        if not lib.tables_equal(condition1.value, condition2.value) then return false end
    else
        if condition1.value ~= condition2.value then return false end
    end

    return true
end

---@param reward1 QuestReward
---@param reward2 QuestReward
---@return boolean
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
    for _, quest in pairs(storage.quests.quests) do
        quest.order = 0
    end

    local visited = {}
    local function dfs(quest)
        if visited[quest.name] then return end
        visited[quest.name] = true

        if quest.prerequisites then
            for _, prereq in pairs(quest.prerequisites) do
                local q = quests.get_quest_from_name(prereq)
                if q then
                    dfs(q)
                    quest.order = math.max(quest.order, q.order + 1)
                end
            end
        end

        if quest.unlocks then
            for _, unlock in pairs(quest.unlocks) do
                local q = quests.get_quest_from_name(unlock)
                if q then
                    q.order = math.max(q.order, quest.order + 1)
                    dfs(q)
                end
            end
        end
    end

    dfs(quests.get_quest_from_name("ground-zero"))

    -- Need to figure out why everything's still zero:
    -- for _, quest in pairs(storage.quests.quests) do
    --     log(quest.name .. " -> " .. quest.order)
    -- end
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

---Get a list of quest objects which unlock a specific feature.
---@param feature_name FeatureName
---@return Quest[]
function quests.get_quests_which_unlock(feature_name)
    local quest_list = {}

    for _, quest in pairs(storage.quests.quests) do
        for _, reward in pairs(quest.rewards) do
            if reward.type == "unlock-feature" and reward.value == feature_name then
                table.insert(quest_list, quest)
                break
            end
        end
    end

    return quest_list
end

---Get a list of quests which reveal a specific quest.
---@param quest Quest
---@return Quest[]
function quests.get_quests_which_reveal(quest)
    local quest_list = {}
    local names = sets.new {}

    for _, q in pairs(storage.quests.quests) do
        if q.unlocks then
            for _, to_reveal in pairs(q.unlocks) do
                if to_reveal == quest.name and not sets.contains(names, q.name) then
                    sets.add(names, q.name)
                    table.insert(quest_list, q)
                end
            end
        end
    end

    if quest.prerequisites then
        for _, revealed_by in pairs(quest.prerequisites) do
            local q = quests.get_quest(revealed_by)
            if q and not sets.contains(names, q.name) then
                sets.add(names, q.name)
                table.insert(quest_list, q)
            end
        end
    end

    return quest_list
end

---Get a list of quests which are revealed by a specific quest.
---@param quest Quest
---@return Quest[]
function quests.get_quests_revealed_by(quest)
    local quest_list = {}
    local names = sets.new {}

    for _, q in pairs(storage.quests.quests) do
        if q.prerequisites then
            for _, revealed_by in pairs(q.prerequisites) do
                if revealed_by == quest.name and not sets.contains(names, q.name) then
                    sets.add(names, q.name)
                    table.insert(quest_list, q)
                end
            end
        end
    end

    if quest.unlocks then
        for _, to_reveal in pairs(quest.unlocks) do
            local q = quests.get_quest(to_reveal)
            if q and not sets.contains(names, q.name) then
                sets.add(names, q.name)
                table.insert(quest_list, q)
            end
        end
    end

    return quest_list
end

---@param quest Quest
---@return LocalisedString
function quests.get_quest_localized_title(quest)
    return {"quest-title." .. quest.name}
end

---@param quest Quest
---@return LocalisedString
function quests.get_quest_localized_description(quest)
    return {"quest-description." .. quest.name}
end

---@param condition QuestCondition
---@return LocalisedString
function quests.get_condition_localized_name(condition)
    return {"quest-condition-name." .. condition.type}
end

---@param condition QuestCondition
---@return LocalisedString
function quests.get_condition_localized_description(condition, ...)
    return {"quest-condition-description." .. condition.type, ...}
end

---@param reward QuestReward
---@return LocalisedString
function quests.get_reward_localized_name(reward)
    return {"quest-reward-name." .. reward.type}
end

---@param reward QuestReward
---@return LocalisedString
function quests.get_reward_localized_description(reward, ...)
    return {"quest-reward-description." .. reward.type, ...}
end

---@param note_name string
---@return LocalisedString
function quests.get_localized_note(note_name)
    return {"questbook-note." .. note_name}
end

---@param feature_name FeatureName
---@return LocalisedString
function quests.get_feature_localized_name(feature_name)
    return {"feature-name." .. feature_name}
end

---@param feature_name FeatureName
---@return LocalisedString
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

---@param quest Quest
function quests._mark_complete(quest)
    local prev = quest.complete
    if not prev then
        quest.complete = true
        gameplay_statistics.increment "total-quests-completed"
    end

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

---@param quest Quest
function quests._mark_revealed(quest)
    quest.revealed = true
end

---Get the current progress of completion for a condition in a quest.
---If the quest is complete, assume 100% progress completion.
---@param quest Quest
---@param condition QuestCondition
---@return number
function quests.get_condition_progress(quest, condition)
    if quests.is_complete(quest) then
        return 1
    end
    return condition.progress / condition.progress_requirement
end

---Process the obtainment of a quest reward.
---@param reward QuestReward
---@param from_quest Quest|nil
function quests.give_reward(reward, from_quest, trigger_reward_received)
    if reward.type == "unlock-feature" then
        storage.quests.unlocked_features[reward.value] = true
    elseif reward.type == "receive-items" then
        if from_quest then
            for _, player in pairs(game.players) do
                if lib.player_is_waiting_to_respawn(player) then
                    quests.defer_receive_items_reward(player, from_quest, reward)
                else
                    quests.try_receive_items_reward(player, from_quest, reward)
                end
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

---@param player LuaPlayer
---@param quest Quest
---@param reward QuestReward
---@return boolean
function quests.try_receive_items_reward(player, quest, reward)
    if not storage.quests.players_rewarded[player.name] then
        storage.quests.players_rewarded[player.name] = {}
    end
    if storage.quests.players_rewarded[player.name][quest.name] then return false end

    storage.quests.players_rewarded[player.name][quest.name] = true

    local reward_value = reward.value
    ---@cast reward_value ItemStackIdentification[]

    local spilled = false
    for _, item_stack in pairs(reward_value) do
        if not lib.safe_insert(player, item_stack) then
            spilled = true
        end
    end

    if spilled then
        player.print("[gps=" .. player.position.x .. "," .. player.position.y .. "," .. player.surface.name .. "]")
    end

    return true
end

---Set a quest's "receive items" reward to be deferred until the player respawns.
---Use this if the player dies before the quest reward can be given.
---For example, when a player dies to electricity, the "Electrocution" quest cannot give items to that player until they respawn.
---@param player LuaPlayer
---@param from_quest Quest
---@param reward QuestReward
function quests.defer_receive_items_reward(player, from_quest, reward)
    if not storage.quests.deferred_rewards then
        storage.quests.deferred_rewards = {}
    end

    if not storage.quests.deferred_rewards[player.index] then
        storage.quests.deferred_rewards[player.index] = {}
    end

    table.insert(storage.quests.deferred_rewards[player.index], {
        from_quest_name = from_quest.name,
        reward = table.deepcopy(reward),
    })
end

---@param player LuaPlayer
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

---@param quest Quest
function quests.print_quest_completion(quest)
    local rewards_str = {""}
    for _, reward in pairs(quest.rewards) do
        local reward_value = reward.value
        local s = {"", "\n"}
        if reward.type == "unlock-feature" then
            ---@cast reward_value FeatureName
            table.insert(s, lib.color_localized_string(quests.get_feature_localized_name(reward_value), "orange", "heading-1"))
            table.insert(s, " ")
            table.insert(s, lib.color_localized_string(quests.get_feature_localized_description(reward_value), "gray"))
        elseif reward.type == "receive-items" then
            ---@cast reward_value ItemStackIdentification[]
            local item_imgs = {}
            for _, item_stack in pairs(reward_value) do
                table.insert(item_imgs, "[img=item." .. item_stack.name .. "]x" .. item_stack.count)
            end
            table.insert(s, lib.color_localized_string(quests.get_reward_localized_name(reward), "yellow", "heading-1"))
            table.insert(s, " [color=gray]" .. table.concat(item_imgs, " ") .. "[.color]")
        else
            table.insert(s, lib.color_localized_string(quests.get_reward_localized_name(reward), "white", "heading-1"))
            table.insert(s, " ")
            if type(reward_value) == "table" then
                ---@cast reward_value SingleQuestConditionValue[]
                table.insert(s, lib.color_localized_string(quests.get_reward_localized_description(reward, "green", "heading-1", table.unpack(reward_value)), "gray"))
            else
                table.insert(s, lib.color_localized_string(quests.get_reward_localized_description(reward, "green", "heading-1", reward_value), "gray"))
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

    for _, player in pairs(game.connected_players) do
        local sound_setting = lib.player_setting_value_as_string(player, "quest-completion-sound")
        if sound_setting ~= "none" and sound_setting ~= "console-message" then -- TODO: Implement quest toasts and stop printing quests to console (change this condition to stop checking for "console-message" when done)
            local path
            if sound_setting == "piano" then
                path = "quest-completed"
            elseif sound_setting == "console-message" then
                path = "utility/console_message"
            elseif sound_setting == "research-completed" then
                path = "utility/research_completed"
            elseif sound_setting == "game-won" then
                path = "utility/game_won"
            elseif sound_setting == "game-lost" then
                path = "utility/game_lost"
            elseif sound_setting == "alert" then
                path = "utility/alert_destroyed"
            end

            if path then
                player.play_sound {path = path}
            else
                lib.log_error("quests.print_quest_completion: missing quest completion sound for " .. sound_setting)
            end
        end
    end
end

-- Check if all conditions are satisfied.
---@param quest QuestIdentification
function quests.check_quest_completion(quest)
    if quests.is_complete(quest) then return end
    for _, condition in pairs(quest.conditions) do
        if condition.progress < condition.progress_requirement then
            return
        end
    end

    quests.complete_quest(quest)
end

---@param condition_type QuestConditionType
---@param condition_value QuestConditionValue|nil
---@return Quest[]
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

---Set a quest condition's progress and check if the quest is complete.
---@param quest Quest
---@param condition QuestCondition
---@param amount int
function quests.set_progress(quest, condition, amount)
    if quests.is_complete(quest) then return end
    condition.progress = math.max(0, math.min(condition.progress_requirement, amount))
    if condition.progress >= condition.progress_requirement then
        quests.check_quest_completion(quest)
    end
end

---Set the progress of all quest conditions of a certain type.
---@param condition_type QuestConditionType
---@param amount int
---@param condition_value QuestConditionValue|nil
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

---Increment the progress of all quest conditions of a certain type.
---@param condition_type QuestConditionType
---@param amount int|nil
---@param condition_value QuestConditionValue|nil
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

---Return whether a given feature has been unlocked by any quest.
---@param feature_name FeatureName
function quests.is_feature_unlocked(feature_name)
    return storage.quests.unlocked_features[feature_name] == true
end

---@param feature_name FeatureName
function quests.unlock_feature(feature_name)
    storage.quests.unlocked_features[feature_name] = true
    event_system.trigger("quest-reward-received", "unlock-feature", feature_name)
end

---Reveal a quest, making it visible in the questbook.
---@param quest Quest
function quests.reveal_quest(quest)
    if quest.revealed then return end
    quest.revealed = true
    event_system.trigger("quest-revealed", quest)
end

---Reveal any quests that are unlocked by this quest and have all prerequisite quests completed.
---@param quest Quest
function quests.check_revelations(quest)
    -- Direct unlocks are always revealed (like OR).
    if quest.unlocks then
        for _, unlock in pairs(quest.unlocks) do
            local unlock_quest = quests.get_quest_from_name(unlock)
            if unlock_quest then
                quests.reveal_quest(unlock_quest)
            else
                lib.log_error("quests.check_revelations: unknown quest: " .. unlock)
            end
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
---Returns whether the quest was removed.
---@param quest QuestIdentification
---@return boolean
function quests.remove_quest(quest)
    local q = quests.get_quest(quest)
    if not q then return false end

    local found_i = -1
    for i, def in ipairs(storage.quests.quest_defs) do
        if def.name == q.name then
            found_i = i
            break
        end
    end
    if found_i >= 1 then
        storage.quests.quest_defs[found_i] = nil
    end

    storage.quests.quest_ids_by_name[q.name] = nil
    storage.quests.quests[q.id] = nil

    -- Set prerequisite quests to unlock the removed quest's quests
    for _, unlock in pairs(q.unlocks or {}) do
        local _q = quests.get_quest(unlock)
        if _q then
            if not _q.prerequisites then
                _q.prerequisites = {}
            end

            for _, prereq in pairs(q.prerequisites or {}) do
                table.insert(_q.prerequisites, prereq)
            end
        end
    end

    -- Set unlockable quests to have the removed quest's prerequisite quests
    for _, prereq in pairs(q.prerequisites or {}) do
        local _q = quests.get_quest(prereq)
        if _q then
            if not _q.unlocks then
                _q.unlocks = {}
            end

            for _, unlock in pairs(q.unlocks or {}) do
                table.insert(_q.unlocks, unlock)
            end
        end
    end

    -- After unlocks and prereqs are reconnected, check for quest reveals.
    for _, prereq in pairs(q.prerequisites or {}) do
        local _q = quests.get_quest(prereq)
        if _q then
            quests.check_revelations(_q)
        end
    end

    if not next(q.prerequisites or {}) then
        quests.check_revelations(q)
    end

    event_system.trigger("quest-removed", q)

    return true
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

    quests.reveal_quest(q)
    quests.print_quest_completion(q)
    quests.give_rewards_of_quest(q)
    quests._mark_complete(q)

    for _, condition in pairs(q.conditions) do
        condition.progress = condition.progress_requirement
    end

    quests.check_revelations(q)
    event_system.trigger("quest-completed", q)
end

---Return a list of all types of quest condition-value pairs.  If a quest condition doesn't have a defined value, the string `"none"` is the placeholder value in the returned list.
---@return QuestConditionTypeValuePair[]
function quests.get_all_condition_types_and_values()
    local seen = {}
    local t = {}

    for _, quest in pairs(storage.quests.quests) do
        ---@cast quest Quest
        for _, condition in pairs(quest.conditions) do
            local condition_value_key = quests.get_condition_value_key(condition.value, condition.value_is_table)
            if not seen[condition.type] then
                seen[condition.type] = {}
            end
            if not seen[condition.type][condition_value_key] then
                table.insert(t, {condition.type, condition.value})
                seen[condition.type][condition_value_key] = true
            end
        end
    end

    return t
end

---Process a step of lightning acceleration, which helps players actually die to Fulgoran lightning for the "Electrocution" quest.
function quests.process_lightning_acceleration()
    local params = storage.quests.lightning_acceleration
    if not params then return end

    local player = params.player
    local character = player.character
    if not character or not character.valid then storage.quests.lightning_acceleration = nil return end

    local surface = character.surface
    if surface.name ~= "fulgora" then storage.quests.lightning_acceleration = nil return end

    -- The number of ticks that the animation waits before starting.
    local ANIMATION_DELAY = 300

    if game.tick == params.start_tick + 1 then
        game.print("\n\n\n\n")
        game.print(lib.color_localized_string({"hextorio.lightning-anim-1"}, "pink", "heading-1"))
    elseif game.tick == params.start_tick + ANIMATION_DELAY / 2 then
        game.print(lib.color_localized_string({"hextorio.lightning-anim-2"}, "red", "heading-1"))
    end

    local start_tick = params.start_tick + ANIMATION_DELAY
    if game.tick < start_tick then return end

    -- The number of ticks between each step of the electrocution animation.
    local ANIMATION_INTERVAL = 3

    -- (phase 1) The distance from the character at which lightning strikes around the player character.
    local ANIMATION_DISTANCE = 25

    -- (phase 1) The number of steps along the hexagonal side that the animation takes.
    local STEPS_PER_PHASE_1_EDGE = 12

    -- (phase 1) The number of steps during which the animation stays at the current vertex.
    local STEPS_PER_PHASE_1_VERTEX = 16

    -- (phase 1) The number of times lightning goes around in a hexagon pattern before proceeding to phase 2.
    local VERTEX_ROUNDS_PHASE_1 = 3

    -- (phase 2) The number of steps taken while closing into the player.
    local STEPS_CLOSING_IN_PHASE_2 = 48

    -- The total number of steps that a vertex round takes in phase 1.
    local TOTAL_STEPS_VERTEX_ROUND_PHASE_1 = STEPS_PER_PHASE_1_EDGE + STEPS_PER_PHASE_1_VERTEX

    -- The total number of steps that phase 1 uses.
    local TOTAL_STEPS_PHASE_1 = VERTEX_ROUNDS_PHASE_1 * TOTAL_STEPS_VERTEX_ROUND_PHASE_1

    -- The total number of steps that phase 2 uses.
    local TOTAL_STEPS_PHASE_2 = STEPS_CLOSING_IN_PHASE_2

    -- The number of ticks since the beginning of the acceleration process.
    local ticks_since_start = game.tick - start_tick

    -- The current "frame" of the electrocution animation.
    local anim_frame = ticks_since_start / ANIMATION_INTERVAL

    -- Skip the tick if not aligned with an animation frame.
    if math.floor(anim_frame) ~= anim_frame then return end

    local center_pos = character.position

    -- This can be cached for improved performance, but it may not be necessary as this animation occurs once per playthrough and does not last very long.
    local vertices = {} ---@type MapPosition[]
    local px = center_pos.x
    local py = center_pos.y
    for i = 1, 6 do
        local angle = i * math.pi / 3
        vertices[i] = {x = px + math.cos(angle) * ANIMATION_DISTANCE, y = py + math.sin(angle) * ANIMATION_DISTANCE}
    end

    if anim_frame < TOTAL_STEPS_PHASE_1 then
        -- This is PHASE 1: Lightning strikes around the player, forming a hexagon in its successive strike locations.
        local vertex_round_step = anim_frame % TOTAL_STEPS_VERTEX_ROUND_PHASE_1
        if vertex_round_step < STEPS_PER_PHASE_1_VERTEX then
            -- The lightning strikes are at hex vertices.
            for i = 1, 6 do
                surface.execute_lightning {
                    name = "lightning",
                    position = vertices[i],
                }
            end
        else
            -- The lightning strikes are between hex vertices.
            local t = (1 + vertex_round_step - STEPS_PER_PHASE_1_VERTEX) / (1 + STEPS_PER_PHASE_1_EDGE)
            for i = 1, 6 do
                local position = lib.lerp_positions(vertices[i], vertices[1 + i % 6], t)
                surface.execute_lightning {
                    name = "lightning",
                    position = position,
                }
            end
        end
    elseif anim_frame < TOTAL_STEPS_PHASE_1 + TOTAL_STEPS_PHASE_2 then
        -- This is PHASE 2: Lightning closes in for the kill.
        local t = (anim_frame - TOTAL_STEPS_PHASE_1) / TOTAL_STEPS_PHASE_2
        for i = 1, 6 do
            local position = lib.lerp_positions(vertices[i], center_pos, t)
            surface.execute_lightning {
                name = "lightning",
                position = position,
            }
        end
    else
        storage.quests.lightning_acceleration = nil
    end
end

function quests.recalculate_all_condition_progress()
    for _, condition_type_value_pair in pairs(quests.get_all_condition_types_and_values()) do
        quests.recalculate_condition_progress_of_type(condition_type_value_pair[1], condition_type_value_pair[2])
    end
end

---@param condition_type QuestConditionType
---@param condition_value QuestConditionValue|nil
function quests.recalculate_condition_progress_of_type(condition_type, condition_value)
    local func = quest_condition_progress_recalculators[condition_type]
    if not func then
        -- Log to be used when most conditions have recalculator functions
        -- lib.log("quests.recalculate_condition_progress_of_type: Attempted to recalculate progress for all quests of type " .. condition_type .. " with value " .. serpent.line(condition_value) .. " but found no recalculator function.")
        return
    end

    local progress = func(condition_value)
    quests.set_progress_for_type(condition_type, progress, condition_value)

    lib.log("quests.recalculate_condition_progress_of_type: Recalculated progress for all quests of type " .. condition_type .. " with value " .. serpent.line(condition_value or {}) .. ". New progress value: " .. progress)
end

---Redistribute all currently received quest rewards of a certain type.  Useful for save migration when data changes significantly.
---@param reward_type QuestRewardType
function quests.redistribute_quest_rewards(reward_type)
    if reward_type == "receive-items" then
        error("redistributing receive-items is not yet supported")
        return
    end

    for _, quest in pairs(storage.quests.quests) do
        if quests.is_complete(quest) then
            for _, reward in pairs(quest.rewards) do
                if reward.type == reward_type then
                    quests.give_reward(reward)
                end
            end
        end
    end
end

---@param entity_that_died LuaEntity
---@param entity_that_caused LuaEntity
---@param damage_type_prot LuaDamagePrototype|nil
function quests.on_entity_killed_entity(entity_that_died, entity_that_caused, damage_type_prot)
    quests.increment_progress_for_type("kill-entity", 1, entity_that_died.name)

    if damage_type_prot then
        if entity_that_caused.force.name == "player" then
            quests.increment_progress_for_type("kill-with-damage-type", 1, damage_type_prot.name)
        end
    end

    if entity_that_died.name == "biter-spawner" or entity_that_died.name == "spitter-spawner" then
        if entity_that_caused.name == "car" or entity_that_caused.name == "tank" then
            quests.increment_progress_for_type "biter-ramming"
        end
    end

    -- This is not in on_player_died because the damage type for cause of death is important.
    if entity_that_died.name == "character" then
        if damage_type_prot then
            quests.increment_progress_for_type("die-to-damage-type", 1, damage_type_prot.name)
        end

        if lib.table_index(lib.get_entity_ammo_categories(entity_that_caused), "railgun") then
            if entity_that_caused.force == game.forces.player then
                quests.increment_progress_for_type "die-to-railgun"
            end
        end
    end
end

---@param player LuaPlayer
function quests.on_player_respawned(player)
    if not storage.quests.deferred_rewards then storage.quests.deferred_rewards = {} end
    if not storage.quests.deferred_rewards[player.index] then return end

    for _, deferred_reward in pairs(storage.quests.deferred_rewards[player.index]) do
        local from_quest = quests.get_quest(deferred_reward.from_quest_name)
        if from_quest then
            quests.try_receive_items_reward(player, from_quest, deferred_reward.reward)
        else
            lib.log_error("quests.on_player_respawned: Failed to find quest for deferred reward for player=" .. player.name .. ", quest_name=" .. deferred_reward.from_quest_name)
        end
    end

    -- All rewards given (or supposed to be given anyway).
    -- Remove record of deferral.
    storage.quests.deferred_rewards[player.index] = nil
end

---@param character LuaEntity
function quests.on_lightning_struck_character(character)
    local player = character.player
    if not player then return end

    if not player.character or not player.character.valid or player.character.health == 0 then
        -- They died, but this isn't a trigger for entity-killed-entity, so handle the "died to electricity" thing separately here.
        quests.increment_progress_for_type("die-to-damage-type", 1, "electric")
        return
    end

    if quests.is_complete "electrocution" or not quests.is_revealed "electrocution" then return end
    if storage.quests.lightning_acceleration and storage.quests.lightning_acceleration.player == player then return end

    -- QoL to spam lightning strikes around players if the "Electrocution" quest is not yet complete.
    storage.quests.lightning_acceleration = {
        player = player,
        start_tick = game.tick,
    }
end



return quests
