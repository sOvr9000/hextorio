
local core_gui = require "api.gui.core_gui"
local coin_tiers = require "api.coin_tiers"

local coin_tier_gui = {}



function coin_tier_gui.create_coin_tier(parent, name)
    local flow = parent.add {type = "flow", direction = "horizontal"}
    flow.style.horizontal_spacing = 8
    flow.name = name or "coins"

    local hex_coin_sprite = flow.add {type = "sprite-button", sprite = "hex-coin"}
    hex_coin_sprite.name = "hex-coin"
    hex_coin_sprite.style.width = 40
    hex_coin_sprite.style.height = 40
    hex_coin_sprite.number = 1

    local gravity_coin_sprite = flow.add {type = "sprite-button", sprite = "gravity-coin"}
    gravity_coin_sprite.name = "gravity-coin"
    gravity_coin_sprite.style.width = 40
    gravity_coin_sprite.style.height = 40
    gravity_coin_sprite.number = 0

    local meteor_coin_sprite = flow.add {type = "sprite-button", sprite = "meteor-coin"}
    meteor_coin_sprite.name = "meteor-coin"
    meteor_coin_sprite.style.width = 40
    meteor_coin_sprite.style.height = 40
    meteor_coin_sprite.number = 0

    local hexaprism_coin_sprite = flow.add {type = "sprite-button", sprite = "hexaprism-coin"}
    hexaprism_coin_sprite.name = "hexaprism-coin"
    hexaprism_coin_sprite.style.width = 40
    hexaprism_coin_sprite.style.height = 40
    hexaprism_coin_sprite.number = 0

    return flow
end

function coin_tier_gui.update_coin_tier(flow, coin)
    -- Don't show any zeros unless it's a total of zero coins.
    local coin_names = {"hex-coin", "gravity-coin", "meteor-coin", "hexaprism-coin"}
    for i = 1, 4 do
        local coin_sprite = flow[coin_names[i]]
        if coin.values[i] > 0 then
            coin_sprite.number = coin.values[i]
            coin_sprite.visible = true
            core_gui.try_give_coin_tooltip(coin_sprite)
        else
            coin_sprite.visible = false
        end
    end

    if coin_tiers.is_zero(coin) then
        flow['hex-coin'].visible = true
        flow['hex-coin'].number = 0
    end
end



return coin_tier_gui
