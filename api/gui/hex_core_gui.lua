
local lib = require "api.lib"
local core_gui = require "api.gui.core_gui"
local axial = require "api.axial"
local terrain = require "api.terrain"
local hex_grid = require "api.hex_grid"
local hex_state_manager = require "api.hex_state_manager"
local coin_tiers  = require "api.coin_tiers"
local trades = require "api.trades"
local event_system = require "api.event_system"
local quests = require "api.quests"
local coin_tier_gui = require "api.gui.coin_tier_gui"
local trades_gui = require "api.gui.trades_gui"
local inventories = require "api.inventories"

local hex_core_gui = {}



function hex_core_gui.register_events()
    event_system.register_gui("gui-clicked", "claim-hex", hex_core_gui.on_claim_hex_button_click)
    event_system.register_gui("gui-clicked", "teleport", hex_core_gui.on_teleport_button_click)
    event_system.register_gui("gui-clicked", "quick-trade", hex_core_gui.on_quick_trade_button_click)
    event_system.register_gui("gui-clicked", "toggle-hexport", hex_core_gui.on_toggle_hexport_button_click)
    event_system.register_gui("gui-clicked", "supercharge", hex_core_gui.on_supercharge_button_click)
    event_system.register_gui("gui-clicked", "hex-mode", hex_core_gui.on_hex_mode_button_click)
    event_system.register_gui("gui-clicked", "hex-mode-confirmation", hex_core_gui.on_hex_mode_confirmation_button_click)
    event_system.register_gui("gui-clicked", "delete-core", hex_core_gui.on_delete_core_button_click)
    event_system.register_gui("gui-clicked", "delete-strongbox", hex_core_gui.on_delete_strongbox_button_click)
    event_system.register_gui("gui-clicked", "upgrade-quality", hex_core_gui.on_upgrade_quality_button_click)
    event_system.register_gui("gui-clicked", "convert-resources", hex_core_gui.on_convert_resources_button_click)
    event_system.register_gui("gui-clicked", "confirmation-button", hex_core_gui.on_confirmation_button_click)
    event_system.register_gui("gui-clicked", "allow-locomotive-trading", hex_core_gui.on_allow_locomotive_trading_button_click)
    event_system.register_gui("gui-clicked", "send-outputs-to-cargo-wagons", hex_core_gui.on_send_outputs_to_cargo_wagons_button_click)
    event_system.register_gui("gui-selection-changed", "update-hex-core", hex_core_gui.update_hex_core)

    event_system.register("trade-processed", function(trade)
        if not trade.hex_core_state or not trade.hex_core_state.hex_core or not trade.hex_core_state.hex_core.valid then return end
        for _, player in pairs(game.connected_players) do
            if player.opened == trade.hex_core_state.hex_core then
                hex_core_gui.update_hex_core(player)
            end
        end
    end)

    event_system.register("hex-claimed", function(surface, state)
        local hex_core = state.hex_core
        if not hex_core or not hex_core.valid then return end
        for _, player in pairs(game.connected_players) do
            if player.opened == hex_core then
                hex_core_gui.update_hex_core(player)
            end
        end
    end)

    event_system.register("player-opened-entity", function(player, entity)
        if entity.valid and entity.name == "hex-core" then
            hex_core_gui.show_hex_core(player)
        end
    end)

    event_system.register("player-closed-entity", function(player, entity)
        if entity.valid and entity.name == "hex-core" then
            hex_core_gui.hide_hex_core(player)
        end
    end)

    event_system.register("trade-toggle-button-clicked", function(player, element)
        hex_core_gui.on_toggle_trade_button_click(player, element)
    end)

    event_system.register("trade-tag-button-clicked", function(player, element)
        hex_core_gui.on_tag_button_click(player, element)
    end)

    event_system.register("trade-add-to-filters-button-clicked", function(player, element)
        hex_core_gui.on_add_to_filters_button_click(player, element)
    end)

    event_system.register("trade-quality-bounds-selected", function(player, element, trade_number)
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
    local claim_hex = claim_flow.add {
        type = "button",
        name = "claim-hex",
        caption = {"hex-core-gui.claim-hex"},
        style = "confirm_button",
        tags = {handlers = {["gui-clicked"] = "claim-hex"}},
    }
    claim_hex.tooltip = {"hex-core-gui.claim-hex-tooltip"}

    local claimed_by = frame.add {type = "label", name = "claimed-by", caption = {"hex-core-gui.claimed-by"}}
    claimed_by.style.font = "heading-2"

    local hex_control_flow = frame.add {type = "table", name = "hex-control-flow", column_count = 7}
    hex_control_flow.visible = false

    local teleport = hex_control_flow.add {
        type = "sprite-button",
        name = "teleport",
        sprite = "virtual-signal/down-arrow",
        tags = {handlers = {["gui-clicked"] = "teleport"}},
    }
    teleport.tooltip = {"hex-core-gui.teleport-tooltip"}

    local quick_trade = hex_control_flow.add {
        type = "sprite-button",
        name = "quick-trade",
        sprite = "virtual-signal/signal-rightwards-leftwards-arrow",
        tags = {handlers = {["gui-clicked"] = "quick-trade"}},
    }
    quick_trade.tooltip = {"hex-core-gui.quick-trade-tooltip"}

    local toggle_hexport = hex_control_flow.add {
        type = "sprite-button",
        name = "toggle-hexport",
        sprite = "item/roboport",
        tags = {handlers = {["gui-clicked"] = "toggle-hexport"}},
    }
    toggle_hexport.tooltip = {"hex-core-gui.toggle-hexport-tooltip"}

    local supercharge = hex_control_flow.add {
        type = "sprite-button",
        name = "supercharge",
        sprite = "item/electric-mining-drill",
        tags = {handlers = {["gui-clicked"] = "supercharge"}},
    }

    local delete_core = hex_control_flow.add {
        type = "sprite-button",
        name = "delete-core",
        sprite = "utility/empty_trash_slot",
        tags = {handlers = {["gui-clicked"] = "delete-core"}},
    }

    local sink_mode = hex_control_flow.add {
        type = "sprite-button",
        name = "sink-mode",
        sprite = "virtual-signal/signal-input",
        tags = {handlers = {["gui-clicked"] = "hex-mode"}},
    }
    sink_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.sink-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.sink-mode-tooltip-body"}}

    local generator_mode = hex_control_flow.add {
        type = "sprite-button",
        name = "generator-mode",
        sprite = "virtual-signal/signal-output",
        tags = {handlers = {["gui-clicked"] = "hex-mode"}},
    }
    generator_mode.tooltip = {"", lib.color_localized_string({"hex-core-gui.generator-mode-tooltip-header"}, "red", "heading-2"), "\n", {"hex-core-gui.generator-mode-tooltip-body"}}

    local sink_mode_confirmation = frame.add {
        type = "sprite-button",
        name = "sink-mode-confirmation",
        sprite = "check-mark-green",
        tags = {handlers = {["gui-clicked"] = "hex-mode-confirmation"}},
    }
    sink_mode_confirmation.tooltip = {"hex-core-gui.sink-mode-confirmation-tooltip"}

    local generator_mode_confirmation = frame.add {
        type = "sprite-button",
        name = "generator-mode-confirmation",
        sprite = "check-mark-green",
        tags = {handlers = {["gui-clicked"] = "hex-mode-confirmation"}},
    }
    generator_mode_confirmation.tooltip = {"hex-core-gui.generator-mode-confirmation-tooltip"}

    local stats = hex_control_flow.add {type = "sprite-button", name = "stats", sprite = "utility/side_menu_production_icon"}

    local upgrade_quality = hex_control_flow.add {
        type = "sprite-button",
        name = "upgrade-quality",
        sprite = "quality/uncommon",
        tags = {handlers = {["gui-clicked"] = "upgrade-quality"}},
    }

    local allow_locomotive_trading = hex_control_flow.add {
        type = "sprite-button",
        name = "allow-locomotive-trading",
        sprite = "item/locomotive",
        tags = {handlers = {["gui-clicked"] = "allow-locomotive-trading"}},
        tooltip = {"hex-core-gui.allow-locomotive-trading-tooltip", storage.item_buffs.train_trading_capacity},
    }

    local send_outputs_to_cargo_wagons = hex_control_flow.add {
        type = "sprite-button",
        name = "send-outputs-to-cargo-wagons",
        sprite = "item/cargo-wagon",
        tags = {handlers = {["gui-clicked"] = "send-outputs-to-cargo-wagons"}},
        tooltip = {"hex-core-gui.send-outputs-to-cargo-wagons-tooltip"},
    }

    local convert_resources = hex_control_flow.add {
        type = "sprite-button",
        name = "convert-resources",
        sprite = "virtual-signal.signal-recycle",
        tags = {handlers = {["gui-clicked"] = "convert-resources"}},
    }
    convert_resources.tooltip = {"", lib.color_localized_string({"hex-core-gui.convert-resources-tooltip-header"}, "blue", "heading-2"), "\n", {"hex-core-gui.convert-resources-tooltip-body"}}

    local delete_strongbox_button = hex_control_flow.add {
        type = "sprite-button",
        name = "delete-strongbox-button",
        sprite = "entity/strongbox-tier-1",
        tags = {handlers = {["gui-clicked"] = "delete-strongbox"}},
        tooltip = {"",
            lib.color_localized_string({"hex-core-gui.delete-strongbox-tooltip-header"}, "red", "heading-2"),
            "\n",
            {"hex-core-gui.delete-strongbox-tooltip-body"},
        },
    }

    local delete_core_confirmation = frame.add {type = "flow", name = "delete-core-confirmation", direction = "horizontal"}
    delete_core_confirmation.visible = false

    local delete_core_confirmation_button = delete_core_confirmation.add {
        type = "sprite-button",
        name = "confirmation-button",
        sprite = "utility/empty_trash_slot",
        tags = {handlers = {["gui-clicked"] = "confirmation-button"}},
    }
    local delete_core_confirmation_label = delete_core_confirmation.add {type = "label", name = "confirmation-label", caption = lib.color_localized_string({"hex-core-gui.delete-core-confirmation"}, "red")}
    delete_core_confirmation_label.style.font = "heading-1"

    local delete_strongbox_confirmation = frame.add {type = "flow", name = "delete-strongbox-confirmation", direction = "horizontal"}
    delete_strongbox_confirmation.visible = false

    local delete_strongbox_confirmation_button = delete_strongbox_confirmation.add {
        type = "sprite-button",
        name = "confirmation-button",
        sprite = "check-mark-green",
        tags = {handlers = {["gui-clicked"] = "confirmation-button"}},
    }
    local delete_strongbox_confirmation_label = delete_strongbox_confirmation.add {type = "label", name = "confirmation-label", caption = lib.color_localized_string({"hex-core-gui.delete-strongbox-confirmation"}, "red")}
    delete_strongbox_confirmation_label.style.font = "heading-1"

    frame.add {type = "line", direction = "horizontal"}

    local trades_header_flow = frame.add {type = "flow", name = "trades-header", direction = "horizontal"}
    local trades_header_label = trades_header_flow.add {type = "label", name = "label", caption = {"hex-core-gui.trades-header"}}
    trades_header_label.style.font = "heading-1"

    local quality_dropdown = core_gui.create_quality_dropdown(trades_header_flow)
    local quality_dropdown_info = trades_header_flow.add {type = "label", name = "info", caption = "[img=virtual-signal.signal-info]"}
    quality_dropdown_info.tooltip = {"hex-core-gui.quality-dropdown-info"}
    quality_dropdown_info.style.top_margin = 4
    quality_dropdown.tags = {handlers = {["gui-selection-changed"] = "update-hex-core"}}

    core_gui.add_warning(frame, {"hex-core-gui.unresearched-penalty"}, "unresearched-penalty")

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
    frame["hex-control-flow"]["quick-trade"].visible = hex_core_gui.is_quick_trade_valid(player, state)
    frame["hex-control-flow"]["delete-strongbox-button"].visible = state.strongboxes ~= nil and #state.strongboxes > 0
    frame["sink-mode-confirmation"].visible = false
    frame["generator-mode-confirmation"].visible = false

    local quality_unlocked = game.forces.player.is_quality_unlocked(prototypes.quality.uncommon)
    frame["trades-header"]["quality-dropdown"].visible = quality_unlocked
    frame["trades-header"]["info"].visible = quality_unlocked

    local has_penalties = false
    local is_unresearched_penalty_enabled = lib.runtime_setting_value "unresearched-penalty" > 0
    for _, trade_id in pairs(state.trades or {}) do
        local trade = trades.get_trade_from_id(trade_id)
        if trade and trades.has_unresearched_penalty(trade, is_unresearched_penalty_enabled) then
            has_penalties = true
            break
        end
    end
    frame["unresearched-penalty"].visible = has_penalties

    if state.claimed then
        frame["claim-flow"].visible = false
        local claimed_by_name = state.claimed_by or {"hextorio.server"}
        local claimed_timestamp = state.claimed_timestamp or 0
        frame["claimed-by"].visible = true
        frame["claimed-by"].caption = {"hex-core-gui.claimed-by", claimed_by_name, lib.ticks_to_string(claimed_timestamp)}

        local locomotive_trading_unlocked = quests.is_feature_unlocked "locomotive-trading"

        frame["hex-control-flow"].visible = true
        frame["hex-control-flow"]["stats"].tooltip = lib.get_str_from_hex_core_stats(hex_grid.get_hex_core_stats(state))
        frame["hex-control-flow"]["teleport"].visible = (quests.is_feature_unlocked "teleportation" or quests.is_feature_unlocked "teleportation-cross-planet") and not lib.is_player_editor_like(player) and state.hex_core ~= nil and player.character ~= nil
        frame["hex-control-flow"]["toggle-hexport"].visible = quests.is_feature_unlocked "hexports"
        frame["hex-control-flow"]["allow-locomotive-trading"].visible = locomotive_trading_unlocked
        frame["hex-control-flow"]["send-outputs-to-cargo-wagons"].visible = locomotive_trading_unlocked

        if locomotive_trading_unlocked then
            frame["hex-control-flow"]["allow-locomotive-trading"].toggled = state.allow_locomotive_trading == true
            frame["hex-control-flow"]["allow-locomotive-trading"].tooltip = {"hex-core-gui.allow-locomotive-trading-tooltip", "[font=heading-2][color=green]" .. storage.item_buffs.train_trading_capacity .. "[.color][.font]"}
            frame["hex-control-flow"]["send-outputs-to-cargo-wagons"].toggled = state.send_outputs_to_cargo_wagons == true
            frame["hex-control-flow"]["send-outputs-to-cargo-wagons"].enabled = state.allow_locomotive_trading == true
            if state.allow_locomotive_trading then
                frame["hex-control-flow"]["send-outputs-to-cargo-wagons"].tooltip = {"hex-core-gui.send-outputs-to-cargo-wagons-tooltip"}
            else
                frame["hex-control-flow"]["send-outputs-to-cargo-wagons"].tooltip = nil
            end
        end

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
            if coin then
                coin_tier_gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin)
            end
        end
    end

    frame["delete-core-confirmation"].visible = false
    frame["delete-strongbox-confirmation"].visible = false
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
        if state.is_well then
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
    frame.visible = true
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.hide_hex_core(player)
    local frame = player.gui.relative["hex-core"]
    if not frame or not frame.valid then return end
    frame.visible = false
end

---Return whether the player can legally make a "quick trade" from their current position with the given hex state.
---@param player LuaPlayer
---@param state HexState
---@return boolean
function hex_core_gui.is_quick_trade_valid(player, state)
    if not state.claimed then return false end
    if not player.character then return false end
    if not quests.is_feature_unlocked "quick-trading" then return false end
    if not state.hex_core or not state.hex_core.valid or not state.trades or not next(state.trades) then return false end
    if not player.can_reach_entity(state.hex_core) then return false end
    if not player.character.can_reach_entity(state.hex_core) then return false end
    return true
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
    local inv_coin = inventories.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    inventories.remove_coin_from_inventory(inv, coin)

    hex_grid.convert_resources(hex_core)
    hex_core_gui.update_hex_core(player)
end

function hex_core_gui.on_upgrade_quality_button_click(player, element)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local coin = hex_grid.get_quality_upgrade_cost(hex_core)
    local inv_coin = inventories.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    inventories.remove_coin_from_inventory(inv, coin)

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
    local inv_coin = inventories.get_coin_from_inventory(inv)
    if coin_tiers.gt(coin, inv_coin) then
        player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
        return
    end

    inventories.remove_coin_from_inventory(inv, coin)

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
        local state = hex_state_manager.get_hex_state(hex_core.surface.index, hex_pos)
        if state then
            if state.is_dungeon then
                player.print(lib.color_localized_string({"hextorio.loot-dungeon-first"}, "red"))
            else
                player.print(lib.color_localized_string({"hextorio.cannot-afford"}, "red"))
            end
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
    if not hex_core or not player.character then return end

    if hex_core.surface == player.character.surface then
        lib.teleport_player(player, hex_core.position, hex_core.surface, true)
        return
    end

    if not quests.is_feature_unlocked "teleportation-cross-planet" then
        player.print(lib.color_localized_string({"hextorio.teleportation-cross-planet-locked"}, "red"))
        return
    end

    if not lib.teleport_player_cross_surface(player, hex_core.position, hex_core.surface, true) then
        player.print({"hextorio.empty-character-inventories"})
        if player.character and player.character.vehicle then
            player.print({"hextorio.empty-vehicle-inventories"})
        end
    end
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
        local inv_coin = inventories.get_coin_from_inventory(inv)
        if coin_tiers.gt(coin, inv_coin) then
            player.print(lib.color_localized_string({"hextorio.cannot-afford-with-cost", coin_tiers.coin_to_text(coin), coin_tiers.coin_to_text(inv_coin)}, "red"))
            return
        end

        inventories.remove_coin_from_inventory(inv, coin)

        hex_grid.delete_hex_core(hex_core)
        hex_core_gui.hide_hex_core(player)
    elseif element.parent.name == "delete-strongbox-confirmation" then
        local hex_core = lib.get_player_opened_entity(player)
        if not hex_core then return end

        local state = hex_grid.get_hex_state_from_core(hex_core)
        if not state then return end

        hex_grid.remove_strongboxes(state)
        hex_core_gui.update_hex_core(player)
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

---@param player LuaPlayer
---@param elem LuaGuiElement
function hex_core_gui.on_allow_locomotive_trading_button_click(player, elem)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    state.allow_locomotive_trading = not elem.toggled
    hex_core_gui.update_hex_core(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function hex_core_gui.on_send_outputs_to_cargo_wagons_button_click(player, elem)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    state.send_outputs_to_cargo_wagons = not elem.toggled
    hex_core_gui.update_hex_core(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function hex_core_gui.on_quick_trade_button_click(player, elem)
    local hex_core = lib.get_player_opened_entity(player)
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    if not hex_core_gui.is_quick_trade_valid(player, state) then
        elem.visible = false
        return
    end

    local inv = lib.get_player_inventory(player)
    if not inv then return end

    local max_output_batches_per_trade = 1 -- Make exactly one output batch's worth of trade per trade in this hex core.
    local check_output_buffer = false -- Don't let output buffers confuse people about why their quick trading isn't working

    local quality_cost_multipliers = lib.get_quality_cost_multipliers()
    local total_removed, total_inserted, remaining_to_insert, total_coins_removed, total_coins_added = trades.process_trades_in_inventories(state.hex_core.surface.name, inv, inv, state.trades, quality_cost_multipliers, check_output_buffer, nil, max_output_batches_per_trade, nil)

    for quality_name, counts in pairs(remaining_to_insert) do
        for item_name, count in pairs(counts) do
            lib.safe_insert(player, {
                name = item_name,
                count = count,
                quality = quality_name,
            })
        end
    end

    hex_core_gui.update_hex_core(player)
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function hex_core_gui.on_delete_strongbox_button_click(player, elem)
    elem.parent.parent["delete-strongbox-confirmation"].visible = true
    elem.enabled = false
end



return hex_core_gui
