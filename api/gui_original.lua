local lib = require "api.lib"
local hex_grid = require "api.hex_grid"

local gui = {}



function gui.init_questbook_button(player)
    if player.gui.top["questbook-button"] then return end
    local questbook_button = player.gui.top.add {
        type = "sprite-button",
        name = "questbook-button",
        sprite = "questbook",
        -- style = "slot_sized_button",
        style = "side_menu_button",
    }
end

function gui.init_hex_core(player)
    local anchor = {
        gui = defines.relative_gui_type.container_gui,
        position = defines.relative_gui_position.right,
    }
    local hex_core_gui = player.gui.relative.add {type = "frame", name = "hex-core-gui", direction = "vertical", anchor = anchor}
    hex_core_gui.caption = {"hex-core-gui.title"}
    hex_core_gui.style.size = {width = 280, height = 625}

    local claim_flow = hex_core_gui.add {type = "flow", name = "claim-flow", direction = "vertical"}
    local claim_price = gui.create_coin_tier(claim_flow, "claim-price")
    local claim_hex = claim_flow.add {type = "button", name = "claim-hex", caption = {"hex-core-gui.claim-hex"}, style = "confirm_button"}
    claim_hex.tooltip = nil

    local claimed_by = hex_core_gui.add {type = "label", name = "claimed-by", caption = {"hex-core-gui.claimed-by"}}
    claimed_by.style.font = "heading-2"

    hex_core_gui.add {type = "line", direction = "horizontal"}

    local trades_header = hex_core_gui.add {type = "label", name = "trades-header", caption = {"hex-core-gui.trades-header"}}
    trades_header.style.font = "heading-1"

    local trades_scroll_pane = hex_core_gui.add {type = "scroll-pane", direction = "vertical"}
    trades_scroll_pane.name = "trades"
end

function gui.init_questbook(player)
    if player.gui.screen["questbook"] then return end
    local questbook = player.gui.screen.add {type = "frame", name = "questbook", direction = "vertical"}
    questbook.caption = {"hextorio-questbook.questbook-title"}
    questbook.style.size = {width = 400, height = 600}
end

function gui.show_hex_core(player)
    local frame = player.gui.relative["hex-core-gui"]
    if not frame then
        gui.init_hex_core(player)
        frame = player.gui.relative["hex-core-gui"]
    end
    frame.visible = true
    gui.update_hex_core(player)
end

function gui.hide_hex_core(player)
    local frame = player.gui.relative["hex-core-gui"]
    if not frame then return end
    frame.visible = false
end

function gui.show_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then
        gui.init_questbook(player)
        frame = player.gui.screen["questbook"]
    end
    frame.visible = true
    player.opened = frame
end

function gui.hide_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then return end
    frame.visible = false
end

function gui.update_trades_scroll_pane(player, trades_scroll_pane, trades)
    trades_scroll_pane.clear()

    for trade_number, trade in ipairs(trades) do
        local trade_button = trades_scroll_pane.add {
            type = "button",
            name = "trade" .. trade_number,
            direction = "horizontal",
        }
        trade_button.style.natural_height = 60 / 1.2
        trade_button.style.horizontally_stretchable = true
        local trade_flow = trade_button.add {
            type = "flow",
            direction = "horizontal",
        }
        local input_flow = trade_flow.add {
            type = "flow",
            direction = "horizontal",
        }
        input_flow.style.horizontally_stretchable = true
        input_flow.style.natural_height = 40 / 1.2
        local trade_arrow_sprite = trade_flow.add {
            type = "sprite",
            sprite = "trade-arrow",
        }
        for i, input_item in ipairs(trade.input_items) do
            local input = input_flow.add {
                type = "sprite-button",
                name = "input" .. tostring(i),
                sprite = "item/" .. input_item.name,
                number = input_item.count,
            }
        end
        trade_arrow_sprite.style.width = 40 / 1.2
        trade_arrow_sprite.style.height = 40 / 1.2
        local output_flow = trade_flow.add {
            type = "flow",
            direction = "horizontal",
        }
        output_flow.style.natural_height = 40 / 1.2
        output_flow.style.horizontally_stretchable = true
        -- output_flow.anchor = {
        --     gui = ,
        --     position = defines.relative_gui_position.right,
        -- }
        for i, output_item in ipairs(trade.output_items) do
            local output = output_flow.add {
                type = "sprite-button",
                name = "output" .. tostring(i),
                sprite = "item/" .. output_item.name,
                number = output_item.count,
            }
        end
    end
end

function gui.update_hex_core(player)
    local frame = player.gui.relative["hex-core-gui"]
    if not frame then
        gui.init_hex_core(player)
        frame = player.gui.relative["hex-core-gui"]
    end

    local hex_core = player.opened
    if not hex_core then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state then return end

    local coin = state.claim_price
    gui.update_coin_tier(frame["claim-flow"]["claim-price"], coin)

    if state.claimed then
        frame["claim-flow"].visible = false
        local claimed_by_name = state.claimed_by or {"hextorio.server"}
        frame["claimed-by"].visible = true
        frame["claimed-by"].caption = {"hex-core-gui.claimed-by", claimed_by_name}
        
    else
        frame["claim-flow"].visible = true
        frame["claimed-by"].visible = false
    end

    gui.update_trades_scroll_pane(player, frame.trades, state.trades)
end

function gui.update_questbook(player)
    local frame = player.gui.screen["questbook"]
    if not frame then
        gui.init_questbook(player)
    end
    -- todo
end

function gui.update_coin_tier(flow, coin)
    -- Don't show leading zeroes, but show intermediate zeroes, and always show hex coin even if total cost is zero.
    local hex_coin_sprite = flow['hex-coin']
    hex_coin_sprite.number = coin.values[1]

    local visible = false
    if coin.values[4] > 0 then visible = true end
    local hexaprism_coin_sprite = flow['hexaprism-coin']
    hexaprism_coin_sprite.number = coin.values[4]
    hexaprism_coin_sprite.visible = visible

    if coin.values[3] > 0 then visible = true end
    local meteor_coin_sprite = flow['meteor-coin']
    meteor_coin_sprite.number = coin.values[3]
    meteor_coin_sprite.visible = visible

    if coin.values[2] > 0 then visible = true end
    local gravity_coin_sprite = flow['gravity-coin']
    gravity_coin_sprite.number = coin.values[2]
    gravity_coin_sprite.visible = visible
end

function gui.create_coin_tier(parent, name)
    local flow = parent.add {type = "flow", direction = "horizontal"}
    flow.style.horizontal_spacing = 8
    flow.name = name or "coins"

    local hex_coin_sprite = flow.add {type = "sprite-button", sprite = "hex-coin"}
    hex_coin_sprite.ignored_by_interaction = true
    hex_coin_sprite.name = "hex-coin"
    hex_coin_sprite.style.width = 40
    hex_coin_sprite.style.height = 40
    hex_coin_sprite.number = 1

    local gravity_coin_sprite = flow.add {type = "sprite-button", sprite = "gravity-coin"}
    gravity_coin_sprite.ignored_by_interaction = true
    gravity_coin_sprite.name = "gravity-coin"
    gravity_coin_sprite.style.width = 40
    gravity_coin_sprite.style.height = 40
    gravity_coin_sprite.number = 0

    local meteor_coin_sprite = flow.add {type = "sprite-button", sprite = "meteor-coin"}
    meteor_coin_sprite.ignored_by_interaction = true
    meteor_coin_sprite.name = "meteor-coin"
    meteor_coin_sprite.style.width = 40
    meteor_coin_sprite.style.height = 40
    meteor_coin_sprite.number = 0

    local hexaprism_coin_sprite = flow.add {type = "sprite-button", sprite = "hexaprism-coin"}
    hexaprism_coin_sprite.ignored_by_interaction = true
    hexaprism_coin_sprite.name = "hexaprism-coin"
    hexaprism_coin_sprite.style.width = 40
    hexaprism_coin_sprite.style.height = 40
    hexaprism_coin_sprite.number = 0

    return flow
end

function gui.on_gui_click(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.element.name == "claim-hex" then
        gui.on_claim_hex_button_click(player)
    elseif event.element.name == "questbook-button" then
        gui.on_questbook_button_click(player)
    end
end

function gui.on_claim_hex_button_click(player)
    local hex_core = player.opened
    if not hex_core then
        lib.log_error("on_claim_hex_button_click: Couldn't find hex core")
        return
    end

    local transformation = hex_grid.get_surface_transformation(hex_core.surface)

    if not transformation then
        lib.log_error("on_claim_hex_button_click: No transformation found")
        return
    end

    local hex_pos = hex_grid.get_hex_containing(hex_core.position, transformation.scale, transformation.rotation)

    if not hex_grid.can_claim_hex(player, player.surface, hex_pos) then
        player.print(lib.color_localized_string({"hex-core-gui.cannot-afford-hex"}, "red"))
        return
    end

    hex_grid.claim_hex(hex_core.surface, hex_pos, player)
    gui.update_hex_core(player)
end

function gui.on_questbook_button_click(player)
    gui.show_questbook(player)
end

function gui.on_gui_closed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- THIS SHOULD NOT BE NECESSARY
    -- THE BUG IN 2.0.43 WHICH MADE THIS NECESSARY
    -- HAS BEEN FIXED FOR 2.0.44 (https://forums.factorio.com/viewtopic.php?t=127900)
    -- (not yet released)
    -- THANKS DEVBRO
    gui.hide_hex_core(player)
    gui.hide_questbook(player)
end

function gui.on_gui_confirmed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    -- THIS SHOULD NOT BE NECESSARY
    -- THE BUG IN 2.0.43 WHICH MADE THIS NECESSARY
    -- HAS BEEN FIXED FOR 2.0.44 (https://forums.factorio.com/viewtopic.php?t=127900)
    -- (not yet released)
    -- THANKS DEVBRO
    gui.hide_hex_core(player)
    gui.hide_questbook(player)
end



return gui
