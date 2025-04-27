local lib = require "api.lib"
local event_system = require "api.event_system"

local quests = {}



function quests.new_quest(params)
    -- if not params.type then
    --     lib.log_error("quests.new_quest: Quest must have a type")
    --     return
    -- end
    if not params.name then
        lib.log_error("quests.new_quest: Quest must have a name")
        return
    end
    local quest = {
        -- type = params.type,
        name = params.name,
        conditions = {},
        rewards = {},
    }

    for _, condition in pairs(params.conditions or {}) do
        table.insert(quest.conditions, condition)
    end

    for _, reward in pairs(params.rewards or {}) do
        table.insert(quest.rewards, reward)
    end

    return quest
end

function quests.new_condition(params)
    if not params.type then
        lib.log_error("Condition must have a type")
        return
    end
    if params.type ~= "kill" then

    end
    local condition = {
        type = params.type,
        values = params.values or {},
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
        values = params.values or {},
    }
    return reward
end

function quests.is_condition_satisfied(condition, info)
    
end

function quests.claim_reward(reward, info)

end



return quests
