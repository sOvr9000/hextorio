
local lib = require "api.lib"
local trades = require "api.trades"
local hex_grid = require "api.hex_grid"
local coin_tiers = require "api.coin_tiers"
local item_ranks = require "api.item_ranks"
local item_values = require "api.item_values"
local event_system  = require "api.event_system"
local item_buffs = require "api.item_buffs"
local passive_coin_buff = require "api.passive_coin_buff"

local core_gui = {}



function core_gui.register_events()
    event_system.register_gui("gui-clicked", "close-button", function(player, elem)
        local frame = elem.parent.parent
        if not frame then return end
        event_system.trigger_gui("gui-closed", frame.name, player, frame)
    end)
end

---Parse an object as a LuaGuiElement.  If obj is a LuaGuiElement, then it is returned unchanged.  If not, then nil is returned.
---@param obj any
---@return LuaGuiElement|nil
function core_gui.convert_object_to_gui_element(obj)
    if not obj or type(obj) ~= "userdata" or obj.object_name ~= "LuaGuiElement" then return end
    return obj
end

---Return whether the given player has the given frame open. Safely handles situations (and returns false) when the player's currently opened object is not a GUI.
---@param player LuaPlayer
---@param frame_name string
---@return boolean
function core_gui.is_frame_open(player, frame_name)
    return player.opened ~= nil and player.opened.object_name == "LuaGuiElement" and player.opened.name == frame_name
end

---Check if a LuaGuiElement is a descendant of a given parent name.
---@param element LuaGuiElement
---@param parent_name string
---@return boolean
function core_gui.is_descendant_of(element, parent_name)
    local parent = element.parent
    if not parent then return false end
    if parent.name == parent_name then return true end
    return core_gui.is_descendant_of(parent, parent_name)
end

---Get the first element of name `parent_name` that is a parent of `elem`.
---@param elem LuaGuiElement
---@param parent_name string
---@return LuaGuiElement|nil
function core_gui.get_parent_of_name(elem, parent_name)
    local parent = elem.parent
    if not parent then return end
    if parent.name == parent_name then return parent end
    return core_gui.get_parent_of_name(parent, parent_name)
end

---Get the first element of a name that matches the pattern `pattern` and is a parent of `elem`.
---@param elem LuaGuiElement
---@param pattern string
---@return LuaGuiElement|nil
function core_gui.get_parent_of_name_match(elem, pattern)
    local parent = elem.parent
    if not parent then return end
    if parent.name:match(pattern) then return parent end
    return core_gui.get_parent_of_name_match(parent, pattern)
end

---Return the player who owns the given LuaGuiElement.  Throws an error if no player owns it.
---@param element LuaGuiElement
---@return LuaPlayer
function core_gui.get_player_from_element(element)
    local player = game.get_player(element.player_index)
    if not player then
        error("Player not found from gui element: " .. tostring(element))
    end
    return player
end

---Give a sprite or sprite button element a tooltip based on its sprite, showing rank, value, and other stats from the perspective of the given surface.
---@param player LuaPlayer
---@param surface_name string
---@param element LuaGuiElement
function core_gui.give_item_tooltip(player, surface_name, element)
    if element.type ~= "sprite" and element.type ~= "sprite-button" then
        lib.log_error("core_gui.give_item_tooltip: elem has wrong element type: " .. element.type)
        return
    end

    local item_name
    local rich_type
    if element.sprite:sub(1, 5) == "item/" then
        item_name = element.sprite:sub(6)
        rich_type = "item"
        if item_name:sub(-5) == "-coin" then
            core_gui.try_give_coin_tooltip(element)
            return
        end
    elseif element.sprite:sub(1, 7) == "entity/" then
        item_name = element.sprite:sub(8)
        rich_type = "fluid"
        if item_name == "sulfuric-acid-geyser" then
            item_name = "sulfuric-acid"
        elseif item_name == "fluorine-vent" then
            item_name = "fluorine"
        end
    else
        lib.log_error("core_gui.give_item_tooltip: Could not determine item name from sprite: " .. element.sprite)
        return
    end

    if not item_values.has_item_value(surface_name, item_name) then
        -- Lots of room for improvement here.  Would be nice to directly clone the default item tooltips.
        element.tooltip = {"",
            prototypes[rich_type][item_name].localised_name,
        }
        return
    end

    local quality = element.quality
    if quality then
        quality = quality.name
    else
        quality = "normal"
    end

    local hex_coin_value = item_values.get_item_value(surface_name, "hex-coin")
    local item_count = element.number or 1

    local value = item_values.get_item_value(surface_name, item_name)
    local location_rich_text = "[img=planet-" .. surface_name .. "]"

    local scaled_value = value / hex_coin_value * lib.get_quality_value_scale(quality)

    local rank_str = {""}
    if lib.is_catalog_item(surface_name, item_name) then
        local rank = item_ranks.get_item_rank(item_name)
        local left_half
        if rank == 1 then
            left_half = core_gui.get_bronze_sprite_half(item_name)
        end
        rank_str = {"", lib.color_localized_string({"hextorio-gui.rank"}, "white", "heading-1"), " " , lib.get_rank_img_str(rank, left_half), "\n\n"}
    end

    local item_img_rich_text = "[" .. rich_type .. "=" .. item_name .. ",quality=" .. quality .. "]"

    element.tooltip = {"",
        item_img_rich_text,
        prototypes[rich_type][item_name].localised_name,
        "\n-=-=-=-=-=-=-=-=-\n",
        rank_str,
        location_rich_text .. " [font=heading-2][color=green]",
        {"hextorio-gui.item-value"},
        "[.color][.font]\n" .. item_img_rich_text .. "x1 = ",
        coin_tiers.base_coin_value_to_text(scaled_value, false, 4),
        "\n\n" .. location_rich_text .. " [font=heading-2][color=yellow]",
        {"hextorio-gui.stack-value-total"},
        "[.color][.font]\n" .. item_img_rich_text .. "x" .. item_count .. " = ",
        coin_tiers.base_coin_value_to_text(item_count * scaled_value, false, 4)
    }
end

function core_gui.give_productivity_tooltip(element, trade, quality, quality_cost_mult)
    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    local s = {"",
        trades.get_total_values_str(trade, quality, quality_cost_mult),
    }

    if trades.trade_has_untradable_items(trade) then
        table.insert(s, 2, lib.color_localized_string({"hextorio-gui.interplanetary-trade-tooltip-header"}, "cyan", "heading-2"))
        table.insert(s, 3, "\n\n")
    end

    if trades.has_any_productivity_modifiers(trade, quality) then
        table.insert(s, "\n\n")
        table.insert(s, trades.get_productivity_bonus_str(trade, quality))
    end

    element.tooltip = s
end

function core_gui.try_give_coin_tooltip(element)
    if element.number >= 1000 then
        element.tooltip = element.number
    else
        element.tooltip = nil
    end
end

function core_gui.generate_sprite_buttons(player, surface_name, flow, items, give_tooltip)
    for item_name, count in pairs(items) do
        local sprite_button = flow.add {
            type = "sprite-button",
            name = item_name,
            sprite = "item/" .. item_name,
            number = count,
        }
        if give_tooltip or give_tooltip == nil then
            core_gui.give_item_tooltip(player, surface_name, sprite_button)
        end
    end
end

---Automatically stretch a LuaGuiElement horizontally.
---@param element LuaGuiElement
function core_gui.auto_width(element)
    element.style.horizontally_stretchable = true
    element.style.horizontally_squashable = true
end

---Automatically stretch a LuaGuiElement vertically.
---@param element LuaGuiElement
function core_gui.auto_height(element)
    element.style.vertically_stretchable = true
    element.style.vertically_squashable = true
end

---Automatically stretch a LuaGuiElement horizontally and vertically.
---@param element LuaGuiElement
function core_gui.auto_width_height(element)
    core_gui.auto_width(element)
    core_gui.auto_height(element)
end

---Create a new LuaGuiElement using the given `add_params`, automatically center is horizontally, and return the individual element that's centered inside the automatically generated flow element.
---@param element LuaGuiElement The parent element under which to create the flow that's used to center the element.
---@param add_params {[string]: any, type: string} Parameters passed to the LuaGuiElement.add() function which creates the centered element.
---@return LuaGuiElement
function core_gui.auto_center_horizontally(element, add_params)
    local name = add_params.name or add_params.type

    local flow = element.add {
        type = "flow",
        name = name .. "-centered",
        direction = "horizontal",
    }

    core_gui.auto_width(flow.add {
        type = "empty-widget",
        name = "empty-left",
    })

    local centered_element = flow.add(add_params)

    core_gui.auto_width(flow.add {
        type = "empty-widget",
        name = "empty-right",
    })

    return centered_element
end

---Create a flow with a title label, a draggable bar, and a close button.
---@param frame LuaGuiElement
---@param caption LocalisedString
---@param include_back_and_forward boolean|nil Whether to include two buttons with left and right arrows like those in the Factoriopedia.
---@return LuaGuiElement flow The flow containing the title label
function core_gui.add_titlebar(frame, caption, include_back_and_forward)
    local titlebar = frame.add{type = "flow"}
    titlebar.drag_target = frame

    titlebar.add{
        type = "label",
        style = "frame_title",
        caption = caption,
        ignored_by_interaction = true,
    }

    titlebar.style.top_margin = -2

    local filler = titlebar.add{
        type = "empty-widget",
        style = "draggable_space",
        ignored_by_interaction = true,
    }

    filler.style.height = 24
    filler.style.horizontally_stretchable = true

    if include_back_and_forward then
        local flow = titlebar.add {
            type = "flow",
            name = "back-and-forward",
            style = "packed_horizontal_flow",
            direction = "horizontal",
        }
        flow.style.right_padding = 5

        flow.add {
            type = "sprite-button",
            name = "back",
            style = "frame_action_button",
            sprite = "utility/backward_arrow",
            tooltip = {"gui.back-instruction"},
            tags = {
                handlers = {["gui-clicked"] = "gui-back"},
                linked_handler_parent_idx = 3, -- This makes the event system trigger "gui-back" on the third parent up from this element.
            },
        }
        flow.add {
            type = "sprite-button",
            name = "forward",
            style = "frame_action_button",
            sprite = "utility/forward_arrow",
            tooltip = {"gui.forward-instruction"},
            tags = {
                handlers = {["gui-clicked"] = "gui-forward"},
                linked_handler_parent_idx = 3, -- This makes the event system trigger "gui-forward" on the third parent up from this element.
            },
        }
    end

    local close_button = titlebar.add{
        type = "sprite-button",
        name = "frame-close-button",
        style = "frame_action_button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close-instruction"},
    }
    close_button.tags = {handlers = {["gui-clicked"] = "close-button"}}

    local tags = frame.tags
    if not tags.handlers then
        tags.handlers = {}
    end
    tags.handlers["gui-closed"] = frame.name

    if include_back_and_forward then
        -- These get triggered on back/forward button click because of linked handlers
        tags.handlers["gui-back"] = frame.name
        tags.handlers["gui-forward"] = frame.name
    end

    frame.tags = tags

    return titlebar
end

function core_gui.add_info(element, info_id, name)
    local info = element.add {
        type = "label",
        name = name,
        caption = core_gui.get_info_caption(info_id),
    }
    info.style.single_line = false
    core_gui.auto_width(info)
end

function core_gui.add_warning(element, info_id, name)
    local info = element.add {
        type = "label",
        name = name,
        caption = core_gui.get_warning_caption(info_id),
    }
    info.style.single_line = false
    core_gui.auto_width(info)
end

function core_gui.get_info_caption(info_id)
    return {"", "[color=117,218,251][img=virtual-signal.signal-info] ", info_id, "[.color]"}
end

function core_gui.get_warning_caption(info_id)
    return {"", "[color=255,255,64][img=utility.warning_icon] ", info_id, "[.color]"}
end

function core_gui.add_sprite_buttons(element, item_stacks, name_prefix, give_item_tooltips)
    if not name_prefix then name_prefix = "" end

    local player
    if give_item_tooltips then
        player = core_gui.get_player_from_element(element)
    end

    for i, item_stack in ipairs(item_stacks) do
        local sprite_button = element.add {
            type = "sprite-button",
            name = name_prefix .. item_stack.name,
            sprite = "item/" .. item_stack.name,
            number = item_stack.count,
            quality = item_stack.quality,
        }
        if give_item_tooltips then
            if player then
                core_gui.give_item_tooltip(player, player.surface.name, sprite_button)
            end
        end
    end
end

---Create a dropdown element for qualities.
---@param parent LuaGuiElement Parent element of new dropdown element.
---@param name string|nil Name of new dropdown element. Defaults to "quality-dropdown".
---@param selected_index int|nil The pre-selected index of the new dropdown element. Defaults to 1 (top).
---@param unlocked_only boolean|nil Whether to only put unlocked qualities in the dropdown. Defaults to false.
---@return LuaGuiElement
function core_gui.create_quality_dropdown(parent, name, selected_index, unlocked_only)
    if unlocked_only == nil then unlocked_only = false end

    local quality_locales = {}
    for quality_name, prot in pairs(prototypes.quality) do
        if quality_name ~= "quality-unknown" and (not unlocked_only or game.forces.player.is_quality_unlocked(prot)) then
            table.insert(quality_locales, {"", "[img=quality." .. quality_name .. "] ", {"quality-name." .. quality_name}})
        end
    end

    return parent.add {type = "drop-down", name = name or "quality-dropdown", items = quality_locales, selected_index = selected_index or 1}
end

---Get the name of the quality that a dropdown has selected.
---@param element LuaGuiElement
---@return string
function core_gui.get_quality_name_from_dropdown(element)
    local item = element.get_item(math.max(1, element.selected_index))[3][1] --[[@as string]]
    if not item then
        lib.log_error("core_gui.get_quality_name_from_dropdown: Could not find item in dropdown, assuming normal quality.")
        return "normal"
    end
    return item:sub(14)
end

---Get the sprite name for an item's rank.
---@param item_name string
---@param rank_value int|nil If not provided, the rank is automatically determined.
---@return string
function core_gui.get_rank_sprite(item_name, rank_value)
    if not rank_value then
        rank_value = item_ranks.get_item_rank(item_name)
    end

    local sprite = "rank-" .. rank_value
    if rank_value == 1 then
        local left_half = core_gui.get_bronze_sprite_half(item_name)
        if left_half ~= nil then
            if left_half then
                sprite = "rank-1-bought"
            else
                sprite = "rank-1-sold"
            end
        end
    end

    return sprite
end

---Get which half, if any, of the bronze star that should be used.
---@param item_name string
---@return boolean|nil
function core_gui.get_bronze_sprite_half(item_name)
    local left_half

    if trades.get_total_bought(item_name) > 0 then
        left_half = false
    elseif trades.get_total_sold(item_name) > 0 then
        left_half = true
    end

    return left_half
end

---Return the element that's currently under the mouse of the player.
---@param player_index int
---@return LuaGuiElement|nil
function core_gui.get_currently_hovered_element(player_index)
    local g = storage.gui
    if not g then
        g = {}
        storage.gui = g
    end
    local hovered = g.hovered_element
    if not hovered then
        hovered = {}
        g.hovered_element = hovered
    end
    return hovered[player_index]
end

---Get the Trade object that the trade GUI flow represents.
---@param player LuaPlayer
---@param flow LuaGuiElement
---@return Trade|nil
function core_gui.get_trade_from_trade_flow(player, flow)
    local trade_number = tonumber(flow.name:sub(7))
    if not trade_number then return end

    local is_trade_overview = core_gui.is_descendant_of(flow, "trade-overview")
    if is_trade_overview then
        return (storage.trade_overview.trades[player.name] or {})[trade_number]
    end

    local hex_core = player.opened
    if not hex_core or hex_core.object_name ~= "LuaEntity" then return end

    local state = hex_grid.get_hex_state_from_core(hex_core)
    if not state or not state.trades then return end

    local trade_id = state.trades[trade_number]
    if not trade_id then return end

    return trades.get_trade_from_id(trade_id)
end

---Generate a buff description tooltip based on buff type.
---@param buff_type ItemBuffType
---@return LocalisedString|nil
function core_gui.get_buff_description_tooltip(buff_type)
    if not storage.item_buffs.has_description[buff_type] then
        return nil
    end

    if buff_type == "passive-coins" then
        local interval = storage.item_buffs.passive_coins_interval
        local calculation_steps = passive_coin_buff.get_passive_gain_calculation_steps(interval * 60)

        local breakdown_str = {"",
            coin_tiers.coin_to_text(coin_tiers.from_base_value(math.floor(0.5 + (calculation_steps[#calculation_steps] or 0)))),
            "\n\n[color=128,128,128][font=heading-2]", {"hextorio-gui.calculation-breakdown"}, "[.font]",
            "\n", {"hextorio-gui.net-coins-per-hour", "\n" .. coin_tiers.coin_to_text(coin_tiers.from_base_value(math.floor(0.5 + (calculation_steps[1] or 0))))},
            "\n\n", {"hextorio-gui.normalize-to-interval", "\n" .. coin_tiers.coin_to_text(coin_tiers.from_base_value(math.floor(0.5 + (calculation_steps[2] or 0)))), interval},
            "\n\n", {"hextorio-gui.buff-effect", "\n" .. coin_tiers.coin_to_text(coin_tiers.from_base_value(math.floor(0.5 + (calculation_steps[3] or 0)))), "[color=green]" .. lib.format_percentage(storage.item_buffs.passive_coins_rate, 1, true, true) .. "[.color]"},
            "[.color]",
        }

        return {"item-buff-description." .. buff_type, breakdown_str, interval}
    elseif buff_type == "train-trading-capacity" then
        return {"item-buff-description." .. buff_type, "[font=heading-2][color=green]" .. storage.item_buffs.train_trading_capacity .. "[.color][.font]"}
    elseif buff_type == "all-buffs-cost-reduced" then
        return {"item-buff-description." .. buff_type, "[font=heading-2][color=green]" .. (math.floor(0.5 + 100 / storage.item_buffs.cost_multiplier) * 0.01) .. "[.color][.font]"}
    elseif buff_type == "unresearched-penalty-reduced" then
        return {"item-buff-description." .. buff_type, "[font=heading-2][color=green]" .. (math.floor(0.5 + 100 / storage.item_buffs.unresearched_penalty_multiplier) * 0.01) .. "[.color][.font]"}
    elseif buff_type == "strongbox-loot" then
        return {"item-buff-description." .. buff_type, (math.floor(0.5 + 100 * storage.item_buffs.strongbox_loot) * 0.01)}
    else
        return {"item-buff-description." .. buff_type}
    end
end



return core_gui
