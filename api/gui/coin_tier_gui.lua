
local core_gui = require "api.gui.core_gui"
local coin_tiers = require "api.coin_tiers"

local coin_tier_gui = {}



---Create a flow containing sprite buttons for the different tiers of coins.
---@param parent LuaGuiElement
---@param name string|nil The name of the created and returned flow element containing sprite buttons for coins. Defaults to "coins" if not provided.
---@return LuaGuiElement
function coin_tier_gui.create_coin_tier(parent, name)
    local flow = parent.add {type = "flow", direction = "horizontal"}
    flow.style.horizontal_spacing = 8
    flow.name = name or "coins"

    for i, coin_name in ipairs(storage.coin_tiers.COIN_NAMES) do
        local coin_sprite = flow.add {type = "sprite-button", sprite = coin_name}
        coin_sprite.name = coin_name
        coin_sprite.style.width = 40
        coin_sprite.style.height = 40

        if i == 1 then
            coin_sprite.number = 1
        else
            coin_sprite.number = 0
        end
    end

    return flow
end

---Update a coin tier flow's sprite buttons to show numbers matching the Coin object's values.
---@param flow LuaGuiElement
---@param coin Coin
---@param show_trailing_zeros boolean|nil Whether to show zeroes after the leading coin tier.  Defaults to false.
function coin_tier_gui.update_coin_tier(flow, coin, show_trailing_zeros)
    local visible = false
    for i = #storage.coin_tiers.COIN_NAMES, 1, -1 do
        local coin_name = storage.coin_tiers.COIN_NAMES[i]
        local coin_sprite = flow[coin_name]

        if show_trailing_zeros then
            visible = visible or coin.values[i] > 0
        else
            visible = coin.values[i] > 0
        end

        coin_sprite.visible = visible

        if visible then
            coin_sprite.number = coin.values[i]
            core_gui.try_give_coin_tooltip(coin_sprite)
        end
    end

    if coin_tiers.is_zero(coin) then
        flow["hex-coin"].visible = true
        flow["hex-coin"].number = 0
    end
end



return coin_tier_gui
