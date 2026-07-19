
-- Utility functions for map generation settings data

local lib = require "api.lib"

local mgs_util = {}



---Set frequency, richness, and size to zero across a list of objects in autoplace controls or autoplace settings.
---@param autoplace_controls {[string]: AutoplaceControl}
---@param keys string[]
function mgs_util.zero_freq_rich_size(autoplace_controls, keys)
    for _, key in pairs(keys) do
        local autoplace_control = autoplace_controls[key]
        if autoplace_control then
            if key ~= "water" then
                -- Exclude water frequency to prevent division-by-zero crashes in noise expressions.
                autoplace_control.frequency = 0
            end

            autoplace_control.richness = 0
            autoplace_control.size = 0
        end
    end
end

---Safely retrieve autoplace controls from MapGenSettings, for compatibility with mods that remove vanilla settings.
---@param mgs MapGenSettings
---@param key string
---@return AutoplaceControl|FrequencySizeRichness
function mgs_util.get_autoplace_control(mgs, key)
    return mgs.autoplace_controls[key] or {frequency = 0, size = 0, richness = 0}
end

---Sum up the total normalized setting value of a target metric (frequency, size, or richness) across multiple keys (iron ore, copper ore, etc)
---@param mgs MapGenSettings
---@param target "frequency"|"size"|"richness"
---@param keys string[]
---@return number
function mgs_util.sum_mgs(mgs, target, keys)
    local sum = 0
    for _, key in pairs(keys) do
        if not mgs[key] then
            lib.log_error("mgs_util.sum_mgs: key \"" .. key .. "\" not found in " .. serpent.line(mgs))
        elseif not mgs[key][target] then
            lib.log_error("mgs_util.sum_mgs: target \"" .. target .. "\" not found in " .. serpent.line(mgs[key]))
        else
            sum = sum + mgs_util.remap_map_gen_setting(mgs[key][target])
        end
    end
    return sum
end

---Turn a map gen setting between 0.16667 and 6 into a number between 0 and 1, or to a specified range
---@param x number|nil
---@param to_min number|nil
---@param to_max number|nil
---@return number
function mgs_util.remap_map_gen_setting(x, to_min, to_max)
    if not x then return ((to_min or 0) + (to_max or 1)) * 0.5 end
    local v = math.log(x, 6) * 0.5 + 0.5
    if to_min and to_max then
        return to_min + (to_max - to_min) * v
    end
    return v
end



return mgs_util
