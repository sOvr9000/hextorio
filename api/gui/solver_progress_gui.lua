
local lib = require "api.lib"
local event_system = require "api.event_system"
local item_value_solver = require "api.item_value_solver"
local hud_gui = require "api.gui.hud_gui"

local solver_progress_gui = {}



function solver_progress_gui.register_events()
    event_system.register("item-value-solver-started", solver_progress_gui.update_progress)
    event_system.register("item-value-solver-progress", solver_progress_gui.update_progress)
    event_system.register("item-value-solver-aborted", solver_progress_gui.on_solver_ended)
    event_system.register("item-values-recalculated", solver_progress_gui.on_solver_ended)
end

---@param player LuaPlayer|nil
function solver_progress_gui.reinitialize(player)
    if not player then
        for _, p in pairs(game.connected_players) do
            solver_progress_gui.reinitialize(p)
        end
        return
    end

    solver_progress_gui.init_solver_progress_gui(player)
end

---@param player LuaPlayer
function solver_progress_gui.init_solver_progress_gui(player)
    local hud = hud_gui.get_hud_gui(player)
    local frame = hud["item-value-solver-progress"]
    if frame then frame.destroy() return end

    frame = hud.add {
        type = "frame",
        name = "item-value-solver-progress",
        direction = "vertical",
    }
    frame.style.width = 400
    frame.visible = false

    local header = frame.add {
        type = "label",
        name = "header",
        caption = {"hextorio-gui.solver-progress-header"},
    }
    header.style.font_color = {1, 1, 0.8}
    header.style.font = "count-font"
    header.style.horizontal_align = "center"
    header.style.width = 360

    local metrics_flow = frame.add {
        type = "flow",
        name = "metrics",
        direction = "horizontal",
    }

    local percentage = metrics_flow.add {
        type = "label",
        name = "percentage",
        caption = "0%",
    }
    percentage.style.font_color = {1, 1, 0.45}
    percentage.style.font = "count-font"
    percentage.style.horizontal_align = "center"
    percentage.style.width = 180

    local time_remaining = metrics_flow.add {
        type = "label",
        name = "time-remaining",
        caption = lib.ticks_to_string(99999),
    }
    time_remaining.style.font_color = {1, 1, 0.45}
    time_remaining.style.font = "count-font"
    time_remaining.style.horizontal_align = "center"
    time_remaining.style.width = 180

    local progress_bar = frame.add {
        type = "progressbar",
        name = "progress-bar",
        value = 0,
    }
    progress_bar.style.color = {1, 1, 0.2}
    progress_bar.style.horizontally_stretchable = true
end

---@param player LuaPlayer|nil
function solver_progress_gui.update_progress(player)
    if not player then
        for _, _player in pairs(game.connected_players) do
            solver_progress_gui.update_progress(_player)
        end
        return
    end

    local hud = hud_gui.get_hud_gui(player)
    local frame = hud["item-value-solver-progress"]
    if not frame then
        solver_progress_gui.init_solver_progress_gui(player)
        frame = hud["item-value-solver-progress"]
    end

    local metrics = frame.metrics
    local label_percentage = metrics.percentage
    local label_time_remaining = metrics["time-remaining"]
    local progress_bar = frame["progress-bar"]

    local percentage, ticks_remaining = item_value_solver.get_progress()
    progress_bar.value = percentage
    label_percentage.caption = lib.format_percentage(percentage, 2, true, false)
    label_time_remaining.caption = lib.ticks_to_string(ticks_remaining)

    frame.visible = true
end

function solver_progress_gui.on_solver_ended()
    for _, player in pairs(game.players) do
        local hud = hud_gui.get_hud_gui(player)
        local frame = hud["item-value-solver-progress"]
        if frame then
            frame.visible = false
        end
    end
end



return solver_progress_gui
