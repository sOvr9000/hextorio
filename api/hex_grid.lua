
local lib = require "api.lib"
local sets = require "api.sets"
local axial = require "api.axial"
local hex_island = require "api.hex_island"
local event_system = require "api.event_system"
local terrain = require "api.terrain"
local trade_loop_finder = require "api.trade_loop_finder"
local hex_state_manager = require "api.hex_state_manager"
local weighted_choice = require "api.weighted_choice"
local item_values = require "api.item_values"
local coin_tiers = require "api.coin_tiers"
local quests = require "api.quests"
local trades = require "api.trades"
local item_ranks  = require "api.item_ranks"
local dungeons = require "api.dungeons"
local inventories = require "api.inventories"
local strongboxes = require "api.strongboxes"
local entity_util = require "api.entity_util"
local piggy_bank  = require "api.piggy_bank"
local gameplay_statistics = require "api.gameplay_statistics"
local hex_util            = require "api.hex_util"
local hex_sets            = require "api.hex_sets"



local allowed_surfaces = sets.new {
    "nauvis",
    "vulcanus",
    "fulgora",
    "gleba",
    "aquilo",
}



local hex_grid = {}



function hex_grid.register_events()
    event_system.register("runtime-setting-changed-trade-flying-text", function(player_index)
        local player = game.get_player(player_index)
        if not player then return end

        storage.hex_grid.show_trade_flying_text[player_index] = lib.player_setting_value(player, "trade-flying-text")
    end)

    event_system.register("item-rank-up", function(item_name)
        local rank = item_ranks.get_item_rank(item_name)
        if rank == 2 then
            hex_grid.apply_extra_trades_bonus_retro(item_name)
        elseif rank == 3 then
            for surface_name, _ in pairs(storage.item_values.values) do
                for _, hex_pos in pairs(trades.get_interplanetary_trade_locations_for_item(surface_name, item_name)) do
                    hex_grid.apply_interplanetary_trade_bonus_retro(surface_name, item_name, hex_pos)
                end
            end
        elseif rank == 4 then
            hex_grid.recover_trades_retro(item_name)
        end
        trades.queue_productivity_update_job()
    end)

    event_system.register("command-add-trade", function(player, params)
        local hex_core = player.selected
        if not hex_core then
            player.print {"hextorio.command-mouse-over-hex-core"}
            return
        end

        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end

        local inputs = params[1]
        if type(inputs) == "string" then
            inputs = {inputs}
        elseif type(inputs) ~= "table" then
            player.print {"hextorio.command-invalid-item-name", inputs}
            return
        end

        if #inputs > 3 or #inputs == 0 then
            player.print {"hextorio.command-invalid-list-size", 1, 1, 3, #inputs}
            return
        end

        local outputs = params[2]
        if type(outputs) == "string" then
            outputs = {outputs}
        elseif type(outputs) ~= "table" then
            player.print {"hextorio.command-invalid-item-name", outputs}
            return
        end

        if #outputs > 3 or #outputs == 0 then
            player.print {"hextorio.command-invalid-list-size", 2, 1, 3, #outputs}
            return
        end

        for _, item_name in pairs(inputs) do
            if type(item_name) ~= "string" or not prototypes.item[item_name] then
                player.print {"hextorio.command-invalid-item-name", item_name}
                return
            end
        end

        for _, item_name in pairs(outputs) do
            if type(item_name) ~= "string" or not prototypes.item[item_name] then
                player.print {"hextorio.command-invalid-item-name", item_name}
                return
            end
        end

        local trade = trades.from_item_names(hex_core.surface.name, params[1], params[2], {target_efficiency = storage.trades.base_trade_efficiency, allow_nil_return = false})
        ---@cast trade Trade

        -- if not trade then
        --     player.print {"hextorio.command-trade-generation-failed"}
        --     return
        -- end

        hex_grid.add_trade(state, trade)
    end)

    event_system.register("command-remove-trade", function(player, params)
        local hex_core = player.selected
        if not hex_core then return end
        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end
        local idx = params[1]
        if idx <= 0 or idx > #state.trades then
            player.print("Failed to remove trade at index " .. idx)
            return
        end
        local trade = trades.get_trade_from_id(state.trades[idx])
        if not trade then return end

        player.print("Removed trade: " .. lib.get_trade_img_str(trade, trades.is_interplanetary_trade(trade)))
        hex_grid.remove_trade_by_index(state, idx, false)
    end)

    event_system.register("command-regenerate-trades", function(player, params)
        gameplay_statistics.set("trades-found", 0)
        storage.trades.recoverable = {}
        storage.trades.discovered_items = {}
        storage.trades.interplanetary_trade_locations = {}

        for surface_name, _ in pairs(storage.hex_grid.surface_hexes) do
            for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
                if state.trades then
                    for i = #state.trades, 1, -1 do
                        -- local trade_id = state.trades[i]
                        -- local trade = trades.get_trade_from_id(trade_id)
                        -- if trade then
                        --     trades.remove_trade_from_tree(trade, false)
                        -- end
                        hex_grid.remove_trade_by_index(state, i, false)
                    end
                end
            end
        end

        local ip_trades_per_item = lib.runtime_setting_value "rank-3-effect" --[[@as int]]
        for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
            local surface = game.get_surface(surface_id)
            if surface then
                trades.generate_interplanetary_trade_locations(surface.name, ip_trades_per_item)

                for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_id)) do
                    if state.hex_core then
                        hex_grid.add_initial_trades(state)
                    end
                end
            else
                lib.log_error("command /regenerate-trades: Could not find surface")
            end
        end
    end)

    event_system.register("command-hextorio-debug", function(player, params)
        hex_grid.claim_hexes_range(player.surface.name, {q = 0, r = 0}, 1, nil, true) -- claim by server
    end)

    event_system.register("command-claim", function(player, params)
        if params[1] then
            if params[1] > 2 then
                player.print("The claim range is too large!")
                return
            end
            if params[1] < 0 then
                player.print("The claim range must be nonnegative.")
                return
            end
        end
        local transformation = terrain.get_surface_transformation(player.surface)
        if not transformation then return end
        local hex_pos = axial.get_hex_containing(player.position, transformation.scale, transformation.rotation)
        hex_grid.claim_hexes_range(player.surface.name, hex_pos, params[1] or 0, nil, false) -- claim by server
    end)

    event_system.register("command-force-claim", function(player, params)
        if params[1] then
            if params[1] > 2 then
                player.print("The claim range is too large!")
                return
            end
            if params[1] < 0 then
                player.print("The claim range must be nonnegative.")
                return
            end
        end
        local transformation = terrain.get_surface_transformation(player.surface)
        if not transformation then return end
        local hex_pos = axial.get_hex_containing(player.position, transformation.scale, transformation.rotation)
        hex_grid.claim_hexes_range(player.surface.name, hex_pos, params[1] or 0, nil, true) -- claim by server
    end)


    event_system.register("command-tp-to-edge", function(player, params)
        local island_extent = hex_island.get_island_extent(player.surface.name)
        local edge_pos = {q = island_extent, r = 0}
        local transformation = terrain.get_surface_transformation(player.surface)
        local center = axial.get_hex_center(edge_pos, transformation.scale, transformation.rotation)
        player.teleport(center)
    end)

    event_system.register("quest-reward-received", function(reward_type, value)
        if reward_type == "unlock-feature" then
            if value == "catalog" then
                local all_trades = {}
                for surface_name, _ in pairs(storage.hex_grid.surface_hexes) do
                    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
                        if state.trades then
                            for _, trade_id in pairs(state.trades) do
                                table.insert(all_trades, trades.get_trade_from_id(trade_id))
                            end
                        end
                    end
                end
                trades.discover_items_in_trades(all_trades)
            -- elseif value == "hexports" then
            --     for surface_name, _ in pairs(storage.hex_grid.surface_hexes) do
            --         for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
            --             if state.claimed then
            --                 hex_grid.spawn_hexport(state, true)
            --             end
            --         end
            --     end
            end
        elseif reward_type == "claim-free-hexes" then
            hex_grid.add_free_hex_claims(value[1], value[2])
        elseif reward_type == "reduce-biters" then
            hex_grid.reduce_biters(value * 0.01)
        elseif reward_type == "all-trades-productivity" then
            trades.increment_base_trade_productivity(value * 0.01)
            trades.queue_productivity_update_job()
        end
    end)

    event_system.register("quests-reinitialized", function(reward_type, value)
        -- Recalculate all trade finds
        local trades_found = 0
        local claimed_hexes = 0
        for _, surface in pairs(game.surfaces) do
            for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface.name)) do
                if state.trades then
                    trades_found = trades_found + #state.trades
                end
                if state.claimed then
                    claimed_hexes = claimed_hexes + 1
                end
            end
        end
        gameplay_statistics.set("trades-found", trades_found)
        gameplay_statistics.set("total-hexes-claimed", claimed_hexes)
    end)

    event_system.register("interplanetary-trade-generated", function(surface_name, item_name, hex_pos)
        hex_grid.apply_interplanetary_trade_bonus_retro(surface_name, item_name, hex_pos)
    end)

    event_system.register("dungeon-looted", function(dungeon)
        for _, tile in pairs(dungeon.maze.tiles) do
            local hex_pos = tile.pos
            local state = hex_state_manager.get_hex_state(dungeon.surface.index, hex_pos)
            if state then
                state.is_dungeon = nil
                state.was_dungeon = true
                hex_grid.add_hex_to_claim_queue(dungeon.surface.index, hex_pos, nil, true, false)
            end
        end
    end)

    event_system.register("entity-died", function(entity)
        if entity.name:sub(1, 15) ~= "strongbox-tier-" then return end
        hex_grid.on_strongbox_killed(entity)
    end)

    event_system.register("runtime-setting-changed-hex-claim-cost-mult-nauvis", function()
        hex_grid.fetch_claim_cost_multiplier_settings "nauvis"
        hex_grid.update_all_hex_claim_costs "nauvis"
    end)

    event_system.register("runtime-setting-changed-hex-claim-cost-mult-vulcanus", function()
        hex_grid.fetch_claim_cost_multiplier_settings "vulcanus"
        hex_grid.update_all_hex_claim_costs "vulcanus"
    end)

    event_system.register("runtime-setting-changed-hex-claim-cost-mult-fulgora", function()
        hex_grid.fetch_claim_cost_multiplier_settings "fulgora"
        hex_grid.update_all_hex_claim_costs "fulgora"
    end)

    event_system.register("runtime-setting-changed-hex-claim-cost-mult-gleba", function()
        hex_grid.fetch_claim_cost_multiplier_settings "gleba"
        hex_grid.update_all_hex_claim_costs "gleba"
    end)

    event_system.register("runtime-setting-changed-hex-claim-cost-mult-aquilo", function()
        hex_grid.fetch_claim_cost_multiplier_settings "aquilo"
        hex_grid.update_all_hex_claim_costs "aquilo"
    end)

    event_system.register("runtime-setting-changed-default-nauvis-hexlight-color", function()
        hex_grid.update_hexlight_default_colors "nauvis"
    end)

    event_system.register("runtime-setting-changed-default-vulcanus-hexlight-color", function()
        hex_grid.update_hexlight_default_colors "vulcanus"
    end)

    event_system.register("runtime-setting-changed-default-fulgora-hexlight-color", function()
        hex_grid.update_hexlight_default_colors "fulgora"
    end)

    event_system.register("runtime-setting-changed-default-gleba-hexlight-color", function()
        hex_grid.update_hexlight_default_colors "gleba"
    end)

    event_system.register("runtime-setting-changed-default-aquilo-hexlight-color", function()
        hex_grid.update_hexlight_default_colors "aquilo"
    end)

    event_system.register("runtime-setting-changed-dungeon-hexlight-color", function()
        hex_grid.update_hexlight_default_colors()
    end)

    event_system.register("runtime-setting-changed-hex-pool-size", function()
        local size = lib.runtime_setting_value_as_int "hex-pool-size"
        hex_grid.set_pool_size(size)
    end)

    event_system.register("train-arrived-at-stop", hex_grid.on_train_arrived_at_stop)
    event_system.register("entity-built", hex_grid.on_entity_built)
    event_system.register("runtime-setting-changed-unresearched-penalty", hex_grid.on_setting_changed_unresearched_penalty)
    event_system.register("player-rotated-entity", hex_grid.on_player_rotated_entity)
    event_system.register("hex-island-generated", hex_grid.on_hex_island_generated)
end

---Get the state of a hex from a hex core entity
---@param hex_core LuaEntity
---@return HexState|nil
function hex_grid.get_hex_state_from_core(hex_core)
    if not hex_core or not hex_core.valid then return end

    local transformation = terrain.get_surface_transformation(hex_core.surface.name)
    if not transformation then
        lib.log_error("hex_grid.get_hex_state_from_core: No transformation found for surface " .. serpent.line(hex_core.surface.name))
        return
    end

    local hex_pos = axial.get_hex_containing(hex_core.position, transformation.scale, transformation.rotation)
    local state = hex_state_manager.get_hex_state(hex_core.surface.index, hex_pos)
    if not state then return end

    if state.hex_core ~= hex_core then
        lib.log_error("hex_grid.get_hex_state_from_core: hex core entities do not match")
        lib.log_error(state.hex_core)
        lib.log_error(hex_core)
    end

    return state
end

---Attempt to generate a random trade for the given hex core state, but don't add it if successful.
---This is intended as a wrapper for `trades.random()` with added restrictions to prevent simple single-core trade loops from being generated.
---@param hex_core_state HexState
---@param volume number
---@param is_interplanetary boolean|nil
---@param include_item string|nil
---@return Trade|nil
function hex_grid.generate_random_trade(hex_core_state, volume, is_interplanetary, include_item)
    if not hex_core_state then
        lib.log_error("hex_grid.generate_random_trade: hex core state is nil")
        return
    end
    if not hex_core_state.hex_core then
        lib.log_error("hex_grid.generate_random_trade: hex core state has no hex core")
        return
    end
    if not hex_core_state.trades then
        lib.log_error("hex_grid.generate_random_trade: hex core state has no trades")
        return
    end

    local cur_trades = trades.convert_trade_id_array_to_trade_array(hex_core_state.trades)
    local idx = #cur_trades + 1

    local attempts = 10
    for _ = 1, attempts do
        local params = {target_efficiency = storage.trades.base_trade_efficiency}
        local trade = trades.random(hex_core_state.hex_core.surface.name, volume, params, is_interplanetary, include_item)
        if trade then
            cur_trades[idx] = trade -- Overwrite previously generated trades if they failed.
            local loops = trade_loop_finder.find_simple_loops(cur_trades)

            -- This can more efficiently be something like "trade_loop_finder.has_simple_loop()", but I don't know how to properly implement generator functions (like from Python) in Lua,
            -- which is what would be ideal to avoid copying and pasting 20-30 lines of code in the case of implementing that function.
            if not next(loops) then
                return trade
            end
        end
    end

    -- Failed to generate trade. Return nil.
    lib.log_error("hex_grid.generate_random_trade: A trade failed to generate within " .. attempts .. " attempts.")
end

---Add a trade to a hex core.
---@param hex_core_state HexState
---@param trade Trade
function hex_grid.add_trade(hex_core_state, trade)
    if not hex_core_state then
        lib.log_error("hex_grid.add_trade: hex core state is nil")
        return
    end
    local hex_core = hex_core_state.hex_core
    if not hex_core then
        lib.log_error("hex_grid.add_trade: hex core is nil in hex core state")
        return
    end

    if not hex_core_state.trades then
        hex_core_state.trades = {}
    end

    trade.hex_core_state = hex_core_state
    table.insert(hex_core_state.trades, trade.id)

    trades.add_trade_to_tree(trade)

    if hex_core_state.hex_core_input_inventory and hex_core_state.hex_core_input_inventory.valid and hex_core_state.hex_core_input_inventory.is_empty() then
        hex_grid.update_hex_core_inventory_filters(hex_core_state)
    end

    hex_grid.set_trade_allowed_qualities(hex_core, trade)

    if hex_core_state.claimed then
        trades.discover_items_in_trades {trade}
    end

    if not hex_core_state.is_dungeon then
        gameplay_statistics.increment "trades-found"
    end
end

function hex_grid.remove_trade_by_index(hex_core_state, idx, recoverable)
    if recoverable == nil then recoverable = true end
    if not hex_core_state then
        lib.log_error("hex_grid.remove_trade_by_index: nil hex core state")
        return
    end
    if idx <= 0 or idx > #hex_core_state.trades then
        lib.log_error("hex_grid.remove_trade_by_index: invalid index " .. idx)
        return
    end

    local trade_id = table.remove(hex_core_state.trades, idx)
    if type(trade_id) ~= "number" then return end -- migration from 0.2.3 saves

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    trades.remove_trade_from_tree(trade, recoverable)
end

---Add items to a hex core's unloader filters, only filling in some or all of the remaining empty filters.
---Return whether there were enough empty filters available for the given item names.
---@param state HexState
---@param output_item_names string[]
---@return boolean
function hex_grid.add_items_to_unloader_filters(state, output_item_names)
    output_item_names = table.deepcopy(output_item_names)

    local has_coins = false
    for i = #output_item_names, 1, -1 do
        if lib.is_coin(output_item_names[i]) then
            table.remove(output_item_names, i)
            has_coins = true
        end
    end

    if has_coins then
        table.insert(output_item_names, 1, "hex-coin")
        table.insert(output_item_names, 2, "gravity-coin")
        table.insert(output_item_names, 3, "meteor-coin")
        table.insert(output_item_names, 4, "hexaprism-coin")
    end

    local item_name_idx = 1
    for _, unloader in pairs(state.output_loaders or {}) do
        ---@cast unloader LuaEntity
        for n = 1, 2 do
            if not unloader.get_filter(n) then
                unloader.set_filter(n, output_item_names[item_name_idx])
                item_name_idx = item_name_idx + 1
                if item_name_idx > #output_item_names then
                    return true
                end
            end
        end
    end

    return false
end

function hex_grid.apply_extra_trade_bonus(state, item_name, volume)
    if state.mode == "sink" or state.mode == "generator" then return end
    if not state.hex_core or not state.hex_core.valid then return end
    if item_values.is_item_interplanetary(state.hex_core.surface.name, item_name) then return end
    if math.random() > storage.item_ranks.bronze_rank_bonus_effect then return end

    local trade = hex_grid.generate_random_trade(state, volume, false, item_name)
    if not trade then
        lib.log_error("hex_grid.apply_extra_trade_bonus: failed to get random trade item name from volume = " .. volume)
        return
    end

    hex_grid.add_trade(state, trade)
    return trade
end

function hex_grid.apply_extra_trades_bonus(state)
    if not state or not state.hex_core or not state.trades then return end
    local surface = state.hex_core.surface
    if lib.is_space_platform(surface) then return end
    local surface_values = item_values.get_item_values_for_surface(surface.name)
    if not surface_values then return end

    local added_trades = {}
    local item_names_set = sets.new(sets.to_array(surface_values))
    local silver_items = sets.new(item_ranks.get_items_at_rank(3))
    item_names_set = sets.union(item_names_set, silver_items)

    for item_name, _ in pairs(item_names_set) do
        if lib.is_catalog_item(item_name) then -- prevent defining an item rank for something that shouldn't have a rank
            local rank = item_ranks.get_item_rank(item_name)
            if rank >= 2 then
                local trade = hex_grid.apply_extra_trade_bonus(state, item_name, item_values.get_item_value(surface.name, item_name))
                if trade then -- "if" check isn't necessary, technically
                    added_trades[item_name] = trade
                end
            end
        end
    end

    local chunk_pos = lib.get_chunk_pos_from_tile_position(state.hex_core.position)
    if next(added_trades) and game.forces.player.is_chunk_charted(state.hex_core.surface, chunk_pos) then
        for item_name, trade in pairs(added_trades) do
            lib.print_notification("extra-trade", {"",
                lib.color_localized_string(
                    {"hextorio.bonus-trade", "[img=item." .. item_name .. "]"},
                    "yellow", "heading-1"
                ),
                " ",
                lib.get_gps_str_from_hex_core(state.hex_core),
                " ",
                lib.get_trade_img_str(trade, trades.is_interplanetary_trade(trade))
            })
        end
    end
end

---Set the mode of a hex core. Return whether the mode was successfully changed.
---@param state HexState
---@param mode HexCoreMode
---@return boolean
function hex_grid.switch_hex_core_mode(state, mode)
    if not mode then
        lib.log_error("hex_grid.switch_hex_core_mode: Tried to set mode to nil")
        return false
    end
    if not state or not state.trades or state.mode then return false end

    local list, reverse
    if mode == "generator" then
        list = "output_items"
        reverse = true
    elseif mode == "sink" then
        list = "input_items"
        reverse = false
    else
        lib.log_error("hex_grid.switch_hex_core_mode: Unrecognized mode: " .. mode)
        return false
    end

    local all_item_names = sets.new()
    for i = #state.trades, 1, -1 do
        for _, item in pairs(trades.get_trade_from_id(state.trades[i])[list]) do
            if not lib.is_coin(item.name) then
                sets.add(all_item_names, item.name)
            end
        end
        hex_grid.remove_trade_by_index(state, i, false)
    end

    for item_name, _ in pairs(all_item_names) do
        local input_names, output_names
        if reverse then
            input_names = {"hex-coin"}
            output_names = {item_name}
        else
            input_names = {item_name}
            output_names = {"hex-coin"}
        end

        local params = {target_efficiency = storage.trades.base_trade_efficiency * 0.1, allow_nil_return = false}
        local trade = trades.from_item_names(state.hex_core.surface.name, input_names, output_names, params)
        ---@cast trade Trade
        -- trade cannot be nil because params.allow_nil_return = false

        hex_grid.add_trade(state, trade)
    end

    if state.mode then
        gameplay_statistics.increment("hex-cores-in-mode", -1, state.mode)
    end
    gameplay_statistics.increment("hex-cores-in-mode", 1, mode)

    state.mode = mode
    return true
end

---Get a hex core state's current mode.
---@param state HexState
---@return HexCoreMode
function hex_grid.get_hex_core_mode(state)
    if not state.mode then return "normal" end
    return state.mode
end

---Set a trade's minimum and maximum allowed qualities. Return whether the trade's resulting quality bounds reflect exactly what was provided to this function.
---Return true if no qualities were automatically excluded due to hex core quality or currently unlocked qualities.
---@param hex_core LuaEntity
---@param trade Trade
---@param min_quality string|nil If not provided, defaults to the lowest quality (normal).
---@param max_quality string|nil If not provided, defaults to min_quality.
---@return boolean
function hex_grid.set_trade_allowed_qualities(hex_core, trade, min_quality, max_quality)
    if not min_quality then
        min_quality = lib.get_lowest_quality().name
    end

    if not max_quality then
        max_quality = min_quality
    end

    local min_quality_tier = lib.get_quality_tier(min_quality)
    local max_quality_tier = lib.get_quality_tier(max_quality)

    if min_quality_tier > max_quality_tier then
        min_quality_tier, max_quality_tier = max_quality_tier, min_quality_tier
        min_quality, max_quality = max_quality, min_quality
    end

    local hex_quality_tier = lib.get_quality_tier(hex_core.quality.name)
    local highest_quality_tier = lib.get_quality_tier(lib.get_highest_unlocked_quality().name)

    local adjusted = max_quality_tier > math.min(hex_quality_tier, highest_quality_tier)
    min_quality_tier = math.min(min_quality_tier, highest_quality_tier, hex_quality_tier)
    max_quality_tier = math.min(max_quality_tier, highest_quality_tier, hex_quality_tier)

    trade.allowed_qualities = {}
    for tier = max_quality_tier, min_quality_tier, -1 do
        table.insert(trade.allowed_qualities, lib.get_quality_at_tier(tier))
    end

    return not adjusted
end

function hex_grid.update_hex_core_inventory_filters(hex_core_state)
    local inventory = hex_core_state.hex_core_input_inventory
    if not inventory or not inventory.valid then return end

    -- Clear all filters
    for i = 1, #inventory do
        inventory.set_filter(i, nil)
    end

    -- Set filters for non-coin items in trades
    local i = 1
    local j = 0
    for _, trade_id in pairs(hex_core_state.trades) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            for _, input in pairs(trade.input_items) do
                if i - j > #inventory then break end
                if input.name:sub(-5) == "-coin" then
                    j = j + 1
                else
                    inventory.set_filter(i - j, {name = input.name, quality = "normal"})
                end
                i = i + 1
            end
            for _, output in pairs(trade.output_items) do
                if i - j > #inventory then break end
                if output.name:sub(-5) == "-coin" then
                    j = j + 1
                else
                    inventory.set_filter(i - j, {name = output.name, quality = "normal"})
                end
                i = i + 1
            end
        end
    end

    -- Set filters for coins
    i = i - j
    if j > 0 then
        if i <= #inventory then inventory.set_filter(i, {name = "hex-coin", quality = "normal"}) end
        if i+1 <= #inventory then inventory.set_filter(i+1, {name = "gravity-coin", quality = "normal"}) end
        if i+2 <= #inventory then inventory.set_filter(i+2, {name = "meteor-coin", quality = "normal"}) end
        if i+3 <= #inventory then inventory.set_filter(i+3, {name = "hexaprism-coin", quality = "normal"}) end
    end
end

---Set up a constant combinator entity's output signals based on its adjacent hex core if possible.
---Creates one section per trade, all disabled by default.
---@param entity LuaEntity
function hex_grid.copy_signals_to_combinator(entity)
    if not entity or not entity.valid then return end
    if entity.type ~= "constant-combinator" then return end

    local state = hex_state_manager.get_hex_state_containing(entity.surface, entity.position)
    if not state then return end

    local hex_core = state.hex_core
    if not hex_core then return end
    if not state.trades or #state.trades == 0 then return end

    -- Adjacency/corner check
    local dx = math.abs(entity.position.x - hex_core.position.x)
    local dy = math.abs(entity.position.y - hex_core.position.y)
    if (dx > 3) or (dy > 3) then return end

    local control = entity.get_or_create_control_behavior()
    if not control then return end
    ---@cast control LuaConstantCombinatorControlBehavior

    for i, trade_id in ipairs(state.trades) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            local section
            if i == 1 then
                section = control.get_section(1)
            else
                section = control.add_section()
            end

            if section then
                local filters = {}
                for _, input_item in ipairs(trade.input_items) do
                    table.insert(filters, {
                        value = {type = "item", name = input_item.name, quality = "normal"},
                        min = -input_item.count
                    })
                end
                for _, output_item in ipairs(trade.output_items) do
                    table.insert(filters, {
                        value = {type = "item", name = output_item.name, quality = "normal"},
                        min = output_item.count
                    })
                end

                section.filters = filters
                section.active = false
            end
        end
    end

    gameplay_statistics.increment "hex-core-trades-read"
end

---Initialize a hex for a dungeon.
---@param surface_id int
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@param hex_stroke_width number
function hex_grid.init_dungeon_hex(surface_id, hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)
    dungeons.spawn_hex(surface_id, hex_pos, hex_grid_scale, hex_grid_rotation, hex_stroke_width)
end

-- Initialize a hex with default state and generate its border
function hex_grid.initialize_hex(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("initialize_hex: No surface found")
        return
    end

    local state = hex_state_manager.get_hex_state(surface_id, hex_pos)
    if not state then return end

    -- Skip if this hex has already been generated
    if state.generated then
        return
    end

    local mgs = storage.hex_grid.mgs[surface.name]
    if not mgs then
        lib.log_error("hex_grid.initialize_hex: No map gen settings found for surface " .. serpent.line(surface))
        return
    end

    -- local planet_size = lib.startup_setting_value("planet-size-" .. surface.name)
    local dist = axial.distance(hex_pos, {q=0, r=0})

    local hex_quality = hex_grid.get_quality_from_distance(surface.name, dist)
    terrain.generate_hex_border(surface_id, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width, nil, hex_quality)

    local is_starting_hex = dist == 0
    local is_land = hex_island.is_land_hex(surface.name, hex_pos)

    local dungeon_chance = lib.runtime_setting_value("dungeon-chance-" .. surface.name)
    local is_dungeon = is_land and (dungeons.is_dungeon_hex(surface_id, hex_pos) or (dist >= 3 and math.random() < dungeon_chance))

    if is_starting_hex then
        if surface.name == "fulgora" then
            surface.create_entity {
                name = "fulgoran-ruin-attractor",
                quality = lib.get_hextreme_or_next_highest_quality(),
                position = {0, -5},
                force = "player",
            }
        elseif surface.name == "vulcanus" then
            for i = 1, 48 do
                local pos = surface.find_non_colliding_position("huge-volcanic-rock", {x = math.random(-20, 20), y = math.random(-20, 20)}, 10, 0.5, false)
                if pos then
                    surface.create_entity {
                        name = "huge-volcanic-rock",
                        position = pos,
                        force = "neutral",
                    }
                end
            end
        elseif surface.name == "nauvis" then
            if lib.runtime_setting_value "nauvis-grace" then
                local turrets = {}
                for _, pos in pairs {
                    {-5, -5},
                    {-5, 6},
                    {6, -5},
                    {6, 6},
                } do
                    table.insert(turrets, surface.create_entity {
                        name = "gun-turret",
                        position = pos,
                        force = "player",
                        quality = "epic",
                    })
                end
                lib.reload_turrets(turrets, {bullet_type = "piercing-rounds-magazine", bullet_count = 30})
            end
            for _, player in pairs(game.connected_players) do
                if not player.character then
                    player.create_character()
                    player.set_controller {type = defines.controllers.character, character = player.character, surface = "nauvis"}
                end
                lib.teleport_player(player, {0, 5}, game.surfaces.nauvis)
            end
        end
        state.is_starting_hex = true
    else
        if surface.name == "fulgora" then
            -- Chance to spawn a fulgoran-ruin-vault
            if math.random() < lib.runtime_setting_value "vault-chance" then
                local transformation = terrain.get_surface_transformation "fulgora"
                surface.create_entity {
                    name = "fulgoran-ruin-vault",
                    position = axial.get_hex_center(hex_pos, transformation.scale, transformation.rotation),
                    force = "neutral",
                }
            elseif math.random() < lib.runtime_setting_value "fulgoran-attractor-chance" then
                local transformation = terrain.get_surface_transformation "fulgora"
                local pos = axial.get_hex_center(hex_pos, transformation.scale, transformation.rotation)
                pos = lib.vector_add(pos, lib.random_unit_vector(9))
                surface.create_entity {
                    name = "fulgoran-ruin-attractor",
                    position = pos,
                    force = "player",
                }
            end
        end
    end

    if is_land then
        state.is_land = true
        state.claim_price = hex_grid.calculate_hex_claim_price(surface, hex_pos)

        hex_grid.generate_hex_resources(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)

        if not is_dungeon then
            if surface.name == "nauvis" then
                local min_biter_distance = lib.remap_map_gen_setting(mgs.starting_area, 0, 3)
                local is_biter_hex = not is_starting_hex and dist >= min_biter_distance
                if is_biter_hex then
                    local biter_chance = lib.remap_map_gen_setting(mgs.autoplace_controls["enemy-base"].frequency)

                    local r = math.random()
                    local proc = r < biter_chance

                    if storage.hex_grid.total_biter_multiplier then
                        biter_chance = biter_chance * storage.hex_grid.total_biter_multiplier
                    end

                    is_biter_hex = r < biter_chance
                    if is_biter_hex then
                        if hex_grid.generate_hex_biters(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width) then
                            state.is_biters = true
                        end
                    else
                        if proc then
                            -- Count some spawner kills towards total spawners killed stat
                            gameplay_statistics.increment("total-spawners-killed", math.random(1, 4))
                        end
                    end
                end
            elseif surface.name == "gleba" then
                local min_pentapod_distance = lib.remap_map_gen_setting(mgs.starting_area, 0, 3)
                local is_pentapod_hex = not is_starting_hex and dist >= min_pentapod_distance
                if is_pentapod_hex then
                    local pentapod_chance = math.sqrt(lib.remap_map_gen_setting(mgs.autoplace_controls.gleba_enemy_base.frequency))

                    local r = math.random()
                    local proc = r < pentapod_chance

                    if storage.hex_grid.total_pentapod_multiplier then
                        pentapod_chance = pentapod_chance * storage.hex_grid.total_pentapod_multiplier
                    end

                    is_pentapod_hex = r < pentapod_chance
                    if is_pentapod_hex then
                        if hex_grid.generate_hex_pentapods(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width) then
                            state.is_pentapods = true
                        end
                    else
                        if proc then
                            -- Count some spawner kills towards total spawners killed stat
                            gameplay_statistics.increment("total-spawners-killed", math.random(1, 2))
                        end
                    end
                end
            end
        end
    else
        terrain.generate_non_land_tiles(surface, hex_pos)
    end

    local flattened_surface_hexes = storage.hex_grid.flattened_surface_hexes[surface.index]
    if not flattened_surface_hexes then
        flattened_surface_hexes = {}
        storage.hex_grid.flattened_surface_hexes[surface.index] = flattened_surface_hexes
    end
    local flat_index = #flattened_surface_hexes + 1

    state.generated = true
    state.send_outputs_to_cargo_wagons = true
    state.flat_index = flat_index

    flattened_surface_hexes[flat_index] = hex_pos

    if hex_grid.can_hex_core_spawn(surface, hex_pos) then
        local center = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
        hex_grid.spawn_hex_core(surface, center)
    end

    if is_dungeon then
        hex_grid.init_dungeon_hex(surface_id, hex_pos, hex_grid_scale, hex_grid_rotation, 3)
        if dungeons.get_dungeon_at_hex_pos(surface_id, hex_pos, false) then
            state.is_dungeon = true -- Gets set to nil when the dungeon gets looted.
            hex_grid.spawn_hex_core(surface, axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation))
        end
    end

    axial.clear_cache('overlapping-chunks', hex_pos, hex_grid_scale, hex_grid_rotation)

    event_system.trigger("hex-generated", surface_id, hex_pos)
end

function hex_grid.generate_hex_resources(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("hex_grid.generate_hex_resources: No surface found")
        return
    end

    local state = hex_state_manager.get_hex_state(surface_id, hex_pos)
    if not state then
        lib.log_error("hex_grid.generate_hex_resources: No hex state found")
        return
    end

    local mgs = storage.hex_grid.mgs[surface.name]
    if not mgs then
        lib.log_error("hex_grid.generate_hex_resources: No map gen settings found for surface " .. serpent.line(surface))
        return
    end

    local dist = axial.distance(hex_pos, {q=0, r=0})
    local is_starting_hex = dist == 0

    local resource_wc, is_well = hex_grid.get_randomized_resource_weighted_choice(surface, hex_pos)
    if not resource_wc then return end

    state.is_resources = true

    if not is_starting_hex then
        -- Based on the standard weighted choice, apply a random bias
        local bias_wc = weighted_choice.copy(resource_wc)
        local resource = weighted_choice.choice(resource_wc)

        local bias_strength = lib.runtime_setting_value "resource-bias" --[[@as number]]

        -- Make the selected resource more likely to be chosen
        resource_wc = weighted_choice.add_bias(bias_wc, resource, bias_strength)
    end

    local resource_names
    local is_hexaprism = false
    if surface.name == "nauvis" then
        local extent = hex_island.get_island_extent "nauvis"
        is_hexaprism = dist >= extent * 0.95
        resource_names = {"iron-ore", "copper-ore", "coal", "stone"}
    elseif surface.name == "vulcanus" then
        resource_names = {"vulcanus_coal", "calcite", "tungsten_ore"}
    elseif surface.name == "fulgora" then
        resource_names = {"scrap"}
    elseif surface.name == "gleba" then
        resource_names = {"gleba_stone"}
    elseif surface.name == "aquilo" then
        resource_names = {}
    end

    local total_resource_size = lib.sum_mgs(mgs.autoplace_controls, "size", resource_names)
    local r = math.random()
    local resource_stroke_width

    local is_mixed
    if surface.name ~= "aquilo" then
        resource_stroke_width = lib.runtime_setting_value("base-resource-width-" .. surface.name) + math.floor(0.5 + r ^ 0.5 * (total_resource_size + dist * lib.runtime_setting_value("resource-width-per-dist-" .. surface.name)))

        -- Bound the resource stroke width to the physical limits of the hexagon and its hex core
        resource_stroke_width = math.min(resource_stroke_width, math.max(2, hex_grid_scale - stroke_width - 4), lib.runtime_setting_value("resource-width-max-" .. surface.name))

        if is_starting_hex then
            if surface.name == "nauvis" then
                is_mixed = lib.runtime_setting_value "starting-resources-mixed"
            else
                is_mixed = true
            end
            resource_stroke_width = tonumber(lib.runtime_setting_value("starting-hex-resource-stroke-width-" .. surface.name)) or 2
        else
            is_mixed = lib.runtime_setting_value "default-resources-mixed"
        end
    end

    local base_richness = 250 * lib.runtime_setting_value "base-resource-richness"
    if surface.name == "fulgora" then
        base_richness = base_richness * 10
    elseif surface.name == "gleba" then
        base_richness = base_richness * 2
    end

    local scaled_richness = base_richness + dist * lib.runtime_setting_value("resource-richness-per-dist-" .. surface.name)

    state.resources = {}
    state.ore_entities = {}

    if is_well then
        state.is_well = true

        local num_entities_min
        local num_entities_max
        if surface.name == "nauvis" then
            num_entities_min = math.floor(0.5 + lib.remap_map_gen_setting(mgs.autoplace_controls["crude-oil"].size, 1, 3))
            num_entities_max = math.floor(0.5 + lib.remap_map_gen_setting(mgs.autoplace_controls["crude-oil"].size, 3, 6))
        elseif surface.name == "vulcanus" then
            num_entities_min = math.floor(0.5 + lib.remap_map_gen_setting(mgs.autoplace_controls.sulfuric_acid_geyser.size, 1, 3))
            num_entities_max = math.floor(0.5 + lib.remap_map_gen_setting(mgs.autoplace_controls.sulfuric_acid_geyser.size, 3, 6))
        elseif surface.name == "aquilo" then
            local size = lib.sum_mgs(mgs.autoplace_controls, "size", {"aquilo_crude_oil", "lithium_brine", "fluorine_vent"}) / 3

            num_entities_min = math.floor(0.5 + 1 + 2 * size)
            num_entities_max = math.floor(0.5 + 3 + 3 * size)
        end

        local num_entities = math.random(num_entities_min, num_entities_max)
        local amount = scaled_richness * 3000
        local radius = math.max(7, (hex_grid_scale - stroke_width) * 0.5)
        local rotation = math.random() * math.pi * 2

        for i = 1, num_entities do
            local resource = weighted_choice.choice(resource_wc)
            if not resource then
                lib.log_error("hex_grid.generate_hex_resources: weighed choice has zero weights")
                return
            end

            local angle = rotation + math.pi * 2 * i / num_entities
            local center = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
            local x = center.x + math.cos(angle) * radius
            local y = center.y + math.sin(angle) * radius

            local pos = {x, y}
            if lib.is_tile_buildable_on(surface, pos) then
                local entity = surface.create_entity{
                    name = resource,
                    position = pos,
                    amount = amount * (0.8 + 0.2 * math.random()),
                }
                if entity and entity.valid then
                    state.resources[resource] = (state.resources[resource] or 0) + entity.amount
                end
            end
        end
    else
        local pie_angles, hex_pos_rect, rotation
        if not is_mixed then
            pie_angles = lib.get_pie_angles(resource_wc)
            hex_pos_rect = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)
            rotation = math.random() * math.pi * 2
        end

        local hex_center = lib.rounded_position(axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation), false)

        local ore_positions
        local offset_hex_center -- Used only by single-hex shapes.  Used to determine how unmixed ores should be generated.
        local ore_generation_mode = lib.runtime_setting_value "ore-generation-mode"
        if ore_generation_mode == "along-edges" then
            ore_positions = axial.get_hex_border_tiles(hex_pos, hex_grid_scale, hex_grid_rotation, resource_stroke_width, stroke_width + 2)
        elseif ore_generation_mode == "single-hex" then
            local offset_scale = 5 + resource_stroke_width
            local offset_rotation = math.random() * math.pi
            local center_offset_hex = axial.get_hex_containing(hex_center, offset_scale, offset_rotation)
            local offset_hex_pos

            if offset_scale > hex_grid_scale / 3 then
                -- Resource hex is too big to be offset, so it must be partially under the hex core.
                offset_hex_pos = center_offset_hex
            else
                -- Resource hex is small enough to be offset to an adjacent hex so that it's not completely under the hex core.
                local closest_dist = math.huge
                for _, adj_pos in pairs(axial.get_adjacent_hexes(center_offset_hex)) do
                    local rect_pos = axial.get_hex_center(adj_pos, offset_scale, offset_rotation)
                    local d = lib.square_distance(rect_pos, hex_center)
                    if d < closest_dist then
                        closest_dist = d
                        offset_hex_pos = adj_pos
                    end
                end
            end

            offset_hex_center = axial.get_hex_center(offset_hex_pos, offset_scale, offset_rotation)

            ore_positions = axial.get_hex_tile_positions(offset_hex_pos, offset_scale, offset_rotation, 0)
        elseif ore_generation_mode == "center-square" then
            ore_positions = {}
            local min_x = hex_center.x - 2 - resource_stroke_width
            local max_x = hex_center.x + 2 + resource_stroke_width
            local min_y = hex_center.y - 2 - resource_stroke_width
            local max_y = hex_center.y + 2 + resource_stroke_width
            for x = min_x, max_x do
                for y = min_y, max_y do
                    table.insert(ore_positions, {x = x, y = y})
                end
            end
        end

        -- Filter out positions that aren't good for ores, like underneath the hex core or on water.
        for i = #ore_positions, 1, -1 do
            local tile = ore_positions[i]
            if not lib.is_land_tile(surface, tile) or lib.is_hazard_tile(surface, tile) or (math.abs(tile.x - hex_center.x) <= 2 and math.abs(tile.y - hex_center.y) <= 2) then
                table.remove(ore_positions, i)
            end
        end

        for _, tile in pairs(ore_positions) do
            if lib.is_tile_buildable_on(surface, tile) then
                local resource, amount
                if is_hexaprism then
                    resource = "hexaprism"
                    amount = 1
                else
                    if is_mixed then
                        resource = weighted_choice.choice(resource_wc)
                        if not resource then
                            lib.log_error("hex_grid.generate_hex_resources: weighed choice has zero weights")
                            return
                        end
                    else
                        local angle
                        if ore_generation_mode == "single-hex" then
                            angle = (math.atan2(tile.y - offset_hex_center.y, tile.x - offset_hex_center.x)) % (2 * math.pi)
                        else
                            angle = (math.atan2(tile.y - hex_pos_rect.y, tile.x - hex_pos_rect.x) + rotation) % (2 * math.pi)
                        end
                        resource = lib.get_item_in_pie_angles(pie_angles, angle) or "iron-ore"
                    end
                    local amount_mean
                    if surface.name == "vulcanus" then
                        if resource == "coal" then
                            amount_mean = scaled_richness * mgs.autoplace_controls.vulcanus_coal.richness
                        elseif resource == "tungsten-ore" then
                            amount_mean = scaled_richness * mgs.autoplace_controls.tungsten_ore.richness
                        else
                            amount_mean = scaled_richness * mgs.autoplace_controls[resource].richness
                        end
                    elseif surface.name == "gleba" then
                        amount_mean = scaled_richness * mgs.autoplace_controls.gleba_stone.richness
                    else
                        amount_mean = scaled_richness * mgs.autoplace_controls[resource].richness
                    end
                    amount = math.floor(amount_mean * (0.8 + 0.4 * math.random()))
                end
                if amount > 0 then
                    local entity = surface.create_entity {name = resource, position = tile, amount = amount}
                    if entity and entity.valid then
                        state.resources[resource] = (state.resources[resource] or 0) + amount
                        table.insert(state.ore_entities, entity)
                    end
                end
            end
        end
    end

    for resource, amount in pairs(state.resources) do
        if amount <= 0 then
            state.resources[resource] = nil
        end
    end

    if surface.name == "gleba" then
        if is_starting_hex then
            local transformation = terrain.get_surface_transformation "gleba"
            local range = (transformation.scale - transformation.stroke_width) * 0.25
            local width = 3
            for i, tile_type in ipairs {"natural-yumako-soil", "natural-jellynut-soil", "wetland-light-green-slime", "wetland-pink-tentacle"} do
                local positions = {}
                local x, dx, entity_name

                if i == 1 then
                    x = range
                    dx = 1
                    entity_name = "yumako-tree"
                elseif i == 2 then
                    x = -range
                    dx = -1
                    entity_name = "jellystem"
                elseif i == 3 then
                    x = range
                    dx = 1
                    entity_name = "copper-stromatolite"
                else
                    x = -range
                    dx = -1
                    entity_name = "iron-stromatolite"
                end

                for y = -range, range do
                    local min_x = x
                    local max_x = x + dx * (width - 1)
                    local center_x = (min_x + max_x) * 0.5

                    local entity_pos
                    if i <= 2 then
                        entity_pos = {x = center_x, y = y}
                    else
                        entity_pos = {x = -y, y = center_x}
                    end

                    for n = 1, width do
                        if i <= 2 then
                            table.insert(positions, {x = x + dx * (n - 1), y = y})
                        else
                            table.insert(positions, {x = -y, y = x + dx * (n - 1)})
                        end
                    end

                    local entity = surface.create_entity {
                        name = entity_name,
                        position = entity_pos,
                    }

                    if entity and i <= 2 then
                        entity.tick_grown = game.tick
                    end
                end
                terrain.set_tiles(surface, positions, tile_type)
            end
        end
    end
end

function hex_grid.get_randomized_resource_weighted_choice(surface, hex_pos)
    local surface_id = lib.get_surface_id(surface)
    surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("hex_grid.generate_hex_resources: No surface found")
        return
    end
    local mgs = storage.hex_grid.mgs[surface.name]
    local dist = axial.distance(hex_pos, {q = 0, r = 0})
    local is_starter_hex = dist == 0
    local dropoff = lib.runtime_setting_value("resource-frequency-dropoff-" .. surface.name)

    local function guarantee_well()
        if is_starter_hex or dist > 2 then return false end

        local island = hex_island.get_island_hex_set(surface.name)
        local within_range, _ = hex_util.all_hexes_within_range({q=0, r=0}, 2, island)
        if not hex_sets.contains(within_range, hex_pos) then return false end

        local hexes_near_spawn = hex_sets.to_array(within_range)

        local num_generated = 0
        for _, pos in pairs(hexes_near_spawn) do
            local state = hex_state_manager.get_hex_state(surface, pos)
            if state and state.is_well then
                return false
            else
                if state and state.generated then
                    num_generated = num_generated + 1
                end
            end
        end

        local chance = 1 / (#hexes_near_spawn - num_generated) -- doesn't hit infinity (not that it matter) because state.generated for the last hex to be generated is only set to true after this function finishes

        return math.random() < chance
    end

    -- Calculate frequencies
    if surface.name == "nauvis" then
        if is_starter_hex or hex_sets.contains(storage.hex_grid.guaranteed_hexaprisms or {}, hex_pos) then
            return storage.hex_grid.resource_weighted_choice.nauvis.resources, false
        end
        local well_names = {"crude-oil"}
        local resource_names = {"iron-ore", "copper-ore", "coal", "stone"}

        local can_be_uranium = dist >= lib.runtime_setting_value "min-uranium-dist"
        if can_be_uranium then
            table.insert(resource_names, "uranium-ore")
        end

        local well_freq = lib.sum_mgs(mgs.autoplace_controls, "frequency", well_names)
        local total_resource_freq = lib.sum_mgs(mgs.autoplace_controls, "frequency", resource_names)
        local resource_freq = total_resource_freq
        resource_freq = resource_freq / #resource_names
        resource_freq = (resource_freq ^ 2.6) * #resource_names
        resource_freq = resource_freq / (1 + dist * dropoff)
        well_freq = well_freq / (1 + dist * dropoff)

        local well_guaranteed = guarantee_well()
        if well_guaranteed then
            return storage.hex_grid.resource_weighted_choice.nauvis.wells, true
        end
        if math.random() > (well_freq + resource_freq) / (1 + #resource_names) then
            return nil, nil
        end

        local is_well = math.random() < well_freq / (well_freq + total_resource_freq)
        if is_well then
            return storage.hex_grid.resource_weighted_choice.nauvis.wells, true
        end

        local is_uranium = can_be_uranium and math.random() < lib.remap_map_gen_setting(mgs.autoplace_controls["uranium-ore"].frequency) / total_resource_freq
        if is_uranium then
            return storage.hex_grid.resource_weighted_choice.nauvis.uranium, false
        end

        local wc = weighted_choice.copy(storage.hex_grid.resource_weighted_choice.nauvis.resources)

        -- Based on the standard weighted choice, apply a random bias
        local bias_wc = weighted_choice.copy(wc)
        local resource = weighted_choice.choice(wc)
        local bias_strength = lib.runtime_setting_value "resource-bias" --[[@as number]]

        -- Make the selected resource more likely to be chosen
        local resource_wc = weighted_choice.add_bias(bias_wc, resource, bias_strength)

        return resource_wc, false
    elseif surface.name == "vulcanus" then
        if is_starter_hex then
            return storage.hex_grid.resource_weighted_choice.vulcanus.starting, false
        end
        local can_be_tungsten = dist >= lib.runtime_setting_value "min-tungsten-dist"

        local well_freq = lib.sum_mgs(mgs.autoplace_controls, "frequency", {"sulfuric_acid_geyser"})
        local resource_freq = lib.sum_mgs(mgs.autoplace_controls, "frequency", {"vulcanus_coal", "calcite", "tungsten_ore"})
        resource_freq = resource_freq * resource_freq / 3
        resource_freq = resource_freq / (1 + dist * dropoff)
        well_freq = well_freq / (1 + dist * dropoff)

        local well_guaranteed = guarantee_well()
        if well_guaranteed then
            return storage.hex_grid.resource_weighted_choice.vulcanus.wells, true
        end

        if math.random() > (well_freq + resource_freq) * 0.25 then
            return nil, nil
        end

        local is_well = math.random() < well_freq / (well_freq + resource_freq)
        if is_well then
            return storage.hex_grid.resource_weighted_choice.vulcanus.wells, true
        end

        local wc
        if can_be_tungsten then
            wc = weighted_choice.copy(storage.hex_grid.resource_weighted_choice.vulcanus.resources)
        else
            wc = weighted_choice.copy(storage.hex_grid.resource_weighted_choice.vulcanus.non_tungsten)
        end

        -- Based on the standard weighted choice, apply a random bias
        local bias_wc = weighted_choice.copy(wc)
        local resource = weighted_choice.choice(wc)

        -- If tungsten bias chance setting triggered, force the bias resource to be tungsten ore and set exact composition, and then apply the usual bias.
        if can_be_tungsten and math.random() < lib.runtime_setting_value "tungsten-bias-chance" then
            resource = "tungsten-ore"
            bias_wc = weighted_choice.set_ratio(bias_wc, "tungsten-ore", 0.4)
        end

        local bias_strength = lib.runtime_setting_value "resource-bias" --[[@as number]]

        -- Make the selected resource more likely to be chosen
        local resource_wc = weighted_choice.add_bias(bias_wc, resource, bias_strength)

        return resource_wc, false
    elseif surface.name == "fulgora" then
        if is_starter_hex then
            return storage.hex_grid.resource_weighted_choice.fulgora.resources, false
        end

        local resource_freq = lib.sum_mgs(mgs.autoplace_controls, "frequency", {"scrap"})
        resource_freq = resource_freq * resource_freq
        resource_freq = resource_freq / (1 + dist * dropoff)
        if math.random() > resource_freq then
            return nil, nil
        end

        return weighted_choice.copy(storage.hex_grid.resource_weighted_choice.fulgora.resources), false
    elseif surface.name == "gleba" then
        local resource_freq = lib.remap_map_gen_setting(mgs.autoplace_controls.gleba_stone.frequency)
        resource_freq = resource_freq * resource_freq
        resource_freq = resource_freq / (1 + dist * dropoff)
        if not is_starter_hex and math.random() > resource_freq then
            return nil, nil
        end

        return weighted_choice.copy(storage.hex_grid.resource_weighted_choice.gleba.resources), false
    elseif surface.name == "aquilo" then
        local well_names = {"aquilo_crude_oil", "lithium_brine", "fluorine_vent"}
        local well_freq = lib.sum_mgs(mgs.autoplace_controls, "frequency", well_names)
        well_freq = well_freq * well_freq / 3
        well_freq = well_freq / (1 + dist * dropoff)
        if math.random() > well_freq then
            return nil, nil
        end

        local wc = storage.hex_grid.resource_weighted_choice.aquilo.wells

        -- Based on the standard weighted choice, apply a random bias
        local bias_wc = weighted_choice.copy(wc)
        local resource = weighted_choice.choice(wc)
        local bias_strength = lib.runtime_setting_value "resource-bias" --[[@as number]]

        -- Make the selected resource more likely to be chosen
        local resource_wc = weighted_choice.add_bias(bias_wc, resource, bias_strength)

        return resource_wc, true
    else
        lib.log_error("hex_grid.get_randomized_resource_weighted_choice: Unknown surface: " .. surface.name)
        return
    end
end

function hex_grid.generate_hex_biters(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.generate_hex_biters: No surface found")
        return false
    end
    surface = game.surfaces[surface_id]

    local dist = axial.distance(hex_pos, {q=0, r=0})
    local quality = hex_grid.get_quality_from_distance(surface.name, dist)

    local num_spawners_min = math.floor(0.5 + lib.remap_map_gen_setting(tonumber(storage.hex_grid.mgs["nauvis"].autoplace_controls["enemy-base"].size), 1, 3))
    local num_spawners_max = math.floor(0.5 + lib.remap_map_gen_setting(tonumber(storage.hex_grid.mgs["nauvis"].autoplace_controls["enemy-base"].size), 1, 5))
    local num_spawners = math.random(num_spawners_min, num_spawners_max)
    local num_worms = math.floor(0.4999 + num_spawners * (0.5 + math.random()))
    local center = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)

    return hex_grid.spawn_enemy_base(surface, center, hex_grid_scale - stroke_width, num_spawners, num_worms, quality)
end

function hex_grid.generate_hex_pentapods(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.generate_hex_biters: No surface found")
        return false
    end
    surface = game.surfaces[surface_id]

    local dist = axial.distance(hex_pos, {q=0, r=0})
    local quality = hex_grid.get_quality_from_distance(surface.name, dist)

    local num_rafts_min = math.floor(0.5 + lib.remap_map_gen_setting(storage.hex_grid.mgs["gleba"].autoplace_controls.gleba_enemy_base.size, 1, 3))
    local num_rafts_max = math.floor(0.5 + lib.remap_map_gen_setting(storage.hex_grid.mgs["gleba"].autoplace_controls.gleba_enemy_base.size, 1, 5))
    local num_rafts = math.random(num_rafts_min, num_rafts_max)
    local center = axial.get_hex_center(hex_pos, hex_grid_scale, hex_grid_rotation)

    return hex_grid.spawn_enemy_base(surface, center, hex_grid_scale - stroke_width, num_rafts, 0, quality)
end

function hex_grid.spawn_enemy_base(surface, center, max_radius, num_spawners, num_worms, quality)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.spawn_enemy_base: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    if not quality then
        quality = prototypes.quality.normal
    end

    local entity_counts = {}

    local evo = game.forces.player.get_evolution_factor(surface)
    if surface.name == "nauvis" then
        if math.random() < 0.5 then
            entity_counts["biter-spawner"] = math.floor(num_spawners / 2)
            entity_counts["spitter-spawner"] = num_spawners - entity_counts["biter-spawner"]
        else
            entity_counts["spitter-spawner"] = math.floor(num_spawners / 2)
            entity_counts["biter-spawner"] = num_spawners - entity_counts["spitter-spawner"]
        end

        local worm_type = "behemoth-worm-turret"
        if evo < 0.25 then
            worm_type = "small-worm-turret"
        elseif evo < 0.50 then
            worm_type = "medium-worm-turret"
        elseif evo < 0.75 then
            worm_type = "big-worm-turret"
        end
        entity_counts[worm_type] = num_worms
    elseif surface.name == "gleba" then
        local chance = lib.runtime_setting_value "small-egg-raft-chance"
        for _ = 1, num_spawners do
            if math.random() < chance then
                entity_counts["gleba-spawner-small"] = (entity_counts["gleba-spawner-small"] or 0) + 1
            else
                entity_counts["gleba-spawner"] = (entity_counts["gleba-spawner"] or 0) + 1
            end
        end
    end

    local entity_table = {}
    for name, count in pairs(entity_counts) do
        for _ = 1, count do
            table.insert(entity_table, name)
        end
    end

    local inner_radius = max_radius * 0.75
    local search_radius = math.max(1, max_radius - inner_radius)
    local any_spawned = false
    for i = 1, #entity_table do
        local idx = math.random(1, #entity_table)
        local entity_name = entity_table[idx]
        table.remove(entity_table, idx)

        local angle = math.random() * math.pi * 2
        local r = math.sqrt(math.random()) * inner_radius
        local x = center.x + math.cos(angle) * r
        local y = center.y + math.sin(angle) * r

        local pos = surface.find_non_colliding_position(entity_name, {x, y}, search_radius, 0.5, true)
        if pos then
            local entity = surface.create_entity {
                name = entity_name,
                position = pos,
                force = "enemy",
                quality = quality,
            }
            if entity then
                any_spawned = true
            end
        end
    end

    return any_spawned
end

---Attempt to spawn a strongbox in the given hex.
---@param state HexState
function hex_grid.try_generate_strongbox(state)
    if not state.hex_core or not state.hex_core.valid or not state.claimed then return end

    local surface = state.hex_core.surface
    local pos = state.hex_core.position
    local offset = lib.random_unit_vector(math.random(8, 16))
    pos = {x = pos.x + offset.x, y = pos.y + offset.y}

    local clear_pos = surface.find_non_colliding_position("strongbox-tier-1", pos, 10, 1, true)
    if not clear_pos then return end

    local loot_scale = hex_grid.get_planet_coin_scaling(surface.name)
    local sb_entity = strongboxes.try_spawn(surface, clear_pos, loot_scale)
    if not sb_entity or not sb_entity.valid then return end

    if not state.strongboxes then
        state.strongboxes = {}
    end

    hex_state_manager.map_entity_to_hex_state(sb_entity.unit_number, surface.name, state.position)
    hex_grid.update_strongbox_entity(state, sb_entity)

    lib.print_notification("strongbox-located", {"",
        lib.color_localized_string({"hextorio.strongbox-located"}, "orange", "heading-1"),
        " ",
        sb_entity.gps_tag,
    })
end

---Update the reference to the strongbox entity that the given hex state holds.
---@param state HexState
---@param sb_entity LuaEntity
function hex_grid.update_strongbox_entity(state, sb_entity)
    if not state.strongboxes then state.strongboxes = {} end
    for i = #state.strongboxes, 1, -1 do
        local sb = state.strongboxes[i]
        if sb then
            if not sb.valid or lib.tables_equal(sb.position, sb_entity.position) then
                table.remove(state.strongboxes, i)
                if sb.valid then
                    sb.destroy()
                end
            end
        end
    end
    table.insert(state.strongboxes, sb_entity)
end

---Remove all strongboxes from this hex core, destroying the entities.
---@param state HexState
function hex_grid.remove_strongboxes(state)
    if not state.strongboxes then return end

    for i = #state.strongboxes, 1, -1 do
        local sb_entity = state.strongboxes[i]
        if sb_entity.valid then
            hex_state_manager.unmap_entity(sb_entity.unit_number)
            sb_entity.destroy()
        end

        state.strongboxes[i] = nil
    end
end

---@param dist number
---@return LuaQualityPrototype
function hex_grid.get_quality_from_distance(surface_name, dist)
    local target_i = math.floor(dist / lib.runtime_setting_value("tiles-per-quality-" .. surface_name)) + 1
    local i = 0
    local _name
    for name, quality in pairs(prototypes.quality) do -- trusting that the quality table is sorted by quality "level" (it seems to be so)
        i = i + 1
        if name ~= "quality-unknown" then
            if i == target_i then
                return quality
            end
            _name = name
        end
    end
    return prototypes.quality[_name]
end

---@param dist number
---@return int
function hex_grid.get_quality_tier_from_distance(surface_name, dist)
    local target_i = math.floor(dist / lib.runtime_setting_value("tiles-per-quality-" .. surface_name)) + 1
    local i = 0
    local _name
    for name, _ in pairs(prototypes.quality) do -- trusting that the quality table is sorted by quality "level" (it seems to be so)
        i = i + 1
        if i == target_i and name ~= "quality-unknown" then
            return i
        end
        _name = name
    end
    if _name == "quality-unknown" then
        i = i - 1
    end
    return i
end

---Check if a hex core can be spawned within a hex
---@param surface SurfaceIdentification
---@param hex_pos HexPos
---@return boolean
function hex_grid.can_hex_core_spawn(surface, hex_pos)
    local state = hex_state_manager.get_hex_state(surface, hex_pos)
    if not state or state.hex_core or not state.is_land or state.deleted or not state.generated then
        return false
    end
    if hex_pos.q == 0 and hex_pos.r == 0 then
        return true
    end
    if hex_grid.is_hex_near_claimed_hex(surface, hex_pos) then
        return true
    end
    return false
end

-- Check if a hex is near a claimed hex
function hex_grid.is_hex_near_claimed_hex(surface, hex_pos)
    local adjacent_hexes = axial.get_adjacent_hexes(hex_pos)
    for _, adj_hex in pairs(adjacent_hexes) do
        local state = hex_state_manager.get_hex_state(surface, adj_hex)
        if state and state.claimed then
            return true
        end
    end
    return false
end

---Return whether the given hex is claimable or eventually claimable.  Note that this does not measure whether the hex is immediately claimable.
---@param player LuaPlayer
---@param surface SurfaceIdentification
---@param hex_pos HexPos
---@param allow_nonland boolean|nil
---@param check_coins boolean|nil
---@param player_inventory_coins Coin|nil
---@return boolean
function hex_grid.can_claim_hex(player, surface, hex_pos, allow_nonland, check_coins, player_inventory_coins)
    if check_coins == nil then check_coins = true end

    local state = hex_state_manager.get_hex_state(surface, hex_pos)
    if not state or state.claimed or not state.generated or state.is_dungeon or not state.is_land and not allow_nonland then
        return false
    end

    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.can_claim_hex: No surface found")
        return false
    end
    local surface_obj = game.get_surface(surface_id)
    if not surface_obj then return false end

    if player then
        if lib.is_player_editor_like(player) then
            return true
        end
    end

    if hex_grid.get_free_hex_claims(surface_obj.name) > 0 then
        return true
    end

    local coin = state.claim_price
    if not coin or coin_tiers.is_zero(coin) then
        return true
    end

    if check_coins then
        if not player_inventory_coins then
            if not player then
                return true
            end

            local inv = lib.get_player_inventory(player)
            if not inv then
                lib.log_error("hex_grid.can_claim_hex: No player inventory found")
                return false
            end

            player_inventory_coins = inventories.get_coin_from_inventory(inv, nil, quests.is_feature_unlocked "piggy-bank")
        end

        if coin_tiers.lt(player_inventory_coins, coin) then
            return false
        end
    end

    return true
end

---Claim a hex and spawn hex cores in adjacent hexes if possible.
---@param surface_id int
---@param hex_pos HexPos
---@param by_player LuaPlayer|nil
---@param allow_nonland boolean|nil
---@param spend_free_claims boolean|nil
function hex_grid.claim_hex(surface_id, hex_pos, by_player, allow_nonland, spend_free_claims)
    if spend_free_claims == nil then spend_free_claims = true end

    if by_player and not hex_grid.can_claim_hex(by_player, surface_id, hex_pos) then
        hex_grid.remove_hex_from_claim_queue(surface_id, hex_pos)
        return
    end

    local surface = game.get_surface(surface_id)
    if not surface then
        lib.log_error("hex_grid.claim_hex: Could not find surface with id " .. surface_id)
        return
    end

    local surface_name = surface.name

    local state = hex_state_manager.get_hex_state(surface_id, hex_pos)
    if not state or state.claimed or not state.generated then return end

    if not allow_nonland then
        if state.is_land then
            if not state.hex_core then
                -- This can happen if trying to claim deep in uncharted areas, where hex cores are trying to spawn but can't yet.
                return
            end
        else
            return
        end
    end

    local dist = hex_island.get_distance_from_spawn(surface_name, hex_pos)

    local spent_last_free_claim = false
    if spend_free_claims then
        if hex_grid.get_free_hex_claims(surface_name) == 1 then
            spent_last_free_claim = true
        end
        hex_grid.add_free_hex_claims(surface_name, -1)
    end

    state.claimed = true
    if by_player then
        state.claimed_by = by_player.name
    end

    state.claimed_timestamp = game.tick

    -- Set tiles
    local tile_name
    if by_player then
        tile_name = lib.player_setting_value(by_player, "claimed-hex-tile")

        -- Purchase
        if not spent_last_free_claim and hex_grid.get_free_hex_claims(surface_name) == 0 and not lib.is_player_editor_like(by_player) then
            local inv = lib.get_player_inventory(by_player)
            if inv then
                local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
                local cost = state.claim_price
                if not cost then
                    -- This shouldn't happen, but if some other rare edge case arises, this will prevent a crash.
                    cost = hex_grid.calculate_hex_claim_price(surface, hex_pos)
                    state.claim_price = cost
                    lib.log_error("hex_grid.claim_hex: Claim price not found in hex state, forced to calculate immediately")
                end
                inventories.remove_coin_from_inventory(inv, cost, nil, is_piggy_bank_unlocked)
            end
        end
    end
    if not tile_name then
        if storage.hex_grid.last_used_claim_tile then
            tile_name = storage.hex_grid.last_used_claim_tile
        else
            tile_name = "refined-concrete"
        end
    else
        storage.hex_grid.last_used_claim_tile = tile_name
    end

    if not (state.is_dungeon or state.was_dungeon) then
        terrain.set_hex_tiles(surface, hex_pos, tile_name)
    end

    local fill_tile_name
    if by_player then
        fill_tile_name = lib.player_setting_value(by_player, "edge-fill-tile")
    end
    if not fill_tile_name then
        if storage.hex_grid.last_used_edge_fill_tile then
            fill_tile_name = storage.hex_grid.last_used_edge_fill_tile
        else
            fill_tile_name = "black-refined-concrete"
        end
    else
        storage.hex_grid.last_used_edge_fill_tile = fill_tile_name
    end

    if state.hex_core and state.hex_core.valid then
        if quests.is_feature_unlocked "hexports" then
            hex_grid.spawn_hexport(state)
        end
        hex_grid.try_generate_strongbox(state)
    end

    hex_grid.add_to_pool(state)

    -- Fil the edges between claimed hexes
    hex_grid.fill_edges_between_claimed_hexes(surface, hex_pos, fill_tile_name)
    hex_grid.fill_corners_between_claimed_hexes(surface, hex_pos, fill_tile_name)

    -- Add trade items to catalog list
    trades.discover_items_in_trades(trades.convert_trade_id_array_to_trade_array(state.trades or {}))

    -- Set default qualities once more just in case mod setting "Default Trade Quality" changed
    for _, trade_id in pairs(state.trades or {}) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            hex_grid.set_trade_allowed_qualities(state.hex_core, trade) -- Leaving both min and max quality nil makes it use defaults as defined by the mod setting
        end
    end

    hex_grid.check_hex_span(surface, hex_pos)
    hex_grid.spawn_adjacent_hex_cores(surface, hex_pos)

    -- Check for distance stuff
    local extent = hex_island.get_island_extent(surface_name)
    if dist == extent then
        gameplay_statistics.set("claim-farthest-hex-on", 1, surface_name)
    end

    gameplay_statistics.increment "total-hexes-claimed"
    gameplay_statistics.increment("claimed-hexes-on", 1, surface_name)

    event_system.trigger("hex-claimed", surface, state)

    state.is_in_claim_queue = nil
end

---Add a hex to the claim queue.
---@param surface SurfaceIdentification The surface on which to claim the hex.
---@param hex_pos HexPos The position of the hex to be claimed.
---@param by_player LuaPlayer|nil The player who requested the claim.
---@param allow_nonland boolean|nil Whether to allow force-claiming non-land tiles like water, lava, etc. Defaults to false.
---@param spend_free_claims boolean|nil Whether to allow spending the currently available free hex claims. Defaults to true.
function hex_grid.add_hex_to_claim_queue(surface, hex_pos, by_player, allow_nonland, spend_free_claims)
    if spend_free_claims == nil then spend_free_claims = true end

    if not storage.hex_grid.claim_queue then
        storage.hex_grid.claim_queue = {}
    end

    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.add_hex_to_claim_queue: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local state = hex_state_manager.get_hex_state(surface, hex_pos)
    if not state then return end
    if hex_grid.is_claimed_or_in_queue(state) then return end

    state.is_in_claim_queue = true

    local idx
    local dist = axial.distance(hex_pos, {q=0, r=0})
    for i, params in ipairs(storage.hex_grid.claim_queue) do
        local d = axial.distance(params.hex_pos, {q=0, r=0})
        if d > dist then
            idx = i
            break
        end
    end
    if not idx then
        idx = #storage.hex_grid.claim_queue + 1
    end

    table.insert(storage.hex_grid.claim_queue, idx, {
        surface_name = surface.name,
        hex_pos = hex_pos,
        by_player = by_player,
        allow_nonland = allow_nonland,
        spend_free_claims = spend_free_claims,
    })
end

function hex_grid.remove_hex_from_claim_queue(surface, hex_pos)
    local state = hex_state_manager.get_hex_state(surface, hex_pos)
    state.is_in_claim_queue = nil

    if not storage.hex_grid.claim_queue then return end

    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.add_hex_to_claim_queue: No surface found")
        return
    end
    surface = game.get_surface(surface_id)
    if not surface then return end

    for i, params in ipairs(storage.hex_grid.claim_queue) do
        if params.surface_name == surface.name and params.hex_pos.q == hex_pos.q and params.hex_pos.r == hex_pos.r then
            table.remove(storage.hex_grid.claim_queue, i)
            return
        end
    end
end

function hex_grid.process_claim_queue()
    if not storage.hex_grid.claim_queue then
        storage.hex_grid.claim_queue = {}
    end
    if not next(storage.hex_grid.claim_queue) then return end

    -- Find the first params that is for a hex with an existing hex core
    local params
    local found = false
    for i = 1, #storage.hex_grid.claim_queue do
        params = storage.hex_grid.claim_queue[i]
        -- TODO: Optimize by not repeatedly calculating coin amounts in inventories
        -- if hex_grid.can_claim_hex(params.by_player, params.surface_name, params.hex_pos, params.allow_nonland) then
        local state = hex_state_manager.get_hex_state(params.surface_name, params.hex_pos)
        if state and state.hex_core then
            found = true
            table.remove(storage.hex_grid.claim_queue, i)
            break
        end
    end

    if not found then
        -- The remaining params are probably for non-land hexes.
        params = table.remove(storage.hex_grid.claim_queue, 1)
    end

    -- Set in-queue flag to nil
    local state = hex_state_manager.get_hex_state(params.surface_name, params.hex_pos)
    if state then
        state.is_in_claim_queue = nil
    end

    hex_grid.claim_hex(params.surface_name, params.hex_pos, params.by_player, params.allow_nonland, params.spend_free_claims)
end

-- Claim hexes within a range, covering water as well
function hex_grid.claim_hexes_range(surface, hex_pos, range, by_player, allow_nonland)
    hex_grid._claim_hexes_dfs(surface, hex_pos, range, by_player, hex_pos, allow_nonland)
end

function hex_grid._claim_hexes_dfs(surface, hex_pos, range, by_player, center_pos, allow_nonland)
    local dist = axial.distance(hex_pos, center_pos)
    if dist > range then return end

    local state = hex_state_manager.get_hex_state(surface, hex_pos)
    if not hex_grid.is_claimed_or_in_queue(state) then
        hex_grid.add_hex_to_claim_queue(surface, hex_pos, by_player, allow_nonland, false)
    end

    for _, adj_hex in pairs(axial.get_adjacent_hexes(hex_pos)) do
        local adj_state = hex_state_manager.get_hex_state(surface, adj_hex)
        if not hex_grid.is_claimed_or_in_queue(adj_state) then
            hex_grid._claim_hexes_dfs(surface, adj_hex, range, by_player, center_pos, allow_nonland)
        end
    end
end

function hex_grid.is_claimed_or_in_queue(state)
    return state.claimed or state.is_in_claim_queue
end

function hex_grid.check_hex_span(surface, hex_pos)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.check_hex_span: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    local span = 0
    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
        if state.claimed then
            span = math.max(span, axial.distance(hex_pos, state.position))
        end
    end

    storage.hex_grid.hex_span[surface] = math.max(span, storage.hex_grid.hex_span[surface] or 0)

    gameplay_statistics.set_if_greater("hex-span", span)
end

---Add free claims on a surface.
---@param surface_name string
---@param amount int
function hex_grid.add_free_hex_claims(surface_name, amount)
    if not storage.hex_grid.free_hex_claims then
        storage.hex_grid.free_hex_claims = {}
    end
    storage.hex_grid.free_hex_claims[surface_name] = math.max(0, (storage.hex_grid.free_hex_claims[surface_name] or 0) + (amount or 1))
end

---Get the number of free hex claims remaining on a surface.
---@param surface_name string
---@return int
function hex_grid.get_free_hex_claims(surface_name)
    if not storage.hex_grid.free_hex_claims then
        return 0
    end
    return storage.hex_grid.free_hex_claims[surface_name] or 0
end

-- Handle chunk generation event for the hex grid
function hex_grid.on_chunk_generated(surface, chunk_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]

    if not allowed_surfaces[surface.name] then return end

    -- Default values
    local transformation = terrain.get_surface_transformation(surface)

    if not transformation then
        lib.log_error("hex_grid.on_chunk_generated: No transformation found")
        return
    end

    hex_grid_scale = transformation.scale
    hex_grid_rotation = transformation.rotation
    stroke_width = transformation.stroke_width

    -- Convert chunk position to rectangle coordinates
    local top_left, bottom_right = lib.chunk_to_rect(chunk_pos)

    -- Find all hexes that overlap with this chunk
    local overlapping_hexes = axial.get_overlapping_hexes(
        top_left, bottom_right, hex_grid_scale, hex_grid_rotation
    )

    -- Try to initialize each overlapping hex if not already generated
    for _, hex_pos in pairs(overlapping_hexes) do
        if storage.initialization.has_game_started or storage.initialization.is_nauvis_generating then
            -- Only initialize if possible
            if hex_grid.can_initialize_hex(surface, hex_pos, hex_grid_scale, hex_grid_rotation) then
                hex_grid.initialize_hex(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
                hex_grid.initialize_adjacent_hexes(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
            end
        end
    end

    -- Return the hexes that were processed for this chunk
    return overlapping_hexes
end

---Return whether a hex state can be initialized at the given hex position on the given surface.
---@param surface SurfaceIdentification
---@param hex_pos HexPos
---@param hex_grid_scale number
---@param hex_grid_rotation number
---@return boolean
function hex_grid.can_initialize_hex(surface, hex_pos, hex_grid_scale, hex_grid_rotation)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then return false end

    local surface_obj = game.get_surface(surface_id)
    if not surface_obj then return false end

    -- Only return true if all overlapping chunks are generated
    for _, chunk_pos in pairs(axial.get_overlapping_chunks(hex_pos, hex_grid_scale, hex_grid_rotation)) do
        if not surface_obj.is_chunk_generated(chunk_pos) then
            return false
        end
    end
    return true
end

function hex_grid.initialize_adjacent_hexes(surface, hex_pos, hex_grid_scale, hex_grid_rotation, stroke_width)
    for _, adj in pairs(axial.get_adjacent_hexes(hex_pos)) do
        local state = hex_state_manager.get_hex_state(surface, adj)
        if state and not state.generated then
            if hex_grid.can_initialize_hex(surface, adj, hex_grid_scale, hex_grid_rotation) then
                hex_grid.initialize_hex(surface, adj, hex_grid_scale, hex_grid_rotation, stroke_width)
            end
        end
    end
end

-- Spawn a hex core at the given position
function hex_grid.spawn_hex_core(surface, position)
    local surface_id = lib.get_surface_id(surface)
    surface = game.surfaces[surface_id]
    if not surface then
        lib.log_error("hex_grid.spawn_hex_core: Invalid surface")
        return
    end

    local transformation = terrain.get_surface_transformation(surface_id)
    if not transformation then
        lib.log_error("hex_grid.spawn_hex_core: No transformation found")
        return
    end

    local rounded_position = lib.rounded_position(position, true)

    local hex_pos = axial.get_hex_containing(position, transformation.scale, transformation.rotation)
    local state = hex_state_manager.get_hex_state(surface_id, hex_pos)
    if not state or state.hex_core then return end

    local dist = axial.distance(hex_pos, {q=0, r=0})

    local quality = hex_grid.get_quality_from_distance(surface.name, dist)

    local entities = surface.find_entities_filtered {
        area = {{rounded_position.x - 2.5, rounded_position.y - 2.5}, {rounded_position.x + 2.5, rounded_position.y + 2.5}},
    }

    for _, e in pairs(entities) do
        if e.valid and not lib.is_entity_immune_to_hex_core_clearing(e) then
            if e.type == "cliff" then
                e.destroy {do_cliff_correction = true}
            else
                e.destroy()
            end
        end
    end

    -- Hex core
    local hex_core = surface.create_entity {name = "hex-core", position = rounded_position, force = "player", quality = quality}
    if not hex_core then
        lib.log_error("hex_grid.spawn_hex_core: Failed to spawn hex core")
        return
    end
    hex_core.destructible = false

    for _, e in pairs(entities) do
        if e.valid and e.type == "character" then
            lib.unstuck_player(e.player)
        end
    end

    state.hex_core = hex_core
    state.hex_core_input_inventory = hex_core.get_inventory(defines.inventory.chest)
    -- state.hex_core_output_inventory = output_chest.get_inventory(defines.inventory.chest)
    state.hex_core_output_inventory = state.hex_core_input_inventory

    hex_grid.generate_loaders(state)
    hex_grid.spawn_hexlight(state)

    state.trades = {}
    hex_grid.add_initial_trades(state)

    return hex_core
end

---Attempt to spawn hex cores in hexes adjacent to the given hex. Return the list of hex core entities successfully spawned.
---@param surface LuaSurface
---@param hex_pos HexPos
---@return LuaEntity[]
function hex_grid.spawn_adjacent_hex_cores(surface, hex_pos)
    local adjacent_hexes = axial.get_adjacent_hexes(hex_pos)
    local transformation = terrain.get_surface_transformation(surface)

    if not transformation then
        lib.log_error("hex_grid.spawn_adjacent_hex_cores: No transformation found")
        return {}
    end

    local spawned = {}
    for _, adj_hex in pairs(adjacent_hexes) do
        if hex_grid.can_hex_core_spawn(surface, adj_hex) then
            local e = hex_grid.spawn_hex_core(surface, axial.get_hex_center(adj_hex, transformation.scale, transformation.rotation))
            if e then
                table.insert(spawned, e)
            end
        end
    end

    return spawned
end

---Spawn a hexport at a hex core.
---@param state HexState
---@param replace_existing boolean|nil Whether to destroy the currently existing hexport first if there is one.  Defaults to true.
function hex_grid.spawn_hexport(state, replace_existing)
    if not state.hex_core then
        lib.log_error("hex_grid.spawn_hexport: Tried to spawn hexport with no hex core")
        return
    end

    if replace_existing == nil then replace_existing = true end

    if state.hexport then
        if replace_existing then
            state.hexport.destroy()
        else
            lib.log_error("hex_grid.spawn_hexport: Hex core already has a hexport.")
            return
        end
    end

    local hexport = state.hex_core.surface.create_entity {
        name = "hexport-" .. state.hex_core.surface.name,
        position = state.hex_core.position,
        force = "player",
    }

    if not hexport then return end

    hexport.destructible = false
    hexport.minable = false

    state.hexport = hexport
end

---Remove the hexport from a hex core.
---@param state HexState
function hex_grid.remove_hexport(state)
    if not state.hexport then return end
    state.hexport.destroy()
    state.hexport = nil
end

---@param state HexState
function hex_grid.spawn_hexlight(state)
    if not state.hex_core or state.hexlight then return end

    local hexlight = state.hex_core.surface.create_entity {
        name = "hexlight-" .. state.hex_core.surface.name,
        position = {state.hex_core.position.x + 2, state.hex_core.position.y + 2},
        force = "player",
    }

    if not hexlight then return end

    local hexlight2 = state.hex_core.surface.create_entity {
        name = "hexlight-" .. state.hex_core.surface.name,
        position = {state.hex_core.position.x - 2, state.hex_core.position.y - 2},
        force = "player",
    }

    if not hexlight2 then return end

    hexlight.destructible = false
    hexlight.minable = false
    hexlight.always_on = true

    if state.is_dungeon then
        hexlight.color = storage.hex_grid.dungeon_hexlight_color
    else
        if not storage.hex_grid.default_hexlight_color then
            hex_grid.update_hexlight_default_colors()
        end
        hexlight.color = storage.hex_grid.default_hexlight_color[state.hex_core.surface.name]
    end

    state.hexlight = hexlight

    hexlight2.destructible = false
    hexlight2.minable = false
    hexlight2.always_on = true
    hexlight2.color = hexlight.color

    state.hexlight2 = hexlight2
end

function hex_grid.remove_hexlight(state)
    if state.hexlight then
        state.hexlight.destroy()
        state.hexlight = nil
    end
    if state.hexlight2 then
        state.hexlight2.destroy()
        state.hexlight2 = nil
    end
end

---@param state HexState
function hex_grid.add_initial_trades(state)
    local dist = hex_island.get_distance_from_spawn(state.hex_core.surface.name, state.position)
    if not dist then
        lib.log_error("hex_grid.add_initial_trades: Could not get BFS distance from spawn, falling back to axial distance")
        dist = axial.distance(state.position, {q=0, r=0})
    end
    local is_starting_hex = dist == 0

    local hex_core = state.hex_core
    if not hex_core then return end

    local surface = hex_core.surface
    local surface_name = surface.name

    if is_starting_hex then
        for _, trade_items in pairs(storage.trades.starting_trades[surface_name]) do
            local input_names = trade_items[1]
            local output_names = trade_items[2]
            local params = {target_efficiency = storage.trades.base_trade_efficiency}
            local trade = trades.from_item_names(state.hex_core.surface.name, input_names, output_names, params)
            if trade then
                hex_grid.add_trade(state, trade)
            else
                lib.log_error("hex_grid.add_initial_trades: Failed to generate trade from item names: " .. serpent.line(input_names) .. " -> " .. serpent.line(output_names) .. " -- Is target_efficiency too high or low (see below)?\nparams = " .. serpent.block(params))
            end
        end
    else
        local island_extent = hex_island.get_island_extent(surface_name)
        local trades_per_hex = lib.runtime_setting_value("trades-per-hex-" .. surface_name)

        local guaranteed_trades = lib.get_at_multi_index(storage.trades.guaranteed_trades, surface_name, state.position.q, state.position.r)
        if guaranteed_trades then
            for _, trade in pairs(guaranteed_trades) do
                hex_grid.add_trade(state, trade)
                trades_per_hex = trades_per_hex - 1
            end
            lib.remove_at_multi_index(storage.trades.guaranteed_trades, surface_name, state.position.q, state.position.r) -- Erase it so that multiple copies of the same trade don't exist in storage (bad for save times)
        end

        --[[
            EXPLANATION OF TRADE VOLUME SAMPLING METHOD:

            Island extent is the distance to the farthest hex tile from spawn, measuring the length of the shortest valid path from spawn to the hex tile.

            All hexes that are (30% * island extent) hex tiles away from spawn (again measuring shortest valid path length) sample with uniform distribution from all items that have values on the respective surface.

            Inside this 30% threshold, an exponential interpolation is made from the lowest item values to the highest, based on distance from spawn to this 30% threshold.

            In one sentence:
            This interpolation puts low-valued, quickly unlockable items near spawn and
            gradually creates trades with more and more expensive items as distance increases,
            where all of the planet-related items are able to be found after 30% of the island's extent.
        ]]

        if trades_per_hex >= 1 then
            local items_sorted_by_value = item_values.get_items_sorted_by_value(surface_name, true, false)
            local max_item_value = item_values.get_item_value(surface_name, items_sorted_by_value[#items_sorted_by_value])

            -- This is the distance from spawn after which the most expensive items can be found
            local threshold_dist = island_extent * 0.3

            -- These two parameters are for scaling volume by distance
            local base = hex_grid.get_trade_volume_base(surface_name)
            local exponent = (max_item_value * 0.5 / base) ^ (1 / threshold_dist)

            -- Exponentially interpolate towards pure random as distance increases, capping after the extent threshold.
            local dist_factor = math.min(dist / threshold_dist, 1)

            for _ = 1, trades_per_hex do
                local random_volume_by_dist
                if dist <= threshold_dist then
                    local r = math.random()
                    random_volume_by_dist = math.min(max_item_value * 0.5, base * (exponent ^ (r * r * dist)))
                else
                    random_volume_by_dist = max_item_value * 0.5
                end

                -- This is a random volume chosen from a uniform distribution of all item values on the surface, resulting in each item having equal chance of being chosen as the central value.
                local random_volume_uniform = item_values.get_item_value(surface_name, items_sorted_by_value[math.random(1, #items_sorted_by_value)])
                local random_volume = math.exp(math.log(random_volume_by_dist) * (1 - dist_factor) + math.log(random_volume_uniform) * dist_factor)

                local trade = hex_grid.generate_random_trade(state, random_volume)
                if trade then
                    hex_grid.add_trade(state, trade)
                end
            end
        end
    end

    hex_grid.apply_extra_trades_bonus(state)
    hex_grid.apply_interplanetary_trade_bonus(state)
end

---Return whether it's possible to delete a given hex core entity.
---@param hex_core LuaEntity
---@return boolean
function hex_grid.can_delete_hex_core(hex_core)
    if not hex_core.valid then return false end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then
        lib.log_error("hex_grid.delete_hex_core: hex core has no state")
        return false
    end

    if not state.claimed then return false end
    if state.position.q == 0 and state.position.r == 0 then return false end

    return true
end

---Delete a hex core entity and its trades, but keep the ground tiles. Return whether the deletion was successful.
---@param hex_core LuaEntity
---@return boolean
function hex_grid.delete_hex_core(hex_core)
    if not hex_grid.can_delete_hex_core(hex_core) then return false end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return false end

    local entities = hex_core.surface.find_entities_filtered {name = "hex-core-loader", radius = 3, position = hex_core.position}
    for _, e in pairs(entities) do
        if e.valid then
            e.destroy()
        end
    end

    hex_grid.remove_from_pool(state)
    hex_grid.remove_strongboxes(state)

    hex_core.destroy()
    event_system.trigger("hex-core-deleted", state)
    state.hex_core = nil

    for _, trade_id in pairs(state.trades) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            trades.remove_trade_from_tree(trade, true)
            hex_grid.try_recover_trade(trade, nil, false)
        end
    end

    state.trades = nil
    state.input_loaders = nil
    state.output_loaders = nil
    state.deleted = true

    hex_grid.remove_hexport(state)
    hex_grid.remove_hexlight(state)

    return true
end

---@param hex_core LuaEntity
function hex_grid.supercharge_resources(hex_core)
    for _, e in pairs(hex_grid.get_hex_resource_entities(hex_core)) do
        e.amount = 4294967295
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    state.is_infinite = true
end

---@param hex_core LuaEntity
function hex_grid.convert_resources(hex_core)
    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state or not state.ore_entities then return end

    local surface = hex_core.surface

    -- Determine most abundant resource
    local max_resource = hex_grid.get_most_abundant_ore(state)
    if not max_resource then return end

    -- Convert the other resources to the most abundant type
    for i, e in ipairs(state.ore_entities) do
        if e.valid then
            if e.name ~= max_resource then
                local new_entity = surface.create_entity {
                    name = max_resource,
                    amount = e.amount,
                    position = e.position,
                }
                if new_entity and new_entity.valid then
                    e.destroy()
                    state.ore_entities[i] = new_entity
                end
            end
        end
    end
end

---@param hex_core LuaEntity
---@param quality LuaQualityPrototype|string
function hex_grid.set_quality(hex_core, quality)
    -- Destroy old entity, spawn new one in with higher quality.
    -- Transfer all old inventory items to new entity.
    -- Transfer slot filters
    -- Update all relevant players' opened entities to new entity.
    -- Update state.hex_core

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local position = hex_core.position
    local surface = hex_core.surface
    local inv = hex_core.get_inventory(defines.inventory.chest)
    if not inv then return end

    local old_inv_len = #inv

    local filters = {}
    for i = 1, #inv do
        filters[i] = inv.get_filter(i)
    end

    local update_players = {}
    for _, player in pairs(game.connected_players) do
        if player.opened == hex_core then
            table.insert(update_players, player)
        end
    end

    local contents = inv.get_contents()

    hex_core.destroy()

    local new_hex_core = surface.create_entity {
        name = "hex-core",
        position = position,
        quality = quality,
        force = "player",
    }

    if not new_hex_core then return end
    new_hex_core.destructible = false

    state.hex_core = new_hex_core
    state.hex_core_input_inventory = new_hex_core.get_inventory(defines.inventory.chest)
    state.hex_core_output_inventory = state.hex_core_input_inventory

    for i = 1, math.min(old_inv_len, #state.hex_core_input_inventory) do
        state.hex_core_input_inventory.set_filter(i, filters[i])
    end

    for _, item_stack in pairs(contents) do
        state.hex_core_input_inventory.insert {
            name = item_stack.name,
            count = item_stack.count,
            quality = item_stack.quality,
        }
    end

    for _, player in pairs(update_players) do
        player.opened = new_hex_core
    end

    if lib.runtime_setting_value "increment-trade-quality" then
        for _, trade_id in pairs(state.trades or {}) do
            local trade = trades.get_trade_from_id(trade_id)
            if trade then
                -- For now, just make trades only use one quality at a time.  This appears to be the only way that people play.
                hex_grid.set_trade_allowed_qualities(new_hex_core, trade, quality.name, quality.name)
            end
        end
    end
end

function hex_grid.upgrade_quality(hex_core)
    if not hex_core then
        lib.log_error("hex_grid.upgrade_quality: hex core is nil")
        return
    end

    local next_quality = hex_core.quality.next
    if not next_quality then
        lib.log_error("hex_grid.upgrade_quality: hex core is already at max quality")
        return
    end
    hex_grid.set_quality(hex_core, next_quality)
end

function hex_grid.generate_loaders(hex_core_state)
    if not hex_core_state.hex_core then return end

    hex_core_state.input_loaders = {}
    hex_core_state.output_loaders = {}

    local surface = hex_core_state.hex_core.surface
    local position = hex_core_state.hex_core.position

    -- Try to preserve filters if already existent
    local filters = {}

    local function get_filters(loader)
        return {loader.get_filter(1), loader.get_filter(2)}
    end

    local function set_filters(loader, _filters)
        loader.set_filter(1, _filters[1])
        loader.set_filter(2, _filters[2])
    end

    local entities = surface.find_entities_filtered {
        name = "hex-core-loader",
        area = {{position.x - 2, position.y - 2}, {position.x + 2, position.y + 2}},
    }
    for _, e in pairs(entities) do
        if e.valid then
            if e.loader_filter_mode == "whitelist" then
                filters[lib.position_to_string(e.position)] = get_filters(e)
            end
            e.destroy()
        end
    end

    local dx = 1
    local dy = -2
    for i = 1, 4 do
        local dir_name = lib.get_direction_name((i + 3 - (i % 2) * 2) % 4 + 1) -- I have no idea why this works, but it does, so don't touch it.
        local dir_name_opposite = lib.get_direction_name((i + 3) % 4 + 1)

        local input_loader = surface.create_entity {name = "hex-core-loader", position = {position.x + dx, position.y + dy}, direction = defines.direction[dir_name], type = "input", force = "player"}
        input_loader.destructible = false
        -- input_loader.rotatable = false
        table.insert(hex_core_state.input_loaders, input_loader)

        local output_loader = surface.create_entity {name = "hex-core-loader", position = {position.x - dx, position.y + dy}, direction = defines.direction[dir_name_opposite], type = "output", force = "player"}
        output_loader.loader_filter_mode = "whitelist"
        output_loader.destructible = false
        -- output_loader.rotatable = false
        if filters[lib.position_to_string(output_loader.position)] then
            set_filters(output_loader, filters[lib.position_to_string(output_loader.position)])
        end
        table.insert(hex_core_state.output_loaders, output_loader)

        dx, dy = dy, -dx
    end
end

function hex_grid.regenerate_all_hex_core_loaders()
    for _, surface in pairs(game.surfaces) do
        for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
            hex_grid.generate_loaders(state)
        end
    end
end

---@param loader LuaEntity
---@param previous_direction defines.direction
function hex_grid.handle_hex_core_loader_flip(loader, previous_direction)
    local state = hex_state_manager.get_hex_state_containing(loader.surface, loader.position)
    if not state then return end

    if not state.input_loaders then
        state.input_loaders = {}
    end

    if not state.output_loaders then
        state.output_loaders = {}
    end

    local remove_from, add_to

    local i = lib.table_index(state.input_loaders, loader)
    if i then
        -- input loader got flipped to become an output loader
        remove_from = state.input_loaders
        add_to = state.output_loaders

        loader.loader_filter_mode = "whitelist"
    else
        -- output loader got flipped to become an input loader
        remove_from = state.output_loaders
        add_to = state.input_loaders
        i = lib.table_index(state.output_loaders, loader)

        loader.loader_filter_mode = "none"
    end

    loader.set_filter(1, nil)
    loader.set_filter(2, nil)

    if i then
        ---@cast remove_from LuaEntity[]
        table.remove(remove_from, i)
    end

    add_to[#add_to+1] = loader
end

function hex_grid.on_entity_settings_pasted(player, source, destination)
    if source.name == "hex-core" and destination.name == "hex-core" then
        local source_state = hex_grid.get_hex_state_from_core(source)
        local destination_state = hex_grid.get_hex_state_from_core(destination)
        if not source_state or not destination_state then return end

        local source_hex_core = source_state.hex_core
        local destination_hex_core = destination_state.hex_core
        if not source_hex_core or not destination_hex_core or not source_hex_core.valid or not destination_hex_core.valid then return end

        local destination_loaders = lib.table_extend(destination_state.output_loaders, destination_state.input_loaders)
        local source_loaders = lib.table_extend(source_state.output_loaders, source_state.input_loaders)

        for i = 1, #source_loaders do
            local source_loader = source_loaders[i]
            local source_dx = source_loader.position.x - source_hex_core.position.x
            local source_dy = source_loader.position.y - source_hex_core.position.y

            for j = 1, #destination_loaders do
                local destination_loader = destination_loaders[j]
                local destination_dx = destination_loader.position.x - destination_hex_core.position.x
                local destination_dy = destination_loader.position.y - destination_hex_core.position.y

                if source_dx == destination_dx and source_dy == destination_dy then
                    if destination_loader.direction ~= source_loader.direction then
                        destination_loader.rotate {by_player = player}
                    end
                    destination_loader.copy_settings(source_loader, player)
                    break
                end
            end
        end
    elseif source.name == "hex-core-loader" and destination.name == "hex-core-loader" then
        local source_state = hex_state_manager.get_hex_state_containing(source.surface, source.position)
        local destination_state = hex_state_manager.get_hex_state_containing(destination.surface, destination.position)
        if not source_state or not destination_state then return end

        local source_is_input = lib.table_index(source_state.input_loaders or {}, source) ~= nil
        local destination_is_input = lib.table_index(destination_state.input_loaders or {}, destination) ~= nil

        if source_is_input ~= destination_is_input then
            -- We also want to copy and paste the I/O setting of the loader.
            -- e.g. paste settings of an input loader onto an output loader while also turning that output loader into an input loader
            destination.rotate {by_player = player}
        end

        -- Still run this because rotating the loader might have cleared the settings after pasting them.
        -- But don't include the by_player because that'll cause an infinite loop here.
        destination.copy_settings(source)
    end
end

-- Fill edges between adjacent claimed hexes using sum of squared distances method
function hex_grid.fill_edges_between_claimed_hexes(surface, hex_pos, tile_type)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.fill_edges_between_claimed_hexes: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    if surface.name == "aquilo" then return end

    local state = hex_state_manager.get_hex_state(surface_id, hex_pos)
    if not state or not state.claimed then return end

    -- If no tile type is specified, use the last claimed hex tile type
    if not tile_type then
        tile_type = storage.hex_grid.last_used_claim_tile or "refined-concrete"
    end

    -- Process each adjacent hex that is claimed
    for _, adj_hex in pairs(axial.get_adjacent_hexes(hex_pos)) do
        local adj_state = hex_state_manager.get_hex_state(surface_id, adj_hex)
        if adj_state and adj_state.claimed then
            terrain.fill_edges_between_hexes(surface, hex_pos, adj_hex, tile_type)
        end
    end
end

-- Finds and fills corners where three claimed hexes meet
function hex_grid.fill_corners_between_claimed_hexes(surface, hex_pos, tile_type)
    local surface_id = lib.get_surface_id(surface)
    if surface_id == -1 then
        lib.log_error("hex_grid.fill_corners_between_claimed_hexes: No surface found")
        return
    end
    surface = game.surfaces[surface_id]

    if surface.name == "fulgora" or surface.name == "aquilo" then return end

    local state = hex_state_manager.get_hex_state(surface_id, hex_pos)
    if not state or not state.claimed then return end

    -- If no tile type is specified, use the last claimed hex tile type
    if not tile_type then
        tile_type = storage.hex_grid.last_used_claim_tile or "refined-concrete"
    end

    -- Get adjacent hexes
    local adjacent_hexes = axial.get_adjacent_hexes(hex_pos)

    -- For each pair of adjacent hexes, check if they share a corner
    for i = 1, #adjacent_hexes do
        local hex_pos2 = adjacent_hexes[i]
        local hex2_state = hex_state_manager.get_hex_state(surface_id, hex_pos2)
        if hex2_state and hex2_state.claimed then
            for j = i+1, #adjacent_hexes do
                local hex_pos3 = adjacent_hexes[j]
                local hex3_state = hex_state_manager.get_hex_state(surface_id, hex_pos3)
                if hex3_state and hex3_state.claimed then
                    -- Check if these three hexes share a corner
                    -- For this to be true, hex1 and hex2 must be adjacent to each other
                    if axial.distance(hex_pos2, hex_pos3) == 1 then
                        terrain.fill_corners_between_hexes(surface, hex_pos, hex_pos2, hex_pos3, tile_type)
                    end
                end
            end
        end
    end
end

function hex_grid.get_hex_resource_entities(hex_core)
    local transformation = terrain.get_surface_transformation(hex_core.surface)
    if not transformation then return {} end

    local entities = hex_core.surface.find_entities_filtered {
        type = "resource",
        position = hex_core.position,
        radius = transformation.scale * storage.constants.ROOT_THREE_OVER_TWO + 0.5,
    }

    -- Filter out invalid entities
    for i = #entities, 1, -1 do
        if not entities[i].valid then
            table.remove(entities, i)
        end
    end

    -- local state = hex_grid.get_hex_state_from_core(hex_core)
    -- if not state then return entities end

    -- local inner_border_tiles = axial.get_hex_border_tiles(state.position, transformation.scale, transformation.rotation, transformation.scale - transformation.stroke_width, transformation.stroke_width, false)
    -- for i = #entities, 1, -1 do
    --     local entity = entities[i]
    --     if not inner_border_tiles[entity.position.x] or not inner_border_tiles[entity.position.x][entity.position.y] then
    --         table.remove(entities, i)
    --     end
    -- end

    return entities
end

function hex_grid.get_delete_core_cost(hex_core)
    if not hex_core or not hex_core.valid then return coin_tiers.new() end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return coin_tiers.new() end

    return state.claim_price or coin_tiers.new()
end

function hex_grid.get_supercharge_cost(hex_core)
    if not hex_core or not hex_core.valid then return coin_tiers.new() end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return coin_tiers.new() end

    local entities = hex_grid.get_hex_resource_entities(hex_core)

    local base_cost
    if state.is_well then
        base_cost = lib.runtime_setting_value "supercharge-cost-per-well"
    else
        base_cost = lib.runtime_setting_value "supercharge-cost-per-tile"
    end

    local total_value = 0
    for _, e in pairs(entities) do
        local products = e.prototype.mineable_properties.products
        for _, product in pairs(products) do
            if product.type == "item" or product.type == "fluid" then
                total_value = total_value + item_values.get_item_value(hex_core.surface.name, product.name)
            end
        end
    end

    base_cost = base_cost * total_value * lib.runtime_setting_value "supercharge-cost-multiplier"

    if hex_core.surface.name == "vulcanus" then
        base_cost = base_cost * 10
    elseif hex_core.surface.name == "fulgora" then
        base_cost = base_cost * 75
    elseif hex_core.surface.name == "aquilo" then
        base_cost = base_cost * 12345
    end

    return coin_tiers.ceil(coin_tiers.from_base_value(#entities * base_cost))
end

function hex_grid.get_quality_upgrade_cost(hex_core)
    if not hex_core or not hex_core.valid then return coin_tiers.new() end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return coin_tiers.new() end

    local quality = hex_core.quality.next
    if not quality then return coin_tiers.new() end

    quality = quality.name
    local mult = lib.get_quality_value_scale(quality)
    local quality_cost_mult = lib.get_quality_cost_multiplier(quality)

    local base_cost = 0
    for _, trade_id in pairs(state.trades or {}) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade then
            local volume = trades.get_total_value_of_trade(trade.surface_name, trade, quality, quality_cost_mult)
            base_cost = base_cost + volume
        end
    end

    return coin_tiers.ceil(coin_tiers.multiply(coin_tiers.from_base_value(base_cost), mult))
end

---Get the cost of converting a hex's ores.
---@param hex_core LuaEntity
---@return Coin
function hex_grid.get_convert_resources_cost(hex_core)
    if not hex_core or not hex_core.valid then return coin_tiers.new() end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state or not state.ore_entities then return coin_tiers.new() end

    local amounts = hex_grid.get_ore_amounts(state)
    local max_resource = hex_grid.get_most_abundant_ore(state, amounts)
    if not max_resource then return coin_tiers.new() end

    local count = 0
    for name, amount in pairs(amounts) do
        if name ~= max_resource then
            count = count + amount
        end
    end

    local item_value = item_values.get_item_value(hex_core.surface.name, max_resource)
    local mult = lib.runtime_setting_value "resource-conversion-cost-multiplier"
    local cost = coin_tiers.ceil(coin_tiers.multiply(coin_tiers.from_base_value(item_value), count * mult))

    return cost
end

---Get the total minable amount of each type of ore entity in the hex state.
---@param state HexState
---@return {[string]: int}
function hex_grid.get_ore_amounts(state)
    if not state.ore_entities then return {} end
    local amounts = {}
    for _, entity in pairs(state.ore_entities) do
        if entity.valid then
            amounts[entity.name] = (amounts[entity.name] or 0) + entity.amount
        end
    end
    return amounts
end

---Get the total number of ore entities for each type of ore entity in the hex state.
---@param state HexState
---@return {[string]: int}
function hex_grid.get_ore_entity_counts(state)
    if not state.ore_entities then return {} end
    local amounts = {}
    for _, entity in pairs(state.ore_entities) do
        if entity.valid then
            amounts[entity.name] = (amounts[entity.name] or 0) + 1
        end
    end
    return amounts
end

---Return whether the hex state currently has multiple ore types.
---@param state HexState
---@return boolean
function hex_grid.has_multiple_ore_types(state)
    if not state.ore_entities then return false end

    local single_type
    for _, e in pairs(state.ore_entities) do
        if e.valid then
            if single_type then
                if e.name ~= single_type then
                    return true
                end
            else
                single_type = e.name
            end
        end
    end

    return false
end

---Return the name of the most abundant ore in the hex. Returns nil for hexes with no ores.
---@param state HexState
---@param amounts {[string]: int}|nil If not provided, the amounts will be calculated automatically.
---@return string|nil
function hex_grid.get_most_abundant_ore(state, amounts)
    if not amounts then
        amounts = hex_grid.get_ore_entity_counts(state)
    end

    local max_amount = 0
    local max_resource

    for resource, amount in pairs(amounts) do
        if amount > max_amount then
            max_amount = amount
            max_resource = resource
        end
    end

    return max_resource
end

function hex_grid.process_hex_core_pool()
    if not storage.hex_grid.pool then
        hex_grid.setup_pool()
        return
    end

    -- (DEBUGGING) Pool size versus total claimed hex cores validation
    -- local total_states = 0
    -- for surface_name, _ in pairs(storage.hex_grid.surface_hexes) do
    --     for _, s in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
    --         if s.claimed and s.hex_core and s.hex_core.valid then
    --             total_states = total_states + 1
    --         end
    --     end
    -- end
    -- local total_pool = 0
    -- for _, pool in pairs(storage.hex_grid.pool) do
    --     total_pool = total_pool + lib.table_length(pool)
    -- end
    -- if total_pool ~= total_states then
    --     log("ERROR: TOTAL CLAIMED HEX CORES: " .. total_states .. " | TOTAL STATES IN POOL: " .. total_pool)
    -- end

    -- (DEBUGGING) Validate actual total active state count versus tracked total active state count
    -- for idx, pool in pairs(storage.hex_grid.pool) do
    --     total_states = 0
    --     for _, params in pairs(pool) do
    --         local state = hex_grid.get_hex_state_from_pool_params(params)
    --         if state and state.is_active then
    --             total_states = total_states + 1
    --         end
    --     end
    --     local tracked = hex_grid.get_pool_active_count(idx)
    --     if tracked ~= total_states then
    --         log("ERROR: pool_idx = " .. idx .. ": ACTUAL ACTIVE HEX STATES = " .. total_states .. ", TRACKED = " .. tracked)
    --     end
    -- end

    local quality_cost_multipliers = lib.get_quality_cost_multipliers()

    storage.hex_grid.cur_pool_idx = (storage.hex_grid.cur_pool_idx or 0) % #storage.hex_grid.pool + 1
    local pool = storage.hex_grid.pool[storage.hex_grid.cur_pool_idx]

    for _, pool_params in pairs(pool) do
        local state = hex_grid.get_hex_state_from_pool_params(pool_params)
        if state then
            hex_grid.process_hex_core_trades(state, state.hex_core_input_inventory, state.hex_core_output_inventory, quality_cost_multipliers, nil)
            hex_grid.process_strongboxes(state)
            hex_grid.process_hexlight(state)
        end
    end
end

function hex_grid.setup_pool()
    local pool = storage.hex_grid.pool
    if not pool then
        pool = {}
        storage.hex_grid.pool = pool
    end
    local cur_pool = {}
    for surface_id, surface_hexes in pairs(storage.hex_grid.surface_hexes) do
        for q, Q in pairs(surface_hexes) do
            for r, state in pairs(Q) do
                if state.claimed then
                    if #pool >= storage.hex_grid.pool_size then
                        table.insert(pool, cur_pool)
                        cur_pool = {}
                    end
                    table.insert(cur_pool, {surface_id = surface_id, hex_pos = {q = q, r = r}})
                end
            end
        end
    end
    table.insert(pool, cur_pool)
    hex_grid.recalculate_pool_active_counts()
end

---@param state HexState
---@param pool_idx int | nil
function hex_grid.add_to_pool(state, pool_idx)
    if not state.hex_core then
        lib.log_error("hex_grid.add_to_pool: state has no hex core (was the core deleted?)")
        return
    end

    if not storage.hex_grid.pool then
        hex_grid.setup_pool()
    end

    if not next(storage.hex_grid.pool) then
        table.insert(storage.hex_grid.pool, {})
        if not storage.hex_grid.pool_active_counts then
            storage.hex_grid.pool_active_counts = {}
        end
        storage.hex_grid.pool_active_counts[1] = 0
    end

    if not pool_idx then
        -- Select first unfilled pool
        for idx, pool in pairs(storage.hex_grid.pool) do
            if #pool < storage.hex_grid.pool_size then
                pool_idx = idx
                break
            end
        end
        if not pool_idx then
            table.insert(storage.hex_grid.pool, {})
            pool_idx = #storage.hex_grid.pool
            if not storage.hex_grid.pool_active_counts then
                storage.hex_grid.pool_active_counts = {}
            end
            storage.hex_grid.pool_active_counts[pool_idx] = 0
        end
    end

    local pool = storage.hex_grid.pool[pool_idx]
    if not pool then
        if pool_idx ~= #storage.hex_grid.pool + 1 then
            lib.log("hex_grid.add_to_pool: pool index out of range; assuming new pool creation")
            pool_idx = #storage.hex_grid.pool + 1
        end
        pool = {}
        storage.hex_grid.pool[pool_idx] = pool
        if not storage.hex_grid.pool_active_counts then
            storage.hex_grid.pool_active_counts = {}
        end
        storage.hex_grid.pool_active_counts[pool_idx] = 0
    end

    ---@type HexPoolParameters
    local pool_params = {
        surface_id = state.hex_core.surface.index,
        hex_pos = state.position,
    }

    table.insert(pool, pool_params)

    if state.is_active then
        hex_grid.increment_pool_active_count(pool_idx, 1)
    end
end

---@param state HexState
---@param pool_idx int | nil The index of the pool that contains the hex state. If not provided, it is located automatically.
---@param idx_in_pool int | nil The index of the hex state in the pool. If not provided, it is located automatically.
function hex_grid.remove_from_pool(state, pool_idx, idx_in_pool)
    if not storage.hex_grid.pool then return end
    if not state.hex_core then
        lib.log_error("hex_grid.remove_from_pool: state has no hex core (was the core deleted?)")
        return
    end

    local surface_id = state.hex_core.surface.index

    if not pool_idx then
        -- Find pool with this state
        for idx, pool in pairs(storage.hex_grid.pool) do
            for idx2, pool_params in pairs(pool) do
                if pool_params.surface_id == surface_id and axial.equals(pool_params.hex_pos, state.position) then
                    pool_idx = idx
                    idx_in_pool = idx2
                    break
                end
            end
            if pool_idx then break end
        end
        if not pool_idx then return end
    end

    local pool = storage.hex_grid.pool[pool_idx]
    if not pool then
        lib.log_error("hex_grid.remove_from_pool: pool not found at pool index = " .. pool_idx)
        return
    end

    if not idx_in_pool then
        for idx2, pool_params in pairs(pool) do
            if pool_params.surface_id == surface_id and axial.equals(pool_params.hex_pos, state.position) then
                idx_in_pool = idx2
                break
            end
        end
        if not idx_in_pool then return end
    end

    if idx_in_pool <= 0 or idx_in_pool > #pool then
        lib.log_error("hex_grid.remove_from_pool: params not found at index = " .. idx_in_pool .. " in pool at pool index = " .. pool_idx)
        return
    end

    if state.is_active then
        hex_grid.increment_pool_active_count(pool_idx, -1)
    end

    table.remove(pool, idx_in_pool)
    hex_grid.cleanup_empty_pools()
end

---@param state HexState
---@param pool_idx int | nil The index of the pool that contains the hex state. If not provided, it is located automatically.
---@param idx_in_pool int | nil The index of the hex state in the pool. If not provided, it is located automatically.
function hex_grid.relocate_in_pool(state, pool_idx, idx_in_pool)
    hex_grid.remove_from_pool(state, pool_idx, idx_in_pool)
    hex_grid.add_to_pool(state)
end

function hex_grid.verify_pool_sizes()
    -- Ensure that no pools are too large.
    local size = hex_grid.get_pool_size()
    for pool_idx, pool in pairs(storage.hex_grid.pool) do
        if #pool > size then
            for idx_in_pool = #pool, size + 1, -1 do
                local params = pool[idx_in_pool]
                local state = hex_grid.get_hex_state_from_pool_params(params)
                if state then
                    hex_grid.relocate_in_pool(state, pool_idx, idx_in_pool)
                end
            end
        end
    end

    -- Ensure that pools are filled in order of first to last, removing unnecessarily empty pools.
    for i = 1, #storage.hex_grid.pool - 1 do
        if i >= #storage.hex_grid.pool then break end
        local pool1 = storage.hex_grid.pool[i]
        for j = 1, size - #pool1 do
            for k = #storage.hex_grid.pool, i + 1, -1 do
                local pool2 = storage.hex_grid.pool[k]
                if pool2 and pool2[1] then
                    local state = hex_grid.get_hex_state_from_pool_params(pool2[1])
                    if state then
                        hex_grid.relocate_in_pool(state, k, 1)
                    end
                    break
                end
            end
        end
    end

    hex_grid.recalculate_pool_active_counts()
end

function hex_grid.cleanup_empty_pools()
    local found = false
    for i = #storage.hex_grid.pool, 1, -1 do
        if not next(storage.hex_grid.pool[i]) then
            if found then
                table.remove(storage.hex_grid.pool, i)
                if storage.hex_grid.pool_active_counts then
                    table.remove(storage.hex_grid.pool_active_counts, i)
                end
            else
                found = true
            end
        end
    end
end

---@param size int
function hex_grid.set_pool_size(size)
    if size < 1 then
        lib.log_error("hex_grid.set_pool_size: size is too small")
        return
    end

    storage.hex_grid.pool_size = size
    hex_grid.verify_pool_sizes()
end

---@return int
function hex_grid.get_pool_size()
    return storage.hex_grid.pool_size
end

---@param params HexPoolParameters
---@return HexState|nil
function hex_grid.get_hex_state_from_pool_params(params)
    return hex_state_manager.get_hex_state(params.surface_id, params.hex_pos)
end

function hex_grid.count_active_hexes(pool)
    local total = 0

    for _, params in pairs(pool) do
        local state = hex_grid.get_hex_state_from_pool_params(params)
        if state and state.is_active then
            total = total + 1
        end
    end

    return total
end

function hex_grid.recalculate_pool_active_counts()
    if not storage.hex_grid.pool_active_counts then
        storage.hex_grid.pool_active_counts = {}
    end
    for pool_idx, pool in pairs(storage.hex_grid.pool) do
        storage.hex_grid.pool_active_counts[pool_idx] = hex_grid.count_active_hexes(pool)
    end
end

function hex_grid.get_pool_active_count(pool_idx)
    if not storage.hex_grid.pool_active_counts then
        hex_grid.recalculate_pool_active_counts()
    end
    return storage.hex_grid.pool_active_counts[pool_idx] or 0
end

function hex_grid.increment_pool_active_count(pool_idx, delta)
    if not storage.hex_grid.pool_active_counts then
        hex_grid.recalculate_pool_active_counts()
    end
    storage.hex_grid.pool_active_counts[pool_idx] = (storage.hex_grid.pool_active_counts[pool_idx] or 0) + delta
end

---Set whether a hex core state is active in the pool processing.  Return whether the change in activity caused a swapping in pool indices.
---@param state HexState
---@param flag boolean
---@return boolean
function hex_grid._set_state_active(state, flag)
    local hex_core = state.hex_core
    if not hex_core then return false end

    local prev = state.is_active
    if flag ~= prev then
        state.is_active = flag
    end

    if flag == prev then return false end
    if not hex_core.valid then return false end

    local this_pool_idx = storage.hex_grid.cur_pool_idx
    if flag then
        hex_grid.increment_pool_active_count(this_pool_idx, 1)
    else
        hex_grid.increment_pool_active_count(this_pool_idx, -1)
    end

    if not flag then return false end

    -- This hex just became active.
    -- Swap to another pool, if possible.
    -- Find the pool with the fewest active hexes.
    -- If that pool has at least two fewer active hexes than this current one,
    -- swap places with an inactive hex.

    local this_pool = storage.hex_grid.pool[this_pool_idx]
    local this_index_in_pool = hex_grid.get_index_in_pool(this_pool, hex_core.surface.index, state.position)
    if this_index_in_pool == -1 then
        lib.log_error("hex_grid._set_state_active: parameters not found in pool for load balancing")
        return false
    end

    for i, params in pairs(this_pool) do
        local other = hex_grid.get_hex_state_from_pool_params(params)
        if other and not other.is_active then
            -- Bubble down all active hex cores over time, towards the front of the pool for fastest processing in the loop below.
            hex_grid.swap_params_in_pool(this_pool_idx, this_index_in_pool, this_pool_idx, i)
            this_index_in_pool = i
            break
        end
    end

    local num_active_here = hex_grid.get_pool_active_count(this_pool_idx)
    local active_threshold = num_active_here - 2

    local min_pool_idx, target_index_in_pool
    local min_active = num_active_here
    for pool_idx, pool in pairs(storage.hex_grid.pool) do
        if pool_idx ~= this_pool_idx then
            local num_active_there = hex_grid.get_pool_active_count(pool_idx)

            if num_active_there <= active_threshold then
                if num_active_there < min_active then
                    min_pool_idx = pool_idx
                    min_active = num_active_there
                    target_index_in_pool = nil

                    for i, params in pairs(pool) do
                        local other = hex_grid.get_hex_state_from_pool_params(params)
                        if other and not other.is_active then
                            target_index_in_pool = i
                            break
                        end
                    end
                end

                if target_index_in_pool and num_active_there == 0 then
                    break
                end
            end
        end
    end

    if min_pool_idx and target_index_in_pool then
        hex_grid.swap_params_in_pool(this_pool_idx, this_index_in_pool, min_pool_idx, target_index_in_pool)
        return true
    end

    return false
end

---Return whether a hex core state is active in the pool processing.
---@param state HexState
---@return boolean
function hex_grid._get_state_active(state)
    return state.is_active == true
end

---@param pool_idx1 int
---@param index_in_pool1 int
---@param pool_idx2 int
---@param index_in_pool2 int
function hex_grid.swap_params_in_pool(pool_idx1, index_in_pool1, pool_idx2, index_in_pool2)
    local pool1 = storage.hex_grid.pool[pool_idx1]
    local pool2 = storage.hex_grid.pool[pool_idx2]

    local params1 = pool1[index_in_pool1]
    local params2 = pool2[index_in_pool2]

    local state1 = hex_grid.get_hex_state_from_pool_params(params1)
    local state2 = hex_grid.get_hex_state_from_pool_params(params2)

    local active1 = false
    if state1 then
        active1 = state1.is_active
    end

    local active2 = false
    if state2 then
        active2 = state2.is_active
    end

    if active1 ~= active2 then
        -- Tracked active counts must account for this swap
        if active1 then
            hex_grid.increment_pool_active_count(pool_idx1, -1)
            hex_grid.increment_pool_active_count(pool_idx2, 1)
        else
            hex_grid.increment_pool_active_count(pool_idx1, 1)
            hex_grid.increment_pool_active_count(pool_idx2, -1)
        end
    end

    pool1[index_in_pool1], pool2[index_in_pool2] = params2, params1
end

---@param pool HexPoolParameters[]
---@param surface_id int
---@param hex_pos HexPos
---@return integer
function hex_grid.get_index_in_pool(pool, surface_id, hex_pos)
    for i, params in pairs(pool) do
        if params.surface_id == surface_id and params.hex_pos.q == hex_pos.q and params.hex_pos.r == hex_pos.r then
            return i
        end
    end
    return -1
end

-- function hex_grid.recalculate_pool_load_balancing()
--     local resolved
--     repeat
--         resolved = true
--         for _, pool in pairs(storage.hex_grid.pool) do
--             for _, params in pairs(pool) do
--                 local state = hex_grid.get_hex_state_from_pool_params(params)
--                 local prev_active = state.is_active
--                 state.is_active = false -- Trigger recalculation
--                 if prev_active then
--                     if hex_grid._set_state_active(state, true) then
--                         resolved = false
--                     end
--                 end
--             end
--         end
--     until resolved

--     log("Pool active hexes:")
--     for pool_idx, pool in pairs(storage.hex_grid.pool) do
--         log(pool_idx .. ": " .. hex_grid.count_active_hexes(pool))
--     end
-- end

---@param state HexState
---@param inventory_input LuaInventory|LuaTrain|nil
---@param inventory_output LuaInventory|LuaTrain|nil
---@param quality_cost_multipliers {[string]: number}|nil
---@param train_stop LuaEntity|nil
function hex_grid.process_hex_core_trades(state, inventory_input, inventory_output, quality_cost_multipliers, train_stop)
    if not state.trades then return end
    if not state.hex_core or not state.hex_core.valid then return end
    if not inventory_input or not inventory_input.valid then return end
    if not inventory_output or not inventory_output.valid then return end

    local is_input_train = inventory_input.object_name == "LuaTrain"
    local is_output_train = inventory_output.object_name == "LuaTrain"

    -- Check if trades can occur
    local total_items = inventory_input.get_item_count()
    if total_items == 0 then
        if not is_input_train then
            hex_grid._set_state_active(state, false)
        end
        return
    end

    if not is_input_train then
        hex_grid._set_state_active(state, true)
    end

    local max_items_per_output = 100000
    if inventory_output.object_name == "LuaTrain" then
        max_items_per_output = 1000000
    end

    local max_output_batches_per_trade = nil -- No limit

    local cargo_wagons
    if is_input_train or is_output_train then
        ---@cast inventory_input LuaTrain
        ---@cast train_stop LuaEntity
        cargo_wagons = lib.get_cargo_wagons_nearest_to_stop(inventory_input, train_stop)
    end

    -- First try to unload whatever buffer is here.  Without this first check for unloading the buffer, a partially full buffer (which wouldn't completely fill the output inventory) can prevent trading from happening to fill the rest of the output inventory in the same tick.
    hex_grid.try_unload_output_buffer(state, inventory_output, cargo_wagons)

    local total_removed, total_inserted, remaining_to_insert, total_coins_removed, total_coins_added = trades.process_trades_in_inventories(state.hex_core.surface.index, inventory_input, inventory_output, state.trades, quality_cost_multipliers, true, max_items_per_output, max_output_batches_per_trade, cargo_wagons)
    hex_grid.add_to_output_buffer(state, remaining_to_insert)

    -- Now try to unload whatever was just traded.
    hex_grid.try_unload_output_buffer(state, inventory_output, cargo_wagons)

    if not state.total_items_sold then
        state.total_items_sold = {}
    end
    lib.add_to_quality_item_counts(state.total_items_sold, total_removed)

    if not state.total_items_bought then
        state.total_items_bought = {}
    end
    lib.add_to_quality_item_counts(state.total_items_bought, total_inserted)

    if not state.total_coins_produced then
        state.total_coins_produced = coin_tiers.new()
    end
    state.total_coins_produced = coin_tiers.add(state.total_coins_produced, total_coins_added)

    if not state.total_coins_consumed then
        state.total_coins_consumed = coin_tiers.new()
    end
    state.total_coins_consumed = coin_tiers.add(state.total_coins_consumed, total_coins_removed)

    hex_grid.process_flying_text(state, total_removed, total_inserted, total_coins_added, total_coins_removed)
end

function hex_grid.process_flying_text(state, total_removed, total_inserted, total_coins_added, total_coins_removed)
    if game.tick < (state.next_flying_text or 0) then
        return
    end

    if not next(total_inserted) and not next(total_removed) then
        return
    end

    state.next_flying_text = game.tick + 40

    local str = ""
    local any_output = false

    for quality, counts in pairs(total_removed) do
        for item_name, count in pairs(counts) do
            if count > 0 then
                str = str .. "[item=" .. item_name .. ",quality=" .. quality .. "]"
            end
        end
    end

    for tier = 4, 1, -1 do
        local c = total_coins_removed.values[tier]
        if c > 0 then
            str = str .. "[item=" .. lib.get_coin_name_of_tier(tier) .. "]"
            break
        end
    end

    str = str .. " [img=trade-arrow] "

    for tier = 4, 1, -1 do
        local c = total_coins_added.values[tier]
        if c > 0 then
            str = str .. "[item=" .. lib.get_coin_name_of_tier(tier) .. "]"
            any_output = true
            break
        end
    end

    for quality, counts in pairs(total_inserted) do
        for item_name, count in pairs(counts) do
            if count > 0 then
                str = str .. "[item=" .. item_name .. ",quality=" .. quality .. "]"
                any_output = true
            end
        end
    end

    if not any_output then
        str = {"", str, "[img=virtual-signal.signal-deny]"} ---@diagnostic disable-line
    end

    if not storage.hex_grid.show_trade_flying_text then
        storage.hex_grid.show_trade_flying_text = {}
    end

    for _, player in pairs(game.connected_players) do
        local show = storage.hex_grid.show_trade_flying_text[player.index]
        if show == nil then
            show = lib.player_setting_value(player, "trade-flying-text")
            storage.hex_grid.show_trade_flying_text[player.index] = show
        end
        if show then
            player.create_local_flying_text {text=str, position=state.hex_core.position, surface=state.hex_core.surface, speed=0.7, time_to_live=200}
        end
    end
end

---Keep the loot in the strongboxes update to date with the current item buffs.
---@param state HexState
function hex_grid.process_strongboxes(state)
    if not state.hex_core or not state.strongboxes or not next(state.strongboxes) then return end

    local planet_loot_scale = hex_grid.get_planet_coin_scaling(state.hex_core.surface.name)
    for _, sb_entity in pairs(state.strongboxes) do
        if sb_entity.valid then
            strongboxes.insert_loot(sb_entity, planet_loot_scale)
        end
    end
end

function hex_grid.process_hexlight(state)
    local hex_core = state.hex_core
    if not state.hexlight or not hex_core then return end

    -- TODO: Check if this really saves UPS.  Idea is to not check for (and add) six signal values if no red or green signals exist at all.
    if not state.claimed or not hex_core.get_circuit_network(defines.wire_connector_id.circuit_red) and not hex_core.get_circuit_network(defines.wire_connector_id.circuit_green) then
        local col
        if state.is_dungeon then
            col = storage.hex_grid.dungeon_hexlight_color
        else
            col = storage.hex_grid.default_hexlight_color[hex_core.surface.name]
        end
        state.hexlight.color = col
        state.hexlight2.color = col
        return
    end

    local R = math.min(255, math.max(0, hex_core.get_signal({type = "virtual", name = "signal-red"}, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)))
    local G = math.min(255, math.max(0, hex_core.get_signal({type = "virtual", name = "signal-green"}, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)))
    local B = math.min(255, math.max(0, hex_core.get_signal({type = "virtual", name = "signal-blue"}, defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green)))

    if R == 0 and G == 0 and B == 0 then
        local col = storage.hex_grid.default_hexlight_color[hex_core.surface.name]
        state.hexlight.color = col
        state.hexlight2.color = col
        return
    end

    local col = {R / 255, G / 255, B / 255}
    state.hexlight.color = col
    state.hexlight2.color = col

    if not quests.is_complete "color-coding" then
        if R == 64 then
            gameplay_statistics.set("give-hexlight-color", 1, {"red", 64})
        end
        if G == 255 then
            gameplay_statistics.set("give-hexlight-color", 1, {"green", 255})
        end
        if B == 128 then
            gameplay_statistics.set("give-hexlight-color", 1, {"blue", 128})
        end
    end
end

function hex_grid.add_to_output_buffer(state, items)
    if not state.output_buffer then
        state.output_buffer = {}
    end
    for quality, _items in pairs(items) do
        if not state.output_buffer[quality] then
            state.output_buffer[quality] = {}
        end
        for item_name, count in pairs(_items) do
            if count <= 0 then
                lib.log_error("hex_grid.add_to_output_buffer: Tried to add a negative amount of items to the output buffer: " .. serpent.block(_items))
            else
                state.output_buffer[quality][item_name] = (state.output_buffer[quality][item_name] or 0) + count
            end
        end
    end
end

function hex_grid.remove_from_output_buffer(state, items)
    if not state.output_buffer then
        state.output_buffer = {}
    end
    for quality, _items in pairs(items) do
        if not state.output_buffer[quality] then
            state.output_buffer[quality] = {}
        end
        for item_name, count in pairs(_items) do
            state.output_buffer[quality][item_name] = (state.output_buffer[quality][item_name] or 0) - count
            if state.output_buffer[quality][item_name] <= 0 then
                state.output_buffer[quality][item_name] = nil
            end
        end
    end
end

---Return whether the buffer is empty after unloading.
---@param state table
---@param inventory_output LuaInventory|LuaTrain|nil
---@param cargo_wagons LuaEntity[]|nil
---@return boolean
function hex_grid.try_unload_output_buffer(state, inventory_output, cargo_wagons)
    if not state.output_buffer or not next(state.output_buffer) then return true end
    if not inventory_output or not inventory_output.valid then return next(state.output_buffer) == nil end

    local is_train = inventory_output.object_name == "LuaTrain"

    local empty = true
    for quality, counts in pairs(state.output_buffer) do
        for item_name, count in pairs(counts) do
            if count < 1 then
                counts[item_name] = nil
            else
                local inserted
                if is_train then
                    inserted = lib.insert_into_train(cargo_wagons or {}, {name = item_name, count = math.min(10000, count), quality = quality}, storage.item_buffs.train_trading_capacity)
                else
                    inserted = inventory_output.insert {name = item_name, count = math.min(10000, count), quality = quality}
                end

                local remaining = counts[item_name] - inserted
                empty = empty and remaining == 0

                if remaining > 0 then
                    counts[item_name] = remaining
                else
                    counts[item_name] = nil
                end
            end
        end
    end

    return empty
end

---Re-fetch settings and force-set all hexlight colors on the given surface.
---@param surface_name string|nil If not provided, all surfaces are updated.
function hex_grid.update_hexlight_default_colors(surface_name)
    if surface_name == nil then
        local dungeon_color = lib.runtime_setting_value "dungeon-hexlight-color"
        ---@cast dungeon_color Color

        storage.hex_grid.dungeon_hexlight_color = dungeon_color

        for _surface_name, _ in pairs(storage.item_values.values) do -- intended to iterate over ALL, not just the existing ones
            hex_grid.update_hexlight_default_colors(_surface_name)
        end

        return
    end

    if not storage.hex_grid.default_hexlight_color then
        storage.hex_grid.default_hexlight_color = {}
    end

    local color = lib.runtime_setting_value("default-" .. surface_name .. "-hexlight-color")
    ---@cast color Color

    storage.hex_grid.default_hexlight_color[surface_name] = color

    local dungeon_color = storage.hex_grid.dungeon_hexlight_color

    lib.log("Setting default hexlight color on " .. surface_name .. " to " .. serpent.line(color))

    if not game.get_surface(surface_name) then return end

    local surface_hexes = hex_state_manager.get_surface_hexes(surface_name)
    if not surface_hexes then return end

    for _, Q in pairs(surface_hexes) do
        for _, state in pairs(Q) do
            if state.hexlight then
                if state.is_dungeon then
                    state.hexlight.color = dungeon_color
                    state.hexlight2.color = dungeon_color
                else
                    state.hexlight.color = color
                    state.hexlight2.color = color
                end
            end
        end
    end
end

---Recalculate the productivities of all trades for a given surface.
---@param surface SurfaceIdentification|nil If not provided, automatically call this function on all existing surfaces that Hextorio affects.
function hex_grid.update_all_trades(surface)
    if surface == nil then
        for surface_id, _ in pairs(storage.hex_grid.surface_hexes) do
            hex_grid.update_all_trades(surface_id)
        end
        return
    end

    local surface_hexes = hex_state_manager.get_surface_hexes(surface)
    if not surface_hexes then return end

    for _, Q in pairs(surface_hexes) do
        for _, state in pairs(Q) do
            if state.trades then
                for _, trade_id in pairs(state.trades) do
                    local trade = trades.get_trade_from_id(trade_id)
                    if trade then
                        trades.check_productivity(trade)
                    end
                end
            end
        end
    end
end

function hex_grid.get_states_with_fewest_trades(surface_name, claimed_only)
    if claimed_only == nil then claimed_only = true end
    local states = {}
    local num_trades = math.huge
    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface_name)) do
        if state.hex_core and (state.claimed or not claimed_only) then
            if state.trades and #state.trades > 0 then
                if #state.trades < num_trades then
                    num_trades = #state.trades
                    states = {state}
                elseif #state.trades == num_trades then
                    table.insert(states, state)
                end
            else
                if num_trades > 0 then
                    states = {state}
                else
                    table.insert(states, state)
                end
            end
        end
    end
    return states
end

function hex_grid.apply_extra_trades_bonus_retro(item_name)
    if not lib.is_catalog_item(item_name) then return end
    local added_trades = {}
    for surface_id, flattened_surface_hexes in pairs(storage.hex_grid.flattened_surface_hexes) do
        local surface = game.get_surface(surface_id)
        if surface and not lib.is_space_platform(surface) then
            local volume = item_values.get_item_value(surface.name, item_name)
            if not item_values.is_item_interplanetary(surface.name, item_name) then
                for _, hex_pos in pairs(flattened_surface_hexes) do
                    local state = hex_state_manager.get_hex_state(surface, hex_pos)
                    if state and state.trades then
                        local trade = hex_grid.apply_extra_trade_bonus(state, item_name, volume)
                        if trade and trade.hex_core_state then
                            -- Avoid interfering with currently active trading lines by deactivating the new trade.
                            trades.set_trade_active(trade, false)
                            table.insert(added_trades, trade)
                        end
                    end
                end
            end
        end
    end
    if next(added_trades) then
        local hex_cores_str = ""
        for i, trade in ipairs(added_trades) do
            if i > 1 then
                hex_cores_str = hex_cores_str .. "   "
            end
            hex_cores_str = hex_cores_str .. lib.get_gps_str_from_hex_core(trade.hex_core_state.hex_core)
        end
        lib.print_notification("extra-trade", {"", lib.color_localized_string({"hextorio.bonus-trades-retro", "[img=item." .. item_name .. "]"}, "yellow", "heading-1"), "\n", hex_cores_str})
    end
end

function hex_grid.apply_interplanetary_trade_bonus(state, item_name)
    if not state.hex_core then return end

    local surface_name = state.hex_core.surface.name

    if not item_name then
        for _item_name, _ in pairs(trades.get_interplanetary_trade_items(surface_name, state.position)) do
            hex_grid.apply_interplanetary_trade_bonus(state, _item_name)
        end
        return
    end

    local trade
    local rank = item_ranks.get_item_rank(item_name)
    if rank >= 3 then
        trade = trades.new_coin_trade(surface_name, item_name, storage.trades.base_trade_efficiency)
        if trade then
            -- Avoid interfering with currently active trading lines by deactivating the new trade.
            trades.set_trade_active(trade, false)

            hex_grid.add_trade(state, trade)
        else
            lib.log_error("hex_grid.apply_interplanetary_trade_bonus: Could not generate interplanetary trade")
        end
    end

    if trade then
        lib.print_notification("interplanetary-trade", {"",
            "[space-age] ",
            lib.color_localized_string(
                {
                    "hextorio.bonus-trade-interplanetary",
                    "[img=item." .. item_name .. "]"
                },
                "cyan", "heading-1"
            ),
            " ",
            lib.get_gps_str_from_hex_core(state.hex_core),
            " ",
            lib.get_trade_img_str(trade),
        })
    end
end

function hex_grid.apply_interplanetary_trade_bonus_retro(surface_name, item_name, hex_pos)
    local state = hex_state_manager.get_hex_state(surface_name, hex_pos)
    if not state or not state.hex_core then return end

    hex_grid.apply_interplanetary_trade_bonus(state, item_name)
end

function hex_grid.try_recover_trade(trade, states, notify)
    local continue = false
    for _, item_name in pairs(trades.get_item_names_in_trade(trade)) do
        if lib.is_catalog_item(item_name) then
            local rank = item_ranks.get_item_rank(item_name)
            if rank >= 4 then
                continue = true
                break
            end
        end
    end
    if not continue then return end
    if not states then
        states = hex_grid.get_states_with_fewest_trades(trade.surface_name)
    end
    if #states > 0 then
        -- Avoid interfering with currently active trading lines by deactivating the relocated trade.
        trades.set_trade_active(trade, false)

        local state = states[math.random(1, #states)]
        hex_grid.add_trade(state, trade)

        if notify then
            local item_name
            for _, _item_name in pairs(trades.get_item_names_in_trade(trade)) do
                if item_ranks.get_item_rank(_item_name) >= 4 then
                    item_name = _item_name
                    break
                end
            end
            if item_name then
                lib.print_notification("trade-recovered", {
                    "",
                    lib.color_localized_string(
                        {
                            "hextorio.trade-recovered",
                            "[img=item." .. item_name .. "]",
                        },
                        "purple",
                        "heading-1"
                    ),
                    " ",
                    lib.get_gps_str_from_hex_core(state.hex_core),
                    " ",
                    lib.get_trade_img_str(trade),
                })
            end
        end
    else
        -- This should never happen, but it's here just in case.
        lib.log_error("hex_grid.try_recover_trade: No states found with minimal trades.")
    end
end

function hex_grid.recover_trades_retro(item_name)
    if not lib.is_catalog_item(item_name) then return end

    for _, surface in pairs(game.surfaces) do
        if not lib.is_space_platform(surface) then
            local states = hex_grid.get_states_with_fewest_trades(surface.name)
            for _, trade_id in pairs(trades.get_recoverable_trades()) do
                local trade = trades.get_trade_from_id(trade_id)
                if trade and trade.surface_name == surface.name and trades.has_item(trade, item_name) then
                    trades.recover_trade(trade)
                    hex_grid.try_recover_trade(trade, states, true)
                end
            end
        end
    end
end

function hex_grid.reduce_biters(portion)
    local transformation = terrain.get_surface_transformation "nauvis"
    if not transformation then return end

    storage.hex_grid.total_biter_multiplier = (storage.total_biter_multiplier or 1) * (1 - portion)
    local surface = game.surfaces.nauvis

    local total = 0
    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes "nauvis") do
        if state.is_biters then
            if math.random() < portion then
                -- TODO: Switch to storing spawner/worm entities in hex state, will reduce risk of bugs if system is extended or reused later, especially if for modded entities
                local entities = surface.find_entities_filtered {
                    force = "enemy",
                    position = axial.get_hex_center(state.position, transformation.scale, transformation.rotation),
                    radius = transformation.scale,
                }
                for _, e in pairs(entities) do
                    if e.valid then
                        if e.type == "unit-spawner" then
                            total = total + 1
                        end
                        e.destroy()
                    end
                end
            end
        end
    end

    gameplay_statistics.increment("total-spawners-killed", total)
end

---@param surface_name string
---@return number
function hex_grid.get_trade_volume_base(surface_name)
    if not storage.trades.trade_volume_base then
        storage.trades.trade_volume_base = {}
    end
    local val = storage.trades.trade_volume_base[surface_name]
    if val then return val end
    local min_item = item_values.get_items_sorted_by_value(surface_name, true, false)[1]
    if not min_item then
        lib.log_error("hex_grid.get_trade_volume_base: No minimal item found, defaulting to 1")
        return 1
    end
    val = item_values.get_item_value(surface_name, min_item) * 1.5
    storage.trades.trade_volume_base[surface_name] = val
    return val
end

---@return HexCoreStats
function hex_grid.get_hex_core_stats(state)
    if not state then
        lib.log_error("hex_grid.get_hex_core_stats: No hex state provided")
        return {
            total_items_produced = {},
            total_items_consumed = {},
            total_coins_produced = coin_tiers.new(),
            total_coins_consumed = coin_tiers.new(),
        }
    end

    local stats = {
        total_items_produced = table.deepcopy(state.total_items_bought or {}),
        total_items_consumed = table.deepcopy(state.total_items_sold or {}),
        total_coins_produced = coin_tiers.copy(state.total_coins_produced or coin_tiers.new()),
        total_coins_consumed = coin_tiers.copy(state.total_coins_consumed or coin_tiers.new()),
    }

    return stats
end

---Get the mutiplier of the strongbox loot value and claim costs on a given surface.
---@param surface_name string
function hex_grid.get_planet_coin_scaling(surface_name)
    --TODO: optimize this function (cache results, they are constant)
    if lib.is_t2_planet(surface_name) then
        return storage.coin_tiers.TIER_SCALING
    elseif lib.is_t3_planet(surface_name) then
        return storage.coin_tiers.TIER_SCALING ^ 1.5
    end
    return 1
end

---Calculate the claim cost for a hex at some position on a given surface.
---@param surface LuaSurface
---@param hex_pos HexPos
---@return Coin
function hex_grid.calculate_hex_claim_price(surface, hex_pos)
    local dist = hex_island.get_distance_from_spawn(surface.name, hex_pos)
    if not dist then
        lib.log_error("hex_grid.calculate_hex_claim_price: Tried to get the distance to a non-land hex: " .. serpent.line(hex_pos))
        dist = 0
    end

    local coin_scaling = hex_grid.get_planet_coin_scaling(surface.name)
    local claim_price = (dist + 1) * (dist + 1) * coin_scaling

    local coin = coin_tiers.from_base_value(claim_price)
    local mult = hex_grid.get_claim_cost_multiplier(surface.name)
    coin = coin_tiers.floor(coin_tiers.multiply(coin, mult))

    if coin_tiers.is_negative(coin) or coin_tiers.is_zero(coin) then
        coin = coin_tiers.from_base_value(1)
    end

    return coin
end

---Get the multiplier of the cost of hex claims for a given surface, from the mod settings.
---@param surface_name string
---@return number
function hex_grid.get_claim_cost_multiplier(surface_name)
    local mult = storage.hex_grid.claim_cost_multiplier[surface_name]
    if not mult then
        mult = 1
        lib.log_error("hex_grid.get_claim_cost_multiplier: Multiplier not found for surface " .. surface_name)
    end
    return mult
end

---@param surface_name string|nil
function hex_grid.fetch_claim_cost_multiplier_settings(surface_name)
    if not surface_name then
        for _surface_name, _ in pairs(storage.item_values.values) do
            hex_grid.fetch_claim_cost_multiplier_settings(_surface_name)
        end
        return
    end

    if not storage.hex_grid.claim_cost_multiplier then
        storage.hex_grid.claim_cost_multiplier = {}
    end

    local val = lib.runtime_setting_value_as_number("hex-claim-cost-mult-" .. surface_name)
    storage.hex_grid.claim_cost_multiplier[surface_name] = val
end

---@param surface_name string
function hex_grid.update_all_hex_claim_costs(surface_name)
    local surface = game.get_surface(surface_name)
    if not surface then return end
    for _, state in pairs(hex_state_manager.get_flattened_surface_hexes(surface)) do
        if state.hex_core then
            -- Claim cost affects delete core cost, so also check claimed hexes
            state.claim_price = hex_grid.calculate_hex_claim_price(surface, state.position)
        end
    end
end

---@param train LuaTrain
---@param train_stop LuaEntity
function hex_grid.on_train_arrived_at_stop(train, train_stop)
    if not storage.train_trading.allow_two_headed_trains and lib.is_train_two_headed(train) then return end
    if not quests.is_feature_unlocked "locomotive-trading" then return end

    local transformation = terrain.get_surface_transformation(train_stop.surface)
    local hex_pos = axial.get_hex_containing(train_stop.position, transformation.scale, transformation.rotation)
    local state = hex_state_manager.get_hex_state(train_stop.surface, hex_pos)
    if not state then return end

    if not state.allow_locomotive_trading then return end

    local inventory_output
    if state.send_outputs_to_cargo_wagons then
        inventory_output = train
    else
        inventory_output = state.hex_core_output_inventory
    end

    local quality_cost_multipliers = lib.get_quality_cost_multipliers()
    hex_grid.process_hex_core_trades(state, train, inventory_output, quality_cost_multipliers, train_stop)
end

---@param entity LuaEntity
function hex_grid.on_entity_built(entity)
    if not entity.valid then return end

    if entity.type == "constant-combinator" then
        hex_grid.copy_signals_to_combinator(entity)
    end
end

function hex_grid.on_setting_changed_unresearched_penalty()
    trades.recalculate_researched_items()

    local penalty = lib.runtime_setting_value "unresearched-penalty"
    ---@cast penalty number

    storage.trades.unresearched_penalty = penalty
    trades.queue_productivity_update_job()
end

---@param sb_entity LuaEntity
function hex_grid.on_strongbox_killed(sb_entity)
    local cur_tier = entity_util.get_tier_of_strongbox(sb_entity)
    if not cur_tier then return end

    local inv = sb_entity.get_inventory(defines.inventory.chest)
    if not inv then return end

    local next_tier = math.min(storage.strongboxes.max_tier, cur_tier + 1)
    local coin_loot = inventories.get_coin_from_inventory(inv)

    storage.strongboxes.total_coins_earned = coin_tiers.add(storage.strongboxes.total_coins_earned or coin_tiers.new(), coin_loot)
    gameplay_statistics.increment "total-strongbox-level"

    -- Include offline players
    local is_piggy_bank_unlocked = quests.is_feature_unlocked "piggy-bank"
    for _, player in pairs(game.players) do
        if is_piggy_bank_unlocked then
            -- This is to be done without normalizing the entire inventory, to avoid annoying situations where the coins you're about to grab suddenly transfer themselves into your piggy bank.
            piggy_bank.increment_player_stored_coins(player.index, coin_loot)
        else
            -- This would normalize the entire inventory if piggy bank was unlocked (impossible with this flow control).
            local player_inv = lib.get_player_inventory(player)
            if player_inv then
                inventories.add_coin_to_inventory(player_inv, coin_loot)
            end
        end
    end

    local state = hex_state_manager.get_hex_state_from_entity(sb_entity.unit_number)
    if not state then return end

    hex_state_manager.unmap_entity(sb_entity.unit_number)

    -- Respawn chest :D
    local planet_loot_scale = hex_grid.get_planet_coin_scaling(sb_entity.surface.name)
    local new_sb_entity = strongboxes.spawn(sb_entity.surface, sb_entity.position, next_tier, planet_loot_scale)

    if new_sb_entity and new_sb_entity.valid then
        hex_state_manager.map_entity_to_hex_state(new_sb_entity.unit_number, new_sb_entity.surface.name, state.position)
        hex_grid.update_strongbox_entity(state, new_sb_entity)
    end

    gameplay_statistics.increment "total-strongbox-level"
end

---@param player LuaPlayer
---@param entity LuaEntity
---@param previous_direction defines.direction
function hex_grid.on_player_rotated_entity(player, entity, previous_direction)
    if entity.name == "hex-core-loader" then
        hex_grid.handle_hex_core_loader_flip(entity, previous_direction)
    end
end

---@param surface LuaSurface
---@param island HexSet
function hex_grid.on_hex_island_generated(surface, island)
    if surface.name ~= "nauvis" then return end

    local gh = storage.hex_grid.guaranteed_hexaprisms
    if not gh then
        gh = {} ---@type HexSet
        storage.hex_grid.guaranteed_hexaprisms = gh
    end

    local extent = hex_island.get_island_extent(surface.name)

    local min_distance = extent * 0.95
    local max_distance = extent

    local center = {q=0, r=0}
    local candidates = {}
    for q, Q in pairs(island) do
        for r, _ in pairs(Q) do
            local pos = {q=q, r=r}
            local dist = axial.distance(center, pos)
            if dist >= min_distance and dist <= max_distance then
                candidates[#candidates+1] = pos
            end
        end
    end

    -- Sample multiple positions for guaranteed hexaprism spawns.
    for i = 1, 10 do
        if #candidates == 0 then
            lib.log_error("hex_grid.on_hex_island_generated: Ran out of position candidates to force hexaprism placement, after " .. (i-1) .. " successful placements.")
            break
        end

        local pos = table.remove(candidates, math.random(1, #candidates))
        hex_sets.add(gh, pos)
    end
end



return hex_grid
