
-- e ^ (3 + scaling_rate * (sb_tier - 1)) = max_sb_health
-- ln(max_sb_health) = 3 + scaling_rate * (sb_tier - 1)
-- (ln(max_sb_health) - 3) / scaling_rate + 1 = sb_tier

local max_sb_health = 50000000
local scaling_rate = 0.5
local max_tier = math.floor((math.log(max_sb_health) - 3) / scaling_rate - 0.5)

return {
    max_tier = max_tier,
}
