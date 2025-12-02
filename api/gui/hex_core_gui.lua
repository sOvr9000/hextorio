
local lib = require "api.lib"
local core_gui = require "api.gui.core_gui"
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_grid = require "api.hex_grid"
local coin_tiers  = require "api.coin_tiers"
local trades = require "api.trades"
local event_system = require "api.event_system"
local quests = require "api.quests"
local coin_tier_gui = require "api.gui.coin_tier_gui"
local trades_gui = require "api.gui.trades_gui"
local gui_events    = require "api.gui.gui_events"

local hex_core_gui = {}



function hex_core_gui.register_events()
    event_system.register_callback("trade-processed", function(trade)
        if not trade.hex_core_state or not trade.hex_core_state.hex_core or not trade.hex_core_state.hex_core.valid then return end
        for _, player in pairs(game.connected_players) do
            if player.opened == trade.hex_core_state.hex_core then
                hex_core_gui.update_hex_core(player)
            end
        end
    end)

    event_system.register_callback("hex-claimed", function(surface, state)
        local hex_core = state.hex_core
        if not hex_core or not hex_core.valid then return end
        for _, player in pairs(game.connected_players) do
            if player.opened == hex_core then
                hex_core_gui.update_hex_core(player)
            end
        end
    end)

    event_system.register_callback("player-opened-entity", function(player, entity)
        if entity.valid and entity.name == "hex-core" then
            hex_core_gui.show_hex_core(player)
        end
    end)

    event_system.register_callback("player-closed-entity", function(player, entity)
        if entity.valid and entity.name == "hex-core" then
            hex_core_gui.hide_hex_core(player)
        end
    end)

    event_system.register_callback("trade-toggle-button-clicked", function(player, element)
        hex_core_gui.on_toggle_trade_button_click(player, element)
    end)

    event_system.register_callback("trade-tag-button-clicked", function(player, element)
        hex_core_gui.on_tag_button_click(player, element)
    end)

    event_system.register_callback("trade-add-to-filters-button-clicked", function(player, element)
        hex_core_gui.on_add_to_filters_button_click(player, element)
    end)

    event_system.register_callback("trade-quality-bounds-selected", function(player, element, trade_number)
        hex_core_gui.on_quality_bound_selected(player, element, trade_number)
    end)
end

---Reinitialize the hex core GUI for the given player, or all online players if no player is provided.
---@param player LuaPlayer|nil
function hex_core_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.connected_players) do
            hex_core_gui.reinitialize(p)
        end
        return
    end

    local frame = player.gui.relative["hex-core"]
    if frame then frame.destroy() end

    hex_core_gui.init_hex_core(player)
end

function hex_core_gui.init_hex_core(player)
    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right,
    }
    local frame = player.gui.relative.add {type = "frame", name = "hex-core", direction = "vertical", anchor = anchor}
    frame.caption = {"hex-core-gui.title"}
    -- gui.add_titlebar(hex_core_gui, {"hex-core-gui.title"})
    -- hex_core_gui.style.size = {width = 444, height = 625}
    frame.style.width = 380
    frame.style.natural_height = 625
    frame.style.vertically_stretchable = true
    frame.visible = false

    local resources_header = frame.add {type = "label", name = "resources-header", caption = {"hex-core-gui.initial-resources"}}
    resources_header.style.font = "heading-2"

    local resources_flow = frame.add {type = "flow", name = "resources-flow", direction = "horizontal"}

    frame.add {type = "line", direction = "horizontal"}

    local claim_flow = frame.add {type = "flow", name = "claim-flow", direction = "vertical"}
    local free_hexes_remaining = claim_flow.add {type = "label", name = "free-hexes-remaining"}
    local claim_price = coin_tier_gui.create_coin_tier(claim_flow, "claim-price")
    local claim_hex = claim_flow.add {type = "button", name = "claim-hex", caption = {"hex-core-gui.claim-hex"}, style = "confirm_button"}
    claim_hex.tooltip = {"hex-core-gui.claim-hex-tooltip"}
    gui_events.register(claim_hex, "on-clicked", function() hex_core_gui.on_claim_hex_button_click(player) end)

    local claimed_by = frame.add {type = "label", name = "claimed-by", caption = {"hex-core-gui.claimed-by"}}
    claimed_by.style.font = "heading-2"

    local hex_control_flow = frame.add {type = "table", name = "hex-control-flow", column_count = 5}
    hex_control_flow.visible = false

    local teleport = hex_control_flow.add {type = "sprite-button", name = "teleport", sprite = "virtual-signal/down-arrow"}
    teleport.tooltip = {"hex-core-gui.teleport-tooltip"}
    gui_events.register(teleport, "on-clicked", function() hex_core_gui.on_teleport_button_click(player, teleport) end)

    local toggle_hexport = hex_control_flow.add {type = "sprite-button", name = "toggle-hexport", sprite = "item/roboport"}
    toggle_hexport.tooltip = {"hex-core-gui.toggle-hexport-tooltip"}
    gui_events.register(toggle_hexport, "on-clicked", function() hex_core_gui.on_toggle_hexport_button_click(player, toggle_hexport) end)

    local supercharge = hex_control_flow.add {type = "sprite-button", name = "supercharge", sprite = "item/electric-mining-drill"}
    gui_events.register(supercharge, "on-clicked", function() hex_core_gui.on_supercharge_button_click(player, supercharge) end)

    local sink_mode = hex_control_flow.add {type = "sprite-button", name = "sink-mode", sprite = "virtual-signal/signal-input"}
    sink_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.sink-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.sink-mode-tooltip-body"}}
    gui_events.register(sink_mode, "on-clicked", function() hex_core_gui.on_hex_mode_button_click(player, sink_mode) end)

    local generator_mode = hex_control_flow.add {type = "sprite-button", name = "generator-mode", sprite = "virtual-signal/signal-output"}
    generator_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.generator-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.generator-mode-tooltip-body"}}
    gui_events.register(generator_mode, "on-clicked", function() hex_core_gui.on_hex_mode_button_click(player, generator_mode) end)

    local sink_mode_confirmation = frame.add {type = "sprite-button", name = "sink-mode-confirmation", sprite = "check-mark-green"}
    sink_mode_confirmation.tooltip = {"hex-core-gui.sink-mode-confirmation-tooltip"}
    gui_events.register(sink_mode_confirmation, "on-clicked", function() hex_core_gui.on_confirmation_button_click(player, sink_mode_confirmation) end)

    local generator_mode_confirmation = frame.add {type = "sprite-button", name = "generator-mode-confirmation", sprite = "check-mark-green"}
    generator_mode_confirmation.tooltip = {"hex-core-gui.generator-mode-confirmation-tooltip"}
    gui_events.register(generator_mode_confirmation, "on-clicked", function() hex_core_gui.on_confirmation_button_click(player, generator_mode_confirmation) end)

    local stats = hex_control_flow.add {type = "sprite-button", name = "stats", sprite = "utility/side_menu_production_icon"}

    local delete_core = hex_control_flow.add {type = "sprite-button", name = "delete-core", sprite = "utility/empty_trash_slot"}
    gui_events.register(delete_core, "on-clicked", function() hex_core_gui.on_delete_core_button_click(player, delete_core) end)

    local upgrade_quality = hex_control_flow.add {type = "sprite-button", name = "upgrade-quality", sprite = "quality/uncommon"}
    gui_events.register(upgrade_quality, "on-clicked", function() hex_core_gui.on_upgrade_quality_button_click(player, upgrade_quality) end)

    local convert_resources = hex_control_flow.add {type = "sprite-button", name = "convert-resources", sprite = "virtual-signal.signal-recycle"}
    convert_resources.tooltip = {"", lib.color_localized_string({"hex-core-gui.convert-resources-tooltip-header"}, "blue", "heading-2"), "\n", {"hex-core-gui.convert-resources-tooltip-body"}}
    gui_events.register(convert_resources, "on-clicked", function() hex_core_gui.on_convert_resources_button_click(player, convert_resources) end)

    local delete_core_confirmation = frame.add {type = "flow", name = "delete-core-confirmation", direction = "horizontal"}
    delete_core_confirmation.visible = false

    local delete_core_confirmation_button = delete_core_confirmation.add {type = "sprite-button", name = "confirmation-button", sprite = "utility/empty_trash_slot"}
    local delete_core_confirmation_label = delete_core_confirmation.add {type = "label", name = "confirmation-label", caption = lib.color_localized_string({"hex-core-gui.delete-core-confirmation"}, "red")}
    delete_core_confirmation_label.style.font = "heading-1"
    gui_events.register(delete_core_confirmation_button, "on-clicked", function() hex_core_gui.on_confirmation_button_click(player, delete_core_confirmation_button) end)

    frame.add {type = "line", direction = "horizontal"}

    local trades_header_flow = frame.add {type = "flow", name = "trades-header", direction = "horizontal"}
    local trades_header_label = trades_header_flow.add {type = "label", name = "label", caption = {"hex-core-gui.trades-header"}}
    trades_header_label.style.font = "heading-1"

    local quality_dropdown = core_gui.create_quality_dropdown(trades_header_flow)
    local quality_dropdown_info = trades_header_flow.add {type = "label", name = "info", caption = "[img=virtual-signal.signal-info]"}
    quality_dropdown_info.tooltip = {"hex-core-gui.quality-dropdown-info"}
    quality_dropdown_info.style.top_margin = 4
    gui_events.register(quality_dropdown, "on-selection-changed", function(value) hex_core_gui.update_hex_core(player) end)

    local trades_scroll_pane = frame.add {type = "scroll-pane", name = "trades", direction = "vertical"}
    core_gui.auto_width_height(trades_scroll_pane)
end

function hex_core_gui.update_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then
        hex_core_gui.init_hex_core(player)
        frame = player.gui.relative["hex-core"]
    end

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    frame["hex-control-flow"]["delete-core"].visible = quests.is_feature_unlocked "hex-core-deletion"
    frame["sink-mode-confirmation"].visible = false
    frame["generator-mode-confirmation"].visible = false

    local quality_unlocked = game.forces.player.is_quality_unlocked(prototypes.quality.uncommon)
    frame["trades-header"]["quality-dropdown"].visible = quality_unlocked
    frame["trades-header"]["info"].visible = quality_unlocked

    if state.claimed then
        frame["claim-flow"].visible = false
        local claimed_by_name = state.claimed_by or {"hextorio.server"}
        local claimed_timestamp = state.claimed_timestamp or 0
        frame["claimed-by"].visible = true
        frame["claimed-by"].caption = {"hex-core-gui.claimed-by", claimed_by_name, lib.ticks_to_string(claimed_timestamp)}

        frame["hex-control-flow"].visible = true
        frame["hex-control-flow"]["stats"].tooltip = lib.get_str_from_hex_core_stats(hex_grid.get_hex_core_stats(state))
        frame["hex-control-flow"]["teleport"].visible = quests.is_feature_unlocked "teleportation" and not lib.is_player_editor_like(player) and state.hex_core ~= nil and player.character ~= nil and player.character.surface.name == state.hex_core.surface.name
        frame["hex-control-flow"]["toggle-hexport"].visible = quests.is_feature_unlocked "hexports"

        if state.hexport then
            frame["hex-control-flow"]["toggle-hexport"].sprite = "item/roboport"
        else
            frame["hex-control-flow"]["toggle-hexport"].sprite = "no-roboport"
        end

        frame["hex-control-flow"]["supercharge"].visible = not state.is_infinite and quests.is_feature_unlocked "supercharging"
        if frame["hex-control-flow"]["supercharge"].visible then
            local cost = hex_grid.get_supercharge_cost(hex_core)
            frame["hex-control-flow"]["supercharge"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.supercharge-tooltip-header"}, "orange", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(cost)},
                "\n",
                {"hex-core-gui.supercharge-tooltip-body"},
            }
        end

        frame["hex-control-flow"]["convert-resources"].visible = quests.is_feature_unlocked "resource-conversion" and hex_grid.has_multiple_ore_types(state)
        if frame["hex-control-flow"]["convert-resources"].visible then
            local cost = hex_grid.get_convert_resources_cost(hex_core)
            frame["hex-control-flow"]["convert-resources"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.convert-resources-tooltip-header"}, "blue", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(cost)},
                "\n",
                {"hex-core-gui.convert-resources-tooltip-body", "[item=" .. hex_grid.get_most_abundant_ore(state) .. "]"},
            }
        end

        frame["hex-control-flow"]["delete-core"].enabled = true
        frame["hex-control-flow"]["delete-core"].visible = quests.is_feature_unlocked "hex-core-deletion" and hex_grid.can_delete_hex_core(hex_core)
        if frame["hex-control-flow"]["delete-core"].visible then
            local cost = hex_grid.get_delete_core_cost(hex_core)
            frame["hex-control-flow"]["delete-core"].tooltip = {"",
                lib.color_localized_string({"hex-core-gui.delete-core-tooltip-header"}, "red", "heading-2"),
                "\n",
                {"hextorio-gui.cost", coin_tiers.coin_to_text(cost)},
                "\n",
                {"hex-core-gui.delete-core-tooltip-body"},
            }
        end

        frame["hex-control-flow"]["sink-mode"].visible = state.mode == nil and quests.is_feature_unlocked "sink-mode"
        frame["hex-control-flow"]["generator-mode"].visible = state.mode == nil and quests.is_feature_unlocked "generator-mode"

        local next_quality = hex_core.quality.next
        if next_quality then
            local next_quality_tier = lib.get_quality_tier(next_quality.name)
            frame["hex-control-flow"]["upgrade-quality"].visible = lib.is_quality_tier_unlocked(next_quality_tier)
            if frame["hex-control-flow"]["upgrade-quality"].visible then
                frame["hex-control-flow"]["upgrade-quality"].sprite = "quality/" .. next_quality.name
                frame["hex-control-flow"]["upgrade-quality"].tooltip = {"",
                    lib.color_localized_string({"hex-core-gui.upgrade-quality-tooltip-header"}, "green", "heading-2"),
                    "\n",
                    {"hextorio-gui.cost", coin_tiers.coin_to_text(hex_grid.get_quality_upgrade_cost(hex_core))},
                    "\n",
                    {"hex-core-gui.upgrade-quality-tooltip-body"},
                }
            end
        else
            frame["hex-control-flow"]["upgrade-quality"].visible = false
        end
    else
        frame["claim-flow"].visible = true
        frame["claimed-by"].visible = false

        frame["hex-control-flow"].visible = false

        if hex_grid.get_free_hex_claims(hex_core.surface.name) > 0 then
            frame["claim-flow"]["free-hexes-remaining"].visible = true
            frame["claim-flow"]["free-hexes-remaining"].caption = {"", lib.color_localized_string({"hextorio-gui.quest-reward"}, "white", "heading-2"), " ", {"hextorio-gui.quest-reward-free-hexes-remaining", hex_grid.get_free_hex_claims(hex_core.surface.name), "green", "heading-2"}}
            coin_tier_gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin_tiers.new())
        else
            frame["claim-flow"]["free-hexes-remaining"].visible = false
            local coin = state.claim_price
            coin_tier_gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin)
        end
    end

    frame["delete-core-confirmation"].visible = false
    -- frame["unloader-filters-flow"].visible = false

    local quality_dropdown = frame["trades-header"]["quality-dropdown"]
    local quality_name = core_gui.get_quality_name_from_dropdown(quality_dropdown)

    local show_quality_bounds = false
    if state.claimed then
        show_quality_bounds = lib.get_highest_unlocked_quality().name ~= "normal"
    end

    trades_gui.update_trades_scroll_pane(player, frame.trades, trades.convert_trade_id_array_to_trade_array(state.trades), {
        show_toggle_trade = state.claimed,
        show_tag_creator = true,
        show_ping_button = true,
        show_add_to_filters = state.claimed,
        show_core_finder = false,
        show_productivity_bar = true,
        show_quality_bounds = show_quality_bounds,
        quality_to_show = quality_name,
        show_productivity_info = true,
        expanded = true,
        is_configuration_unlocked = quests.is_feature_unlocked "trade-configuration",
    })

    hex_core_gui.update_hex_core_resources(player)
end

function hex_core_gui.update_hex_core_resources(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then
        lib.log_error("gui.update_hex_core_resources: hex-core frame could not be found")
        return
    end

    local resources_flow = frame["resources-flow"]
    if not resources_flow then
        lib.log_error("gui.update_hex_core_resources: resources-flow could not be found")
        return
    end

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then
        lib.log_error("gui.update_hex_core_resources: hex_core entity could not be found")
        return
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then
        lib.log_error("gui.update_hex_core_resources: hex_core state could not be found")
        return
    end

    local resources = state.resources or {}

    resources_flow.clear()
    for resource_name, amount in pairs(resources) do
        if state.is_infinite then
            amount = 1000000000000
        end
        local sprite = "item/" .. resource_name
        if state.is_well or state.is_oil then -- is_oil for <=0.2.3, should make this a function
            sprite = "entity/" .. resource_name
        end
        local resource = resources_flow.add {
            type = "sprite-button",
            sprite = sprite,
            number = amount,
        }
        core_gui.give_item_tooltip(player, hex_core.surface.name, resource)
    end

    if not next(resources) then
        resources_flow.add {
            type = "label",
            name = "no-resources",
            caption = {"hextorio.none"},
        }
    end
end

function hex_core_gui.is_hex_core_open(player)
    local frame = player.gui.relative["hex-core"]
    return frame ~= nil and frame.visible
end

function hex_core_gui.show_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    -- if not frame then
    --     hex_core_gui.init_hex_core(player)
    --     frame = player.gui.relative["hex-core"]
    -- end
    frame.visible = true
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.hide_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    if not frame then return end
    frame.visible = false
end

function hex_core_gui.on_toggle_trade_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_serial = tonumber(element.name:sub(14)) -- The location in the hex's trades listing
    local trade_id = state.trades[trade_serial] -- The global identifier of the trade
    if not trade_id then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    trades.set_trade_active(trade, not trades.is_active(trade))
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.on_hex_core_trade_control_flow_button_clicked(player, element)
    if element.name:sub(1, 13) == "toggle-trade-" then
        hex_core_gui.on_toggle_trade_button_click(player, element)
    elseif element.name:sub(1, 15) == "add-to-filters-" then
        hex_core_gui.on_add_to_filters_button_click(player, element)
    end
end

function hex_core_gui.on_add_to_filters_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_number = tonumber(element.name:sub(16))
    local trade_id = state.trades[trade_number]
    if not trade_id then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    local _, output_item_names = trades.get_input_output_item_names_of_trade(trade)
    hex_grid.add_items_to_unloader_filters(state, output_item_names)
end

function hex_core_gui.on_trade_item_clicked(player, element)
    if not quests.is_feature_unlocked "catalog" then return end

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local item_name = element.sprite:sub(6)

    event_system.trigger("hex-core-trade-item-clicked", item_name) -- Show the trade overview
end

function hex_core_gui.on_hex_mode_button_click(player, element)
    local mode = element.name:sub(1, -6)
    element.parent.parent[mode .. "-mode-confirmation"].visible = true
end

function hex_core_gui.on_hex_mode_confirmation_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local mode = element.name:sub(1, -19)
    local succeeded = hex_grid.switch_hex_core_mode(state, mode)

    if succeeded then
        for _, elem in pairs(element.parent.children) do
            if elem.name:sub(-5) == "-mode" then
                elem.visible = false
            end
        end

        hex_core_gui.update_hex_core(player)
    end
end

function hex_core_gui.on_convert_resources_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_convert_resources_cost(hex_core)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    coin_tiers.remove_coin_from_inventory(inv, coin)

    hex_grid.convert_resources(hex_core)
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.on_upgrade_quality_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_quality_upgrade_cost(hex_core)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    coin_tiers.remove_coin_from_inventory(inv, coin)

    hex_grid.upgrade_quality(hex_core)
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.on_supercharge_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    if state.is_infinite then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_supercharge_cost(hex_core)
    local inv_coin = coin_tiers.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    coin_tiers.remove_coin_from_inventory(inv, coin)

    hex_grid.supercharge_resources(hex_core)
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.on_claim_hex_button_click(player)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then
        lib.log_error("on_claim_hex_button_click: Couldn't find hex core")
        return
    end

    local transformation = terrain.get_surface_transformation(hex_core.surface)

    if not transformation then
        lib.log_error("on_claim_hex_button_click: No transformation found")
        return
    end

    local hex_pos = axial.get_hex_containing(hex_core.position, transformation.scale, transformation.rotation)

    if not hex_grid.can_claim_hex(player, player.surface, hex_pos) then
        local state = hex_grid.get_hex_state(hex_core.surface.index, hex_pos)
        if state.is_dungeon then
            player.print(lib.color_localized_string({"hextorio.loot-dungeon-first"}, "red"))
        else
            player.print(lib.color_localized_string({"hextorio.cannot-afford"}, "red"))
        end
        return
    end

    hex_grid.add_hex_to_claim_queue(hex_core.surface, hex_pos, player)
end

function hex_core_gui.on_delete_core_button_click(player, element)
    element.parent.parent["delete-core-confirmation"].visible = true
    element.enabled = false
end

function hex_core_gui.on_teleport_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end
    if hex_core.surface.name ~= player.surface.name then return end

    lib.teleport_player(player, hex_core.position, hex_core.surface)
end

function hex_core_gui.on_toggle_hexport_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    if state.hexport then
        hex_grid.remove_hexport(state)
        element.sprite = "no-roboport"
    else
        hex_grid.spawn_hexport(state)
        element.sprite = "item/roboport"
    end
end

function hex_core_gui.on_confirmation_button_click(player, element)
    if element.parent.name == "delete-core-confirmation" then
        local hex_core = lib.get_player_opened_entity(player)
        if not hex_core then return end

        local inv = lib.get_player_inventory(player)
        if not inv then return end

        local coin = hex_grid.get_delete_core_cost(hex_core)
        local inv_coin = coin_tiers.get_coin_from_inventory(inv)
        if coin_tiers.gt(coin, inv_coin) then
            player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
            return
        end

        coin_tiers.remove_coin_from_inventory(inv, coin)

        hex_grid.delete_hex_core(hex_core)
        core_gui.hide_all_frames(player)
    end
end

function hex_core_gui.on_tag_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local trade_serial = tonumber(element.name:sub(12))
    local trade_id = state.trades[trade_serial]
    if not trade_id then return end

    local trade = trades.get_trade_from_id(trade_id)
    if not trade then return end

    local trade_str = lib.get_trade_img_str(trade, trades.is_interplanetary_trade(trade))

    state.tags_created = (state.tags_created or -1) + 1

    player.force.add_chart_tag(state.hex_core.surface, {
        position = {x = state.hex_core.position.x, y = state.hex_core.position.y + state.tags_created * 4, surface = state.hex_core.surface},
        -- icon = {type = "entity", name = "hex-core"},
        text = trade_str,
        quality = state.hex_core.quality,
    })

    quests.set_progress_for_type("create-trade-map-tag", 1)
end

function hex_core_gui.on_quality_bound_selected(player, element, trade_number)
    local signal = element.elem_value

    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    if not signal then
        hex_core_gui._reset_quality_bound(element, hex_core.quality.name)
        signal = element.elem_value
    elseif signal.type ~= "quality" then
        player.print({"hextorio.invalid-quality-selected"})
        hex_core_gui._reset_quality_bound(element, hex_core.quality.name)
        signal = element.elem_value
    end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    trade = trades.get_trade_from_id(state.trades[trade_number])
    if not trade then return end

    local adjusted = false
    if element.name:sub(1, 12) == "min-quality-" then
        adjusted = not hex_grid.set_trade_allowed_qualities(hex_core, trade, signal.name, trade.allowed_qualities[1])
    elseif element.name:sub(1, 12) == "max-quality-" then
        adjusted = not hex_grid.set_trade_allowed_qualities(hex_core, trade, trade.allowed_qualities[#trade.allowed_qualities], signal.name)
    end

    if adjusted then
        player.print({"hextorio.quality-bounds-adjusted"})
        element.elem_value = nil
    end

    hex_core_gui.update_hex_core(player)
end

---Reset a choose-elem-button's element value to a valid quality.
---@param element LuaGuiElement
---@param hex_core_quality string|nil
function hex_core_gui._reset_quality_bound(element, hex_core_quality)
    if element.name:sub(1, 12) == "min-quality-" then
        element.elem_value = {type = "quality", name = "normal"}
    elseif element.name:sub(1, 12) == "max-quality-" then
        local quality_tier = lib.get_quality_tier(lib.get_highest_unlocked_quality().name)
        if hex_core_quality then
            quality_tier = math.min(quality_tier, lib.get_quality_tier(hex_core_quality))
        end
        element.elem_value = {type = "quality", name = lib.get_quality_at_tier(quality_tier)}
    end
end



return hex_core_gui
