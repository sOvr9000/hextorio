local lib = require "api.lib"
local sets = require "api.sets"
local item_values = require "api.item_values"
local trade_loop_finder = require "api.trade_loop_finder"
local weighted_choice = require "api.weighted_choice"
local event_system = require "api.event_system"

local tournament_trades = {}

local VERSION = 1
local PLANET_DEFAULT_ORDERS = {
    nauvis = "3",
    vulcanus = "7",
    fulgora = "7",
    gleba = "7",
    aquilo = "19",
}
local PLANET_ORDER = {"nauvis", "vulcanus", "fulgora", "gleba", "aquilo"}
local RESIDUES_BY_ORDER = {
    [3] = {1},
    [7] = {1, 2, 4},
    [19] = {1, 4, 5, 6, 7, 9, 11, 16, 17},
}
local FALLBACK_REASONS = {
    disabled = true,
    legacy_surface = true,
}

function tournament_trades.register_events()
    local function reset()
        tournament_trades.reset_storage()
    end

    event_system.register("runtime-setting-changed-tournament-trades-enabled", reset)
    event_system.register("runtime-setting-changed-tournament-order-nauvis", reset)
    event_system.register("runtime-setting-changed-tournament-order-vulcanus", reset)
    event_system.register("runtime-setting-changed-tournament-order-fulgora", reset)
    event_system.register("runtime-setting-changed-tournament-order-gleba", reset)
    event_system.register("runtime-setting-changed-tournament-order-aquilo", reset)
    event_system.register("runtime-setting-changed-tournament-coin-trade-policy", reset)
    event_system.register("runtime-setting-changed-tournament-coin-bin-index", reset)
    event_system.register("runtime-setting-changed-tournament-binning-mode", reset)
    event_system.register("runtime-setting-changed-tournament-strictness", reset)
    event_system.register("runtime-setting-changed-tournament-efficiency-profile", reset)
    event_system.register("post-item-values-recalculated", reset)
end

function tournament_trades.init()
    tournament_trades.ensure_storage()
end

function tournament_trades.ensure_storage()
    if not storage.trades then return end
    local t = storage.trades.tournament
    if not t or t.version ~= VERSION then
        t = {
            version = VERSION,
            enabled = false,
            settings_hash = "",
            per_surface = {},
        }
        storage.trades.tournament = t
    end

    t.enabled = lib.runtime_setting_value_as_boolean "tournament-trades-enabled"
    t.settings_hash = tournament_trades.get_settings_hash()
    t.per_surface = t.per_surface or {}
    return t
end

function tournament_trades.reset_storage()
    if not storage.trades then return end
    storage.trades.tournament = {
        version = VERSION,
        enabled = lib.runtime_setting_value_as_boolean "tournament-trades-enabled",
        settings_hash = tournament_trades.get_settings_hash(),
        per_surface = {},
    }
end

function tournament_trades.get_settings_hash()
    local parts = {
        tostring(lib.runtime_setting_value_as_boolean "tournament-trades-enabled"),
        lib.runtime_setting_value_as_string "tournament-coin-trade-policy",
        tostring(lib.runtime_setting_value_as_int "tournament-coin-bin-index"),
        lib.runtime_setting_value_as_string "tournament-binning-mode",
        lib.runtime_setting_value_as_string "tournament-strictness",
        lib.runtime_setting_value_as_string "tournament-efficiency-profile",
    }

    for _, surface_name in ipairs(PLANET_ORDER) do
        parts[#parts + 1] = surface_name .. ":" .. tournament_trades.get_order_setting_value(surface_name)
    end

    return table.concat(parts, "|")
end

function tournament_trades.get_order_setting_value(surface_name)
    local setting_name = "tournament-order-" .. surface_name
    local ok, value = pcall(lib.runtime_setting_value_as_string, setting_name)
    if ok and value then return value end
    return PLANET_DEFAULT_ORDERS[surface_name] or "legacy"
end

function tournament_trades.resolve_order(surface_name, ignore_disabled)
    if not ignore_disabled and not lib.runtime_setting_value_as_boolean "tournament-trades-enabled" then
        return nil, "disabled"
    end
    if not storage.SUPPORTED_PLANETS or not storage.SUPPORTED_PLANETS[surface_name] then
        return nil, "unsupported_surface"
    end

    local value = tournament_trades.get_order_setting_value(surface_name)
    if value == "legacy" then
        return nil, "legacy_surface"
    end

    local order = tonumber(value)
    if not order or not RESIDUES_BY_ORDER[order] then
        return nil, "unsupported_order"
    end

    return order
end

function tournament_trades.get_coin_policy()
    return lib.runtime_setting_value_as_string "tournament-coin-trade-policy"
end

function tournament_trades.get_coin_bin(order)
    local configured = lib.runtime_setting_value_as_int "tournament-coin-bin-index"
    if configured < 1 or configured > order then
        return 1, configured
    end
    return configured, configured
end

function tournament_trades.get_residues(order)
    return RESIDUES_BY_ORDER[order]
end

function tournament_trades.edge_distance(order, source_bin, dest_bin)
    local distance = (dest_bin - source_bin) % order
    if distance == 0 then return nil end
    return distance
end

function tournament_trades.is_legal_edge(order, source_bin, dest_bin)
    local distance = tournament_trades.edge_distance(order, source_bin, dest_bin)
    if not distance then return false end
    for _, residue in ipairs(tournament_trades.get_residues(order)) do
        if residue == distance then
            return true
        end
    end
    return false
end

function tournament_trades.classify_edge(order, distance)
    if distance == 1 then
        return "main-cycle"
    end

    local chords = {}
    for _, residue in ipairs(tournament_trades.get_residues(order)) do
        if residue ~= 1 then
            chords[#chords + 1] = residue
        end
    end
    table.sort(chords)

    for i, residue in ipairs(chords) do
        if residue == distance then
            if i <= math.ceil(#chords / 2) then
                return "short-chord"
            end
            return "long-chord"
        end
    end

    return "invalid"
end

function tournament_trades.edge_weight(edge_type)
    if edge_type == "main-cycle" then return 3 end
    if edge_type == "short-chord" then return 2 end
    if edge_type == "long-chord" then return 2 end
    return 0
end

function tournament_trades.efficiency_multiplier(edge_type)
    local profile = lib.runtime_setting_value_as_string "tournament-efficiency-profile"
    if profile == "off" then
        return 1
    end
    if profile == "cycle-bonus-and-chord-penalty" then
        if edge_type == "main-cycle" then return 1.08 end
        if edge_type == "short-chord" then return 0.9 end
        if edge_type == "long-chord" then return 0.8 end
    elseif profile == "chord-penalty" then
        if edge_type == "short-chord" then return 0.92 end
        if edge_type == "long-chord" then return 0.84 end
    end
    return 1
end

function tournament_trades.get_eligible_items(surface_name, coin_policy)
    local surface_vals = item_values.get_item_values_for_surface(surface_name, false) or {}
    local items = {}

    for item_name, value in pairs(surface_vals) do
        if value and value > 0 and value < math.huge and lib.is_item(item_name) and item_values.is_item_tradable(surface_name, item_name) then
            local prot = prototypes.item[item_name]
            if prot and not prot.hidden and (coin_policy ~= "legacy" or not lib.is_coin(item_name)) then
                items[#items + 1] = item_name
            end
        end
    end

    if coin_policy ~= "legacy" then
        for _, coin_name in ipairs(storage.coin_tiers.COIN_NAMES) do
            if lib.is_item(coin_name) then
                items[#items + 1] = coin_name
            end
        end
    end

    local seen = {}
    local deduped = {}
    for _, item_name in ipairs(items) do
        if not seen[item_name] then
            seen[item_name] = true
            deduped[#deduped + 1] = item_name
        end
    end

    table.sort(deduped, function(a, b)
        local av = item_values.get_item_value(surface_name, a)
        local bv = item_values.get_item_value(surface_name, b)
        if av == bv then return a < b end
        return av < bv
    end)

    return deduped
end

function tournament_trades.create_empty_bins(order)
    local bins = {}
    for i = 1, order do
        bins[i] = {
            bin_index = i,
            items = {},
            contains_coins = false,
            coin_only = false,
            non_coin_item_count = 0,
            total_item_count = 0,
            min_value = nil,
            max_value = nil,
            median_value = nil,
            warnings = {},
        }
    end
    return bins
end

function tournament_trades.add_item_to_bin(surface_name, bins, item_to_bin, item_name, bin_index)
    local bin = bins[bin_index]
    bin.items[#bin.items + 1] = item_name
    item_to_bin[item_name] = bin_index

    local is_coin = lib.is_coin(item_name)
    bin.contains_coins = bin.contains_coins or is_coin
    if not is_coin then
        bin.non_coin_item_count = bin.non_coin_item_count + 1
    end
    bin.total_item_count = bin.total_item_count + 1

    local value = item_values.get_item_value(surface_name, item_name)
    bin.min_value = math.min(bin.min_value or value, value)
    bin.max_value = math.max(bin.max_value or value, value)
end

function tournament_trades.finalize_bin_stats(surface_name, bins)
    for _, bin in ipairs(bins) do
        table.sort(bin.items, function(a, b)
            local av = item_values.get_item_value(surface_name, a)
            local bv = item_values.get_item_value(surface_name, b)
            if av == bv then return a < b end
            return av < bv
        end)
        bin.coin_only = bin.contains_coins and bin.non_coin_item_count == 0
        if #bin.items > 0 then
            local median_item = bin.items[math.ceil(#bin.items / 2)]
            bin.median_value = item_values.get_item_value(surface_name, median_item)
        end
    end
end

function tournament_trades.build_surface_data(surface_name, ignore_disabled)
    tournament_trades.ensure_storage()

    local order, reason = tournament_trades.resolve_order(surface_name, ignore_disabled)
    if not order then
        return nil, reason
    end

    local coin_policy = tournament_trades.get_coin_policy()
    local coin_bin, configured_coin_bin = tournament_trades.get_coin_bin(order)
    local bins = tournament_trades.create_empty_bins(order)
    local item_to_bin = {}
    local allowed_bins = {}
    for i = 1, order do
        if coin_policy ~= "unique-coin-bin" or i ~= coin_bin then
            allowed_bins[#allowed_bins + 1] = i
        end
    end

    local normal_items = {}
    for _, item_name in ipairs(tournament_trades.get_eligible_items(surface_name, coin_policy)) do
        if lib.is_coin(item_name) then
            if coin_policy ~= "legacy" then
                tournament_trades.add_item_to_bin(surface_name, bins, item_to_bin, item_name, coin_bin)
            end
        else
            normal_items[#normal_items + 1] = item_name
        end
    end

    for i, item_name in ipairs(normal_items) do
        local target_bin = allowed_bins[((i - 1) % #allowed_bins) + 1]
        tournament_trades.add_item_to_bin(surface_name, bins, item_to_bin, item_name, target_bin)
    end

    tournament_trades.finalize_bin_stats(surface_name, bins)

    local graph = tournament_trades.build_graph(order)
    local surface_data = {
        surface_name = surface_name,
        order = order,
        coin_policy = coin_policy,
        coin_bin = coin_bin,
        configured_coin_bin = configured_coin_bin,
        residues = table.deepcopy(tournament_trades.get_residues(order)),
        item_to_bin = item_to_bin,
        bins = bins,
        bin_stats = bins,
        graph = graph,
        created_tick = game and game.tick or 0,
        generation = {},
        validation = {},
    }

    storage.trades.tournament.per_surface[surface_name] = surface_data
    return surface_data
end

function tournament_trades.get_surface_data(surface_name, ignore_disabled)
    local t = tournament_trades.ensure_storage()
    local order, reason = tournament_trades.resolve_order(surface_name, ignore_disabled)
    if not order then
        return nil, reason
    end

    local settings_hash = tournament_trades.get_settings_hash()
    if t.settings_hash ~= settings_hash then
        t.settings_hash = settings_hash
        t.per_surface = {}
    end

    local surface_data = t.per_surface[surface_name]
    if surface_data and surface_data.order == order then
        return surface_data
    end

    return tournament_trades.build_surface_data(surface_name, ignore_disabled)
end

function tournament_trades.build_graph(order)
    local graph = {}
    for source_bin = 1, order do
        graph[source_bin] = {}
        for _, distance in ipairs(tournament_trades.get_residues(order)) do
            local dest_bin = ((source_bin + distance - 1) % order) + 1
            local edge_type = tournament_trades.classify_edge(order, distance)
            graph[source_bin][#graph[source_bin] + 1] = {
                source_bin = source_bin,
                dest_bin = dest_bin,
                distance = distance,
                edge_type = edge_type,
                weight = tournament_trades.edge_weight(edge_type),
            }
        end
    end
    return graph
end

function tournament_trades.choose_edge(surface_data, include_item)
    local weighted_edges = {}
    local include_bin = include_item and surface_data.item_to_bin[include_item] or nil

    for source_bin, edges in pairs(surface_data.graph) do
        for _, edge in ipairs(edges) do
            if #surface_data.bins[source_bin].items > 0 and #surface_data.bins[edge.dest_bin].items > 0 then
                local include_matches = not include_bin or include_bin == source_bin or include_bin == edge.dest_bin
                if include_matches then
                    weighted_edges[#weighted_edges + 1] = {item = edge, weight = edge.weight}
                end
            end
        end
    end

    local wc = weighted_choice.from_list(weighted_edges)
    if not wc then return end
    return weighted_choice.choice(wc)
end

function tournament_trades.choose_items_from_bin(bin, count, include_item)
    if #bin.items == 0 then return {} end

    local names = {}
    local used = {}
    if include_item then
        names[#names + 1] = include_item
        used[include_item] = true
    end

    local attempts = #bin.items * 2
    while #names < count and attempts > 0 do
        attempts = attempts - 1
        local item_name = bin.items[math.random(1, #bin.items)]
        if not used[item_name] then
            names[#names + 1] = item_name
            used[item_name] = true
        end
    end

    return names
end

function tournament_trades.validate_tentative(tentative, surface_data)
    local source_bin = tentative.tournament_source_bin
    local dest_bin = tentative.tournament_dest_bin
    if not tournament_trades.is_legal_edge(surface_data.order, source_bin, dest_bin) then
        return false, "illegal-edge"
    end

    for _, input_item in ipairs(tentative.input_items) do
        if surface_data.item_to_bin[input_item.name] ~= source_bin then
            return false, "input-bin-mismatch"
        end
    end
    for _, output_item in ipairs(tentative.output_items) do
        if surface_data.item_to_bin[output_item.name] ~= dest_bin then
            return false, "output-bin-mismatch"
        end
    end

    return true
end

function tournament_trades.make_tentative(surface_name, input_item_names, output_item_names, params, metadata, generator)
    local input_items = {}
    local output_items = {}
    for i, name in ipairs(input_item_names) do
        input_items[i] = {name = name}
    end
    for i, name in ipairs(output_item_names) do
        output_items[i] = {name = name}
    end

    local tentative = {
        surface_name = surface_name,
        input_items = input_items,
        output_items = output_items,
    }
    for key, value in pairs(metadata) do
        tentative[key] = value
    end

    local solved = generator.solve_item_counts(surface_name, tentative, params)
    if not solved and params.allow_nil_return then
        return nil
    end
    return tentative
end

function tournament_trades.generate_once(surface_name, volume, params, allow_untradable, include_item, generator, ignore_disabled)
    local surface_data, reason = tournament_trades.get_surface_data(surface_name, ignore_disabled)
    if not surface_data then
        return nil, reason
    end

    if include_item and lib.is_coin(include_item) and surface_data.coin_policy == "legacy" then
        return nil, "legacy-coin-policy"
    end

    local edge = tournament_trades.choose_edge(surface_data, include_item)
    if not edge then
        return nil, "no-eligible-edge"
    end

    local num_inputs, num_outputs = generator._generate_random_trade_shape()
    local include_side = nil
    if include_item then
        local include_bin = surface_data.item_to_bin[include_item]
        if include_bin == edge.source_bin then
            include_side = "input"
        elseif include_bin == edge.dest_bin then
            include_side = "output"
        else
            return nil, "included-item-unbinned"
        end
    end

    local input_item_names = tournament_trades.choose_items_from_bin(surface_data.bins[edge.source_bin], num_inputs, include_side == "input" and include_item or nil)
    local output_item_names = tournament_trades.choose_items_from_bin(surface_data.bins[edge.dest_bin], num_outputs, include_side == "output" and include_item or nil)
    if #input_item_names == 0 or #output_item_names == 0 then
        return nil, "empty-side"
    end

    local generation_params = table.deepcopy(params)
    generator.set_trade_generation_parameter_defaults(generation_params)
    if generation_params.scale_target_efficiency_by_items then
        generation_params.scale_target_efficiency_by_items = false
        generator.scale_trade_efficiency_by_total_items(generation_params, #input_item_names + #output_item_names)
    end

    local mult = tournament_trades.efficiency_multiplier(edge.edge_type)
    generation_params.target_efficiency = generation_params.target_efficiency * mult

    local metadata = {
        tournament_managed = true,
        tournament_surface = surface_name,
        tournament_order = surface_data.order,
        tournament_source_bin = edge.source_bin,
        tournament_dest_bin = edge.dest_bin,
        tournament_edge_distance = edge.distance,
        tournament_edge_type = edge.edge_type,
        tournament_efficiency_multiplier = mult,
        tournament_binning_generation = surface_data.created_tick,
        tournament_coin_policy = surface_data.coin_policy,
        tournament_coin_bin = surface_data.coin_bin,
    }

    local tentative = tournament_trades.make_tentative(surface_name, input_item_names, output_item_names, generation_params, metadata, generator)
    if not tentative then
        return nil, "solve-failed"
    end

    local valid, validation_reason = tournament_trades.validate_tentative(tentative, surface_data)
    if not valid then
        return nil, validation_reason
    end

    return tentative
end

function tournament_trades.generate_random(surface_name, existing_trades, volume, params, allow_untradable, include_item, generator)
    local order, reason = tournament_trades.resolve_order(surface_name)
    if not order then
        return nil, reason
    end

    local strictness = lib.runtime_setting_value_as_string "tournament-strictness"
    local candidate_trades = table.deepcopy(existing_trades)
    local slot = #candidate_trades + 1
    local last_reason = nil

    for _ = 1, 10 do
        local tentative, attempt_reason = tournament_trades.generate_once(surface_name, volume, params, allow_untradable, include_item, generator)
        last_reason = attempt_reason
        if tentative then
            candidate_trades[slot] = tentative
            if not next(trade_loop_finder.find_simple_loops(candidate_trades)) then
                return tentative
            end
            last_reason = "simple-loop"
        end
    end

    if strictness == "strict" then
        lib.log_error("tournament_trades.generate_random: failed on " .. surface_name .. " (" .. tostring(last_reason) .. ")")
        return nil, last_reason
    elseif strictness == "skip-invalid" then
        return nil, last_reason
    end

    return nil, last_reason or "fallback-legacy"
end

function tournament_trades.should_fallback(reason)
    return reason and (FALLBACK_REASONS[reason] or lib.runtime_setting_value_as_string "tournament-strictness" == "fallback-legacy")
end

function tournament_trades.validate_graph(order)
    local result = {passed = true, warnings = {}, failures = {}}
    local residues = tournament_trades.get_residues(order)
    local expected_out = #residues

    for source_bin = 1, order do
        local count = 0
        for dest_bin = 1, order do
            if source_bin ~= dest_bin and tournament_trades.is_legal_edge(order, source_bin, dest_bin) then
                count = count + 1
                if tournament_trades.is_legal_edge(order, dest_bin, source_bin) then
                    result.passed = false
                    result.failures[#result.failures + 1] = "double edge " .. source_bin .. "<->" .. dest_bin
                end
            end
        end
        if count ~= expected_out then
            result.passed = false
            result.failures[#result.failures + 1] = "bin " .. source_bin .. " has " .. count .. " outgoing edges; expected " .. expected_out
        end
    end

    return result
end

function tournament_trades.validate_bins(surface_data)
    local result = {passed = true, warnings = {}, failures = {}}
    if surface_data.configured_coin_bin ~= surface_data.coin_bin then
        result.warnings[#result.warnings + 1] = "configured coin bin " .. surface_data.configured_coin_bin .. " exceeds order " .. surface_data.order .. "; using 1"
    end

    local coin_items = 0
    local non_coin_in_coin_bin = 0
    for _, coin_name in ipairs(storage.coin_tiers.COIN_NAMES) do
        local bin = surface_data.item_to_bin[coin_name]
        if surface_data.coin_policy == "legacy" then
            if bin then
                result.passed = false
                result.failures[#result.failures + 1] = "coin binned under legacy policy: " .. coin_name
            end
        else
            if bin ~= surface_data.coin_bin then
                result.passed = false
                result.failures[#result.failures + 1] = "coin in wrong bin: " .. coin_name
            else
                coin_items = coin_items + 1
            end
        end
    end

    local coin_bin = surface_data.bins[surface_data.coin_bin]
    if coin_bin then
        non_coin_in_coin_bin = coin_bin.non_coin_item_count
        if surface_data.coin_policy == "unique-coin-bin" and non_coin_in_coin_bin > 0 then
            result.passed = false
            result.failures[#result.failures + 1] = "unique coin bin contains " .. non_coin_in_coin_bin .. " non-coin items"
        end
    end

    result.coin_items = coin_items
    result.non_coin_in_coin_bin = non_coin_in_coin_bin
    return result
end

function tournament_trades.validate_generated(surface_data)
    local result = {passed = true, warnings = {}, failures = {}, checked = 0, managed = 0, exempt_coin = 0}
    local by_surface = ((storage.trades or {}).tree or {}).by_surface or {}
    local surface_trades = by_surface[surface_data.surface_name] or {}
    local all_trades = ((storage.trades or {}).tree or {}).all_trades_lookup or {}

    for trade_id, _ in pairs(surface_trades) do
        local trade = all_trades[trade_id]
        result.checked = result.checked + 1
        if trade and trade.tournament_managed then
            result.managed = result.managed + 1
            local valid, reason = tournament_trades.validate_tentative(trade, surface_data)
            if not valid then
                result.passed = false
                result.failures[#result.failures + 1] = "trade " .. tostring(trade.id) .. ": " .. reason
            end
        elseif trade and surface_data.coin_policy == "legacy" and (trade.has_coins_in_input or trade.has_coins_in_output) then
            result.exempt_coin = result.exempt_coin + 1
        end
    end

    return result
end

function tournament_trades.run_dry_generation(surface_name, surface_data, generator)
    local result = {passed = true, warnings = {}, failures = {}, generated = 0}
    local params = {target_efficiency = storage.trades.base_trade_efficiency or 1, allow_nil_return = true}
    local volume = storage.item_values.base_coin_value or 10

    for _ = 1, math.max(12, surface_data.order) do
        local tentative, reason = tournament_trades.generate_once(surface_name, volume, params, false, nil, generator, true)
        if tentative then
            result.generated = result.generated + 1
        else
            result.warnings[#result.warnings + 1] = "dry generation skipped: " .. tostring(reason)
        end
    end

    if result.generated == 0 then
        result.passed = false
        result.failures[#result.failures + 1] = "dry generation produced no trades"
    end
    return result
end

function tournament_trades.validate_surface(surface_name, scope, generator)
    local surface_data, reason = tournament_trades.get_surface_data(surface_name, true)
    if not surface_data then
        return "Tournament validation for " .. surface_name .. ": " .. tostring(reason)
    end

    scope = scope or "full"
    local lines = {
        "Tournament validation for " .. surface_name,
        "order=" .. surface_data.order .. " policy=" .. surface_data.coin_policy .. " coin_bin=" .. surface_data.coin_bin,
    }

    local function append_result(label, result)
        lines[#lines + 1] = label .. ": " .. (result.passed and "PASS" or "FAIL")
        if result.checked then
            lines[#lines + 1] = "  checked=" .. result.checked .. " managed=" .. result.managed .. " legacy_coin_exempt=" .. result.exempt_coin
        end
        if result.coin_items then
            lines[#lines + 1] = "  coin_items=" .. result.coin_items .. " non_coin_in_coin_bin=" .. result.non_coin_in_coin_bin
        end
        if result.generated then
            lines[#lines + 1] = "  dry_generated=" .. result.generated
        end
        for _, warning in ipairs(result.warnings or {}) do
            lines[#lines + 1] = "  WARN " .. warning
        end
        for _, failure in ipairs(result.failures or {}) do
            lines[#lines + 1] = "  FAIL " .. failure
        end
    end

    if scope == "bins" or scope == "full" then
        append_result("graph", tournament_trades.validate_graph(surface_data.order))
        append_result("bins", tournament_trades.validate_bins(surface_data))
    end
    if scope == "generated" or scope == "full" then
        append_result("generated", tournament_trades.validate_generated(surface_data))
        append_result("dry-run", tournament_trades.run_dry_generation(surface_name, surface_data, generator))
    end
    if scope == "cycles" or scope == "full" then
        local graph = tournament_trades.validate_graph(surface_data.order)
        append_result("cycles", graph)
        lines[#lines + 1] = "  main_cycle_bins=" .. surface_data.order
    end

    return table.concat(lines, "\n")
end

function tournament_trades.validate_command(player, params, generator)
    local surface_name = params[1] or (player and player.surface and player.surface.name) or "nauvis"
    local scope = params[2] or "full"
    if not storage.SUPPORTED_PLANETS[surface_name] then
        if player then
            player.print {"hextorio.command-invalid-surface"}
        else
            game.print("Invalid surface: " .. tostring(surface_name))
        end
        return
    end

    local valid_scopes = sets.new {"bins", "generated", "cycles", "full"}
    if not valid_scopes[scope] then
        local msg = "Invalid scope. Use bins, generated, cycles, or full."
        if player then player.print(msg) else game.print(msg) end
        return
    end

    local output = tournament_trades.validate_surface(surface_name, scope, generator)
    if player then
        player.print(output)
    else
        game.print(output)
    end
    helpers.write_file("hextorio/trade_generator_tests.log", "[TournamentTrades]\n" .. output .. "\n", true)
end

return tournament_trades
