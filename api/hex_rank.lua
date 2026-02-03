
local lib = require "api.lib"
local sets = require "api.sets"
local event_system = require "api.event_system"
local gameplay_statistics = require "api.gameplay_statistics"

local INV_LOG10 = 0.43429448190325182765112891891661 -- e^(1/INV_LOG10) = 10

local hex_rank = {}



---@alias HexRankFactorMetadataMap {[GameplayStatisticType]: HexRankFactorMetadata}

---@class HexRankStorage
---@field hex_rank int The current global hex rank
---@field scale number Overall multiplier to the calculation of total hex rank
---@field factor_metadata HexRankFactorMetadataMap Mapping of statistics types that go into computing hex rank to their metadata
---@field factor_term_cache {[GameplayStatisticType]: number} Mapping of statistics types to the amount contributed to the total hex rank

---@class HexRankFactorMetadata
---@field goal_term number|nil The amount of contribution needed to fill the corresponding progress bar completely in the hex rank GUI. Required if goal_stat is not defined.
---@field goal_stat number|nil The value of the statistic needed to fill the corresponding progress bar completely in the hex rank GUI. Required if goal_stat is not defined.
---@field coefficient number Multiplier to the contribution that this factor has towards total hex rank.



function hex_rank.init()
    local total_quests
    if storage.quests and storage.quests.quest_defs then
        total_quests = lib.table_length(storage.quests.quest_defs)
    else
        total_quests = 50 -- heuristic if hex_rank.init() is somehow ran before control on_init is
        lib.log_error("hex_rank.init: Quest data not yet set")
    end

    local total_techs = lib.table_length(game.forces.player.technologies)

    local total_items
    if storage.coin_tiers and storage.coin_tiers.COIN_TIERS_BY_NAME then
        -- TODO: to better support modded items, either check if an item has a defined value here or actually define modded item values so that it's safe to assume that any item has a value (which makes it possible to rank them up)
        total_items = 0
        for item_name, _ in pairs(prototypes.item) do
            if lib.is_catalog_item(item_name) then
                total_items = total_items + 1
            end
        end
    else
        total_items = 200 -- heuristic if hex_rank.init() is somehow ran before control on_init is
        lib.log_error("hex_rank.init: Coin tiers data not yet set")
    end

    -- These factors aren't necessarily a 1:1 copy of all possible gameplay statistics types; instead, this is just a list of the ones that go into computing hex rank
    ---@type HexRankFactorMetadataMap
    local factors = {
        ["total-hexes-claimed"] = {
            goal_term = 3.5,
            coefficient = 1,
        },
        ["total-quests-completed"] = {
            goal_stat = total_quests,
            coefficient = 2,
        },
        ["total-strongbox-level"] = {
            goal_term = 2.5,
            coefficient = 1,
        },
        ["net-coin-production"] = {
            goal_term = 11,
            coefficient = 1,
        },
        ["total-spawners-killed"] = {
            goal_term = 3.1,
            coefficient = 2.1,
        },
        ["tech-tree-completion"] = {
            goal_stat = total_techs,
            coefficient = 2,
        },
        ["total-unique-items-traded"] = {
            goal_stat = total_items * 5, -- once for each item on each planet
            coefficient = 3,
        },
        ["total-resources-depleted"] = {
            goal_term = 4,
            coefficient = 1,
        },
        ["total-dungeons-looted"] = {
            goal_term = 2,
            coefficient = 2.7,
        },
        ["total-item-buff-level"] = {
            goal_term = 2.4,
            coefficient = 1,
        },
        ["total-item-rank"] = {
            goal_stat = total_items * 4,
            coefficient = 1.2,
        },
        ["fastest-ship-speed"] = {
            goal_stat = 550,
            coefficient = 2,
        },
        ["science-per-hour"] = {
            goal_term = 4.4,
            coefficient = 3,
        },
        ["total-rockets-launched"] = {
            goal_term = 4,
            coefficient = 2,
        },
    }

    hex_rank.init_factors(factors)

    ---@type HexRankStorage
    storage.hex_rank = {
        hex_rank = 0,
        scale = 30,
        factor_metadata = factors,
        factor_term_cache = {},
    }
end

function hex_rank.register_events()
    event_system.register("hex-rank-factor-changed", hex_rank.recalculate_hex_rank)
    event_system.register("gameplay-statistic-changed", hex_rank.on_gameplay_statistic_changed)

    event_system.register("entity-killed-entity", hex_rank.on_entity_killed_entity)
end

---Set up the factor metadata for runtime. Modifies the table in place.
---@param factors HexRankFactorMetadataMap
function hex_rank.init_factors(factors)
    for key, metadata in pairs(factors) do
        if metadata.goal_term then
            metadata.goal_stat = math.floor(0.5 + 10 ^ metadata.goal_term)
        end
        if not metadata.goal_stat then
            lib.log_error("hex_rank.init_factors: HexRankFactorMetadata is missing either goal_stat or goal_term for gameplay statistic " .. key)
        end
    end
end

---Get the current hex rank/level.
---@return int
function hex_rank.get_current_hex_rank()
    if not storage.hex_rank then return 0 end
    if not storage.hex_rank.hex_rank then return 0 end
    return storage.hex_rank.hex_rank
end

---Set the current hex rank/level.
---@param val number
function hex_rank.set_current_hex_rank(val)
    if not storage.hex_rank then
        hex_rank.init()
    end

    if val < 0 then
        lib.log_error("hex_rank.set_current_hex_rank: Hex rank is negative")
        val = 0
    end

    local prev = storage.hex_rank.hex_rank
    local new = math.floor(0.5 + val)
    if prev == new then return end

    storage.hex_rank.hex_rank = new
    event_system.trigger("hex-rank-changed", prev, new)
end

---Freshly calculate the total hex rank by summing up all factors again.
function hex_rank.recalculate_hex_rank()
    local factors = (storage.hex_rank or {}).factor_metadata
    if not factors then
        hex_rank.init()
        factors = storage.hex_rank.factor_metadata
    end

    local scale = storage.hex_rank.scale
    local factor_term_cache = storage.hex_rank.factor_term_cache

    local total = 0
    for key, metadata in pairs(factors) do
        local stat = gameplay_statistics.get(key)
        local coefficient = metadata.coefficient or 1
        local term = math.log(stat + 1) * INV_LOG10 * coefficient
        total = total + term

        factor_term_cache[key] = term
    end

    -- Overall multiplier
    total = total * scale

    hex_rank.set_current_hex_rank(total)
end

---Get the last computed result of how much a gameplay statistics factor contributed to hex rank.
---@param stat GameplayStatisticType
---@return number term How much "hex rank" was contributed by `stat`.
function hex_rank.get_factor_term_cache(stat)
    if not storage.hex_rank then
        hex_rank.init()
    end

    return storage.hex_rank.factor_term_cache[stat] or 0
end

---Get the progress ratio for a given factor (0 to 1+, where 1 = goal achieved).
---@param stat GameplayStatisticType
---@return number progress The ratio of current progress to goal (independent of coefficient).
function hex_rank.get_factor_progress(stat)
    local goal_stat = (((storage.hex_rank or {}).factor_metadata or {})[stat] or {}).goal_stat or 1000000
    local current_stat = gameplay_statistics.get(stat)

    local raw_term = math.log(current_stat + 1) * INV_LOG10
    local goal_term = math.log(goal_stat + 1) * INV_LOG10

    local progress = raw_term / goal_term
    progress = progress * progress * progress

    return progress
end

---Get the current and goal amount of progress on hex rank statistics.  These are direct measures of the gameplay statistics instead of hex rank calculations.
---@param stat GameplayStatisticType
---@return int, int completion A tuple containing the (1) current statistic value and (2) the goal set for the given statistic type.
function hex_rank.get_hex_rank_completion(stat)
    local goal = (((storage.hex_rank or {}).factor_metadata or {})[stat] or {}).goal_stat or 1000000
    return gameplay_statistics.get(stat), goal
end

---Get the overall scaling of hex rank calculation.
---@return number
function hex_rank.get_overall_scale()
    return (storage.hex_rank or {}).scale or 1
end

---@param stat_type GameplayStatisticType
---@param prev_value int
---@param new_value int
function hex_rank.on_gameplay_statistic_changed(stat_type, prev_value, new_value)
    local factors = (storage.hex_rank or {}).factor_metadata
    if not factors then
        hex_rank.init()
        factors = storage.hex_rank.factor_metadata
    end

    if factors[stat_type] then
        hex_rank.recalculate_hex_rank()
    end
end



return hex_rank
