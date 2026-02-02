
local lib = require "api.lib"
local core_gui = require "api.gui.core_gui"
local gui_stack = require "api.gui.gui_stack"
local event_system = require "api.event_system"
local quests       = require "api.quests"
local hex_rank     = require "api.hex_rank"

local hex_rank_gui = {}



---@type {[GameplayStatisticType]: {sprite: string}}
local factor_metadata = {
    ["total-hexes-claimed"] = {
        sprite = "hexagon-with-plus-sign",
    },
    ["total-quests-completed"] = {
        sprite = "questbook",
    },
    ["total-strongbox-level"] = {
        sprite = "entity.strongbox-tier-1",
    },
    ["net-coin-production"] = {
        sprite = "hex-coin",
    },
    ["total-spawners-killed"] = {
        sprite = "entity.gleba-spawner",
    },
    ["tech-tree-completion"] = {
        sprite = "virtual-signal.shape-t-4",
    },
    ["total-unique-items-traded"] = {
        sprite = "virtual-signal.signal-rightwards-leftwards-arrow",
    },
    ["total-resources-depleted"] = {
        sprite = "item.electric-mining-drill",
    },
    ["total-dungeons-looted"] = {
        sprite = "entity.dungeon-gun-turret",
    },
    ["total-item-buff-level"] = {
        sprite = "utility.side_menu_bonus_icon",
    },
    ["total-item-rank"] = {
        sprite = "gold-star",
    },
    ["fastest-ship-speed"] = {
        sprite = "item.thruster",
    },
    ["science-per-hour"] = {
        sprite = "virtual-signal.signal-science-pack",
    },
    ["total-rockets-launched"] = {
        sprite = "item.rocket-silo",
    },
}

function hex_rank_gui.register_events()
    event_system.register_gui("gui-clicked", "hex-rank-button", hex_rank_gui.on_hex_rank_button_clicked)
    event_system.register_gui("gui-closed", "hex-rank", hex_rank_gui.hide_hex_rank)

    event_system.register("hex-rank-changed", hex_rank_gui.on_hex_rank_changed)

    event_system.register("quest-reward-received", function(reward_type, value)
        if reward_type == "unlock-feature" and value == "hex-rank" then
            for _, player in pairs(game.connected_players) do
                hex_rank_gui.reinitialize(player)
            end
        end
    end)

    event_system.register("runtime-setting-changed-show-hex-rank-hud", function(player_index)
        local player = game.get_player(player_index)
        if not player then return end

        local flow = player.gui.center["hex-rank-hud"]
        if not flow then
            hex_rank_gui.init_hex_rank_hud(player)
            flow = player.gui.center["hex-rank-hud"]
        end

        flow.visible = lib.player_setting_value_as_boolean(player, "show-hex-rank-hud")

        if flow.visible then
            hex_rank_gui.update_hex_rank_hud(player)
        end
    end)

    event_system.register("player-display-scaled-changed", function(player)
        hex_rank_gui.reinitialize(player)
    end)
end

---Reinitialize the hex rank GUI for the given player, or all players if no player is provided.
---@param player LuaPlayer|nil
function hex_rank_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.players) do
            hex_rank_gui.reinitialize(p)
        end
        return
    end

    local frame = player.gui.screen["hex-rank"]
    if frame then frame.destroy() end

    local button = player.gui.top["hex-rank-button"]
    if button then button.destroy() end

    local hud = player.gui.center["hex-rank-hud"]
    if hud then hud.destroy() end

    hex_rank_gui.init_hex_rank_button(player)
    hex_rank_gui.init_hex_rank(player)
    hex_rank_gui.init_hex_rank_hud(player)
end

---@param player LuaPlayer
function hex_rank_gui.init_hex_rank_button(player)
    if player.gui.top["hex-rank-button"] then return end
    local hex_rank_button = player.gui.top.add {
        type = "sprite-button",
        name = "hex-rank-button",
        sprite = "hex-rank-button",
        style = "side_menu_button",
        tooltip = {"hextorio-gui.frame-toggle-button-tooltip"},
        visible = quests.is_feature_unlocked "hex-rank",
    }
    hex_rank_button.tags = {handlers = {["gui-clicked"] = "hex-rank-button"}}
end

---@param player LuaPlayer
function hex_rank_gui.init_hex_rank(player)
    if player.gui.screen["hex-rank"] then return end

    local frame = player.gui.screen.add {type = "frame", name = "hex-rank", direction = "vertical"}
    frame.style.size = {width = 600, height = 800}
    frame.visible = false
    frame.tags = {handlers = {["gui-closed"] = "hex-rank"}}

    core_gui.add_titlebar(frame, {"hextorio-gui.hex-rank"})

    local hex_rank_label = core_gui.auto_center_horizontally(frame, {
        type = "label",
        name = "hex-rank",
    })
    hex_rank_label.style.top_padding = 15
    hex_rank_label.style.bottom_padding = 20

    local scroll_pane = frame.add {
        type = "scroll-pane",
        name = "rows",
        direction = "vertical",
        horizontal_scroll_policy = "never",
    }

    local display_scale = player.display_scale
    for factor_type, metadata in pairs(factor_metadata) do
        hex_rank_gui.build_hex_rank_factor_row(scroll_pane, factor_type, metadata, display_scale)
    end
end

---@param parent LuaGuiElement
---@param factor_type string
---@param metadata table
---@param display_scale number
function hex_rank_gui.build_hex_rank_factor_row(parent, factor_type, metadata, display_scale)
    local frame = parent.add {
        type = "frame",
        name = "factor-" .. factor_type,
        direction = "horizontal",
        tags = {
            factor_type = factor_type,
        },
    }
    frame.style.horizontally_stretchable = true

    local sprite_name = metadata.sprite

    local image = frame.add {
        type = "sprite",
        name = "image",
        sprite = sprite_name,
    }
    image.style.size = {50 / display_scale, 50 / display_scale}
    image.style.top_padding = 3
    image.style.stretch_image_to_widget_size = true

    local flow = frame.add {
        type = "flow",
        name = "flow",
        direction = "vertical",
    }
    flow.style.horizontally_stretchable = true

    local details_flow = flow.add {
        type = "flow",
        name = "details",
        direction = "horizontal",
    }
    details_flow.style.horizontally_stretchable = true

    local progress_bar = flow.add {
        type = "progressbar",
        name = "progress-bar",
        value = 0,
    }
    progress_bar.style.horizontally_stretchable = true
    progress_bar.style.color = {0.6, 0.85, 1}

    local factor_label = details_flow.add {
        type = "label",
        name = "factor-label",
        caption = {"",
            "[img=virtual-signal.signal-info] ",
            {"hextorio-hex-rank-factor-label." .. factor_type},
        },
        tooltip = {"hextorio-hex-rank-factor-tooltip." .. factor_type},
    }
    factor_label.style.font = "heading-2"

    local empty = details_flow.add {type = "empty-widget", name = "empty"}
    empty.style.horizontally_stretchable = true

    local contribution = details_flow.add {
        type = "label",
        name = "contribution",
    }
    contribution.style.font = "count-font"
    contribution.style.font_color = {0.75, 0.125, 1}
end

---@param player LuaPlayer
function hex_rank_gui.init_hex_rank_hud(player)
    if player.gui.center["hex-rank-hud"] then return end

    local hud = player.gui.center.add {
        type = "flow",
        name = "hex-rank-hud",
        direction = "vertical",
        ignored_by_interaction = true,
    }
    hud.style.vertically_stretchable = true
    hud.style.height = 1413 / player.display_scale
    hud.style.vertically_squashable = true

    local hex_rank_label = hud.add {
        type = "label",
        name = "hex-rank",
    }

    hex_rank_gui.update_hex_rank_hud(player)
end

---Update the hex rank info GUI for a player.
---@param player LuaPlayer
function hex_rank_gui.update_hex_rank_gui(player)
    local frame = player.gui.screen["hex-rank"]
    if not frame then
        hex_rank_gui.init_hex_rank(player)
        frame = player.gui.screen["hex-rank"]
    end

    if not frame.visible then return end

    local hex_rank_label = frame["hex-rank-centered"]["hex-rank"]
    local rows = frame["rows"]

    hex_rank_label.caption = "[font=count-font][color=192,32,255][img=hex-rank] " .. ((storage.hex_rank or {}).hex_rank or 0) .. "[.color][.font]"

    for _, elem in pairs(rows.children) do
        hex_rank_gui.update_hex_rank_factor_row(elem)
    end
end

---Update a row of the hex rank GUI corresponding to a given hex rank factor.
---@param elem LuaGuiElement
function hex_rank_gui.update_hex_rank_factor_row(elem)
    local factor_type = elem.tags.factor_type
    if not factor_type then
        lib.log_error("hex_rank_gui.update_hex_rank_factor_row: factor_type not found in elem.tags")
        return
    end

    -- type checking is very slow to be done repeatedly but maybe it's okay here for now
    if type(factor_type) ~= "string" then
        lib.log_error("hex_rank_gui.update_hex_rank_factor_row: elem.tags.factor_type is not a string")
        return
    end

    local flow = elem["flow"]
    local image = elem["image"]
    if not flow or not image then return end

    local progress_bar = flow["progress-bar"]
    local details = flow["details"]
    if not progress_bar or not details then return end

    local contribution = details["contribution"]
    if not contribution then return end

    local term = hex_rank.get_factor_term_cache(factor_type)
    if math.abs(term) < 1e-9 then
        elem.style = "inside_deep_frame"
        elem.style.minimal_height = 70 / 1.2
        elem.style.horizontally_stretchable = true
        elem.style.bottom_padding = 2

        image.visible = false
        flow.visible = false
    else
        elem.style = "frame"
        elem.style.minimal_height = 70 / 1.2
        elem.style.horizontally_stretchable = true
        elem.style.bottom_padding = 2

        image.visible = true
        flow.visible = true

        local progress = hex_rank.get_factor_progress(factor_type)
        local current, goal = hex_rank.get_hex_rank_completion(factor_type)

        local font = "count-font"

        contribution.caption = "[img=hex-rank] +" .. (math.floor(0.5 + 10 * term * hex_rank.get_overall_scale()) / 10)
        progress_bar.value = math.min(1, progress)
        progress_bar.tooltip = {"", 
            "[font=" .. font .. "]" .. current .. " / " .. goal .. "   (" .. lib.format_percentage(progress_bar.value, 0, true, false) .. ")[.font]\n\n",
            lib.color_localized_string({"hextorio-gui.hex-rank-progress-logarithmic", font}, "gray"),
        }
    end
end

---Update the hex rank HUD for a player.
---@param player LuaPlayer
---@param new_value int|nil
function hex_rank_gui.update_hex_rank_hud(player, new_value)
    local flow = player.gui.center["hex-rank-hud"]
    if not flow then
        hex_rank_gui.init_hex_rank_hud(player)
        flow = player.gui.center["hex-rank-hud"]
    end

    if not flow or not flow.valid or not flow.visible then return end

    -- local center_flow = flow["center"]
    -- if not center_flow or not center_flow.valid or not center_flow.visible then return end

    local label = flow["hex-rank"]
    if not label or not label.valid or not label.visible then return end

    if not new_value then
        new_value = (storage.hex_rank or {}).hex_rank or 0
    end

    label.caption = "[img=hex-rank] [font=count-font][color=192,32,255]" .. new_value .. "[.color][.font]"
end

---Show the hex rank info GUI for a player.
---@param player LuaPlayer
function hex_rank_gui.show_hex_rank(player)
    local frame = player.gui.screen["hex-rank"]
    if not frame then
        hex_rank_gui.init_hex_rank(player)
        frame = player.gui.screen["hex-rank"]
    end
    gui_stack.add(player, frame)
    hex_rank_gui.update_hex_rank_gui(player)
    frame.force_auto_center()
end

---Hide the hex rank info GUI for a player.
---@param player LuaPlayer
function hex_rank_gui.hide_hex_rank(player)
    local frame = player.gui.screen["hex-rank"]
    if not frame or not frame.valid then return end
    gui_stack.pop(player, gui_stack.index_of(player, frame))
end

---@param player LuaPlayer
---@param elem LuaGuiElement
function hex_rank_gui.on_hex_rank_button_clicked(player, elem)
    if core_gui.is_frame_open(player, "hex-rank") then
        hex_rank_gui.hide_hex_rank(player)
    else
        hex_rank_gui.show_hex_rank(player)
    end
end

---@param prev int
---@param new int
function hex_rank_gui.on_hex_rank_changed(prev, new)
    for _, player in pairs(game.connected_players) do
        hex_rank_gui.update_hex_rank_hud(player, new)
        hex_rank_gui.update_hex_rank_gui(player)
    end
end



return hex_rank_gui
