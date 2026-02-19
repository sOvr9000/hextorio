
local lib = require "api.lib"
local core_gui = require "api.gui.core_gui"
local gui_stack = require "api.gui.gui_stack"
local event_system = require "api.event_system"

local intro_gui = {}



function intro_gui.register_events()
    event_system.register_gui("gui-closed", "hextorio-intro", function(player, elem)
        local frame = player.gui.screen["hextorio-intro"]
        if frame and frame.valid then
            gui_stack.pop(player, gui_stack.index_of(player, frame))
            player.mod_settings["hextorio-show-intro"] = {value = false}
        end
    end)

    event_system.register("player-joined", function(player)
        if storage.initialization and not storage.initialization.has_game_started then return end
        intro_gui.show_once(player)
    end)

    event_system.register("game-started", function()
        for _, player in pairs(game.connected_players) do
            intro_gui.show_once(player)
        end
    end)

    event_system.register("runtime-setting-changed-show-intro", function(player_index)
        local player = game.get_player(player_index)
        if not player then return end
        if not lib.player_setting_value_as_boolean(player, "show-intro") then return end

        intro_gui.show(player)
    end)
end

---Show the Hextorio intro GUI to a player.
---@param player LuaPlayer
function intro_gui.show(player)
    local frame = player.gui.screen["hextorio-intro"]
    if frame and frame.valid then
        frame.destroy()
    end

    local intro_gui_storage = storage.intro_gui
    if not intro_gui_storage then
        lib.log_error("intro_gui.show: Could not find intro GUI data storage")
        return
    end

    local intro_steps = intro_gui_storage.intro_steps
    if not intro_steps then
        lib.log_error("intro_gui.show: Could not find intro GUI step data")
        return
    end

    local display_density_scale = player.display_density_scale

    frame = player.gui.screen.add {
        type = "frame",
        name = "hextorio-intro",
        direction = "vertical",
    }
    frame.style.width = 800 / display_density_scale
    frame.style.height = 350 / display_density_scale
    core_gui.add_titlebar(frame, {"hextorio-gui.intro"})

    local scroll_pane = frame.add {
        type = "scroll-pane",
        name = "steps",

        horizontal_scroll_policy = "always",
        vertical_scroll_policy = "never",

        -- This has no effect for some reason.
        -- direction = "horizontal",
    }

    -- An attempt to make direction = "horizontal" have an effect.
    -- scroll_pane.horizontal_scroll_policy = "always"
    -- scroll_pane.vertical_scroll_policy = "never"

    scroll_pane.style.horizontally_stretchable = true
    scroll_pane.style.top_padding = 10 / display_density_scale

    -- This wrapper flow is necessary to prevent the scroll pane from stacking children vertically, since direction = "horizontal" has no effect.
    local scroll_flow = scroll_pane.add {
        type = "flow",
        name = "flow",
        direction = "horizontal",
    }

    for _, step_name in pairs(intro_steps) do
        intro_gui.add_intro_step(scroll_flow, step_name, display_density_scale)
    end

    frame.force_auto_center()

    gui_stack.add(player, frame)
end

---Add an intro step to the intro GUI.
---@param flow LuaGuiElement
---@param step_name string
---@param display_density_scale number
function intro_gui.add_intro_step(flow, step_name, display_density_scale)
    local sprite_path = "intro-step-" .. step_name
    if not helpers.is_valid_sprite_path(sprite_path) then
        lib.log_error("intro_gui.add_intro_step: Sprite path " .. sprite_path .. " is invalid")
        return
    end

    local is_first = #flow.children == 0

    if not is_first then
        flow.add {
            type = "line",
            direction = "vertical",
        }
    end

    local step_flow = flow.add {
        type = "flow",
        name = "step-" .. step_name,
        direction = "vertical",
    }

    local image = step_flow.add {
        type = "sprite",
        name = "image",
        sprite = sprite_path,
    }
    image.style.stretch_image_to_widget_size = true
    image.style.left_margin = 50 / display_density_scale
    image.style.right_margin = 50 / display_density_scale
    image.style.size = 256 / 1.2 / display_density_scale

    local caption = core_gui.auto_center_horizontally(step_flow, {
        type = "label",
        name = "info",
        caption = lib.color_localized_string({"hextorio-intro-gui-caption." .. step_name}, "white", "heading-2"),
    })
    caption.style.single_line = false
    caption.style.horizontal_align = "center"
end

---Show the Hextorio intro GUI to a player if it hasn't been shown to them previously in the save.
---@param player LuaPlayer
function intro_gui.show_once(player)
    local intro_gui_storage = storage.intro_gui
    if not intro_gui_storage then
        lib.log_error("intro_gui: Could not find intro GUI data storage")
        return
    end

    local players_is_first_join = intro_gui_storage.is_first_join
    if not players_is_first_join then
        players_is_first_join = {}
        intro_gui_storage.is_first_join = players_is_first_join
    end

    if not players_is_first_join[player.index] then
        intro_gui.show(player)
        players_is_first_join[player.index] = true
    end
end



return intro_gui
