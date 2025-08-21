-- Dungeons are cleared way too easily using atomic bombs.
-- This needs to be done because we can't have any "I WIN" buttons before you're even 20% of the way through the game progression.

local lib = require "api.lib"

local damage_mult = lib.startup_setting_value "atomic-bomb-damage-multiplier"

local atomic_rocket = data.raw["projectile"]["atomic-rocket"]


local to_adjust = {}
local total_recs = 0


local function damage_update(current_path, key, value)
    -- log(table.concat(current_path, "."))
    if #current_path >= 2 and current_path[#current_path - 1] == "damage" and key == "amount" then
        return value * damage_mult
    end
    if #current_path >= 2 and current_path[#current_path - 1] == "action_delivery" and key == "projectile" then
        to_adjust[value] = true
    end
    return value
end

local function rec_damage_update()
    total_recs = total_recs + 1
    if total_recs > 10 then
        log("recursion limit exceeded")
        return
    end

    if next(to_adjust) then
        for proj, _ in pairs(to_adjust) do
            to_adjust[proj] = nil
            local prot = data.raw["projectile"][proj]
            if prot then
                lib.apply_to_table_with_path(prot, damage_update)
            end
        end

        rec_damage_update()
    end
end


lib.apply_to_table_with_path(atomic_rocket, damage_update)
rec_damage_update()


