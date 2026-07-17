
-- Utility functions for map generation settings data

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



return mgs_util
