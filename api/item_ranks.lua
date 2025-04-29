
local lib = require "api.lib"
local event_system = require "api.event_system"

local item_ranks = {}



function item_ranks.init()
    event_system.register_callback("command-rank-up", function(player, params)
        if item_ranks.rank_up(params[1]) then
            event_system.trigger("post-rank-up-command", player, params)
        end
    end)
    event_system.register_callback("command-rank-up-all", function(player, params)
        for item_name, _ in pairs(storage.item_ranks.item_ranks) do
            item_ranks.rank_up(item_name)
        end
        event_system.trigger("post-rank-up-all-command", player, params)
    end)
end

function item_ranks.init_item(item_name)
    if lib.is_coin(item_name) or not lib.is_item(item_name) then
        lib.log_error("item_ranks.init_item: tried to define rank for coin or non-item: " .. item_name)
        return
    end
    local rank = {
        item_name = item_name,
        rank = 1,
        progress = {0, 0, 0, 0},
    }
    storage.item_ranks.item_ranks[item_name] = rank
    return rank
end

function item_ranks.get_item_rank(item_name)
    if lib.is_coin(item_name) or not lib.is_item(item_name) then
        lib.log_error("item_ranks.get_item_rank: tried to get rank of coin or non-item: " .. item_name)
        return 0
    end
    local rank = item_ranks.get_rank_obj(item_name)
    if not rank then return 0 end
    return rank.rank
end

function item_ranks.get_rank_obj(item_name)
    local rank = storage.item_ranks.item_ranks[item_name]
    if not rank then
        rank = item_ranks.init_item(item_name)
    end
    return rank
end

function item_ranks.is_item_rank_defined(item_name)
    return storage.item_ranks.item_ranks[item_name] ~= nil
end

-- Progress an item rank by some amount on one of the rank tiers.
-- Return how many ranks have been passed from this progress increment.
function item_ranks.progress_item_rank(item_name, toward_rank, amount)
    if item_name:sub(-5) == "-coin" then
        return 0
    end
    local rank = item_ranks.get_rank_obj(item_name)
    if not rank then return end
    if toward_rank < 2 or toward_rank > 4 then
        lib.log_error("item_ranks.progress_item_rank: toward_rank is out of range")
        return 0
    end
    amount = amount or 1
    rank.progress[toward_rank - 1] = math.max(0, math.min(storage.item_ranks.rank_up_requirements[toward_rank - 1], rank.progress[toward_rank - 1] + amount))
    local old_rank = rank.rank
    item_ranks._try_rank_up(rank)
    return rank.rank - old_rank
end

function item_ranks._try_rank_up(rank)
    if rank.rank >= 5 then return end
    if rank.rank <= 0 then return end
    if rank.progress[rank.rank] < storage.item_ranks.rank_up_requirements[rank.rank] then return end
    if item_ranks.rank_up(rank.item_name) then
        item_ranks._try_rank_up(rank) -- go up to the highest rank achieved retroactively
    end
end

-- Force rank up an item by one tier (bypass progress requirements). Return whether the rank was actually increased. Rank cannot go past the max tier.
function item_ranks.rank_up(item_name)
    local rank = item_ranks.get_rank_obj(item_name)
    if not rank then return false end
    if rank.rank >= 5 then return false end
    if rank.rank <= 0 then return false end

    rank.rank = rank.rank + 1

    local localization = "hextorio.item-rank-up"
    if rank.rank == 5 then
        localization = "hextorio.item-rank-up-max"
    end

    game.print({localization, "[item=" .. item_name .. "]", lib.get_rank_img_str(rank.rank)})

    event_system.trigger("item-rank-up", item_name)

    return true
end

function item_ranks.get_rank_bonus_effect(rank_tier)
    if rank_tier == 1 then
        return 0.0
    elseif rank_tier == 2 then
        return 0.1
    elseif rank_tier == 3 then
        return 0.2
    elseif rank_tier == 4 then
        return 0.3
    elseif rank_tier == 5 then
        return 0.5
    end
end



return item_ranks
