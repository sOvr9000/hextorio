
local lib = require "api.lib"
local event_system = require "api.event_system"
local quests       = require "api.quests"



local item_ranks = {}



function item_ranks.register_events()
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
    event_system.register_callback("quests-reinitialized", function()
        quests.set_progress_for_type("total-item-rank", item_ranks.get_total_item_rank())
    end)
end

---Initialize a rank object for an item, failing if the item cannot have a rank.
---@param item_name string
---@return ItemRank|nil
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

---Get the rank of an item.
---@param item_name string
---@return int
function item_ranks.get_item_rank(item_name)
    if lib.is_coin(item_name) or not lib.is_item(item_name) then
        lib.log_error("item_ranks.get_item_rank: tried to get rank of coin or non-item: " .. item_name)
        return 0
    end
    local rank = item_ranks.get_rank_obj(item_name)
    if not rank then
        lib.log_error("item_ranks.get_item_rank: could not find rank object of item: " .. item_name)
        return 0
    end
    return rank.rank
end

---Get the rank object for an item if it exists.  An attempt to create a rank object will be made if it doesn't exist.
---@param item_name string
---@return ItemRank|nil
function item_ranks.get_rank_obj(item_name)
    local rank = storage.item_ranks.item_ranks[item_name]
    if not rank then
        rank = item_ranks.init_item(item_name)
    end
    return rank
end

---Return whether the item has a defined rank.
---@param item_name string
---@return boolean
function item_ranks.is_item_rank_defined(item_name)
    return storage.item_ranks.item_ranks[item_name] ~= nil
end

---Progress an item by some amount toward one of the rank tiers, and return how many ranks have been passed from this progress increment.
---@param item_name string
---@param toward_rank int
---@param amount int|nil
---@return int
function item_ranks.progress_item_rank(item_name, toward_rank, amount)
    if item_name:sub(-5) == "-coin" then
        return 0
    end
    local rank = item_ranks.get_rank_obj(item_name)
    if not rank then return 0 end
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

---Try to rank up a rank object by one tier, respecting progress requirements.
---@param rank ItemRank
function item_ranks._try_rank_up(rank)
    if rank.rank >= 5 then return end
    if rank.rank <= 0 then return end
    if rank.progress[rank.rank] < storage.item_ranks.rank_up_requirements[rank.rank] then return end
    if item_ranks.rank_up(rank.item_name) then
        item_ranks._try_rank_up(rank) -- go up to the highest rank achieved retroactively
    end
end

---Force rank up an item by one tier (bypass progress requirements), and return whether the rank was actually increased. Rank cannot go past the max tier.
---@param item_name string
---@return boolean
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

    lib.print_notification("item-ranked-up", {localization, "[item=" .. item_name .. "]", lib.get_rank_img_str(rank.rank)})
    event_system.trigger("item-rank-up", item_name)

    quests.increment_progress_for_type "total-item-rank"
    quests.increment_progress_for_type("items-at-rank-" .. rank.rank)

    return true
end

---Get the bonus effect from a rank tier.
---@param rank_tier int
---@return number
function item_ranks.get_rank_bonus_effect(rank_tier)
    if not rank_tier then
        lib.log_error("item_ranks.get_rank_bonus_effect: rank_tier is nil")
        return 0
    end
    if rank_tier == 1 then
        return 0.00
    elseif rank_tier == 2 then
        return 0.05
    elseif rank_tier == 3 then
        return 0.10
    elseif rank_tier == 4 then
        return 0.15
    elseif rank_tier == 5 then
        return 0.25
    end
    lib.log_error("item_ranks.get_rank_bonus_effect: rank_tier is out of range: " .. rank_tier)
    return 0
end

---Count the total number of stars in the item ranks.
---Bronze star rank has one star, and it is item rank 2, but it is only counted as one toward the total.
---@return int
function item_ranks.get_total_item_rank()
    local total = 0
    for _, rank in pairs(storage.item_ranks.item_ranks) do
        total = total + rank.rank - 1
    end
    return total
end

---Get a list of items that currently have a rank within the given range (inclusive).
---@param from_rank int|nil If not provided, it is assumed to be 1.
---@param to_rank int|nil If not provided, it is assumed to be the maximum possible rank.
---@return string[]
function item_ranks.get_items_at_rank(from_rank, to_rank)
    if not to_rank then to_rank = math.huge end
    if not from_rank then from_rank = 1 end

    local item_names = {}
    for item_name, rank_obj in pairs(storage.item_ranks.item_ranks) do
        if rank_obj.rank >= from_rank and rank_obj.rank <= to_rank then
            table.insert(item_names, item_name)
        end
    end

    return item_names
end



return item_ranks
