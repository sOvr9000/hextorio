
local lib = require "api.lib"
local trades = require "api.trades"
local coin_tiers = require "api.coin_tiers"
local item_ranks = require "api.item_ranks"
local item_values = require "api.item_values"
local gui_events  = require "api.gui.gui_events"

local core_gui = {}



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

function core_gui.give_item_tooltip(player, surface_name, element)
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

    local quality = element.quality
    if quality then
        quality = quality.name
    else
        quality = "normal"
    end

    local hex_coin_value = item_values.get_item_value(surface_name, "hex-coin")
    local item_count = element.number or 1
    local value = item_values.get_item_value(surface_name, item_name)
    local scaled_value = value / hex_coin_value * lib.get_quality_value_scale(quality)

    local rank_str = {""}
    if lib.is_catalog_item(item_name) then
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
        "[img=planet-" .. surface_name .. "] [font=heading-2][color=green]",
        {"hextorio-gui.item-value"},
        "[.color][.font]\n" .. item_img_rich_text .. "x1 = ",
        coin_tiers.base_coin_value_to_text(scaled_value, false, 4),
        "\n\n[img=planet-" .. surface_name .. "] [font=heading-2][color=yellow]",
        {"hextorio-gui.stack-value-total"},
        "[.color][.font]\n" .. item_img_rich_text .. "x" .. item_count .. " = ",
        coin_tiers.base_coin_value_to_text(item_count * scaled_value, false, nil)
    }
end

function core_gui.give_productivity_tooltip(element, trade, quality, quality_cost_mult)
    quality = quality or "normal"
    quality_cost_mult = quality_cost_mult or 1

    local s = {"",
        trades.get_total_values_str(trade, quality, quality_cost_mult),
    }

    if trades.is_interplanetary_trade(trade) then
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

function core_gui.add_titlebar(frame, caption)
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

    local close_button = titlebar.add{
        type = "sprite-button",
        name = "frame-close-button",
        style = "frame_action_button",
        sprite = "utility/close",
        hovered_sprite = "utility/close_black",
        clicked_sprite = "utility/close_black",
        tooltip = {"gui.close-instruction"},
    }

    gui_events.register(close_button, "on-clicked", function()
        local player = core_gui.get_player_from_element(frame)
        gui_events.trigger(player, frame, "on-closed")
    end)
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

function core_gui.create_quality_dropdown(parent, name, selected_index)
    local quality_locales = {}
    for quality_name, _ in pairs(prototypes.quality) do
        if quality_name ~= "quality-unknown" then
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
        left_half = true
    elseif trades.get_total_sold(item_name) > 0 then
        left_half = false
    end

    return left_half
end



return core_gui
